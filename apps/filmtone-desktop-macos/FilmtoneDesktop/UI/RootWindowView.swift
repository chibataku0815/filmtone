import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct RootWindowView: View {
    @State private var state = EditorState()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PreviewSurface(
                sourceURL: state.sourceURL,
                sourceKind: state.sourceKind,
                presetName: state.presetName,
                presetStrength: state.presetStrength,
                lookSlug: state.lookSlug,
                videoPreviewSeconds: state.videoPreviewSeconds
            )
            // M5-B Pass 3: user confirmed `.clear` posture is the correct
            // Apple Liquid Glass dramatic refraction; all panels and the
            // capsule unified on `.clear`. GlassEffectContainer(spacing: 12)
            // coordinates morphing/refraction across the right rail.
            GlassEffectContainer(spacing: 12) {
                VStack(alignment: .trailing, spacing: 12) {
                    GlassControlGroup()
                    if state.sourceURL != nil {
                        GradeControls(state: state)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect(
                                .clear,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                    }
                    if state.isExporting {
                        ExportProgressBar(state: state)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect(
                                .clear,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                    }
                }
            }
            .padding(20)
            // M5-A.3 + F4: scrub bar sits close to the window's bottom
            // edge (12pt padding) so it reads as a chrome-adjacent control
            // rather than a panel floating mid-preview.
            if state.sourceKind == .video,
               let duration = state.videoDurationSeconds,
               duration > 0 {
                // Full-width VStack so the scrub bar centers horizontally in
                // the window. Without .frame(maxWidth: .infinity) the VStack
                // sizes to its child intrinsic width and the ZStack's
                // .topTrailing alignment pushes it to the right edge.
                VStack {
                    Spacer()
                    VideoScrubBar(state: state, duration: duration)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(
                            .clear,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .padding(.bottom, 60)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 880, minHeight: 560)
        // The real reason the toolbar previously read as solid white was an
        // opaque AppKit toolbar background painted on top of the Liquid Glass
        // chrome. Hiding it lets the preview Image (which already extends via
        // backgroundExtensionEffect) show through, giving the unified Apple
        // Liquid Glass toolbar real content to refract — toolbar buttons and
        // title still render normally, but the chrome bar itself becomes the
        // glass surface the design language calls for.
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Image(systemName: "camera.aperture")
                    .symbolRenderingMode(.hierarchical)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentOpenPanel()
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .keyboardShortcut("o", modifiers: .command)
                .help("Open a still image or video")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentExportPanel()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(state.sourceURL == nil || state.isExporting)
                .help(state.sourceKind == .video ? "Export the current video" : "Export the current still")
            }
        }
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie, .quickTimeMovie, .mpeg4Movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Open"
        panel.message = "Choose a still image or short video to preview"
        if panel.runModal() == .OK, let url = panel.url {
            state.setSource(url, kind: detectSourceKind(of: url))
        }
    }

    private func detectSourceKind(of url: URL) -> FilmtoneSourceKind {
        if let utType = UTType(filenameExtension: url.pathExtension) {
            if utType.conforms(to: .movie) {
                return .video
            }
        }
        return .still
    }

    private func presentExportPanel() {
        guard let sourceURL = state.sourceURL else { return }
        switch state.sourceKind {
        case .still:
            presentStillExportPanel(sourceURL: sourceURL)
        case .video:
            presentVideoExportPanel(sourceURL: sourceURL)
        }
    }

    private func presentStillExportPanel(sourceURL: URL) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "-" + state.presetName + ".png"
        panel.message = "Export the still + sidecar JSON"
        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        let format: StillExportFormat
        switch outputURL.pathExtension.lowercased() {
        case "jpg", "jpeg": format = .jpeg
        default: format = .png
        }

        let request = FilmtoneStillExportRequest(
            sourceURL: sourceURL,
            outputURL: outputURL,
            presetName: state.presetName,
            presetStrength: state.presetStrength,
            lookSlug: state.lookSlug,
            format: format
        )

        state.isExporting = true
        state.exportProgress = 0
        state.exportProgressMessage = "Exporting still…"
        state.currentExportTask = Task.detached {
            do {
                let result = try FilmtoneStillExporter.export(request)
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 1
                    state.exportProgressMessage = nil
                    state.lastExportSummary = "Exported \(result.pixelWidth)×\(result.pixelHeight) → \(result.outputURL.lastPathComponent)"
                    state.currentExportTask = nil
                }
            } catch {
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 0
                    state.exportProgressMessage = nil
                    state.lastExportSummary = "Export failed: \(error)"
                    state.currentExportTask = nil
                }
            }
        }
    }

    private func presentVideoExportPanel(sourceURL: URL) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "-" + state.presetName + ".mp4"
        panel.message = "Export the video + sidecar JSON"
        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        let request = FilmtoneVideoExportRequest(
            sourceURL: sourceURL,
            outputURL: outputURL,
            presetName: state.presetName,
            presetStrength: state.presetStrength,
            lookSlug: state.lookSlug
        )

        state.isExporting = true
        state.exportProgress = 0
        state.exportProgressMessage = "Reading video…"
        state.currentExportTask = Task.detached {
            do {
                let result = try await FilmtoneVideoExporter.export(request) { progress in
                    Task { @MainActor in
                        state.exportProgress = progress.normalized
                        state.exportProgressMessage = "Rendering frame \(progress.processedFrames)/\(progress.estimatedTotalFrames)"
                    }
                }
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 1
                    state.exportProgressMessage = nil
                    state.lastExportSummary = "Exported \(result.outputWidth)×\(result.outputHeight), \(result.processedFrames) frames → \(result.outputURL.lastPathComponent)"
                    state.currentExportTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 0
                    state.exportProgressMessage = nil
                    state.lastExportSummary = "Export cancelled"
                    state.currentExportTask = nil
                }
            } catch {
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 0
                    state.exportProgressMessage = nil
                    state.lastExportSummary = "Export failed: \(error)"
                    state.currentExportTask = nil
                }
            }
        }
    }
}

/// M5-A.3: scrub bar for video preview. Continuous binding to
/// `state.videoPreviewSeconds`; coalescing of rapid drag events happens
/// downstream in `PreviewSurface` via in-flight Task cancellation.
private struct VideoScrubBar: View {
    @Bindable var state: EditorState
    let duration: Double

    private var seconds: Binding<Double> {
        Binding(
            get: { state.videoPreviewSeconds ?? 0 },
            set: { state.videoPreviewSeconds = max(0, min($0, duration)) }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(format(seconds.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .leading)
            Slider(value: seconds, in: 0...max(duration, 0.001))
            Text(format(duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .frame(maxWidth: 560)
    }

    private func format(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "0:00.00" }
        let total = value
        let minutes = Int(total / 60)
        let secondsRemainder = total - Double(minutes * 60)
        return String(format: "%d:%05.2f", minutes, secondsRemainder)
    }
}

private struct ExportProgressBar: View {
    @Bindable var state: EditorState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: state.exportProgress)
                .progressViewStyle(.linear)
                .frame(width: 240)
            HStack {
                if let message = state.exportProgressMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    state.cancelExport()
                }
                .controlSize(.small)
            }
        }
    }
}

#Preview {
    RootWindowView()
}
