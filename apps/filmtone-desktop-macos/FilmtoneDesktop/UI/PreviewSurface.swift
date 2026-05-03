import AppKit
import CoreImage
import SwiftUI

struct PreviewSurface: View {
    let sourceURL: URL?
    let sourceKind: FilmtoneSourceKind
    let presetName: String
    let presetStrength: Double

    var body: some View {
        Color.black
            .overlay {
                if let sourceURL {
                    PreviewImageView(
                        sourceURL: sourceURL,
                        sourceKind: sourceKind,
                        presetName: presetName,
                        presetStrength: presetStrength
                    )
                } else {
                    EmptyPreviewLabel()
                }
            }
    }
}

private struct PreviewImageView: NSViewRepresentable {
    let sourceURL: URL
    let sourceKind: FilmtoneSourceKind
    let presetName: String
    let presetStrength: Double

    final class Coordinator {
        var currentTask: Task<Void, Never>?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.imageFrameStyle = .none
        view.isEditable = false
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        // Phase 1b/1c preview: load source (still or video midpoint) → grade
        // → CGImage → NSImage. Phase 2 C2: video path uses async modern
        // AVAssetImageGenerator (`generator.image(at:)`); we wrap the call in
        // a Task and cancel any in-flight Task on subsequent updates so
        // preset switches don't cause stale frame races. Phase 3 will move
        // to MTKView with caching.
        context.coordinator.currentTask?.cancel()

        let url = sourceURL
        let kind = sourceKind
        let preset = presetName
        let strength = presetStrength

        switch kind {
        case .still:
            let source = CIImage(contentsOf: url)
            renderAndAssign(
                source: source,
                presetName: preset,
                presetStrength: strength,
                sourceURL: url,
                fallbackURL: url,
                into: nsView
            )
        case .video:
            context.coordinator.currentTask = Task { @MainActor in
                let preview = try? await FilmtoneVideoFramePreviewLoader.loadMidpointFrame(from: url)
                guard !Task.isCancelled else { return }
                renderAndAssign(
                    source: preview?.image,
                    presetName: preset,
                    presetStrength: strength,
                    sourceURL: url,
                    fallbackURL: url,
                    into: nsView
                )
            }
        }
    }

    @MainActor
    private func renderAndAssign(
        source: CIImage?,
        presetName: String,
        presetStrength: Double,
        sourceURL: URL,
        fallbackURL: URL,
        into nsView: NSImageView
    ) {
        guard let source else {
            nsView.image = NSImage(contentsOf: fallbackURL)
            return
        }
        let params = FilmtonePresetCatalog.params(for: presetName, strength: presetStrength)
        let sourceSeed = FilmtoneGradePipeline.makeStableSourceSeed(
            from: sourceURL.absoluteString
        )
        let graded = FilmtoneGradePipeline.apply(
            to: source,
            params: params,
            sourceSeed: sourceSeed
        )
        guard let cg = FilmtoneCIContext.shared.createCGImage(
            graded,
            from: graded.extent,
            format: .RGBA8,
            colorSpace: FilmtoneCIContext.outputColorSpace
        ) else {
            nsView.image = NSImage(contentsOf: fallbackURL)
            return
        }
        nsView.image = NSImage(
            cgImage: cg,
            size: NSSize(width: graded.extent.width, height: graded.extent.height)
        )
    }
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
        presetStrength: 1.0
    )
    .frame(width: 600, height: 400)
}
