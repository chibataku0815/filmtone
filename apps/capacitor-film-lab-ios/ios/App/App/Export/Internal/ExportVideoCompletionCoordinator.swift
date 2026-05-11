import AVFoundation
import Foundation

/// Phase 2B-10C: video export completion / failure lifecycle owner lifted
/// out of `FilmtoneExportSession.exportVideo(...)`. Owns the dispatch
/// group, completion / failure locks, finished flags, captured error,
/// input finishing, reader / writer cancellation on first failure,
/// waiting, and captured-error throw handoff. The session keeps owning
/// reader / writer setup, video sample decode, lookahead selection, depth
/// matching, timeline mapping, frame append, and audio append.
///
/// Semantics preserved from the previous inline implementation:
/// - first-error-wins: only the first `failExport` cancels reader/writer
///   and finishes both inputs with `markAsFinished: true`
/// - `finishVideoInput` / `finishAudioInput` are idempotent and leave the
///   dispatch group exactly once per entered side
/// - `finishAudioInput(markAsFinished:)` is a no-op when `audioInput`
///   was nil at init, before any lock is acquired
final class ExportVideoCompletionCoordinator {
    private let reader: AVAssetReader
    private let audioReader: AVAssetReader?
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput?

    private let completionLock = NSLock()
    private let failureLock = NSLock()
    private let dispatchGroup = DispatchGroup()
    private var videoInputFinished = false
    private var audioInputFinished: Bool
    private var capturedError: Error?

    init(
        reader: AVAssetReader,
        audioReader: AVAssetReader? = nil,
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        audioInput: AVAssetWriterInput?
    ) {
        self.reader = reader
        self.audioReader = audioReader
        self.writer = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.audioInputFinished = audioInput == nil
    }

    var hasCapturedError: Bool {
        failureLock.lock()
        defer { failureLock.unlock() }
        return capturedError != nil
    }

    func enterVideo() {
        dispatchGroup.enter()
    }

    func enterAudio() {
        dispatchGroup.enter()
    }

    func finishVideoInput(markAsFinished: Bool) {
        completionLock.lock()
        defer { completionLock.unlock() }
        guard !videoInputFinished else {
            return
        }
        if markAsFinished {
            videoInput.markAsFinished()
        }
        videoInputFinished = true
        dispatchGroup.leave()
    }

    func finishAudioInput(markAsFinished: Bool) {
        guard let audioInput else {
            return
        }

        completionLock.lock()
        defer { completionLock.unlock() }
        guard !audioInputFinished else {
            return
        }
        if markAsFinished {
            audioInput.markAsFinished()
        }
        audioInputFinished = true
        dispatchGroup.leave()
    }

    func failExport(_ error: Error) {
        failureLock.lock()
        let shouldStore = capturedError == nil
        if shouldStore {
            capturedError = error
        }
        failureLock.unlock()

        guard shouldStore else {
            return
        }

        reader.cancelReading()
        audioReader?.cancelReading()
        writer.cancelWriting()
        finishVideoInput(markAsFinished: true)
        finishAudioInput(markAsFinished: true)
    }

    func wait() {
        dispatchGroup.wait()
    }

    func throwCapturedErrorIfNeeded() throws {
        failureLock.lock()
        let error = capturedError
        failureLock.unlock()
        if let error {
            throw error
        }
    }
}
