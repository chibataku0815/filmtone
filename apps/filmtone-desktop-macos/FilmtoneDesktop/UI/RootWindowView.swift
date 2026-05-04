import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct RootWindowView: View {
    @State private var state = EditorState()
    @State private var library = LibraryViewModel()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PreviewSurface(
                state: state,
                sourceURL: state.sourceURL,
                sourceKind: state.sourceKind,
                presetName: state.presetName,
                presetStrength: state.presetStrength,
                lookSlug: state.lookSlug,
                videoPreviewSeconds: state.videoPreviewSeconds,
                sourceProfileSelection: state.sourceProfileSelection,
                quickState: state.quickState,
                paramOverrides: state.paramOverrides
            )
            // M5-B Pass 3: user confirmed `.clear` posture is the correct
            // Apple Liquid Glass dramatic refraction; all panels and the
            // capsule unified on `.clear`. GlassEffectContainer(spacing: 12)
            // coordinates morphing/refraction across the right rail.
            GlassEffectContainer(spacing: 12) {
                VStack(alignment: .trailing, spacing: 12) {
                    GlassControlGroup()
                    if state.sourceURL != nil {
                        // M5-C.1: Source Profile Picker — sits above the Look
                        // controls so the user picks the input transform
                        // before the Look layer. Same Pass 4 dark-tinted
                        // .clear glass posture for visual continuity.
                        SourceProfileControls(state: state)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect(
                                .clear.tint(.black.opacity(0.30)),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        // M5-C.2a: snapshot-driven Look library Picker +
                        // "Save Current Look…" button. Sits between the
                        // source-side normalization and the strength slider
                        // so the user picks input → Look → strength in
                        // top-down reading order.
                        LookLibraryControls(state: state, library: library)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect(
                                .clear.tint(.black.opacity(0.30)),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        // M5-C.3a: Quick adjust 3-axis sliders sit between
                        // Look selection and Strength so the user reads
                        // top-down: input → Look → Quick offsets → Strength.
                        QuickAdjustControls(state: state)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect(
                                .clear.tint(.black.opacity(0.30)),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        // M5-B Pass 4: subtle dark tint on `.clear` Liquid
                        // Glass gives the operating panel a stable luminance
                        // baseline for white text + visible Slider track,
                        // while preserving Pass 3's dramatic refraction
                        // posture on the rest of the chrome.
                        GradeControls(state: state)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect(
                                .clear.tint(.black.opacity(0.30)),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        // M5-C.4: Mac-native Export Inspector replaces
                        // the previous one-line ExportProgressBar +
                        // toolbar-only flow. Persistent panel that
                        // surfaces format / quality controls before the
                        // run, live progress while running, and elapsed
                        // / dims / file size / Reveal / Share after.
                        ExportInspectorPanel(
                            state: state,
                            onExportTap: { presentExportPanel() }
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(
                            .clear.tint(.black.opacity(0.30)),
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
                    // M5-D.1: dark-tinted .clear posture matches the
                    // right-rail panels so the scrub bar reads as the same
                    // chrome family and stays visible on bright preview
                    // frames where untinted .clear refracts into the
                    // backdrop.
                    VideoScrubBar(state: state, duration: duration)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(
                            .clear.tint(.black.opacity(0.30)),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .padding(.bottom, 60)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 880, minHeight: 560)
        // M5-C.2a: load the on-disk library so the Picker lists saved
        // Looks at first paint. Built-in Stone / Urban appear immediately
        // via the empty-snapshot prefix path; user-saved entries fade in
        // once the actor returns.
        .task {
            await library.bootstrap()
        }
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
                .disabled(exportDisabled)
                .help(exportHelpText)
            }
        }
    }

    private var sourceCapBlocked: Bool {
        guard state.sourceURL != nil else { return false }
        return FilmtoneSourceInputTransform.sourceExceedsCapacity(
            selection: state.sourceProfileSelection,
            probedColorClass: state.probedSourceColorClass
        )
    }

    private var exportDisabled: Bool {
        state.sourceURL == nil || state.isExporting || sourceCapBlocked
    }

    private var exportHelpText: String {
        if sourceCapBlocked,
           let reason = FilmtoneSourceInputTransform.sourceCapReason(
            probedColorClass: state.probedSourceColorClass
           ) {
            return reason
        }
        return state.sourceKind == .video ? "Export the current video" : "Export the current still"
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
        // M5-C.4: format / quality come from the inspector's controls,
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

/// M5-A.3: scrub bar for video preview. Continuous binding to
/// `state.videoPreviewSeconds`; coalescing of rapid drag events happens
/// downstream in `PreviewSurface` via in-flight Task cancellation.
/// M5-D.2: gains a Play/Pause button + Space-key shortcut. Manual scrub
/// drag pauses playback via `onEditingChanged`.
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
            Button {
                state.togglePlayback()
            } label: {
                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .keyboardShortcut(.space, modifiers: [])
            .help(state.isPlaying ? "Pause (Space)" : "Play (Space)")
            Text(format(seconds.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .leading)
            Slider(
                value: seconds,
                in: 0...max(duration, 0.001),
                onEditingChanged: { editing in
                    // Pause playback the moment the user grabs the scrub
                    // thumb so the ticker doesn't fight the drag.
                    if editing { state.stopPlayback() }
                }
            )
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

#Preview {
    RootWindowView()
}
