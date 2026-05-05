import AppKit
import SwiftUI

// M5-C.4: Mac-native Export Inspector. Mirrors iOS canonical
// `FilmtoneExportPanel`'s 4-state surface (blocked / progress /
// finished / ready) but using Mac-native idioms:
//   - Save to Photos  → Reveal in Finder (NSWorkspace)
//   - iOS share sheet → NSSharingServicePicker
//
// State priority matches iOS: source-cap blocked beats progress beats
// finished beats ready. Width-locked at 220pt to match the rest of the
// right-rail panels (Source Profile / Look / Quick / Grade).

struct ExportInspectorPanel: View {
    @Bindable var state: EditorState
    let onExportTap: () -> Void
    let onHighlightReelTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
            statePanel
        }
        .frame(width: 220)
    }

    @ViewBuilder
    private var statePanel: some View {
        if !state.sourceCapViolations.isEmpty {
            blockedState
        } else if state.isExporting {
            progressState
        } else if let result = state.lastExportResult {
            finishedState(result: result)
        } else {
            readyState
        }
    }

    // MARK: - States

    private var readyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            formatSelector

            if state.exportFormat == .jpeg && state.sourceKind == .still {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quality")
                            .font(.callout)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int((state.jpegQuality * 100).rounded()))%")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    FilmtoneGlassSlider(value: $state.jpegQuality, range: 0.5...1.0)
                }
            }

            if let lastError = state.lastExportError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(Color.orange.opacity(0.95))
                    .lineLimit(3)
            }

            // M5-F.1: Apple canonical macOS 26 prominent button posture
            // for the right-rail dark-tinted Liquid Glass container.
            // Replaces .borderedProminent (system blue solid box) which
            // read as out-of-family on the dark glass chrome.
            Button {
                onExportTap()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(state.sourceKind == .video ? "Export Video…" : "Export Still…")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilmtoneGlassPrimaryButtonStyle())
            .disabled(state.sourceURL == nil)
            .filmtonePointingHandCursor(state.sourceURL != nil)

            if state.canCreateHighlightReel {
                Button {
                    onHighlightReelTap()
                } label: {
                    HStack {
                        Image(systemName: "film.stack")
                        Text("Highlight…")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
                .accessibilityIdentifier("filmtone.export.highlightReel")
                .filmtonePointingHandCursor()
            }
        }
    }

    private var formatSelector: some View {
        HStack(spacing: 4) {
            exportFormatButton(.png, label: "PNG")
            exportFormatButton(.jpeg, label: "JPEG")
        }
        .padding(4)
        .frame(width: 220)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.16))
        )
        .glassEffect(
            .clear.tint(Color.white.opacity(0.07)),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .disabled(state.sourceKind == .video)
    }

    private func exportFormatButton(_ format: StillExportFormat, label: String) -> some View {
        Button {
            state.exportFormat = format
        } label: {
            Text(label)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(FilmtoneGlassSegmentButtonStyle(isSelected: state.exportFormat == format))
        .filmtonePointingHandCursor(state.sourceKind != .video)
    }

    private var progressState: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int((state.exportProgress * 100).rounded()))%")
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                Spacer()
                Button("Cancel") {
                    state.cancelExport()
                }
                .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
                .filmtonePointingHandCursor()
            }
            ProgressView(value: state.exportProgress)
                .progressViewStyle(.linear)
                .tint(.white)
            if let message = state.exportProgressMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
    }

    private func finishedState(result: ExportResultSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(FilmtoneFormatters.formattedElapsed(result.elapsedSeconds))
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                Spacer()
                Text("Done")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.85), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                MetricRow(
                    label: "Output",
                    value: "\(result.pixelWidth)×\(result.pixelHeight)"
                        + (result.processedFrames.map { " · \($0)f" } ?? "")
                )
                MetricRow(
                    label: "File size",
                    value: FilmtoneFormatters.formattedFileSize(result.fileSizeBytes)
                )
                MetricRow(
                    label: "File",
                    value: result.outputURL.lastPathComponent
                )
                if let sidecarURL = result.sidecarURL {
                    MetricRow(
                        label: "Sidecar",
                        value: sidecarURL.lastPathComponent
                    )
                }
            }

            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([result.outputURL])
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                        Text("Reveal")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
                .filmtonePointingHandCursor()

                ShareSourceButton(url: result.outputURL)
            }

            Button {
                state.resetExportResult()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Export Again")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
            .filmtonePointingHandCursor()
        }
    }

    private var blockedState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                Text("Export disabled")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
            }
            ForEach(state.sourceCapViolations, id: \.self) { reason in
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            Color.orange.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Share button (NSSharingServicePicker bridge)

/// AppKit bridge so `NSSharingServicePicker` anchors near the button.
/// SwiftUI's `ShareLink` doesn't expose anchor placement on macOS the
/// way the iOS share sheet handles itself, and on a tinted-glass rail
/// we want the popover to land below the button rather than under the
/// cursor.
private struct ShareSourceButton: View {
    let url: URL
    @State private var shareRequest = 0

    var body: some View {
        Button {
            shareRequest += 1
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                Text("Share")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
        .filmtonePointingHandCursor()
        .background(ShareAnchor(url: url, request: shareRequest))
    }
}

private struct ShareAnchor: NSViewRepresentable {
    let url: URL
    let request: Int

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.anchorView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.url = url
        context.coordinator.anchorView = nsView
        context.coordinator.showIfNeeded(request: request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject {
        var url: URL
        weak var anchorView: NSView?
        private var lastRequest = 0

        init(url: URL) { self.url = url }

        @MainActor
        func showIfNeeded(request: Int) {
            guard request != lastRequest else { return }
            lastRequest = request
            guard request > 0, let anchorView else { return }
            let picker = NSSharingServicePicker(items: [url])
            picker.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        }
    }
}
