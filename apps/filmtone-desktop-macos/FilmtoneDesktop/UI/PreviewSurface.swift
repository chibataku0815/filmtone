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
            // M5-H.1.1: branded `FilmtoneBackdrop` is gated to the empty
            // launch state only. The moment a source loads (or even before
            // the first render lands while the probe is in flight) we swap
            // to a neutral `Color.black` backdrop so any letterbox bars
            // around `.scaledToFit()` don't bleed warm tone into color
            // judgment on the preview. Both branches keep
            // `.backgroundExtensionEffect()` so the Liquid Glass toolbar
            // continues to refract a real surface.
            if sourceURL == nil {
                FilmtoneBackdrop()
                    .backgroundExtensionEffect()
                EmptyPreviewLabel()
            } else {
                Color.black
                    .backgroundExtensionEffect()
                // M5-I.2: video sources mount the AVPlayer view as soon as
                // `state.videoSession` lands. The session probes the asset
                // off-actor, builds the graded `AVMutableVideoComposition`,
                // and AVFoundation now owns the per-frame decode + grade
                // loop on its private dispatch queue. The brief window
                // between `setSource(.video)` and session readiness shows
                // only the black backdrop above (no `Image(nsImage:)`
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
            paramOverrides: paramOverrides
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
                paramOverrides: overrides
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
        paramOverrides: FilmtonePhase0ParamsPatch
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
        guard let cg = FilmtoneCIContext.shared.createCGImage(
            graded,
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
}

// M5-H.1: replaces the prior dark + system-icon placeholder. Uses the
// runtime AppIcon so the launch state visually anchors on the brand mark
// the user already sees in the Dock / Finder, plus the wordmark and a
// soft Japanese CTA. Stays inside the FilmtoneBackdrop gradient so the
// Liquid Glass chrome above continues to refract a real surface.
private struct EmptyPreviewLabel: View {
    var body: some View {
        VStack(spacing: 16) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                    .opacity(0.92)
            }
            Text("Filmtone")
                .font(.system(size: 28, weight: .light))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.92))
            Text("素材を開いて始めましょう")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// M5-H.1: brand backdrop. Warm-leaning near-black gradient evokes the
// dark-room negative-on-light-table feel without competing with the
// preview content; identical to the iOS launch palette tone, kept dark
// enough that color judgment on the preview is unaffected.
private struct FilmtoneBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.06, blue: 0.05),
                Color(red: 0.02, green: 0.02, blue: 0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
        paramOverrides: .empty
    )
    .frame(width: 600, height: 400)
}
