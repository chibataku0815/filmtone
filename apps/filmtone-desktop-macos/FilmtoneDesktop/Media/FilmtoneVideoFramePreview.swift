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
    // Extracts a midpoint frame as CIImage. Per master handoff §13 #1
    // (`midpoint`). Uses macOS 13+ async API
    // `AVAssetImageGenerator.image(at:)` so we no longer trip the
    // `copyCGImage(at:actualTime:)` deprecation warning. Falls back from
    // zero tolerance to 0.5s tolerance to mirror iOS
    // `copyPreviewCGImage(...)` recovery (FilmtoneExportSession.swift:
    // 1254-1262).
    static func loadMidpointFrame(from sourceURL: URL) async throws -> FilmtoneVideoFramePreview {
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
        let posterSec = midpoint(durationSec: durationSec)
        let posterCMTime = CMTime(seconds: posterSec, preferredTimescale: 600)

        let cgImage: CGImage
        do {
            cgImage = try await copyCGImage(
                asset: asset,
                time: posterCMTime,
                tolerance: .zero
            )
        } catch {
            do {
                cgImage = try await copyCGImage(
                    asset: asset,
                    time: posterCMTime,
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
            posterTimeSeconds: posterSec
        )
    }

    private static func midpoint(durationSec: Double) -> Double {
        guard durationSec.isFinite, durationSec > 0 else { return 0 }
        return durationSec * 0.5
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
