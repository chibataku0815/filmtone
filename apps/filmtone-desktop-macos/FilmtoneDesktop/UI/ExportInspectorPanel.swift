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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            Picker("Format", selection: $state.exportFormat) {
                Text("PNG").tag(StillExportFormat.png)
                Text("JPEG").tag(StillExportFormat.jpeg)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .colorScheme(.dark)
            .disabled(state.sourceKind == .video)

            if state.exportFormat == .jpeg && state.sourceKind == .still {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Quality")
                            .font(.callout)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int((state.jpegQuality * 100).rounded()))%")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Slider(value: $state.jpegQuality, in: 0.5...1.0)
                        .tint(.white)
                }
            }

            if let lastError = state.lastExportError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(Color.orange.opacity(0.95))
                    .lineLimit(3)
            }

            Button {
                onExportTap()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(state.sourceKind == .video ? "Export Video…" : "Export Still…")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(state.sourceURL == nil)
        }
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
                .controlSize(.small)
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
                .controlSize(.small)

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
            .controlSize(.small)
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

    var body: some View {
        ShareAnchor(url: url)
            .frame(maxWidth: .infinity)
            .frame(height: 22)
    }
}

private struct ShareAnchor: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "Share", target: context.coordinator, action: #selector(Coordinator.share(_:)))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")
        button.imagePosition = .imageLeading
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.url = url
        nsView.target = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject {
        var url: URL
        init(url: URL) { self.url = url }

        @objc func share(_ sender: NSButton) {
            let picker = NSSharingServicePicker(items: [url])
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}
