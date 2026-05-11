import AVFoundation
import Foundation

/// Phase 2B-10C: audio export queue body owner lifted out of
/// `FilmtoneExportSession.exportVideo(...)`. Owns the per-call audio
/// sample pull, reader-failure check, AAC append (delegated to
/// `ExportMediaWriter`), and finish / failure routing through the
/// shared `ExportVideoCompletionCoordinator`.
///
/// The session only instantiates and starts the pump when both
/// `audioInput` and `audioOutput` are non-nil — the audio preservation
/// gate (`highlightTimeline == nil && request.output.preserveAudio`)
/// stays on the session.
///
/// Behavior preserved verbatim from the inline body:
/// - stop when a captured error already exists, finishing the audio
///   input with `markAsFinished: true`
/// - pull `audioOutput.copyNextSampleBuffer()`; on nil with a failed
///   reader, throw `FilmtoneMediaError.exportFailed(reader.error?...)`;
///   on nil with a non-failed reader, finish the audio input
/// - append through `ExportMediaWriter.appendAudioSample` with
///   `waitForReady: false`
/// - on any thrown error, route through `completion.failExport(_)`
final class ExportVideoAudioPump {
    private let audioInput: AVAssetWriterInput
    private let audioOutput: AVAssetReaderTrackOutput
    private let reader: AVAssetReader
    private let writer: AVAssetWriter
    private let audioQueue: DispatchQueue
    private let mediaWriter: ExportMediaWriter
    private let completion: ExportVideoCompletionCoordinator

    init(
        audioInput: AVAssetWriterInput,
        audioOutput: AVAssetReaderTrackOutput,
        reader: AVAssetReader,
        writer: AVAssetWriter,
        audioQueue: DispatchQueue,
        mediaWriter: ExportMediaWriter,
        completion: ExportVideoCompletionCoordinator
    ) {
        self.audioInput = audioInput
        self.audioOutput = audioOutput
        self.reader = reader
        self.writer = writer
        self.audioQueue = audioQueue
        self.mediaWriter = mediaWriter
        self.completion = completion
    }

    func start(checkCancelled: @escaping () throws -> Void) {
        audioInput.requestMediaDataWhenReady(on: audioQueue) { [self] in
            while audioInput.isReadyForMoreMediaData {
                if completion.hasCapturedError {
                    completion.finishAudioInput(markAsFinished: true)
                    return
                }

                do {
                    try checkCancelled()
                    guard let sampleBuffer = audioOutput.copyNextSampleBuffer() else {
                        if reader.status == .failed {
                            throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "Audio read failed.")
                        }
                        completion.finishAudioInput(markAsFinished: true)
                        return
                    }

                    try mediaWriter.appendAudioSample(
                        sampleBuffer,
                        audioInput: audioInput,
                        writer: writer,
                        reader: reader,
                        waitForReady: false,
                        checkCancelled: checkCancelled
                    )
                } catch {
                    completion.failExport(error)
                    return
                }
            }
        }
    }
}
