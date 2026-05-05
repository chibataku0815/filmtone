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
    /// M5-J.2: when true the still render path composes a 50:50
    /// Before/After split (left = source, right = graded) before
    /// rasterizing to NSImage. Video sources read this through
    /// `FilmtoneDesktopVideoRenderInputs.compareEnabled` instead.
    let compareEnabled: Bool
    /// M5-I.4a: empty-state CTA entry point. RootWindowView owns the
    /// platform file picker; PreviewSurface only renders the open affordance.
    let onOpenRequested: () -> Void

    @State private var renderedImage: NSImage?
    /// M5-H.1.2: identity of the source that produced `renderedImage`.
    /// The body gates the cached frame on `renderedSourceURL == sourceURL`
    /// so a source swap doesn't flash the prior source's last frame on
    /// top of the new source's black backdrop while the new render is in
    /// flight. Same-source param changes (preset / strength / Look /
    /// Quick / overrides / scrub) keep this URL equal to `sourceURL`,
    /// so the previous frame stays visible until the new one lands —
    /// the user never sees an intentional black flash mid-edit.
    @State private var renderedSourceURL: URL?

    var body: some View {
        ZStack {
            // M5-I.4a: empty launches on a branded Liquid Glass backdrop;
            // loaded media sits on a neutral dark frosted matte instead of
            // pure black. The content layer itself remains glass-free so
            // grading judgment stays trustworthy.
            PreviewBackdrop(mode: sourceURL == nil ? .empty : .loaded)
                .backgroundExtensionEffect()
            if sourceURL == nil {
                EmptyPreviewLabel(onOpenRequested: onOpenRequested)
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
                          let renderedImage,
                          renderedSourceURL == sourceURL {
                    // M5-H.1: switched from `.scaledToFill().clipped()` to
                    // `.scaledToFit()` so source aspect ratio is preserved
                    // end to end (vertical phone footage no longer gets
                    // cropped to a center band, ultra-wide stills no longer
                    // lose edges).
                    // M5-H.1.2: identity gate ensures we never paint the
                    // previous source's frame over the new source's
                    // backdrop during a source swap.
                    Image(nsImage: renderedImage)
                        .resizable()
                        .scaledToFit()
                }
            }
        }
        // M5-I.2: video sources no longer need the still render path or the
        // per-tick scrub re-extract — the AVPlayer composition handler is
        // the live preview. Only still sources rerun `renderCurrent()` on
        // edit changes, so the task key drops `videoPreviewSeconds` for
        // video and the renderer early-returns on `.video`.
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
            compareEnabled: compareEnabled
        )) {
            await renderCurrent()
        }
    }

    private func renderCurrent() async {
        guard let sourceURL else {
            // M5-H.1.2: clear both the cached frame and its source identity
            // so the next source open starts from a clean slate.
            renderedImage = nil
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
            renderedImage = nil
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

        let source: CIImage? = CIImage(contentsOf: sourceURL)
        let probedColorClass: SourceColorClassDTO? =
            FilmtoneSourceProber.probeStill(sourceURL: sourceURL).colorClass
        guard !Task.isCancelled else { return }
        state.probedSourceColorClass = probedColorClass

        let nsImage = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            return PreviewSurface.renderToNSImage(
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
                compareEnabled: compare
            )
        }.value

        guard !Task.isCancelled else { return }
        // M5-H.1.2: update the cached frame and its source identity in the
        // same MainActor turn. On render success the gate
        // `renderedSourceURL == sourceURL` opens; on failure (nsImage nil)
        // we clear the identity too so the gate stays closed and the
        // black backdrop is what shows, not a stale frame from a prior
        // source.
        renderedImage = nsImage
        renderedSourceURL = (nsImage != nil) ? sourceURL : nil
    }

    nonisolated private static func renderToNSImage(
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
        compareEnabled: Bool
    ) -> NSImage? {
        guard let source else {
            return NSImage(contentsOf: fallbackURL)
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
            creativeLut: creativeLut
        )
        // M5-J.2: compose 50:50 (left=raw source pre-transform, right=graded)
        // when the compare toggle is on. Helper rescales `source` onto the
        // graded canvas extent so split rectangles always have meaningful
        // pixels behind them.
        let output: CIImage = compareEnabled
            ? FilmtoneCompareCompose.makeSplit(source: source, graded: graded, splitAt: 0.5)
            : graded
        guard let cg = FilmtoneCIContext.shared.createCGImage(
            output,
            from: graded.extent,
            format: .RGBA8,
            colorSpace: FilmtoneCIContext.outputColorSpace
        ) else {
            return NSImage(contentsOf: fallbackURL)
        }
        return NSImage(
            cgImage: cg,
            size: NSSize(width: graded.extent.width, height: graded.extent.height)
        )
    }
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
}

private struct PreviewBackdrop: View {
    enum Mode {
        case empty
        case loaded
    }

    let mode: Mode

    var body: some View {
        switch mode {
        case .empty:
            BrandedOpeningBackdrop()
        case .loaded:
            NeutralFrostedPreviewMatte()
        }
    }
}

// M5-I.4a: neutral matte for letterbox / pillarbox areas. The material is
// intentionally near-neutral and dark, softer than pure black but without
// warm/cool cast that could bias preview color judgment.
private struct NeutralFrostedPreviewMatte: View {
    var body: some View {
        ZStack {
            Color(red: 0.078, green: 0.078, blue: 0.082)
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.18)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.035),
                    Color.black.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// M5-I.4a: replaces the prior flat opening placeholder with a branded
// Liquid Glass surface and an actual Open CTA. Uses the runtime AppIcon so
// the launch state anchors on the same mark shown in Dock / Finder.
private struct EmptyPreviewLabel: View {
    let onOpenRequested: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 92, height: 92)
                            .opacity(0.94)
                    }
                    Text("Filmtone")
                        .font(.system(size: 28, weight: .light))
                        .tracking(4)
                        .foregroundStyle(primaryTextStyle)
                    Text("素材を開いて始めましょう")
                        .font(.callout)
                        .foregroundStyle(secondaryTextStyle)
                }
                .padding(.horizontal, 44)
                .padding(.vertical, 28)

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
        }
    }

    private var primaryTextStyle: some ShapeStyle {
        colorScheme == .light ? Color.black.opacity(0.82) : Color.white.opacity(0.92)
    }

    private var secondaryTextStyle: some ShapeStyle {
        colorScheme == .light ? Color.black.opacity(0.52) : Color.white.opacity(0.64)
    }
}

// M5-I.4a: opening-only clear Liquid Glass field. This avoids the dark
// background + gray card posture. The AppKit window is also non-opaque, so
// this layer can actually reveal the desktop / windows behind Filmtone.
private struct BrandedOpeningBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            ZStack {
                Color.clear
                Rectangle()
                    .fill(baseClearWash)
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .light ? 0.12 : 0.055),
                        Color.white.opacity(colorScheme == .light ? 0.025 : 0.010),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .light ? 0.105 : 0.055),
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

    private var baseClearWash: Color {
        colorScheme == .light
            ? Color.white.opacity(0.022)
            : Color.white.opacity(0.010)
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
        compareEnabled: false,
        onOpenRequested: {}
    )
    .frame(width: 600, height: 400)
}
