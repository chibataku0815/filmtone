import CoreImage
import Foundation

// M5-J.2 Before/After compare compositor.
//
// Pure CoreImage helper shared by the still preview path
// (PreviewSurface.renderToNSImage) and the AVPlayer video composition
// handler (FilmtoneDesktopVideoComposition). Composes a left=source /
// right=graded split at a fixed fraction of the graded canvas extent.
// `splitAt` is clamped to [0, 1]. The source CIImage is rescaled so its
// extent matches the graded canvas before splitting — required because
// the still load path and the video sourceImage may carry their original
// pixel extent rather than the graded preview canvas.

enum FilmtoneCompareCompose {

    /// Compose a 2-pane split image whose left pane shows `source` and
    /// whose right pane shows `graded`. The split is at
    /// `graded.extent.minX + graded.extent.width * clamp(splitAt, 0, 1)`.
    /// Returns `graded` unchanged when the canvas is degenerate (zero
    /// width/height) or when `source` has no usable extent.
    static func makeSplit(
        source: CIImage,
        graded: CIImage,
        splitAt: CGFloat
    ) -> CIImage {
        let canvas = graded.extent
        guard canvas.width > 0, canvas.height > 0 else { return graded }
        let clampedSplit = max(0, min(1, splitAt))
        let rescaledSource = rescale(source: source, to: canvas)
        let splitX = canvas.minX + canvas.width * clampedSplit
        let leftRect = CGRect(
            x: canvas.minX,
            y: canvas.minY,
            width: max(0, splitX - canvas.minX),
            height: canvas.height
        )
        let rightRect = CGRect(
            x: splitX,
            y: canvas.minY,
            width: max(0, canvas.maxX - splitX),
            height: canvas.height
        )
        let leftPane = rescaledSource.cropped(to: leftRect)
        let rightPane = graded.cropped(to: rightRect)
        return leftPane.composited(over: rightPane)
    }

    /// Translate `source` so its origin sits at `(0, 0)` and scale it to
    /// fill `canvas`, then translate back to `canvas.origin` and crop to
    /// the canvas. No-op when the extents already coincide.
    static func rescale(source: CIImage, to canvas: CGRect) -> CIImage {
        guard source.extent.width > 0, source.extent.height > 0 else { return source }
        if source.extent == canvas { return source }
        let translated = source.transformed(
            by: CGAffineTransform(
                translationX: -source.extent.origin.x,
                y: -source.extent.origin.y
            )
        )
        let scaleX = canvas.width / max(1, translated.extent.width)
        let scaleY = canvas.height / max(1, translated.extent.height)
        return translated
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(translationX: canvas.minX, y: canvas.minY))
            .cropped(to: canvas)
    }
}
