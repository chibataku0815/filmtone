import AVFoundation
import CoreGraphics
import Foundation

/// Phase 2B-10D: output-size math lifted out of `FilmtoneExportSession`.
/// Owns the long-edge scaling formula used by video export, still export,
/// the mezzanine service, and the preview renderer.
///
/// Behavior preserved verbatim:
/// - `naturalSize.applying(preferredTransform)` then take `abs()` of both
///   components before scaling
/// - `width == 0` or `height == 0` returns `CGSize(width: longEdge, height: longEdge)`
/// - scale is `min(longEdge / maxEdge, 1.0)` — never upscale
/// - even-width/-height enforced via `Int(...) / 2 * 2`, minimum 2
enum ExportGeometry {
    static func scaledSize(for track: AVAssetTrack, longEdge: Int) -> CGSize {
        let transformed = track.naturalSize.applying(track.preferredTransform)
        let sourceSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        return scaledSize(for: sourceSize, longEdge: longEdge)
    }

    static func scaledSize(for sourceSize: CGSize, longEdge: Int) -> CGSize {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return CGSize(width: longEdge, height: longEdge)
        }

        let maxEdge = max(sourceSize.width, sourceSize.height)
        let scale = min(CGFloat(longEdge) / maxEdge, 1.0)
        let width = max(2, Int((sourceSize.width * scale).rounded()) / 2 * 2)
        let height = max(2, Int((sourceSize.height * scale).rounded()) / 2 * 2)
        return CGSize(width: width, height: height)
    }
}
