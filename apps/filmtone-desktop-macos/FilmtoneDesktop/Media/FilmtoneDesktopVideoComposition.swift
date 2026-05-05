import AVFoundation
import CoreImage
import CoreMedia
import FilmLabSwiftCore
import Foundation

// M5-I.2 AVPlayer preview route — composition factory.
//
// Given an asset + its video track + a snapshot of the user-driven render
// inputs, returns an `AVMutableVideoComposition` whose handler runs the
// Filmtone source-profile transform and grade pipeline once per composed
// frame. AVFoundation calls the handler on its private dispatch queue, so
// the handler must be free of any MainActor / non-Sendable capture.
//
// Render size is capped to 1280 long-edge after honoring the track's
// preferredTransform (vertical iPhone footage stays vertical), matching
// the iOS preview cost envelope. Grade math is identical to the still
// preview path; only the per-frame plumbing changes.

struct FilmtoneDesktopVideoRenderInputs: Sendable {
    let presetName: String
    let presetStrength: Double
    let lookSlug: String?
    let sourceProfileSelection: CameraProfileSelection
    let probedColorClass: SourceColorClassDTO?
    let quickState: FilmtoneQuickState
    let paramOverrides: FilmtonePhase0ParamsPatch
    /// M5-J.2: when true the composition handler emits a split
    /// (left = pre-transform source, right = graded) instead of the
    /// graded frame alone. Preview-only — never reaches the export path.
    let compareEnabled: Bool
    /// M5-K3: horizontal split position in [0, 1] used when
    /// `compareEnabled` is true. Pulled from `EditorState.compareSplit
    /// Fraction` so a video composition rebuild after a drag picks up
    /// the new fraction; defaults to mid-frame for fresh sessions.
    let compareSplitFraction: Double
    let sourceURL: URL
}

enum FilmtoneDesktopVideoComposition {

    static let previewLongEdge: CGFloat = 1280
    /// M5-K4: long-edge cap for scrub-thumbnail rendering. Far smaller than
    /// the live 1280 preview canvas so per-thumbnail grade cost stays
    /// negligible against the live AVPlayer GPU path. Owned here so the
    /// composition factory and the scrub-thumbnail provider agree without
    /// a cross-file constant import.
    static let thumbnailLongEdge: CGFloat = 240

    /// Build a graded video composition. Returns `nil` if the track is
    /// unusable (zero size etc.); caller falls back to no composition
    /// (raw playback) in that case.
    static func make(
        asset: AVAsset,
        videoTrack: AVAssetTrack,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        nominalFrameRate: Float,
        inputs: FilmtoneDesktopVideoRenderInputs
    ) -> AVMutableVideoComposition? {
        let renderSize = previewRenderSize(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform
        )
        return makeComposition(
            asset: asset,
            videoTrack: videoTrack,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            nominalFrameRate: nominalFrameRate,
            inputs: inputs,
            renderSize: renderSize
        )
    }

    /// M5-K4: small-canvas variant for `AVAssetImageGenerator`-backed scrub
    /// thumbnails. Identical handler to `make(...)` so the thumbnail visual
    /// stays consistent with the live preview; only the canvas shrinks.
    static func makeThumbnailComposition(
        asset: AVAsset,
        videoTrack: AVAssetTrack,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        nominalFrameRate: Float,
        inputs: FilmtoneDesktopVideoRenderInputs,
        renderSize: CGSize
    ) -> AVMutableVideoComposition? {
        return makeComposition(
            asset: asset,
            videoTrack: videoTrack,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            nominalFrameRate: nominalFrameRate,
            inputs: inputs,
            renderSize: renderSize
        )
    }

    private static func makeComposition(
        asset: AVAsset,
        videoTrack: AVAssetTrack,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        nominalFrameRate: Float,
        inputs: FilmtoneDesktopVideoRenderInputs,
        renderSize: CGSize
    ) -> AVMutableVideoComposition? {
        guard renderSize.width > 0, renderSize.height > 0 else { return nil }

        // Resolve invariants once per composition build so the handler
        // closure does not redo them per frame.
        let resolvedParams = FilmtonePresetCatalog.resolved(
            presetName: inputs.presetName,
            strength: inputs.presetStrength,
            lookSlug: inputs.lookSlug,
            quickState: inputs.quickState,
            paramOverrides: inputs.paramOverrides
        )
        let resolvedProfileEntry = FilmtoneSourceInputTransform.resolve(
            selection: inputs.sourceProfileSelection,
            probedColorClass: inputs.probedColorClass
        )
        let preparedCreativeLut: PreparedCreativeLut?
        if let slug = inputs.lookSlug,
           inputs.presetStrength > 0,
           let look = FilmtoneCreativePackCatalog.find(slug: slug) {
            preparedCreativeLut = FilmtoneCreativeLutLoader.load(look: look)
        } else {
            preparedCreativeLut = nil
        }
        let sourceSeed = FilmtoneGradePipeline.makeStableSourceSeed(
            from: inputs.sourceURL.absoluteString
        )

        let renderBounds = CGRect(origin: .zero, size: renderSize)
        let compareEnabled = inputs.compareEnabled
        // M5-K3: snapshot the clamped split fraction at composition build
        // time. Drag updates rebuild the composition (RootWindowView's
        // VideoCompositionRefreshKey) so each handler invocation sees a
        // fresh, valid fraction.
        let compareSplitFraction = FilmtoneCompareSplitMath.clamp(
            inputs.compareSplitFraction
        )
        let composition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                let timeSeconds = CMTimeGetSeconds(request.compositionTime)
                // AVVideoComposition provides `sourceImage` in presentation
                // orientation, but its extent may still be the asset's source
                // pixel extent. Normalize it onto this composition's
                // `renderSize` before grading, matching the iOS live-preview
                // route. Returning source-sized frames into a 1280-capped
                // render canvas causes visible cropping / incomplete framing.
                let base = scaledPreviewSourceImage(
                    request.sourceImage,
                    outputSize: renderSize
                )
                let normalized = FilmtoneSourceInputTransform.apply(
                    to: base,
                    entry: resolvedProfileEntry
                )
                let graded = FilmtoneGradePipeline.apply(
                    to: normalized,
                    params: resolvedParams,
                    frameTimeSeconds: timeSeconds.isFinite ? timeSeconds : 0,
                    sourceSeed: sourceSeed,
                    creativeLut: preparedCreativeLut
                )
                // Halation / bloom mip pyramids can grow extent beyond the
                // composition canvas. Crop back to renderBounds so
                // AVFoundation receives exactly the requested preview frame.
                let cropped = graded.cropped(to: renderBounds)
                let output: CIImage
                if compareEnabled {
                    // M5-J.2 / M5-K3: left = pre-transform source
                    // (intentionally flat for log inputs), right = graded.
                    // `base` already sits on `renderBounds`, and `cropped`
                    // is also clamped to `renderBounds`, so the helper's
                    // rescale is a no-op here but keeps the still / video
                    // paths convergent. Split position threads through
                    // from `EditorState.compareSplitFraction`.
                    output = FilmtoneCompareCompose.makeSplit(
                        source: base,
                        graded: cropped,
                        splitAt: compareSplitFraction
                    )
                } else {
                    output = cropped
                }
                request.finish(with: output, context: FilmtoneCIContext.shared)
            }
        )

        composition.renderSize = renderSize

        // AVFoundation requires a positive frameDuration. Source nominal
        // rate is preferred; fall back to 30 fps if AVAssetTrack reports
        // zero (some odd containers / image sequences).
        let fps = nominalFrameRate > 0 ? nominalFrameRate : 30
        composition.frameDuration = CMTime(
            value: 1,
            timescale: CMTimeScale(fps.rounded())
        )

        return composition
    }

    /// Apply the track's preferredTransform to the natural size, then
    /// scale the result so the long edge equals `previewLongEdge`. This
    /// keeps vertical iPhone footage vertical while honoring the cost
    /// envelope the grade pipeline (halation 6-mip pyramid + grain) was
    /// tuned against on iOS.
    static func previewRenderSize(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform
    ) -> CGSize {
        return scaledRenderSize(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            longEdgeCap: previewLongEdge
        )
    }

    /// M5-K4: orientation-aware thumbnail canvas. Same shape as
    /// `previewRenderSize` but capped at `thumbnailLongEdge`.
    static func thumbnailRenderSize(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform
    ) -> CGSize {
        return scaledRenderSize(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            longEdgeCap: thumbnailLongEdge
        )
    }

    private static func scaledRenderSize(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        longEdgeCap: CGFloat
    ) -> CGSize {
        let oriented = naturalSize.applying(preferredTransform)
        let displayWidth = abs(oriented.width)
        let displayHeight = abs(oriented.height)
        guard displayWidth > 0, displayHeight > 0 else { return .zero }

        let longEdge = max(displayWidth, displayHeight)
        guard longEdge > longEdgeCap else {
            return CGSize(
                width: max(1, displayWidth.rounded()),
                height: max(1, displayHeight.rounded())
            )
        }
        let scale = longEdgeCap / longEdge
        return CGSize(
            width: max(1, (displayWidth * scale).rounded()),
            height: max(1, (displayHeight * scale).rounded())
        )
    }

    /// Mirrors iOS `scaledPreviewVideoSourceImage`: AVVideoComposition has
    /// already applied presentation orientation, so only normalize origin,
    /// scale into the preview canvas, and crop to the exact render bounds.
    static func scaledPreviewSourceImage(_ image: CIImage, outputSize: CGSize) -> CIImage {
        let normalized = image.transformed(by: CGAffineTransform(
            translationX: -image.extent.origin.x,
            y: -image.extent.origin.y
        ))
        let width = max(normalized.extent.width, 1)
        let height = max(normalized.extent.height, 1)
        let scaleX = outputSize.width / width
        let scaleY = outputSize.height / height
        return normalized
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: CGRect(origin: .zero, size: outputSize))
    }
}
