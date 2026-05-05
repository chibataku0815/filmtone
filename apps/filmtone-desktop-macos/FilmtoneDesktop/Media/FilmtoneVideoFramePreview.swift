import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import Foundation

enum FilmtoneVideoFramePreviewError: Error {
    case missingVideoTrack(URL)
    case generatorFailed(URL, underlying: Error?)
}

struct FilmtoneVideoFramePreview {
    let image: CIImage
    let durationSeconds: Double
    let naturalSize: CGSize
    let preferredTransform: CGAffineTransform
    let posterTimeSeconds: Double
}

enum FilmtoneVideoFramePreviewLoader {
    /// Extracts a frame at `seconds` from the start of `sourceURL`. M5-A.3
    /// scrub callers pass the scrub-bar value here; `loadMidpointFrame`
    /// is the legacy entry that defaults `seconds` to duration × 0.5.
    /// Falls back from zero tolerance to 0.5 s tolerance to mirror iOS
    /// `copyPreviewCGImage(...)` recovery (FilmtoneExportSession.swift:
    /// 1254-1262). Uses macOS 13+ async `AVAssetImageGenerator.image(at:)`.
    static func loadFrame(
        from sourceURL: URL,
        atSeconds seconds: Double
    ) async throws -> FilmtoneVideoFramePreview {
        let asset = AVURLAsset(url: sourceURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw FilmtoneVideoFramePreviewError.missingVideoTrack(sourceURL)
        }

        // AVAssetTrack is not Sendable, so we cannot fan out into multiple
        // `async let`s — Swift 6 flags the cross-Task capture as a data race.
        // The variadic `load(_:_:)` overload from AVAsynchronousKeyValueLoading
        // resolves both keys on a single underlying request without splitting
        // ownership.
        let (resolvedSize, resolvedTransform) = try await videoTrack.load(
            .naturalSize,
            .preferredTransform
        )
        let durationCMTime = try await asset.load(.duration)
        let durationSec = max(0, CMTimeGetSeconds(durationCMTime))
        let clampedSec = clamp(seconds: seconds, durationSec: durationSec)
        let frameCMTime = CMTime(seconds: clampedSec, preferredTimescale: 600)

        let cgImage: CGImage
        do {
            cgImage = try await copyCGImage(
                asset: asset,
                time: frameCMTime,
                tolerance: .zero
            )
        } catch {
            do {
                cgImage = try await copyCGImage(
                    asset: asset,
                    time: frameCMTime,
                    tolerance: CMTime(seconds: 0.5, preferredTimescale: 600)
                )
            } catch let fallbackError {
                throw FilmtoneVideoFramePreviewError.generatorFailed(
                    sourceURL,
                    underlying: fallbackError
                )
            }
        }

        return FilmtoneVideoFramePreview(
            image: CIImage(cgImage: cgImage),
            durationSeconds: durationSec,
            naturalSize: resolvedSize,
            preferredTransform: resolvedTransform,
            posterTimeSeconds: clampedSec
        )
    }

    /// Per master handoff §13 #1 (`midpoint`). Resolves duration first
    /// then delegates to `loadFrame(from:atSeconds:)`. Used by callers
    /// that have not yet probed duration (open-time first frame).
    static func loadMidpointFrame(from sourceURL: URL) async throws -> FilmtoneVideoFramePreview {
        let asset = AVURLAsset(url: sourceURL)
        let durationCMTime = try await asset.load(.duration)
        let durationSec = max(0, CMTimeGetSeconds(durationCMTime))
        return try await loadFrame(
            from: sourceURL,
            atSeconds: midpoint(durationSec: durationSec)
        )
    }

    /// Resolves video duration without decoding any frames. Used by
    /// `EditorState` on `setSource(.video)` to seed the scrub bar range.
    static func loadDurationSeconds(from sourceURL: URL) async throws -> Double {
        let asset = AVURLAsset(url: sourceURL)
        let durationCMTime = try await asset.load(.duration)
        return max(0, CMTimeGetSeconds(durationCMTime))
    }

    private static func midpoint(durationSec: Double) -> Double {
        guard durationSec.isFinite, durationSec > 0 else { return 0 }
        return durationSec * 0.5
    }

    private static func clamp(seconds: Double, durationSec: Double) -> Double {
        guard seconds.isFinite, durationSec.isFinite, durationSec > 0 else {
            return 0
        }
        return min(max(seconds, 0), durationSec)
    }

    private static func copyCGImage(
        asset: AVAsset,
        time: CMTime,
        tolerance: CMTime
    ) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        let (image, _) = try await generator.image(at: time)
        return image
    }
}
