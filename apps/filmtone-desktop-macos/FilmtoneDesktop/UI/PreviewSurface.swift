import AppKit
import CoreImage
import FilmLabSwiftCore
import SwiftUI

// M5-B F2 (real root cause): rendered via SwiftUI Image(nsImage:) instead
// of NSImageView/NSViewRepresentable. The NSViewRepresentable path was
// opaque to SwiftUI, so .glassEffect / .backgroundExtensionEffect could
// not sample the preview pixels — toolbar + right-rail panels read as
// flat material because there was no SwiftUI-visible content beneath
// them to refract. Image(nsImage:) is sampleable, restoring true Apple
// Liquid Glass behavior on macOS 26.
struct PreviewSurface: View {
    @Bindable var state: EditorState
    let sourceURL: URL?
    let sourceKind: FilmtoneSourceKind
    let presetName: String
    let presetStrength: Double
    let lookSlug: String?
    /// M5-A.3: scrub-bar time in seconds for video sources. `nil`
    /// triggers the legacy midpoint loader (still path or pre-probe
    /// state — keeps first paint identical to pre-M5-A.3).
    let videoPreviewSeconds: Double?
    /// M5-C.1: source profile selection. Auto resolves at probe time;
    /// .builtIn(...) is sticky. Routed into the preview render so the
    /// Picker change drives a visible re-grade.
    let sourceProfileSelection: CameraProfileSelection
    /// M5-C.3a: Quick adjust 3-axis offsets folded into the resolved
    /// render params after preset/look/strength resolution.
    let quickState: FilmtoneQuickState
    /// M5-C.3a: per-key parameter override patch applied between the
    /// preset/look resolve and the quick-state pass.
    let paramOverrides: FilmtonePhase0ParamsPatch
    /// M5-M (CC-B): Backlight Veil profile id + continuous intensity. The
    /// still preview path resolves the optical scatter coefficients in
    /// `FilmtoneGradePipeline.apply` so the live preview matches video /
    /// export Backlight behavior. `paramOverrides` already carries the
    /// (intensity-scaled) energy-key changes from
    /// `FilmtoneOpticalFilterCatalog.renderParamOverrides`; these two
    /// fields drive the optical scatter composite branch + cache key.
    let opticalFilterProfileId: String?
    let opticalFilterIntensity: Double
    /// M5-J.2 / M5-K3: when true the still preview also renders a raw
    /// pre-transform companion frame so the compare overlay can show
    /// left=source / right=graded as a SwiftUI mask, and so dragging the
    /// split bar does not require rerunning the grade pipeline. Video
    /// sources read this through `FilmtoneDesktopVideoRenderInputs`
    /// instead.
    let compareEnabled: Bool
    /// M5-I.4a: empty-state CTA entry point. RootWindowView owns the
    /// platform file picker; PreviewSurface only renders the open affordance.
    let onOpenRequested: () -> Void

    @State private var renderedFrames: RenderedFrames?
    /// M5-H.1.2: identity of the source that produced `renderedFrames`.
    /// The body gates the cached frame on `renderedSourceURL == sourceURL`
    /// so a source swap doesn't flash the prior source's last frame on
    /// top of the new source's black backdrop while the new render is in
    /// flight. Same-source param changes (preset / strength / Look /
    /// Quick / overrides / scrub) keep this URL equal to `sourceURL`,
    /// so the previous frame stays visible until the new one lands —
    /// the user never sees an intentional black flash mid-edit.
    @State private var renderedSourceURL: URL?
    /// M5-M visual recovery: low-resolution video poster used as the
    /// media-derived backdrop layer (`scaledToFill + blur + dim`). Seeded
    /// once per video session via the existing scrub thumbnail provider so
    /// the backdrop never goes solid-black or transparent-desktop in any
    /// region uncovered by the aspect-fit AVPlayer view.
    @State private var videoBackdropImage: NSImage?
    @State private var videoBackdropSeededFor: URL?

    var body: some View {
        ZStack {
            // M5-M visual recovery: empty launch keeps the branded clear
            // Liquid Glass field; loaded media uses a media-derived blurred
            // copy (still: graded frame; video: scrub-thumbnail poster) as
            // the backdrop, never solid black and never bare desktop. The
            // actual color-judgment media renders aspect-fit / glass-free
            // on top of the backdrop in the layers below.
            if sourceURL == nil {
                PreviewBackdrop(mode: .empty)
                    .backgroundExtensionEffect()
            } else {
                MediaDerivedBackdrop(image: backdropImage)
                    .backgroundExtensionEffect()
            }
            if sourceURL == nil {
                // M5-M: `.fixedSize()` pins the plate to its intrinsic
                // compact size regardless of the window width/height. The
                // surrounding `BrandedOpeningBackdrop` still fills the
                // window; only the labeled plate stays compact. Keeps
                // K1's bounded luminous-field readability without regressing
                // to a stretching marketing-page posture on wide windows.
                EmptyPreviewLabel(onOpenRequested: onOpenRequested)
                    .fixedSize()
            } else {
                // M5-I.2: video sources mount the AVPlayer view as soon as
                // `state.videoSession` lands. The session probes the asset
                // off-actor, builds the graded `AVMutableVideoComposition`,
                // and AVFoundation now owns the per-frame decode + grade
                // loop on its private dispatch queue. The brief window
                // between `setSource(.video)` and session readiness shows
                // only the preview matte above (no `Image(nsImage:)`
                // bridging frame — random-seek extraction is exactly the
                // path this slice removes).
                if sourceKind == .video, let session = state.videoSession {
                    FilmtoneDesktopPlayerView(player: session.player)
                } else if sourceKind == .still,
                          let frames = renderedFrames,
                          renderedSourceURL == sourceURL {
                    // M5-H.1: switched from `.scaledToFill().clipped()` to
                    // `.scaledToFit()` so source aspect ratio is preserved
                    // end to end (vertical phone footage no longer gets
                    // cropped to a center band, ultra-wide stills no longer
                    // lose edges).
                    // M5-H.1.2: identity gate ensures we never paint the
                    // previous source's frame over the new source's
                    // backdrop during a source swap.
                    // M5-K3: when compareEnabled, the SwiftUI mask layers
                    // the raw source over the left side of the graded image
                    // so dragging the split is a pure SwiftUI invalidation
                    // — no CoreImage re-grade per drag tick.
                    StillCompareLayer(
                        graded: frames.graded,
                        sourceForCompare: frames.sourceForCompare,
                        compareEnabled: compareEnabled,
                        compareSplitFraction: state.compareSplitFraction
                    )
                }
                // M5-K3: drag handle sits on top of the media layers and
                // constrains itself to the media's aspect-fit rect (not
                // the full preview region) so letterbox / pillarbox
                // matte areas are not draggable.
                if compareEnabled, let aspect = mediaAspectRatio {
                    CompareSplitOverlay(
                        fraction: $state.compareSplitFraction,
                        mediaAspectRatio: aspect
                    )
                }
            }
        }
        // M5-I.2: video sources no longer need the still render path or the
        // per-tick scrub re-extract — the AVPlayer composition handler is
        // the live preview. Only still sources rerun `renderCurrent()` on
        // edit changes, so the task key drops `videoPreviewSeconds` for
        // video and the renderer early-returns on `.video`.
        // M5-K3: `compareSplitFraction` is intentionally NOT part of the
        // key — the still split is composited SwiftUI-side from the cached
        // graded + sourceForCompare frames, so dragging never reruns the
        // grade pipeline.
        .task(id: PreviewRenderKey(
            sourceURL: sourceURL,
            sourceKind: sourceKind,
            presetName: presetName,
            presetStrength: presetStrength,
            lookSlug: lookSlug,
            videoPreviewSeconds: sourceKind == .video ? nil : videoPreviewSeconds,
            sourceProfileSelection: sourceProfileSelection,
            quickState: quickState,
            paramOverrides: paramOverrides,
            compareEnabled: compareEnabled,
            opticalFilterProfileId: opticalFilterProfileId,
            opticalFilterIntensity: opticalFilterIntensity
        )) {
            await renderCurrent()
        }
        // M5-M visual recovery: seed (or reset) the video backdrop poster
        // whenever the source identity or session presence changes. The
        // thumbnail provider quantizes to 0.25s buckets and serves a
        // ~240px-edge frame, so this is cheap and yields a stable poster
        // for the blurred backdrop. Stills bypass: the backdrop reads
        // `renderedFrames?.graded` directly.
        .task(id: VideoBackdropTaskKey(
            sourceURL: sourceURL,
            sourceKind: sourceKind,
            hasSession: state.videoSession != nil
        )) {
            seedVideoBackdrop()
        }
    }

    /// Frame the media-derived backdrop should blur + dim. Stills use the
    /// already-rendered graded NSImage so the backdrop and the foreground
    /// are pixel-coherent. Video uses a poster captured by the scrub
    /// thumbnail provider.
    private var backdropImage: NSImage? {
        if sourceKind == .still {
            guard renderedSourceURL == sourceURL else { return nil }
            return renderedFrames?.graded
        }
        return videoBackdropImage
    }

    private func seedVideoBackdrop() {
        guard sourceKind == .video, let url = sourceURL else {
            videoBackdropImage = nil
            videoBackdropSeededFor = nil
            return
        }
        // New source: invalidate the previous poster so we don't flash it
        // behind the wrong AVPlayer content.
        if videoBackdropSeededFor != url {
            videoBackdropImage = nil
        }
        guard let session = state.videoSession,
              videoBackdropSeededFor != url else { return }
        let secs = videoPreviewSeconds ?? 0
        videoBackdropSeededFor = url
        session.thumbnailProvider.requestThumbnail(atSeconds: secs) { image, _ in
            // Drop late completions for a source the user has already
            // moved on from.
            guard sourceURL == url else { return }
            videoBackdropImage = image
        }
    }

    /// M5-K3: aspect ratio of the actually-rendered media so the compare
    /// overlay can map drag-x onto the media's own width even when the
    /// preview is letterboxed inside the window. Stills read from the
    /// cached graded NSImage (post-grade extent equals the source extent
    /// today, but routes via the rendered frame so future preview caps
    /// stay correct). Video reads from the live session's oriented size.
    private var mediaAspectRatio: CGFloat? {
        if sourceKind == .video, let session = state.videoSession {
            return session.displayAspectRatio
        }
        if sourceKind == .still,
           let graded = renderedFrames?.graded,
           graded.size.height > 0 {
            return graded.size.width / graded.size.height
        }
        return nil
    }

    private func renderCurrent() async {
        guard let sourceURL else {
            // M5-H.1.2: clear both the cached frame and its source identity
            // so the next source open starts from a clean slate.
            renderedFrames = nil
            renderedSourceURL = nil
            state.probedSourceColorClass = nil
            return
        }
        // M5-I.2: video preview is owned by FilmtoneDesktopVideoSession
        // (AVPlayer + AVMutableVideoComposition). The session probes the
        // asset and pushes `probedColorClass` back into EditorState
        // itself, so this path stays still-only — short-circuit before
        // any AVAssetImageGenerator extraction runs.
        if sourceKind == .video {
            renderedFrames = nil
            renderedSourceURL = nil
            return
        }
        let preset = presetName
        let strength = presetStrength
        let slug = lookSlug
        let profileSelection = sourceProfileSelection
        let quick = quickState
        let overrides = paramOverrides
        let compare = compareEnabled
        let opticalProfileId = opticalFilterProfileId
        let opticalIntensity = opticalFilterIntensity

        let source: CIImage? = CIImage(contentsOf: sourceURL)
        let probe = FilmtoneSourceProber.probeStill(sourceURL: sourceURL)
        let probedColorClass: SourceColorClassDTO? = probe.colorClass
        let probedOptics: CameraOpticsDTO? = probe.cameraOptics
        guard !Task.isCancelled else { return }
        state.applyProbedSourceColorClass(probedColorClass, for: sourceURL)

        let frames = await Task.detached(priority: .userInitiated) { () -> RenderedFrames? in
            return PreviewSurface.renderFrames(
                source: source,
                presetName: preset,
                presetStrength: strength,
                lookSlug: slug,
                sourceURL: sourceURL,
                fallbackURL: sourceURL,
                sourceProfileSelection: profileSelection,
                probedColorClass: probedColorClass,
                quickState: quick,
                paramOverrides: overrides,
                compareEnabled: compare,
                opticalFilterProfileId: opticalProfileId,
                opticalFilterIntensity: opticalIntensity,
                cameraOptics: probedOptics
            )
        }.value

        guard !Task.isCancelled else { return }
        // M5-H.1.2: update the cached frame and its source identity in the
        // same MainActor turn. On render success the gate
        // `renderedSourceURL == sourceURL` opens; on failure (frames nil)
        // we clear the identity too so the gate stays closed and the
        // black backdrop is what shows, not a stale frame from a prior
        // source.
        renderedFrames = frames
        renderedSourceURL = (frames != nil) ? sourceURL : nil
    }

    nonisolated private static func renderFrames(
        source: CIImage?,
        presetName: String,
        presetStrength: Double,
        lookSlug: String?,
        sourceURL: URL,
        fallbackURL: URL,
        sourceProfileSelection: CameraProfileSelection,
        probedColorClass: SourceColorClassDTO?,
        quickState: FilmtoneQuickState,
        paramOverrides: FilmtonePhase0ParamsPatch,
        compareEnabled: Bool,
        // M5-M (CC-B): Backlight Veil profile + intensity + still-probe
        // camera optics. Threaded from `state.opticalFilterProfileId` /
        // `state.opticalFilterIntensity` and `FilmtoneSourceProber.probeStill`
        // so the still live preview routes through the same Backlight Veil
        // composite as exports / video preview, at the user's chosen strength.
        opticalFilterProfileId: String?,
        opticalFilterIntensity: Double,
        cameraOptics: CameraOpticsDTO?
    ) -> RenderedFrames? {
        guard let source else {
            // CIImage failed (HEIC variant etc.) — fall back to a directly
            // loaded NSImage so the user at least sees the source. Compare
            // is not meaningful without a CIImage to split, so the
            // companion frame stays nil and the body silently behaves as
            // if compare were off for this rendition.
            if let fallback = NSImage(contentsOf: fallbackURL) {
                return RenderedFrames(graded: fallback, sourceForCompare: nil)
            }
            return nil
        }
        // M5-C.1: apply the resolved input transform before grade.
        let resolvedProfile = FilmtoneSourceInputTransform.resolve(
            selection: sourceProfileSelection,
            probedColorClass: probedColorClass
        )
        let normalizedSource = FilmtoneSourceInputTransform.apply(
            to: source,
            entry: resolvedProfile
        )
        let params = FilmtonePresetCatalog.resolved(
            presetName: presetName,
            strength: presetStrength,
            lookSlug: lookSlug,
            quickState: quickState,
            paramOverrides: paramOverrides
        )
        let sourceSeed = FilmtoneGradePipeline.makeStableSourceSeed(
            from: sourceURL.absoluteString
        )
        let creativeLut: PreparedCreativeLut?
        if let lookSlug,
           presetStrength > 0,
           let look = FilmtoneCreativePackCatalog.find(slug: lookSlug) {
            creativeLut = FilmtoneCreativeLutLoader.load(look: look)
        } else {
            creativeLut = nil
        }
        let graded = FilmtoneGradePipeline.apply(
            to: normalizedSource,
            params: params,
            sourceSeed: sourceSeed,
            cameraOptics: cameraOptics,
            creativeLut: creativeLut,
            lutIntensity: FilmtonePresetCatalog.clampStrength(presetStrength),
            opticalFilterProfileId: opticalFilterProfileId,
            opticalFilterIntensity: opticalFilterIntensity
        )
        guard let gradedNSImage = rasterize(
            ciImage: graded,
            extent: graded.extent,
            fallback: fallbackURL
        ) else {
            return nil
        }
        // M5-K3: build the companion source frame only when compare is on
        // so toggling V is the only re-grade-adjacent moment that touches
        // CoreImage. Drag updates the SwiftUI mask only.
        let sourceForCompare: NSImage? = compareEnabled
            ? rasterize(
                ciImage: FilmtoneCompareCompose.rescale(source: source, to: graded.extent),
                extent: graded.extent,
                fallback: nil
            )
            : nil
        return RenderedFrames(
            graded: gradedNSImage,
            sourceForCompare: sourceForCompare
        )
    }

    /// Rasterize a CIImage to NSImage at the canvas extent. When
    /// rasterization fails, fall back to a directly-loaded NSImage from
    /// the source URL if `fallback` is set, otherwise return nil so the
    /// caller can omit the companion compare frame instead of pasting in
    /// the wrong pixels.
    nonisolated private static func rasterize(
        ciImage: CIImage,
        extent: CGRect,
        fallback: URL?
    ) -> NSImage? {
        if let cg = FilmtoneCIContext.shared.createCGImage(
            ciImage,
            from: extent,
            format: .RGBA8,
            colorSpace: FilmtoneCIContext.outputColorSpace
        ) {
            return NSImage(
                cgImage: cg,
                size: NSSize(width: extent.width, height: extent.height)
            )
        }
        if let fallback {
            return NSImage(contentsOf: fallback)
        }
        return nil
    }
}

private struct RenderedFrames {
    let graded: NSImage
    /// Pre-input-transform raw source rasterized onto the graded canvas
    /// extent. Only populated when compare is on; nil otherwise so the
    /// SwiftUI body short-circuits to the single graded layer.
    let sourceForCompare: NSImage?
}

private struct PreviewRenderKey: Hashable {
    let sourceURL: URL?
    let sourceKind: FilmtoneSourceKind
    let presetName: String
    let presetStrength: Double
    let lookSlug: String?
    let videoPreviewSeconds: Double?
    let sourceProfileSelection: CameraProfileSelection
    let quickState: FilmtoneQuickState
    let paramOverrides: FilmtonePhase0ParamsPatch
    let compareEnabled: Bool
    let opticalFilterProfileId: String?
    let opticalFilterIntensity: Double
}

/// M5-M visual recovery: drives the one-shot video poster fetch behind
/// `MediaDerivedBackdrop`. Fires when the source url, the source kind, or
/// the session attachment flips — not on every scrub tick, so the
/// backdrop stays stable while the user moves around the timeline.
private struct VideoBackdropTaskKey: Hashable {
    let sourceURL: URL?
    let sourceKind: FilmtoneSourceKind
    let hasSession: Bool
}

/// M5-K3: still preview compositor. Lays the graded NSImage on the full
/// preview area, then masks the raw companion frame on top of the left
/// half determined by `compareSplitFraction`. Both NSImages are sized to
/// the same graded canvas, so `.scaledToFit()` resolves to the same
/// drawn rect inside the parent — the mask divides exactly along the
/// media's own width, even when the parent letterboxes.
private struct StillCompareLayer: View {
    let graded: NSImage
    let sourceForCompare: NSImage?
    let compareEnabled: Bool
    let compareSplitFraction: Double

    var body: some View {
        ZStack {
            Image(nsImage: graded)
                .resizable()
                .scaledToFit()
            if compareEnabled, let sourceForCompare {
                Image(nsImage: sourceForCompare)
                    .resizable()
                    .scaledToFit()
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle()
                                .frame(
                                    width: geo.size.width
                                        * CGFloat(FilmtoneCompareSplitMath.clamp(compareSplitFraction)),
                                    height: geo.size.height,
                                    alignment: .leading
                                )
                        }
                    }
            }
        }
    }
}

/// M5-K3: draggable split overlay. Clamps the handle x to the media's
/// aspect-fit rect inside the preview region and exposes a left/right
/// resize cursor on hover so the affordance is obvious. Apple Liquid
/// Glass posture on the grip; the connecting line is a thin neutral bar
/// so it does not bias color judgment.
private struct CompareSplitOverlay: View {
    @Binding var fraction: Double
    let mediaAspectRatio: CGFloat

    var body: some View {
        GeometryReader { geo in
            let mediaRect = aspectFitRect(aspect: mediaAspectRatio, in: geo.size)
            let clamped = FilmtoneCompareSplitMath.clamp(fraction)
            let handleX = mediaRect.minX + mediaRect.width * CGFloat(clamped)
            ZStack(alignment: .topLeading) {
                Color.clear
                // M5-K3 P2: hit target spans the full media height around
                // the line + grip so the user can grab anywhere along the
                // visible bar, not just the 36 pt center grip. Width is
                // sized to fully cover the grip (36 pt) plus slight slop.
                Color.clear
                    .frame(width: 40, height: mediaRect.height)
                    .contentShape(Rectangle())
                    .position(x: handleX, y: mediaRect.midY)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                guard mediaRect.width > 0 else { return }
                                let raw = (value.location.x - mediaRect.minX) / mediaRect.width
                                fraction = FilmtoneCompareSplitMath.clamp(Double(raw))
                            }
                    )
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 1.5, height: mediaRect.height)
                    .position(x: handleX, y: mediaRect.midY)
                    .allowsHitTesting(false)
                    .shadow(color: .black.opacity(0.45), radius: 1.5, x: 0, y: 0)
                CompareSplitGrip()
                    .position(x: handleX, y: mediaRect.midY)
                    .allowsHitTesting(false)
            }
        }
    }

    private func aspectFitRect(aspect: CGFloat, in size: CGSize) -> CGRect {
        guard aspect > 0, size.width > 0, size.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let containerAspect = size.width / size.height
        if containerAspect > aspect {
            let width = size.height * aspect
            let x = (size.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: size.height)
        } else {
            let height = size.width / aspect
            let y = (size.height - height) / 2
            return CGRect(x: 0, y: y, width: size.width, height: height)
        }
    }
}

private struct CompareSplitGrip: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .frame(width: 36, height: 36)
            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.92))
        }
        .glassEffect(.clear, in: Circle())
        .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 1)
    }
}

private struct PreviewBackdrop: View {
    enum Mode {
        case empty
    }

    let mode: Mode

    var body: some View {
        switch mode {
        case .empty:
            BrandedOpeningBackdrop()
        }
    }
}

// M5-M visual recovery: media-derived backdrop. When a frame is available
// (still: graded NSImage; video: low-res scrub-thumbnail poster) the
// backdrop fills the window with a `scaledToFill + blur + dim` copy so any
// area not covered by the aspect-fit foreground media (or refracted by the
// overlaid inspector glass) shows the same source content rather than a
// solid black matte or transparent desktop. The fallback while a frame is
// pending is a near-neutral dark wash — explicitly not pure black, never
// allowed to drop to bare desktop transparency. The actual grading-judgment
// media draws on top of this, glass-free, at aspect-fit.
private struct MediaDerivedBackdrop: View {
    let image: NSImage?

    var body: some View {
        ZStack {
            // Near-neutral dark fallback. Sits behind the blurred media
            // copy so a brief frame-loading window does not flash desktop
            // through the transparent AppKit window.
            Color(red: 0.078, green: 0.078, blue: 0.082)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 56, opaque: true)
                    .saturation(0.85)
                    .overlay(Color.black.opacity(0.42))
                    .clipped()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: image != nil)
    }
}

// M5-I.4a + M5-K1: branded Liquid Glass empty-state + Open CTA. Uses the
// runtime AppIcon so the launch state anchors on the same mark shown in
// Dock / Finder. K1 wraps the brand stack and CTA in a bounded luminous
// field so icon / title / subtitle / Open button stay readable over
// arbitrary desktop backgrounds (the surrounding `BrandedOpeningBackdrop`
// keeps clear-glass posture and cannot guarantee contrast on bright
// desktops by itself). The plate is intentionally bounded — not a full
// opaque card — so the launch state still reads as app-first Liquid Glass
// rather than a marketing landing page.
private struct EmptyPreviewLabel: View {
    let onOpenRequested: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 22) {
                VStack(spacing: 16) {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 92, height: 92)
                            .opacity(0.96)
                    }
                    Text("Filmtone")
                        .font(.system(size: 28, weight: .light))
                        .tracking(4)
                        .foregroundStyle(primaryTextStyle)
                    Text("素材を開いて始めましょう")
                        .font(.callout)
                        .foregroundStyle(secondaryTextStyle)
                }
                .padding(.horizontal, 56)
                .padding(.vertical, 32)

                Button {
                    onOpenRequested()
                } label: {
                    Label("素材を開く", systemImage: "folder")
                        .font(.headline)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .help("Open a still image or video")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
            .background {
                // Bounded luminous field. Subtle dark wash + ultraThin
                // material gives the central content a readable surface
                // without becoming an opaque marketing slab. Soft inner
                // highlight on top picks up the Liquid Glass feel.
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(plateWash)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(colorScheme == .light ? 0.55 : 0.42)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(plateStroke, lineWidth: 0.5)
                    )
            }
        }
    }

    private var primaryTextStyle: some ShapeStyle {
        colorScheme == .light ? Color.black.opacity(0.86) : Color.white.opacity(0.94)
    }

    private var secondaryTextStyle: some ShapeStyle {
        colorScheme == .light ? Color.black.opacity(0.62) : Color.white.opacity(0.72)
    }

    private var plateWash: Color {
        colorScheme == .light
            ? Color.white.opacity(0.32)
            : Color.black.opacity(0.32)
    }

    private var plateStroke: Color {
        colorScheme == .light
            ? Color.black.opacity(0.06)
            : Color.white.opacity(0.10)
    }
}

// M5-I.4a + M5-K1: opening-only Liquid Glass field. Keeps the clear-glass
// direction (the AppKit window is non-opaque so the desktop is visible
// through the app) but adds a subtle neutral wash so brand text and the
// CTA don't disappear over bright desktop backgrounds. The bounded plate
// behind `EmptyPreviewLabel` carries the rest of the contrast budget;
// this backdrop stays transparent enough to preserve the premium glass
// feel and avoid a marketing-page posture.
private struct BrandedOpeningBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            ZStack {
                Color.clear
                Rectangle()
                    .fill(baseNeutralWash)
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .light ? 0.10 : 0.045),
                        Color.white.opacity(colorScheme == .light ? 0.020 : 0.008),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .light ? 0.085 : 0.050),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 80,
                    endRadius: 620
                )
                .blendMode(.screen)
            }
            .glassEffect(.clear, in: Rectangle())
        }
    }

    // K1: was `.white.opacity(0.022/0.010)` — too transparent over bright
    // desktops. Move to a neutral dark wash in dark mode and a soft white
    // wash in light mode, raising contrast for brand/CTA readability while
    // keeping the field clear enough to feel native Liquid Glass.
    private var baseNeutralWash: Color {
        colorScheme == .light
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.18)
    }
}

#Preview {
    PreviewSurface(
        state: EditorState(),
        sourceURL: nil,
        sourceKind: .still,
        presetName: "reset",
        presetStrength: 1.0,
        lookSlug: nil,
        videoPreviewSeconds: nil,
        sourceProfileSelection: .auto,
        quickState: .zero,
        paramOverrides: .empty,
        opticalFilterProfileId: nil,
        opticalFilterIntensity: 1.0,
        compareEnabled: false,
        onOpenRequested: {}
    )
    .frame(width: 600, height: 400)
}
