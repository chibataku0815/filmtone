import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import FilmLabSwiftCore
import Foundation

/// Phase 2B-7A: media writer / reader primitive collaborator lifted out
/// of `FilmtoneExportSession`. Owns writer construction, video input /
/// reader-output settings, audio pipeline construction, audio append,
/// finish/wait control, and CMTime helpers.
///
/// `exportVideo`, `exportStillImage`, `appendVideoSample`, and the render
/// path remain on `FilmtoneExportSession`. Cancellation is forwarded as a
/// closure (`checkCancelled`) so the session keeps ownership of the
/// `cancelled` flag.
///
/// Writer settings, reader pixel-format candidate order, audio settings,
/// the 15-second wait timeout, the 30-second finish timeout, and CMTime
/// math are preserved exactly from the pre-extraction `FilmtoneExportSession`
/// bodies.
final class ExportMediaWriter {
    private let outputURL: URL
    private let outputFPS: Int
    private let colorPipeline: FilmtoneColorPipelineContract

    init(
        outputURL: URL,
        outputFPS: Int,
        colorPipeline: FilmtoneColorPipelineContract
    ) {
        self.outputURL = outputURL
        self.outputFPS = outputFPS
        self.colorPipeline = colorPipeline
    }

    func makeWriter(outputSize: CGSize) throws -> AVAssetWriter {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        writer.movieFragmentInterval = .invalid
        return writer
    }

    func makeVideoInput(outputSize: CGSize) -> AVAssetWriterInput {
        let width = Int(outputSize.width.rounded())
        let height = Int(outputSize.height.rounded())
        let bitRate = max(width * height * 6, 3_000_000)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoExpectedSourceFrameRateKey: outputFPS,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAllowFrameReorderingKey: false,
            ],
            AVVideoColorPropertiesKey: colorPipeline.writerColorProperties,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        input.transform = .identity
        return input
    }

    func makeVideoReaderOutput(
        for track: AVAssetTrack,
        reader: AVAssetReader,
        codecFamily: SourceCodecFamilyDTO?
    ) -> (output: AVAssetReaderTrackOutput, degradedDecodePath: Bool)? {
        let candidates: [(pixelFormat: OSType, degraded: Bool)]
        if codecFamily == .prores422 {
            candidates = [
                (kCVPixelFormatType_422YpCbCr16, false),
                (kCVPixelFormatType_64RGBAHalf, true),
                (kCVPixelFormatType_32BGRA, true),
            ]
        } else {
            candidates = [
                (kCVPixelFormatType_32BGRA, false),
            ]
        }

        for candidate in candidates {
            let output = AVAssetReaderTrackOutput(
                track: track,
                outputSettings: colorPipeline.videoReaderOutputSettings(pixelFormat: candidate.pixelFormat)
            )
            output.alwaysCopiesSampleData = false
            if reader.canAdd(output) {
                return (output, candidate.degraded)
            }
        }

        return nil
    }

    func makeAudioPipeline(
        for track: AVAssetTrack
    ) -> (input: AVAssetWriterInput, output: AVAssetReaderTrackOutput) {
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
        )
        let input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVEncoderBitRateKey: 128_000,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44_100,
            ]
        )
        input.expectsMediaDataInRealTime = false
        return (input, output)
    }

    func appendAudioSample(
        _ sampleBuffer: CMSampleBuffer,
        audioInput: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader,
        waitForReady: Bool = true,
        checkCancelled: () throws -> Void
    ) throws {
        try autoreleasepool {
            if waitForReady {
                try waitUntilReadyForMoreMediaData(
                    audioInput,
                    writer: writer,
                    reader: reader,
                    label: "audio",
                    checkCancelled: checkCancelled
                )
            }

            if !audioInput.append(sampleBuffer) {
                throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "Audio samples could not be appended.")
            }
        }
    }

    func finish(
        writer: AVAssetWriter,
        checkCancelled: () throws -> Void
    ) throws {
        try checkCancelled()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        let waitResult = semaphore.wait(timeout: .now() + 30)
        if waitResult == .timedOut {
            writer.cancelWriting()
            throw FilmtoneMediaError.exportFailed("The writer did not finish output within the expected time.")
        }

        try checkCancelled()

        guard writer.status == .completed else {
            throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The export did not complete.")
        }
    }

    func waitUntilReadyForMoreMediaData(
        _ input: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader? = nil,
        label: String,
        checkCancelled: () throws -> Void
    ) throws {
        let startedWaitingAt = Date()
        while !input.isReadyForMoreMediaData {
            try checkCancelled()

            if let reader {
                switch reader.status {
                case .failed:
                    throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "The reader failed while waiting for media data.")
                case .cancelled:
                    throw FilmtoneMediaError.exportCancelled
                default:
                    break
                }
            }

            switch writer.status {
            case .failed:
                throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The writer failed while waiting for media data.")
            case .cancelled:
                throw FilmtoneMediaError.exportCancelled
            case .completed:
                throw FilmtoneMediaError.exportFailed("The writer completed before all media data was appended.")
            default:
                break
            }

            if Date().timeIntervalSince(startedWaitingAt) >= 15 {
                throw FilmtoneMediaError.exportFailed("The \(label) writer input stopped accepting media data.")
            }

            Thread.sleep(forTimeInterval: 0.002)
        }
    }

    static func validPresentationTime(for sampleBuffer: CMSampleBuffer) -> CMTime {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard time.isValid, time.isNumeric else {
            return .zero
        }
        return time
    }

    static func nonNegativeTime(_ time: CMTime) -> CMTime {
        guard time.isValid, time.isNumeric else {
            return .zero
        }
        return CMTimeCompare(time, .zero) < 0 ? .zero : time
    }

    static func absoluteSecondsBetween(_ lhs: CMTime, _ rhs: CMTime) -> Double {
        let seconds = abs(CMTimeGetSeconds(CMTimeSubtract(lhs, rhs)))
        return seconds.isFinite ? seconds : Double.greatestFiniteMagnitude
    }
}
