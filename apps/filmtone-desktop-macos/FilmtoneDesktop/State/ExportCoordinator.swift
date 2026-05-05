import AppKit
import FilmLabSwiftCore
import Foundation
import UniformTypeIdentifiers

// M5-G.1: Export flow coordinator carved out of `RootWindowView` so the
// root view's responsibility stays "compose panels + wire toolbar". The
// coordinator owns the user-facing export sequence: present
// `NSSavePanel`, build the `Filmtone*ExportRequest`, spawn the
// detached Task, and feed result / error back into `EditorState`.
//
// Stateless against `EditorState` for now — `isExporting` /
// `exportProgress` / `lastExportResult` / `currentExportTask` etc. still
// live on `EditorState` because `ExportInspectorPanel` already binds
// against them. A follow-up slice may promote this to `@Observable` and
// pull those fields onto the coordinator so `EditorState` shrinks back
// toward "render-state only".
@MainActor
final class ExportCoordinator {
    func presentExportPanel(for state: EditorState) {
        guard let sourceURL = state.sourceURL else { return }
        switch state.sourceKind {
        case .still:
            presentStillExportPanel(state: state, sourceURL: sourceURL)
        case .video:
            presentVideoExportPanel(state: state, sourceURL: sourceURL)
        }
    }

    // MARK: - Still

    private func presentStillExportPanel(state: EditorState, sourceURL: URL) {
        // M5-C.4: format / quality come from the inspector controls,
        // not the NSSavePanel filename extension. The panel still
        // accepts both content types so the user can override the
        // extension manually if they want.
        let panel = NSSavePanel()
        panel.allowedContentTypes = state.exportFormat == .jpeg ? [.jpeg, .png] : [.png, .jpeg]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent
            + "-" + state.presetName
            + "." + state.exportFormat.fileExtension
        panel.message = "Export the still + sidecar JSON"
        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        // Inspector-driven format wins; if the user hand-typed a
        // mismatched extension, we still honor inspector intent because
        // the encoder is what writes the bytes.
        let format = state.exportFormat
        let jpegQuality = state.jpegQuality

        let request = FilmtoneStillExportRequest(
            sourceURL: sourceURL,
            outputURL: outputURL,
            presetName: state.presetName,
            presetStrength: state.presetStrength,
            lookSlug: state.lookSlug,
            format: format,
            jpegQuality: jpegQuality,
            sourceProfileSelection: state.sourceProfileSelection,
            quickState: state.quickState,
            paramOverrides: state.paramOverrides
        )

        let startedAt = Date()
        state.exportStartedAt = startedAt
        state.lastExportResult = nil
        state.lastExportError = nil
        state.isExporting = true
        state.exportProgress = 0
        state.exportProgressMessage = "Exporting still…"
        state.currentExportTask = Task.detached {
            do {
                let result = try FilmtoneStillExporter.export(request)
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: result.outputURL.path)[.size] as? Int64) ?? 0
                let elapsed = Date().timeIntervalSince(startedAt)
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 1
                    state.exportProgressMessage = nil
                    state.lastExportSummary = nil
                    state.lastExportError = nil
                    state.lastExportResult = ExportResultSnapshot(
                        outputURL: result.outputURL,
                        sidecarURL: result.sidecarURL,
                        pixelWidth: result.pixelWidth,
                        pixelHeight: result.pixelHeight,
                        processedFrames: nil,
                        fileSizeBytes: fileSize,
                        elapsedSeconds: elapsed,
                        sourceKind: .still
                    )
                    state.currentExportTask = nil
                }
            } catch {
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 0
                    state.exportProgressMessage = nil
                    state.lastExportError = "Export failed: \(error.localizedDescription)"
                    state.currentExportTask = nil
                }
            }
        }
    }

    // MARK: - Video

    private func presentVideoExportPanel(state: EditorState, sourceURL: URL) {
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
            lookSlug: state.lookSlug,
            sourceProfileSelection: state.sourceProfileSelection,
            quickState: state.quickState,
            paramOverrides: state.paramOverrides
        )

        let startedAt = Date()
        state.exportStartedAt = startedAt
        state.lastExportResult = nil
        state.lastExportError = nil
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
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: result.outputURL.path)[.size] as? Int64) ?? 0
                let elapsed = Date().timeIntervalSince(startedAt)
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 1
                    state.exportProgressMessage = nil
                    state.lastExportSummary = nil
                    state.lastExportError = nil
                    state.lastExportResult = ExportResultSnapshot(
                        outputURL: result.outputURL,
                        sidecarURL: result.sidecarURL,
                        pixelWidth: result.outputWidth,
                        pixelHeight: result.outputHeight,
                        processedFrames: result.processedFrames,
                        fileSizeBytes: fileSize,
                        elapsedSeconds: elapsed,
                        sourceKind: .video
                    )
                    state.currentExportTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 0
                    state.exportProgressMessage = nil
                    state.lastExportError = "Export cancelled"
                    state.currentExportTask = nil
                }
            } catch {
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 0
                    state.exportProgressMessage = nil
                    state.lastExportError = "Export failed: \(error.localizedDescription)"
                    state.currentExportTask = nil
                }
            }
        }
    }
}
