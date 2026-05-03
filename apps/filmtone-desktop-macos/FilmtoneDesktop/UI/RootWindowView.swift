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
                presetStrength: state.presetStrength
            )
            VStack(alignment: .trailing, spacing: 12) {
                GlassControlGroup()
                if state.sourceURL != nil {
                    GradeControls(state: state)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                if state.isExporting {
                    ExportProgressBar(state: state)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        .frame(minWidth: 880, minHeight: 560)
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
            presetStrength: state.presetStrength
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
