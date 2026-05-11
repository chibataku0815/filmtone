import CoreImage
import CoreVideo
import Foundation
import ImageIO
import simd

/// Source provenance of a depth payload. v1.3 ships only AVDepthData (HEIC
/// auxiliary disparity/depth). Phase B reserves a Core ML Depth-Anything-v2
/// path; placeholders are intentionally absent until that lane lands so we
/// don't bake speculative cases into the wire/sidecar vocabulary.
enum DepthSource: String, Codable {
    case avDepthData = "avDepthData"
    // Phase B (post-v1.3): case coreMLDepthAnyV2
}

/// Normalized, orientation-aware depth payload consumed by the v1.3 native
/// renderer.
///
/// Conventions (plan §6.1):
/// - `pixelBuffer` is `kCVPixelFormatType_OneComponent32Float`.
/// - Values are linearly normalized into `[0, 1]` where `0` = nearest pixel
///   in the source frame and `1` = farthest. Renderer can invert as needed.
/// - `orientation` mirrors the source `CGImagePropertyOrientation` so the
///   depth grid aligns with the source CIImage in its natural orientation.
/// - `intrinsics` is opaque to v1.3 callers; held for Phase B normal
///   derivation (camera-space ray reconstruction).
struct FilmtoneDepthMap {
    let width: Int
    let height: Int
    let orientation: CGImagePropertyOrientation
    let pixelBuffer: CVPixelBuffer
    let source: DepthSource
    let intrinsics: simd_float3x3?

    /// CIImage view of the depth grid, with the source orientation applied so
    /// it composes against a CIImage built from the same source asset in its
    /// natural orientation.
    var ciImage: CIImage {
        CIImage(cvPixelBuffer: pixelBuffer)
            .oriented(orientation)
    }
}
