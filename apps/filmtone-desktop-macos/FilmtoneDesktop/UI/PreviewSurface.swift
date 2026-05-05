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

    var body: some View {
        ZStack {
            // M5-H.1: branded backdrop replaces the flat `Color.black`. The
            // gradient still extends via .backgroundExtensionEffect() so
            // the Liquid Glass toolbar/chrome has continuous content to
            // refract even when the rendered image is letterboxed.
            FilmtoneBackdrop()
                .backgroundExtensionEffect()
            if let renderedImage {
                // M5-H.1: switched from `.scaledToFill().clipped()` to
                // `.scaledToFit()` so source aspect ratio is preserved end
                // to end (vertical phone footage no longer gets cropped to
                // a center band, ultra-wide stills no longer lose edges).
                // Toolbar refraction is now satisfied by the FilmtoneBackdrop
                // layer above, so we don't need the image to extend.
                Image(nsImage: renderedImage)
                    .resizable()
                    .scaledToFit()
            } else if sourceURL == nil {
                EmptyPreviewLabel()
            }
        }
        .task(id: PreviewRenderKey(
            sourceURL: sourceURL,
            sourceKind: sourceKind,
            presetName: presetName,
            presetStrength: presetStrength,
            lookSlug: lookSlug,
            videoPreviewSeconds: videoPreviewSeconds,
            sourceProfileSelection: sourceProfileSelection,
            quickState: quickState,
            paramOverrides: paramOverrides
        )) {
            await renderCurrent()
        }
    }

    private func renderCurrent() async {
        guard let sourceURL else {
            renderedImage = nil
            state.probedSourceColorClass = nil
            return
        }
        let preset = presetName
        let strength = presetStrength
        let slug = lookSlug
        let scrubSeconds = videoPreviewSeconds
        let profileSelection = sourceProfileSelection
        let quick = quickState
        let overrides = paramOverrides

        let source: CIImage?
        let probedColorClass: SourceColorClassDTO?
        switch sourceKind {
        case .still:
            source = CIImage(contentsOf: sourceURL)
            probedColorClass = FilmtoneSourceProber.probeStill(sourceURL: sourceURL).colorClass
        case .video:
            // M5-C.1: probe video color class for the Picker resolved-Auto
            // label and the source-cap gate. Errors are swallowed (probe
            // failure → nil colorClass → identity transform; preview
            // proceeds with the legacy code path).
            let probedClass = (try? await FilmtoneSourceProber.probeVideo(sourceURL: sourceURL))?.colorClass
            probedColorClass = probedClass
            if let scrubSeconds {
                source = (try? await FilmtoneVideoFramePreviewLoader.loadFrame(
                    from: sourceURL,
                    atSeconds: scrubSeconds
                ))?.image
            } else {
                source = (try? await FilmtoneVideoFramePreviewLoader.loadMidpointFrame(
                    from: sourceURL
                ))?.image
            }
        }
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
        renderedImage = nsImage
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
