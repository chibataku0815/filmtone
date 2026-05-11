import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
import Foundation

enum FilmtoneVideoReaderError: Error {
    case readerSetupFailed(URL, underlying: Error?)
    case unsupportedPixelFormat(URL)
    case unsupportedAudioTrack(URL)
    case readerStartFailed(URL, underlying: Error?)
    case readerFailedDuringRead(URL, underlying: Error?)
}

// AVAssetReader wrapper that yields decoded frames as
// `(CMSampleBuffer, CVPixelBuffer)` pairs. Lifted from iOS
// `FilmtoneExportSession.makeVideoReaderOutput(...)` (lines 1300-1330) but
// limited to canonical 32BGRA (no ProRes / 422YpCbCr16 fallback — Phase 2
// will reintroduce when the source profile catalog ports).
//
// Phase 2 C1+C2: receives a fully-loaded `FilmtoneVideoTrackProbe` rather
// than discovering the track via the deprecated synchronous
// `asset.tracks(withMediaType:)`. The prober ran modern async loaders
// (`asset.loadTracks` / `track.load(.naturalSize)` / `.preferredTransform` /
// `.nominalFrameRate` / `.duration`) so this initializer remains throwing-
// sync — no Sendable / actor-isolation churn for the per-frame read loop.
//
// `@unchecked Sendable` mirroring FilmtoneVideoWriter: used from a single
// Task in the exporter; Phase 2+ will revisit isolation alongside IOSurface-
// backed Metal compute.
final class FilmtoneVideoReader: @unchecked Sendable {
    let sourceURL: URL
    let durationSeconds: Double
    let naturalSize: CGSize
    let preferredTransform: CGAffineTransform
    let nominalFrameRate: Float

    private let asset: AVURLAsset
    private let reader: AVAssetReader
    private let trackOutput: AVAssetReaderTrackOutput
    private let audioOutput: AVAssetReaderTrackOutput?

    init(
        probe: FilmtoneVideoTrackProbe,
        contract: FilmtoneColorPipelineContract,
        preserveAudio: Bool = false
    ) throws {
        let sourceURL = probe.asset.url
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: probe.asset)
        } catch {
            throw FilmtoneVideoReaderError.readerSetupFailed(sourceURL, underlying: error)
        }

        let trackOutput = AVAssetReaderTrackOutput(
            track: probe.track,
            outputSettings: contract.videoReaderOutputSettings(
                pixelFormat: kCVPixelFormatType_32BGRA
            )
        )
        trackOutput.alwaysCopiesSampleData = false

        guard reader.canAdd(trackOutput) else {
            throw FilmtoneVideoReaderError.unsupportedPixelFormat(sourceURL)
        }
        reader.add(trackOutput)

        let audioOutput: AVAssetReaderTrackOutput?
        if preserveAudio, let audioTrack = probe.audioTrack {
            let output = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                ]
            )
            guard reader.canAdd(output) else {
                throw FilmtoneVideoReaderError.unsupportedAudioTrack(sourceURL)
            }
            reader.add(output)
            audioOutput = output
        } else {
            audioOutput = nil
        }

        self.sourceURL = sourceURL
        self.asset = probe.asset
        self.reader = reader
        self.trackOutput = trackOutput
        self.audioOutput = audioOutput
        self.durationSeconds = probe.durationSeconds
        self.naturalSize = probe.naturalSize
        self.preferredTransform = probe.preferredTransform
        self.nominalFrameRate = probe.nominalFrameRate
    }

    func start() throws {
        guard reader.startReading() else {
            throw FilmtoneVideoReaderError.readerStartFailed(
                sourceURL,
                underlying: reader.error
            )
        }
    }

    // Returns `nil` once the reader has drained all sample buffers.
    func nextSampleBuffer() throws -> (sampleBuffer: CMSampleBuffer, pixelBuffer: CVPixelBuffer)? {
        guard let sample = trackOutput.copyNextSampleBuffer() else {
            switch reader.status {
            case .completed:
                return nil
            case .failed, .cancelled:
                throw FilmtoneVideoReaderError.readerFailedDuringRead(
                    sourceURL,
                    underlying: reader.error
                )
            default:
                return nil
            }
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
            return nil
        }
        return (sample, pixelBuffer)
    }

    func nextAudioSampleBuffer() throws -> CMSampleBuffer? {
        guard let audioOutput else {
            return nil
        }
        guard let sample = audioOutput.copyNextSampleBuffer() else {
            switch reader.status {
            case .completed:
                return nil
            case .failed, .cancelled:
                throw FilmtoneVideoReaderError.readerFailedDuringRead(
                    sourceURL,
                    underlying: reader.error
                )
            default:
                return nil
            }
        }
        return sample
    }

    func cancel() {
        reader.cancelReading()
    }

    var estimatedFrameCount: Int {
        guard durationSeconds > 0, nominalFrameRate > 0 else { return 0 }
        return Int((Double(nominalFrameRate) * durationSeconds).rounded())
    }

    var hasAudioOutput: Bool {
        audioOutput != nil
    }

    var displaySize: CGSize {
        let rect = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }
}
