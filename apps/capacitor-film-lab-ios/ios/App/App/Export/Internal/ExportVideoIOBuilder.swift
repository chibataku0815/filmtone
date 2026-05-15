import AVFoundation
import CoreGraphics
import CoreVideo
import FilmLabSwiftCore
import Foundation

/// Phase 2B-10D: video export writer/reader setup lifted out of
/// `FilmtoneExportSession.exportVideo(...)`. Builds the AVAssetWriter,
/// video input, pixel-buffer adaptor, optional audio pipeline,
/// AVAssetReader, video reader output, and starts writing / reading
/// before the queue pumps spin up.
///
/// The session keeps owning mezzanine routing, asset / video-track
/// lookup, depth reader setup, timeline construction, queue pump
/// orchestration, `appendOutputFrame(...)`, post-wait finish, and
/// `CompletedExport` assembly. Video may be routed through a mezzanine, but
/// audio preservation reads from the original source asset so a video-only
/// mezzanine cannot silently strip source audio. The audio preservation gate
/// (`highlightTimeline == nil && request.output.preserveAudio`) is
/// applied here using the highlight timeline value passed in.
///
/// Order preserved verbatim from the inline setup block:
/// 1. compute `outputSize` via `ExportGeometry.scaledSize`
/// 2. create writer, video input, pixel-buffer adaptor
/// 3. guard `writer.canAdd(videoInput)`; throw
///    `"Video writer input could not be added."` if false
/// 4. `writer.add(videoInput)`
/// 5. resolve audio track only when highlight timeline is nil and
///    `request.output.preserveAudio` is true
/// 6. build audio pipeline; add audio input if `writer.canAdd(audioInput)`
/// 7. create a dedicated audio `AVAssetReader` from the original source asset
/// 8. `AVAssetReader(asset:)`
/// 9. `mediaWriter.makeVideoReaderOutput(for:reader:codecFamily:)`
/// 10. throw `"Video reader output could not be added."` if nil
/// 11. capture `degradedDecodePath`
/// 12. `reader.add(videoOutput)`
/// 13. guard `writer.startWriting()`; throw
///     `writer.error?.localizedDescription ?? "The writer failed to start."`
/// 14. guard `reader.startReading()`; throw
///     `reader.error?.localizedDescription ?? "The reader failed to start."`
/// 15. start the audio reader when present
/// 16. `writer.startSession(atSourceTime: .zero)`
final class ExportVideoIOBuilder {
    struct Context {
        let outputSize: CGSize
        let writer: AVAssetWriter
        let videoInput: AVAssetWriterInput
        let adaptor: AVAssetWriterInputPixelBufferAdaptor
        let audioInput: AVAssetWriterInput?
        let audioOutput: AVAssetReaderTrackOutput?
        let audioReader: AVAssetReader?
        let reader: AVAssetReader
        let videoOutput: AVAssetReaderTrackOutput
        let degradedDecodePath: Bool
    }

    private let request: Phase0ExportRequestDTO
    private let mediaWriter: ExportMediaWriter

    init(
        request: Phase0ExportRequestDTO,
        mediaWriter: ExportMediaWriter
    ) {
        self.request = request
        self.mediaWriter = mediaWriter
    }

    func makeContext(
        asset: AVURLAsset,
        audioAsset: AVURLAsset,
        videoTrack: AVAssetTrack,
        highlightTimeline: FilmtoneHighlightReelFrameTimeline?
    ) throws -> Context {
        let outputSize = ExportGeometry.scaledSize(for: videoTrack, longEdge: request.output.longEdge)
        let writer = try mediaWriter.makeWriter(outputSize: outputSize)
        let videoInput = mediaWriter.makeVideoInput(outputSize: outputSize)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(outputSize.width.rounded()),
                kCVPixelBufferHeightKey as String: Int(outputSize.height.rounded()),
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw FilmtoneMediaError.exportFailed("Video writer input could not be added.")
        }
        writer.add(videoInput)

        let audioTrack = highlightTimeline == nil && request.effectivePreserveAudio
            ? audioAsset.tracks(withMediaType: .audio).first
            : nil
        let audioInput: AVAssetWriterInput?
        let audioOutput: AVAssetReaderTrackOutput?
        let audioReader: AVAssetReader?
        if let audioTrack {
            let pair = mediaWriter.makeAudioPipeline(for: audioTrack)
            audioInput = pair.input
            audioOutput = pair.output
            guard writer.canAdd(pair.input) else {
                throw FilmtoneMediaError.exportFailed("Audio writer input could not be added.")
            }
            writer.add(pair.input)
        } else {
            audioInput = nil
            audioOutput = nil
        }

        if let audioOutput {
            let reader = try AVAssetReader(asset: audioAsset)
            guard reader.canAdd(audioOutput) else {
                throw FilmtoneMediaError.exportFailed("Audio reader output could not be added.")
            }
            reader.add(audioOutput)
            audioReader = reader
        } else {
            audioReader = nil
        }

        let reader = try AVAssetReader(asset: asset)
        let videoOutputSelection = mediaWriter.makeVideoReaderOutput(
            for: videoTrack,
            reader: reader,
            codecFamily: request.sourceProbe?.codecFamily ?? request.sourceProbe?.sourceVideoMetadata?.codecFamily
        )
        guard let videoOutputSelection else {
            throw FilmtoneMediaError.exportFailed("Video reader output could not be added.")
        }
        let videoOutput = videoOutputSelection.output
        let degradedDecodePath = videoOutputSelection.degradedDecodePath
        reader.add(videoOutput)

        guard writer.startWriting() else {
            throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The writer failed to start.")
        }
        guard reader.startReading() else {
            audioReader?.cancelReading()
            writer.cancelWriting()
            throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "The reader failed to start.")
        }
        if let audioReader {
            guard audioReader.startReading() else {
                reader.cancelReading()
                writer.cancelWriting()
                throw FilmtoneMediaError.exportFailed(audioReader.error?.localizedDescription ?? "The audio reader failed to start.")
            }
        }
        writer.startSession(atSourceTime: .zero)

        return Context(
            outputSize: outputSize,
            writer: writer,
            videoInput: videoInput,
            adaptor: adaptor,
            audioInput: audioInput,
            audioOutput: audioOutput,
            audioReader: audioReader,
            reader: reader,
            videoOutput: videoOutput,
            degradedDecodePath: degradedDecodePath
        )
    }
}
