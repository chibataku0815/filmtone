import AppKit
import CoreImage
import SwiftUI

// M5-B F2 (real root cause): rendered via SwiftUI Image(nsImage:) instead
// of NSImageView/NSViewRepresentable. The NSViewRepresentable path was
// opaque to SwiftUI, so .glassEffect / .backgroundExtensionEffect could
// not sample the preview pixels — toolbar + right-rail panels read as
// flat material because there was no SwiftUI-visible content beneath
// them to refract. Image(nsImage:) is sampleable, restoring true Apple
// Liquid Glass behavior on macOS 26.
struct PreviewSurface: View {
    let sourceURL: URL?
    let sourceKind: FilmtoneSourceKind
    let presetName: String
    let presetStrength: Double
    let lookSlug: String?
    /// M5-A.3: scrub-bar time in seconds for video sources. `nil`
    /// triggers the legacy midpoint loader (still path or pre-probe
    /// state — keeps first paint identical to pre-M5-A.3).
    let videoPreviewSeconds: Double?

    @State private var renderedImage: NSImage?

    var body: some View {
        ZStack {
            Color.black
            if let renderedImage {
                // Apple's Landmarks sample applies backgroundExtensionEffect()
                // directly on Image(...).resizable().scaledToFill() so the
                // image extends/mirrors into the toolbar safe area. Liquid
                // Glass chrome refracts what's beneath it — SwiftUI must be
                // able to sample those pixels, which an NSViewRepresentable
                // would block.
                Image(nsImage: renderedImage)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .backgroundExtensionEffect()
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
            videoPreviewSeconds: videoPreviewSeconds
        )) {
            await renderCurrent()
        }
    }

    private func renderCurrent() async {
        guard let sourceURL else {
            renderedImage = nil
            return
        }
        let preset = presetName
        let strength = presetStrength
        let slug = lookSlug
        let scrubSeconds = videoPreviewSeconds

        let source: CIImage?
        switch sourceKind {
        case .still:
            source = CIImage(contentsOf: sourceURL)
        case .video:
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

        let nsImage = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            return PreviewSurface.renderToNSImage(
                source: source,
                presetName: preset,
                presetStrength: strength,
                lookSlug: slug,
                sourceURL: sourceURL,
                fallbackURL: sourceURL
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
        fallbackURL: URL
    ) -> NSImage? {
        guard let source else {
            return NSImage(contentsOf: fallbackURL)
        }
        let params = FilmtonePresetCatalog.resolved(
            presetName: presetName,
            strength: presetStrength,
            lookSlug: lookSlug
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
            to: source,
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
}

private struct EmptyPreviewLabel: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("Open a still image or video to preview")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PreviewSurface(
        sourceURL: nil,
        sourceKind: .still,
        presetName: "reset",
        presetStrength: 1.0,
        lookSlug: nil,
        videoPreviewSeconds: nil
    )
    .frame(width: 600, height: 400)
}
