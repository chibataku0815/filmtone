import AppKit
import AVFoundation
import FilmLabSwiftCore
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct RootWindowView: View {
    @State private var state = EditorState()
    @State private var library = LibraryViewModel()
    @State private var hostingWindow: NSWindow?
    @State private var minimumContentSize = CGSize(width: 1080, height: 720)
    @State private var rootSafeAreaTopInset: CGFloat = 0
    // M5-G.1: export user flow lives on the coordinator now. Root view
    // just calls into it from the toolbar Export button + the inspector
    // tap callback (P2 from 2026-05-05 review).
    @State private var exportCoordinator = ExportCoordinator()
    // M5-J1: editing sidebar open/close persists across launches and
    // across source changes. `@AppStorage` writes do not reset when
    // `state.setSource` runs, so the user's last preference holds.
    @AppStorage("editorSidebarOpen") private var sidebarOpen: Bool = true

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
                paramOverrides: state.paramOverrides,
                compareEnabled: state.isCompareEnabled,
                onOpenRequested: { presentOpenPanel() }
            )
            .ignoresSafeArea(.container, edges: .all)
            // M5-J1: the right-rail panel stack moved into `EditorSidebar`
            // so the chrome can:
            //   1) reserve top inset (72pt) for the unified toolbar +
            //      breathing margin so panels never tuck under the
            //      titlebar/glass toolbar background;
            //   2) reserve bottom inset (120pt) so panels never overlap
            //      the floating `VideoScrubBar` capsule for video sources;
            //   3) clip vertical overflow into the sidebar's internal
            //      ScrollView so a tall stack (Source/Look/Quick/Grade/
            //      Inspector) is always operable, regardless of source
            //      kind or window height;
            //   4) collapse cleanly via `⌘\` / toolbar `sidebar.right`
            //      so the preview can reclaim the full window width.
            // The `if sidebarOpen` gate uses `@AppStorage`, so the user's
            // last preference persists across source changes and relaunches.
            if sidebarOpen {
                EditorSidebar(
                    state: state,
                    library: library,
                    exportCoordinator: exportCoordinator
                )
                .padding(.top, 72)
                .padding(.bottom, 120)
                .padding(.trailing, 12)
            }
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
                        .padding(.vertical, 16)
                        .glassEffect(
                            .clear.tint(.black.opacity(0.30)),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .padding(.bottom, 64)
                }
                .frame(maxWidth: .infinity)
            }
        }
        // M5-I.4a follow-up: empty launch keeps a roomier floor, then
        // opening media relaxes the floor to that source's display aspect
        // so the window behaves closer to QuickTime instead of forcing
        // letterbox / pillarbox through a fixed desktop minimum.
        .frame(minWidth: minimumContentSize.width, minHeight: minimumContentSize.height)
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
        .background(WindowAccessor { window in
            resolveWindow(window)
        })
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: RootSafeAreaTopInsetKey.self,
                    value: proxy.safeAreaInsets.top
                )
            }
        )
        .onPreferenceChange(RootSafeAreaTopInsetKey.self) { inset in
            rootSafeAreaTopInset = inset
        }
        // Hide the opaque AppKit toolbar background so the unified chrome can
        // refract the preview / opening surface. The titlebar brand is hidden
        // separately in `configureWindowForTransparentGlass(_:)`; Open /
        // Export stay as the only visible toolbar actions.
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentOpenPanel()
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .keyboardShortcut("o", modifiers: .command)
                .buttonStyle(.glass)
                .help("Open a still image or video")
                .filmtonePointingHandCursor()
            }
            ToolbarItem(placement: .primaryAction) {
                // M5-J.2: Before/After 50:50 compare toggle. Disabled
                // until a source is loaded so the unmodified `V` shortcut
                // is a no-op in the empty state. Save Look rename / save
                // prompts use AppKit `NSAlert` (modal, separate keyWindow)
                // so the toolbar shortcut does not fire while a prompt is
                // up. SF Symbol flips to `.fill` on ON for a subtle visual
                // affordance without adding a label.
                Button {
                    state.toggleCompare()
                } label: {
                    Label(
                        "Compare",
                        systemImage: state.isCompareEnabled
                            ? "rectangle.split.2x1.fill"
                            : "rectangle.split.2x1"
                    )
                }
                .keyboardShortcut("v", modifiers: [])
                .buttonStyle(.glass)
                .disabled(state.sourceURL == nil)
                .help(state.isCompareEnabled
                    ? "Hide Before/After (V)"
                    : "Show Before/After (V)")
                .filmtonePointingHandCursor(state.sourceURL != nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportCoordinator.presentExportPanel(for: state)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .keyboardShortcut("e", modifiers: .command)
                .buttonStyle(.glassProminent)
                .disabled(exportDisabled)
                .help(exportHelpText)
                .filmtonePointingHandCursor(!exportDisabled)
            }
            // M5-J1: sidebar open/close. `⌘\` follows the macOS HIG
            // trailing-inspector convention. Lives next to Open/Export so
            // collapsed state still surfaces the reopen affordance.
            // `keyboardShortcut` on a Toolbar Button is scoped through the
            // first-responder chain, so a focused TextField or NSOpenPanel
            // sheet absorbs `⌘\` first and the toggle does not fire mid
            // text input / save prompt.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sidebarOpen.toggle()
                } label: {
                    Label(
                        sidebarOpen ? "Hide Inspector" : "Show Inspector",
                        systemImage: "sidebar.right"
                    )
                }
                .keyboardShortcut("\\", modifiers: .command)
                .buttonStyle(.glass)
                .help(sidebarOpen
                      ? "Hide editing sidebar (⌘\\)"
                      : "Show editing sidebar (⌘\\)")
                .filmtonePointingHandCursor()
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
            let kind = detectSourceKind(of: url)
            state.setSource(url, kind: kind)
            resizeWindowToSourceAspect(url: url, kind: kind)
        }
    }

    private func resizeWindowToSourceAspect(url: URL, kind: FilmtoneSourceKind) {
        switch kind {
        case .still:
            guard let mediaSize = stillDisplaySize(url: url) else { return }
            resizeWindow(toMediaDisplaySize: mediaSize)
        case .video:
            Task {
                guard let probe = try? await FilmtoneSourceProber.probeVideo(sourceURL: url) else { return }
                let displayRect = CGRect(origin: .zero, size: probe.naturalSize)
                    .applying(probe.preferredTransform)
                let mediaSize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))
                await MainActor.run {
                    guard state.sourceURL == url else { return }
                    resizeWindow(toMediaDisplaySize: mediaSize)
                }
            }
        }
    }

    private func resolveWindow(_ window: NSWindow?) {
        guard let window else { return }
        hostingWindow = window
        configureWindowForTransparentGlass(window)
    }

    private func configureWindowForTransparentGlass(_ window: NSWindow) {
        // SwiftUI `.clear` / `.glassEffect` cannot reveal anything outside
        // the app while AppKit keeps the backing window opaque. Make the
        // window itself transparent so the empty opening state can behave
        // like clear Liquid Glass instead of a painted dark canvas.
        window.styleMask.insert(.fullSizeContentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = ""
        window.subtitle = ""
        window.toolbarStyle = .unifiedCompact
        window.hasShadow = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func resizeWindow(toMediaDisplaySize mediaSize: CGSize) {
        guard let window = hostingWindow ?? NSApp.keyWindow,
              mediaSize.width > 0,
              mediaSize.height > 0
        else { return }

        let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? window.frame
        let aspect = mediaSize.width / mediaSize.height
        let frameInset = windowFrameInset(for: window)
        let topChromeAllowance = previewTopChromeAllowance(for: window)
        let availableContentSize = CGSize(
            width: max(360, screenFrame.width - 96 - frameInset.width),
            height: max(320, screenFrame.height - 96 - frameInset.height)
        )
        let preferredContentSize = CGSize(
            width: min(availableContentSize.width, 1440),
            height: min(availableContentSize.height, 980)
        )
        let contentMinimum = minimumContentSize(
            forAspect: aspect,
            topChromeAllowance: topChromeAllowance,
            within: availableContentSize
        )
        minimumContentSize = contentMinimum
        window.contentMinSize = contentMinimum

        var contentSize = previewAreaAspectFitSize(
            aspect: aspect,
            topChromeAllowance: topChromeAllowance,
            in: preferredContentSize
        )
        if contentSize.width < contentMinimum.width || contentSize.height < contentMinimum.height {
            contentSize = contentMinimum
        }
        window.contentAspectRatio = contentSize

        let currentFrame = window.frame
        let frameRect = window.frameRect(forContentRect: CGRect(origin: .zero, size: contentSize))
        let nextOrigin = CGPoint(
            x: currentFrame.midX - frameRect.width / 2,
            y: currentFrame.midY - frameRect.height / 2
        )
        var nextFrame = CGRect(origin: nextOrigin, size: frameRect.size)
        if nextFrame.width <= screenFrame.width {
            nextFrame.origin.x = min(max(nextFrame.minX, screenFrame.minX), screenFrame.maxX - nextFrame.width)
        } else {
            nextFrame.origin.x = screenFrame.minX
        }
        if nextFrame.height <= screenFrame.height {
            nextFrame.origin.y = min(max(nextFrame.minY, screenFrame.minY), screenFrame.maxY - nextFrame.height)
        } else {
            nextFrame.origin.y = screenFrame.minY
        }
        window.setFrame(nextFrame, display: true, animate: true)
    }

    private func stillDisplaySize(url: URL) -> CGSize? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        else { return nil }
        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        guard width > 0, height > 0 else { return nil }
        let orientationRaw = (properties[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value
        let orientation = orientationRaw.flatMap(CGImagePropertyOrientation.init(rawValue:))
        let swapsAxes = orientation == .left
            || orientation == .leftMirrored
            || orientation == .right
            || orientation == .rightMirrored
        return swapsAxes
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
    }

    private func previewAreaAspectFitSize(
        aspect: CGFloat,
        topChromeAllowance: CGFloat,
        in bounds: CGSize
    ) -> CGSize {
        let previewHeightBounds = max(1, bounds.height - topChromeAllowance)
        var size = CGSize(
            width: bounds.width,
            height: bounds.width / aspect + topChromeAllowance
        )
        if size.height > bounds.height {
            size.height = previewHeightBounds + topChromeAllowance
            size.width = previewHeightBounds * aspect
        }
        return size
    }

    private func minimumContentSize(
        forAspect aspect: CGFloat,
        topChromeAllowance: CGFloat,
        within bounds: CGSize
    ) -> CGSize {
        let minShort: CGFloat = 360
        let minLong: CGFloat = 720
        let requestedPreviewSize: CGSize
        if aspect >= 1 {
            let width = max(minLong, minShort * aspect)
            requestedPreviewSize = CGSize(width: width, height: width / aspect)
        } else {
            let height = max(minLong, minShort / aspect)
            requestedPreviewSize = CGSize(width: height * aspect, height: height)
        }
        let requested = CGSize(
            width: requestedPreviewSize.width,
            height: requestedPreviewSize.height + topChromeAllowance
        )
        if requested.width <= bounds.width, requested.height <= bounds.height {
            return requested
        }
        return previewAreaAspectFitSize(
            aspect: aspect,
            topChromeAllowance: topChromeAllowance,
            in: bounds
        )
    }

    private func windowFrameInset(for window: NSWindow) -> CGSize {
        let contentSize = CGSize(width: 1000, height: 1000)
        let frameSize = window.frameRect(forContentRect: CGRect(origin: .zero, size: contentSize)).size
        return CGSize(
            width: max(0, frameSize.width - contentSize.width),
            height: max(0, frameSize.height - contentSize.height)
        )
    }

    private func previewTopChromeAllowance(for window: NSWindow) -> CGFloat {
        if window.styleMask.contains(.fullSizeContentView) {
            return 0
        }
        let layoutInset = window.contentView.map { contentView in
            max(0, contentView.bounds.height - window.contentLayoutRect.height)
        } ?? 0
        let measuredInset = max(rootSafeAreaTopInset, layoutInset)
        if measuredInset > 1 {
            return min(measuredInset, 96)
        }
        // macOS unified toolbar / titlebar height when SwiftUI has not
        // reported safe-area geometry yet. This is only used to calculate
        // the first post-open window resize.
        return 34
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

private struct RootSafeAreaTopInsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
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
            .buttonStyle(FilmtoneGlassIconButtonStyle())
            .keyboardShortcut(.space, modifiers: [])
            .help(state.isPlaying ? "Pause (Space)" : "Play (Space)")
            .filmtonePointingHandCursor()
            Text(format(seconds.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .leading)
            FilmtoneGlassSlider(
                value: seconds,
                range: 0...max(duration, 0.001),
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
    let compareEnabled: Bool

    @MainActor
    init(state: EditorState) {
        self.presetName = state.presetName
        self.presetStrength = state.presetStrength
        self.lookSlug = state.lookSlug
        self.sourceProfileSelection = state.sourceProfileSelection
        self.probedSourceColorClass = state.probedSourceColorClass
        self.quickState = state.quickState
        self.paramOverrides = state.paramOverrides
        self.compareEnabled = state.isCompareEnabled
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
