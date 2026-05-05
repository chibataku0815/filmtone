import AppKit
import AVFoundation
import FilmLabSwiftCore
import SwiftUI
import UniformTypeIdentifiers

struct RootWindowView: View {
    @State private var state = EditorState()
    @State private var library = LibraryViewModel()
    // M5-G.1: export user flow lives on the coordinator now. Root view
    // just calls into it from the toolbar Export button + the inspector
    // tap callback (P2 from 2026-05-05 review).
    @State private var exportCoordinator = ExportCoordinator()

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
            // M5-H.1: the leading `GlassControlGroup()` "Phase 0" placeholder
            // banner was retired — the right rail now opens directly with
            // the source-loaded panels (or stays empty until a source loads).
            GlassEffectContainer(spacing: 12) {
                VStack(alignment: .trailing, spacing: 12) {
                    if state.sourceURL != nil {
                        // M5-C.1: Source Profile Picker — sits above the Look
                        // controls so the user picks the input transform
                        // before the Look layer. Same Pass 4 dark-tinted
                        // .clear glass posture for visual continuity.
                        SourceProfileControls(state: state)
                            .padding(.horizontal, 16)
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassEffect(
                                .clear.tint(.black.opacity(0.30)),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        // M5-C.3a: Quick adjust 3-axis sliders sit between
                        // Look selection and Strength so the user reads
                        // top-down: input → Look → Quick offsets → Strength.
                        QuickAdjustControls(state: state)
                            .padding(.horizontal, 16)
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
                            .padding(.horizontal, 16)
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
                            onExportTap: { exportCoordinator.presentExportPanel(for: state) }
                        )
                        .padding(.horizontal, 16)
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
                        .padding(.horizontal, 16)
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
        // M5-H.1: with the 5-panel right rail (SourceProfile / LookLibrary
        // / QuickAdjust / Grade / ExportInspector) the previous
        // 880×560 minimum could clip the rail vertically once a source
        // loaded. Bumping to 1080×720 keeps the rail visible at minimum
        // size; .defaultSize on WindowGroup opens at a roomier 1280×800.
        .frame(minWidth: 1080, minHeight: 720)
        // M5-I.2: any edit that changes a render input must rebuild the
        // graded `AVMutableVideoComposition` so the next composed frame
        // reflects the user's intent. Collapsing the 7 individual
        // `.onChange(of:)` modifiers into one Hashable refresh key keeps
        // the SwiftUI body type-checker tractable (the long modifier
        // chain previously tripped "expression too complex"); the
        // session itself debounces 100ms to absorb rapid Slider drags.
        // No-op for stills (videoSession is nil).
        .onChange(of: VideoCompositionRefreshKey(state: state)) { _, _ in
            state.refreshVideoCompositionIfNeeded()
        }
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
                // M5-H.1: replace the `camera.aperture` SF Symbol placeholder
                // with the iOS-canonical AppIcon (already populated by
                // M5-E.1, commit 758ada3a). NSApp.applicationIconImage is
                // the live runtime icon, so we don't duplicate the asset.
                // Group wraps the optional so ToolbarContentBuilder gets a
                // concrete View (some View?) — without it the build fails
                // on `'ToolbarItem<(), some View?>' conform to 'View'`.
                Group {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 20, height: 20)
                    }
                }
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
                    exportCoordinator.presentExportPanel(for: state)
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

}

/// M5-A.3 / M5-D.2 / M5-I.2: scrub bar for video preview. The Slider
/// drives `AVPlayer.seek(to:)` directly; the periodic time observer in
/// `FilmtoneDesktopVideoSession` pushes player time back into
/// `state.videoPreviewSeconds` so the thumb follows playback. Manual
/// drag flips `state.isScrubbing` so the observer doesn't yank the
/// thumb mid-drag, and pauses playback for the duration of the drag.
/// Adds a 1×/2×/3× rate menu (M5-I.2 acceptance).
private struct VideoScrubBar: View {
    @Bindable var state: EditorState
    let duration: Double

    private var seconds: Binding<Double> {
        Binding(
            get: { state.videoPreviewSeconds ?? 0 },
            set: { newValue in
                let clamped = max(0, min(newValue, duration))
                state.videoPreviewSeconds = clamped
                state.seekVideo(toSeconds: clamped)
            }
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
                    // Drag start: hold the periodic time observer off so
                    // it doesn't fight the user's finger; pause playback
                    // so AVPlayer doesn't keep advancing under the seek.
                    // Drag end: clear the flag and let the observer
                    // resume time updates. Resume must be explicit Play.
                    state.isScrubbing = editing
                    if editing {
                        state.videoSession?.pause()
                    }
                }
            )
            Text(format(duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .trailing)
            PlaybackRateMenu(state: state)
        }
        .frame(maxWidth: 600)
    }

    private func format(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "0:00.00" }
        let total = value
        let minutes = Int(total / 60)
        let secondsRemainder = total - Double(minutes * 60)
        return String(format: "%d:%05.2f", minutes, secondsRemainder)
    }
}

/// M5-I.2: snapshot of EditorState fields that, when any change, mean
/// the graded `AVMutableVideoComposition` must be rebuilt. Collapses
/// what would otherwise be 7 chained `.onChange(of:)` modifiers (which
/// trip the SwiftUI body type-checker on `RootWindowView`) into one
/// Equatable value the body can watch.
private struct VideoCompositionRefreshKey: Equatable {
    let presetName: String
    let presetStrength: Double
    let lookSlug: String?
    let sourceProfileSelection: CameraProfileSelection
    let probedSourceColorClass: SourceColorClassDTO?
    let quickState: FilmtoneQuickState
    let paramOverrides: FilmtonePhase0ParamsPatch

    @MainActor
    init(state: EditorState) {
        self.presetName = state.presetName
        self.presetStrength = state.presetStrength
        self.lookSlug = state.lookSlug
        self.sourceProfileSelection = state.sourceProfileSelection
        self.probedSourceColorClass = state.probedSourceColorClass
        self.quickState = state.quickState
        self.paramOverrides = state.paramOverrides
    }
}

/// M5-I.2: 1× / 2× / 3× playback rate selector. Sits on the right of
/// the scrub bar; matches the dark Liquid Glass posture of the
/// surrounding capsule via `.colorScheme(.dark)` so the AppKit-bridged
/// menu chrome inherits white-on-dark.
private struct PlaybackRateMenu: View {
    @Bindable var state: EditorState

    private static let options: [Double] = [1.0, 2.0, 3.0]

    var body: some View {
        Menu {
            ForEach(Self.options, id: \.self) { rate in
                Button {
                    state.setPlaybackRate(rate)
                } label: {
                    HStack {
                        Text("\(Self.label(for: rate))")
                        if abs(rate - state.playbackRate) < 0.01 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(Self.label(for: state.playbackRate))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
                .frame(minWidth: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .controlSize(.small)
        .colorScheme(.dark)
        .help("Playback rate")
    }

    private static func label(for rate: Double) -> String {
        // Integer rates render as "1×", "2×"; fractional rates fall back
        // to one decimal so future additions like 0.5× display sanely.
        if abs(rate.rounded() - rate) < 0.01 {
            return "\(Int(rate))×"
        }
        return String(format: "%.1f×", rate)
    }
}

#Preview {
    RootWindowView()
}
