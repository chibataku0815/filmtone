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

    func presentHighlightReelPanel(for state: EditorState) {
        guard state.canCreateHighlightReel,
              let sourceURL = state.sourceURL else {
            return
        }
        presentVideoHighlightReelPanel(state: state, sourceURL: sourceURL)
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
        panel.nameFieldStringValue = FilmtoneExportFilename.defaultFilename(
            sourceURL: sourceURL,
            presetName: state.presetName,
            lookSlug: state.lookSlug,
            fileExtension: state.exportFormat.fileExtension
        )
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
            paramOverrides: state.paramOverrides,
            packageCreativeLut: state.packageCreativeLut,
            importedGradeLook: state.selectedImportedGrade,
            importedGradeSidecarURL: state.selectedImportedGradeSidecarURL,
            gradeRecipe: state.currentGradeRecipe,
            capturePackageProvenance: state.capturePackageProvenance,
            highlightMarkers: nil,
            opticalFilterProfileId: state.opticalFilterProfileId,
            opticalFilterIntensity: state.opticalFilterIntensity
        )

        let startedAt = Date()
        state.exportStartedAt = startedAt
        state.lastExportResult = nil
        state.lastExportError = nil
        state.isExporting = true
        state.exportProgress = 0
        state.exportProgressMessage = "Exporting still…"
        state.currentExportTask = Task.detached {
            let scopedURLs = Self.startSandboxAccess(forSource: request.sourceURL, output: request.outputURL)
            defer { Self.stopSandboxAccess(scopedURLs) }
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
                        sourceKind: .still,
                        videoTimingMode: nil,
                        outputFrameRate: nil
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
        panel.nameFieldStringValue = FilmtoneExportFilename.defaultFilename(
            sourceURL: sourceURL,
            presetName: state.presetName,
            lookSlug: state.lookSlug,
            fileExtension: "mp4"
        )
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
            paramOverrides: state.paramOverrides,
            packageCreativeLut: state.packageCreativeLut,
            importedGradeLook: state.selectedImportedGrade,
            importedGradeSidecarURL: state.selectedImportedGradeSidecarURL,
            gradeRecipe: state.currentGradeRecipe,
            capturePackageProvenance: state.capturePackageProvenance,
            highlightMarkers: state.exportHighlightMarkers,
            opticalFilterProfileId: state.opticalFilterProfileId,
            opticalFilterIntensity: state.opticalFilterIntensity,
            outputLongEdgeLimit: state.videoExportOutputLongEdgeLimit,
            videoTimingMode: state.resolvedVideoTimingMode
        )

        let startedAt = Date()
        state.exportStartedAt = startedAt
        state.lastExportResult = nil
        state.lastExportError = nil
        state.isExporting = true
        state.exportProgress = 0
        state.exportProgressMessage = "Reading video…"
        state.currentExportTask = Task.detached {
            let scopedURLs = Self.startSandboxAccess(forSource: request.sourceURL, output: request.outputURL)
            defer { Self.stopSandboxAccess(scopedURLs) }
            do {
                let result = try await FilmtoneVideoExporter.export(request) { progress in
                    Task { @MainActor in
                        state.exportProgress = progress.normalized
                        state.exportProgressMessage = progress.message
                            ?? "Rendering frame \(progress.processedFrames)/\(progress.estimatedTotalFrames)"
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
                        sourceKind: .video,
                        videoTimingMode: result.videoTimingMode,
                        outputFrameRate: result.outputFrameRate
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

    private func presentVideoHighlightReelPanel(state: EditorState, sourceURL: URL) {
        switch state.highlightReelOutputMode {
        case .combined:
            presentCombinedVideoHighlightReelPanel(state: state, sourceURL: sourceURL)
        case .separate:
            presentSeparateVideoHighlightClipsPanel(state: state, sourceURL: sourceURL)
        }
    }

    private func presentCombinedVideoHighlightReelPanel(state: EditorState, sourceURL: URL) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent
            + "-highlight-\(FilmtoneFormatters.formattedSecondsShort(state.highlightReelClipDurationSec)).mp4"
        panel.message = "Export a silent Highlight from video markers"
        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        let request = makeVideoHighlightReelRequest(
            state: state,
            sourceURL: sourceURL,
            outputURL: outputURL
        )
        let options = state.highlightReelOptions

        let startedAt = Date()
        state.exportStartedAt = startedAt
        state.lastExportResult = nil
        state.lastExportError = nil
        state.isExporting = true
        state.exportProgress = 0
        state.exportProgressMessage = "Building Highlight…"
        state.currentExportTask = Task.detached {
            let scopedURLs = Self.startSandboxAccess(forSource: request.sourceURL, output: request.outputURL)
            defer { Self.stopSandboxAccess(scopedURLs) }
            do {
                let result = try await FilmtoneVideoExporter.exportHighlightReel(request, options: options) { progress in
                    Task { @MainActor in
                        state.exportProgress = progress.normalized
                        state.exportProgressMessage = progress.message
                            ?? "Rendering frame \(progress.processedFrames)/\(progress.estimatedTotalFrames)"
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
                        sidecarURL: nil,
                        pixelWidth: result.outputWidth,
                        pixelHeight: result.outputHeight,
                        processedFrames: result.processedFrames,
                        fileSizeBytes: fileSize,
                        elapsedSeconds: elapsed,
                        sourceKind: .video,
                        videoTimingMode: result.videoTimingMode,
                        outputFrameRate: result.outputFrameRate
                    )
                    state.currentExportTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 0
                    state.exportProgressMessage = nil
                    state.lastExportError = "Highlight cancelled"
                    state.currentExportTask = nil
                }
            } catch {
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 0
                    state.exportProgressMessage = nil
                    state.lastExportError = "Highlight failed: \(error.localizedDescription)"
                    state.currentExportTask = nil
                }
            }
        }
    }

    private func presentSeparateVideoHighlightClipsPanel(state: EditorState, sourceURL: URL) {
        guard let segments = state.exportHighlightMarkers?.highlightReelSegments(options: state.highlightReelOptions),
              !segments.isEmpty else {
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        panel.message = "Choose a folder for separate Highlight clips"
        guard panel.runModal() == .OK, let directoryURL = panel.url else { return }

        var reservedPaths = Set<String>()
        let outputURLs = segments.indices.map { index in
            Self.uniqueHighlightClipURL(
                directoryURL: directoryURL,
                sourceURL: sourceURL,
                durationSec: state.highlightReelClipDurationSec,
                index: index,
                reservedPaths: &reservedPaths
            )
        }
        let exportItems = zip(segments, outputURLs).map { pair in
            let (segment, outputURL) = pair
            return (
                segment: segment,
                request: makeVideoHighlightReelRequest(
                    state: state,
                    sourceURL: sourceURL,
                    outputURL: outputURL
                )
            )
        }

        let startedAt = Date()
        state.exportStartedAt = startedAt
        state.lastExportResult = nil
        state.lastExportError = nil
        state.isExporting = true
        state.exportProgress = 0
        state.exportProgressMessage = "Building Highlight clips…"
        state.currentExportTask = Task.detached {
            let scopedURLs = Self.startSandboxAccess(forSource: sourceURL, outputs: outputURLs)
            defer { Self.stopSandboxAccess(scopedURLs) }
            do {
                let total = max(1, exportItems.count)
                var firstResult: FilmtoneVideoExportResult?
                var processedFrames = 0
                for (index, item) in exportItems.enumerated() {
                    try Task.checkCancellation()
                    let result = try await FilmtoneVideoExporter.exportHighlightReel(
                        item.request,
                        segments: [item.segment]
                    ) { progress in
                        let normalized = min(1.0, (Double(index) + progress.normalized) / Double(total))
                        Task { @MainActor in
                            state.exportProgress = normalized
                            state.exportProgressMessage = progress.message
                                ?? "Rendering clip \(index + 1)/\(total)"
                        }
                    }
                    if firstResult == nil {
                        firstResult = result
                    }
                    processedFrames += result.processedFrames
                }

                guard let firstResult else {
                    throw FilmtoneVideoExportError.noHighlightMarkers
                }

                let fileSize = outputURLs.reduce(Int64(0)) { total, url in
                    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                    return total + size
                }
                let elapsed = Date().timeIntervalSince(startedAt)
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 1
                    state.exportProgressMessage = nil
                    state.lastExportSummary = nil
                    state.lastExportError = nil
                    state.lastExportResult = ExportResultSnapshot(
                        outputURL: directoryURL,
                        sidecarURL: nil,
                        pixelWidth: firstResult.outputWidth,
                        pixelHeight: firstResult.outputHeight,
                        processedFrames: processedFrames,
                        fileSizeBytes: fileSize,
                        elapsedSeconds: elapsed,
                        sourceKind: .video,
                        videoTimingMode: .normal,
                        outputFrameRate: firstResult.outputFrameRate,
                        shareURLs: outputURLs
                    )
                    state.currentExportTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 0
                    state.exportProgressMessage = nil
                    state.lastExportError = "Highlight cancelled"
                    state.currentExportTask = nil
                }
            } catch {
                await MainActor.run {
                    state.isExporting = false
                    state.exportProgress = 0
                    state.exportProgressMessage = nil
                    state.lastExportError = "Highlight failed: \(error.localizedDescription)"
                    state.currentExportTask = nil
                }
            }
        }
    }

    private func makeVideoHighlightReelRequest(
        state: EditorState,
        sourceURL: URL,
        outputURL: URL
    ) -> FilmtoneVideoExportRequest {
        FilmtoneVideoExportRequest(
            sourceURL: sourceURL,
            outputURL: outputURL,
            presetName: state.presetName,
            presetStrength: state.presetStrength,
            lookSlug: state.lookSlug,
            sourceProfileSelection: state.sourceProfileSelection,
            quickState: state.quickState,
            paramOverrides: state.paramOverrides,
            packageCreativeLut: state.packageCreativeLut,
            importedGradeLook: state.selectedImportedGrade,
            importedGradeSidecarURL: state.selectedImportedGradeSidecarURL,
            gradeRecipe: state.currentGradeRecipe,
            capturePackageProvenance: state.capturePackageProvenance,
            highlightMarkers: state.exportHighlightMarkers,
            opticalFilterProfileId: state.opticalFilterProfileId,
            opticalFilterIntensity: state.opticalFilterIntensity,
            outputLongEdgeLimit: state.videoExportOutputLongEdgeLimit
        )
    }

    nonisolated private static func uniqueHighlightClipURL(
        directoryURL: URL,
        sourceURL: URL,
        durationSec: Double,
        index: Int,
        reservedPaths: inout Set<String>
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let durationLabel = FilmtoneFormatters.formattedSecondsShort(durationSec)
        let numberedName = "\(baseName)-highlight-\(durationLabel)-\(String(format: "%02d", index + 1))"
        var candidate = directoryURL
            .appendingPathComponent(numberedName)
            .appendingPathExtension("mp4")
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) || reservedPaths.contains(candidate.path) {
            candidate = directoryURL
                .appendingPathComponent("\(numberedName)-\(suffix)")
                .appendingPathExtension("mp4")
            suffix += 1
        }
        reservedPaths.insert(candidate.path)
        return candidate
    }

    nonisolated private static func startSandboxAccess(forSource sourceURL: URL, output outputURL: URL) -> [URL] {
        startSandboxAccess(forSource: sourceURL, outputs: [outputURL])
    }

    nonisolated private static func startSandboxAccess(forSource sourceURL: URL, outputs outputURLs: [URL]) -> [URL] {
        let candidates = [
            sourceURL,
        ] + outputURLs + outputURLs.map { $0.deletingLastPathComponent() }

        var seen = Set<URL>()
        var scopedURLs: [URL] = []
        for candidate in candidates {
            let url = candidate.standardizedFileURL
            guard seen.insert(url).inserted else { continue }
            if url.startAccessingSecurityScopedResource() {
                scopedURLs.append(url)
            }
        }
        return scopedURLs
    }

    nonisolated private static func stopSandboxAccess(_ scopedURLs: [URL]) {
        for url in scopedURLs.reversed() {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
