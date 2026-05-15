import AppKit
import AVFoundation
import FilmLabSwiftCore
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct RootWindowView: View {
    @State private var state = EditorState()
    @State private var library = LibraryViewModel()
    @State private var importedGradeLibrary = ImportedGradeLibraryViewModel()
    @State private var hostingWindow: NSWindow?
    // M5-M follow-up: empty opening starts at a compact floor so the launch
    // window reads as a compact opening dialog rather than a 1080×720
    // marketing slab. `resizeWindow(toMediaDisplaySize:)` raises this floor
    // (and the actual frame) once the user opens media; `onChange(state.sourceURL == nil)`
    // shrinks back to compact when the source is cleared.
    @State private var minimumContentSize = Self.compactOpeningMinimumSize
    @State private var rootSafeAreaTopInset: CGFloat = 0
    // M5-M follow-up: cached display size of the currently-opened source.
    // Opening a new source writes this once; sidebar toggles no longer
    // resize the window because the inspector now overlays the preview
    // instead of reserving a portrait side column.
    @State private var lastMediaDisplaySize: CGSize? = nil
    // M5-G.1: export user flow lives on the coordinator now. Root view
    // just calls into it from the toolbar Export button + the inspector
    // tap callback (P2 from 2026-05-05 review).
    @State private var exportCoordinator = ExportCoordinator()
    // M5-J1: landscape right-rail open/close. Persists across launches
    // and source changes via `@AppStorage` so the user's last preference
    // holds. Default true: landscape opens with the inspector visible.
    @AppStorage("editorSidebarOpen") private var sidebarOpen: Bool = true
    @State private var openPanelPresented: Bool = false
    // M5-M.3: portrait summoned right-rail slide-in. Default false so a
    // freshly opened portrait clip shows full media unobstructed; ⌘\ slides
    // the rail in from the trailing edge and dismisses it. Reuses the same
    // `EditorSidebar` surface as the landscape rail — only the visibility
    // default and slide animation differ.
    @AppStorage("editorPortraitInspectorOpen") private var portraitInspectorOpen: Bool = false
    // M5-M: cached display aspect ratio of the opened source. Stills populate
    // this from `stillDisplaySize`; video seeds it from the initial probe so
    // portrait overlay insets / window sizing are correct before `videoSession`
    // attaches, then reads `videoSession.displayAspectRatio` reactively once
    // available. nil = no source (empty state / pending probe).
    @State private var sourceAspectRatio: CGFloat? = nil

    // M5-M: portrait when aspect < 1.0 (height > width). Nil (no source)
    // is treated as landscape so the empty opening screen uses the default
    // full-window ZStack layout. Video derives aspect reactively from the
    // session when available, with `sourceAspectRatio` as the pre-session
    // probe fallback.
    private var isPortraitSource: Bool {
        if state.sourceKind == .video, let session = state.videoSession {
            return session.displayAspectRatio < 1.0
        }
        guard let ratio = sourceAspectRatio else { return false }
        return ratio < 1.0
    }

    // M5-M.3: which inspector surface is "current" for the loaded source.
    // Portrait → bottom sheet; landscape → right rail. Drives the toolbar
    // toggle button label/help and the ⌘\ keyboard shortcut binding.
    private var inspectorVisible: Bool {
        isPortraitSource ? portraitInspectorOpen : sidebarOpen
    }

    private func toggleInspector() {
        if isPortraitSource {
            portraitInspectorOpen.toggle()
        } else {
            sidebarOpen.toggle()
        }
    }

    var body: some View {
        editorOverlayLayout
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
        // M5-M: when the source is cleared, reset the stored still aspect
        // so `isPortraitSource` reverts to landscape (empty-state layout).
        // M5-M follow-up: also shrink the window back to the compact opening
        // posture so a closed-source state does not leave a 1440×980 frame
        // that the user must resize themselves before reopening media.
        .onChange(of: state.sourceURL) { _, newURL in
            if newURL == nil {
                sourceAspectRatio = nil
                applyCompactOpeningPosture()
            }
        }
        // M5-C.2a: load the on-disk library so the Picker lists saved
        // Looks at first paint. Built-in Stone / Urban appear immediately
        // via the empty-snapshot prefix path; user-saved entries fade in
        // once the actor returns.
        .task {
            await library.bootstrap()
            await importedGradeLibrary.bootstrap()
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
        // M5-K1: explicit `id:` on every ToolbarItem keeps identity stable
        // across body re-evaluations (sidebar open/close, compare flip,
        // export-disabled flip). Each `Label`'s title and `systemImage`
        // are also held constant — state-dependent text is moved to
        // `.help(...)`, and Compare's fill toggle uses `.symbolVariant`
        // instead of swapping the systemImage string. Without this, the
        // sidebar toggle visibly redrew the neighbouring Open / Compare /
        // Export icons because their parent ToolbarItem identity was lost.
        .toolbar {
            ToolbarItem(id: "filmtone.toolbar.open", placement: .primaryAction) {
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
            ToolbarItem(id: "filmtone.toolbar.compare", placement: .primaryAction) {
                // M5-J.2 + M5-K1: Before/After 50:50 compare toggle. The
                // `Label` is structurally constant (title + base
                // systemImage); `.symbolVariant(.fill)` selects the
                // filled glyph on ON, leaving Label identity untouched
                // so flipping compare doesn't ripple a redraw to its
                // toolbar siblings. Disabled until a source is loaded so
                // the unmodified `V` shortcut is a no-op in the empty
                // state. Save Look rename / save prompts use AppKit
                // `NSAlert` (modal, separate keyWindow) so the toolbar
                // shortcut does not fire while a prompt is up.
                Button {
                    state.toggleCompare()
                } label: {
                    Label("Compare", systemImage: "rectangle.split.2x1")
                        .symbolVariant(state.isCompareEnabled ? .fill : .none)
                }
                .keyboardShortcut("v", modifiers: [])
                .buttonStyle(.glass)
                .disabled(state.sourceURL == nil)
                .help(state.isCompareEnabled
                    ? "Hide Before/After (V)"
                    : "Show Before/After (V)")
                .filmtonePointingHandCursor(state.sourceURL != nil)
            }
            ToolbarItem(id: "filmtone.toolbar.export", placement: .primaryAction) {
                Button {
                    exportCoordinator.presentExportPanel(for: state)
                } label: {
                    // `square.and.arrow.up`'s arrow protrudes above the
                    // square, giving the SF Symbol a taller intrinsic
                    // bounding box than `folder` / `rectangle.split.2x1` /
                    // `sidebar.right`. Left at default scale the toolbar
                    // pill auto-sized taller and Liquid Glass sampled a
                    // larger area, making Export visibly bigger and
                    // brighter than its neighbours. `.imageScale(.small)`
                    // shrinks just this symbol so the four pills match.
                    Label("Export", systemImage: "square.and.arrow.up")
                        .imageScale(.small)
                }
                .keyboardShortcut("e", modifiers: .command)
                // Match the other toolbar items' `.glass` posture. The
                // `.glassProminent` accent fill extended its tint past the
                // pill outline, making Export visibly bleed against its
                // neighbours.
                .buttonStyle(.glass)
                .disabled(exportDisabled)
                .help(exportHelpText)
                .filmtonePointingHandCursor(!exportDisabled)
            }
            // M5-J1 + M5-K1: sidebar open/close. `⌘\` follows the macOS
            // HIG trailing-inspector convention. Lives next to Open/Export
            // so collapsed state still surfaces the reopen affordance.
            // `keyboardShortcut` on a Toolbar Button is scoped through the
            // first-responder chain, so a focused TextField or NSOpenPanel
            // sheet absorbs `⌘\` first and the toggle does not fire mid
            // text input / save prompt. The `Label` keeps a fixed title
            // ("Inspector") so the ToolbarItem identity is preserved on
            // every toggle; Hide/Show wording lives only in `.help(...)`.
            ToolbarItem(id: "filmtone.toolbar.sidebar", placement: .primaryAction) {
                Button {
                    toggleInspector()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .keyboardShortcut("\\", modifiers: .command)
                .buttonStyle(.glass)
                // No source = nothing to inspect; mirror Compare / Export
                // disabled posture so the empty state cannot summon an
                // inspector with no content.
                .disabled(state.sourceURL == nil)
                // M5-M.3 follow-up: static help text. The previous
                // `inspectorVisible ? "Hide..." : "Show..."` ternary forced
                // the Label / .help to recompute on every ⌘\ press, which
                // — combined with the toolbar's Liquid Glass background
                // re-sampling as the rail slid in — read as flicker on
                // each toggle. A single phrasing carries both intents.
                .help("Show / Hide editing panel (⌘\\)")
                .filmtonePointingHandCursor(state.sourceURL != nil)
            }
        }
    }

    // M5-M.3: inspector posture — single right-rail (`EditorSidebar`)
    // reused across orientations, distinguished only by which `@AppStorage`
    // key drives visibility:
    //   - Landscape: `editorSidebarOpen` (default true). Rail is present
    //     from launch; ⌘\ toggles.
    //   - Portrait: `editorPortraitInspectorOpen` (default false). Rail
    //     starts hidden so the loaded portrait clip is fully visible; ⌘\
    //     summons and dismisses with a `.move(edge: .trailing)` slide.
    // The rail extends to the window bottom (only a 24pt breathing inset).
    // The floating scrub bar capsule shrinks horizontally when the
    // inspector is open so the rail and scrub bar live side-by-side
    // instead of stacking vertically — the user can scrub while every
    // panel including Export is reachable. `PreviewSurface` owns the loaded
    // backdrop posture behind the aspect-fit preview.
    @ViewBuilder
    private var editorOverlayLayout: some View {
        ZStack(alignment: .topTrailing) {
            PreviewSurface(
                state: state,
                sourceURL: state.sourceURL,
                sourceKind: state.sourceKind,
                gradeRecipe: state.currentGradeRecipe,
                videoPreviewSeconds: state.videoPreviewSeconds,
                sourceProfileSelection: state.sourceProfileSelection,
                compareEnabled: state.isCompareEnabled
            )
            .ignoresSafeArea(.container, edges: .all)
            // Right-rail inspector. Same `EditorSidebar` for both portrait
            // and landscape. `inspectorVisible` resolves to the right
            // `@AppStorage` based on `isPortraitSource`. The slide-in
            // transition only animates the portrait summon (landscape
            // default-open mounts without animation on first paint).
            if inspectorVisible {
                EditorSidebar(
                    state: state,
                    library: library,
                    importedGradeLibrary: importedGradeLibrary,
                    exportCoordinator: exportCoordinator
                )
                .padding(.top, 72)
                .padding(.bottom, sidebarBottomPadding)
                .padding(.trailing, 12)
                // M5-M.3 follow-up: pure `.move(edge: .trailing)` without
                // `.combined(with: .opacity)`. The opacity fade compounded
                // with the slide as a visible flicker — especially on the
                // toolbar's Apple Liquid Glass buttons re-sampling the
                // partially-transparent rail mid-animation. The slide alone
                // hides the rail at the trailing edge, which is enough.
                .transition(.move(edge: .trailing))
                // M8: the scrub overlay is a bottom-aligned full-window
                // layout container. Keep the inspector above that container
                // so transparent scrub padding can never steal taps from
                // controls that are visibly inside the right rail.
                .zIndex(2)
            }
            // M5-A.3 + F4: scrub bar floats above the window bottom edge.
            // When the inspector is open, the scrub bar reserves a right
            // gutter equal to the rail footprint (320 width + 12 trailing
            // pad) so it shrinks horizontally to live alongside the rail.
            // Both surfaces remain fully usable simultaneously and the
            // rail no longer needs vertical clearance above the scrub bar.
            if state.sourceKind == .video,
               let duration = state.videoDurationSeconds,
               duration > 0 {
                videoScrubOverlay(duration: duration)
                    .zIndex(1)
            }
        }
        // M5-M.3 follow-up: single animation hook on the resolved
        // `inspectorVisible` instead of two stacked modifiers (one per
        // @AppStorage value). Two stacked animations on a shared subtree
        // could fire the same change twice — once for each modifier —
        // producing a visible double-step on toolbar redraws and the rail
        // slide. A single animation tied to the resolved boolean keeps
        // every toggle to a single spring step.
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: inspectorVisible)
    }

    // M8 follow-up: the previous structure used a top `Spacer(minLength: 0)
    // .allowsHitTesting(false)` to push the scrub strip to the bottom of a
    // full-window VStack. In practice SwiftUI on macOS 26 still claimed
    // mouse events in the Spacer's y-range — likely because Spacer in a
    // .frame(maxHeight:.infinity) container picks up the whole vertical
    // band as its layout extent and hit testing then resolves to the
    // VStack rather than falling through. The visible symptom: chips in
    // the right rail's lower half stopped responding when scrolled into
    // that band, and only worked when scrolled back above it.
    //
    // The fix: drop the Spacer. The VStack now hugs its scrub-strip
    // content (scrub bar height + bottom padding only); the outer
    // `.frame(maxHeight: .infinity, alignment: .bottom)` anchors that
    // content to the window bottom without filling the upper space with
    // a hit-claiming layout box. The empty area above the strip is pure
    // layout — no SwiftUI content there — so hits in the rail's lower
    // half pass through to the inspector at .zIndex(2).
    @ViewBuilder
    private func videoScrubOverlay(duration: Double) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
                VideoScrubBar(state: state, duration: duration)
                    .padding(.horizontal, isPortraitSource ? 12 : 0)
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
            }
            // Right inset the width of the inspector footprint so the
            // scrub bar centers within the area to the left of the rail
            // when the inspector is open. Applying this as `.padding`
            // rather than a `Color.clear` sibling keeps the HStack at its
            // intrinsic (scrub bar) height — `Color.clear.frame(width:)`
            // leaves height unconstrained and would expand the row to
            // fill the whole window, lifting the scrub bar to vertical
            // center.
            .padding(.trailing, inspectorVisible ? inspectorReservedWidth : 0)
            if scrubBarBottomPadding > 0 {
                Color.clear
                    .frame(height: scrubBarBottomPadding)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // Inspector bottom inset. The rail extends to near the window bottom
    // regardless of source kind — the floating scrub bar capsule shrinks
    // horizontally (`videoScrubOverlay` reserves a right gutter of
    // `inspectorReservedWidth` when the inspector is open) so the rail
    // no longer needs vertical clearance above it. The 24pt inset gives
    // the bottom-most panel a breathing band against the window edge.
    private var sidebarBottomPadding: CGFloat { 24 }

    // Width reserved on the right edge of `videoScrubOverlay` for the
    // inspector when it's open: `EditorSidebar` is 320pt wide and is
    // mounted with a 12pt trailing pad in `editorOverlayLayout`.
    private var inspectorReservedWidth: CGFloat { 320 + 12 }

    // Scrub bar bottom inset. Portrait clips lift the capsule slightly
    // closer to the media bottom so it doesn't float in dead space below
    // the aspect-locked window bottom; landscape uses a roomier inset.
    private var scrubBarBottomPadding: CGFloat {
        isPortraitSource ? 24 : 64
    }

    private var sourceCapBlocked: Bool {
        !state.sourceCapViolations.isEmpty
    }

    private var exportDisabled: Bool {
        state.sourceURL == nil || state.isExporting || sourceCapBlocked
    }

    private var exportHelpText: String {
        if sourceCapBlocked,
           let reason = state.sourceCapViolations.first {
            return reason
        }
        return state.sourceKind == .video ? "Export the current video" : "Export the current still"
    }

    private func presentOpenPanel() {
        guard !openPanelPresented else { return }
        let panel = NSOpenPanel()
        var contentTypes: [UTType] = [.image, .movie, .quickTimeMovie, .mpeg4Movie, .json]
        if let drxType = UTType(filenameExtension: "drx") {
            contentTypes.append(drxType)
        }
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = "Open"
        panel.message = "Choose a still, video, iOS capture package, or DaVinci grade"

        openPanelPresented = true
        let targetWindow = hostingWindow ?? NSApp.keyWindow ?? NSApp.mainWindow
        NSApp.activate(ignoringOtherApps: true)
        if let targetWindow {
            targetWindow.makeKeyAndOrderFront(nil)
        }
        // Window-attached sheets can become invisible on the transparent
        // full-size Liquid Glass window while still disabling the app. Present
        // the picker as an app-modal panel and explicitly raise it instead.
        panel.level = .modalPanel
        panel.center()
        panel.begin { response in
            completeOpenPanel(response: response, url: panel.url)
        }
    }

    private func completeOpenPanel(response: NSApplication.ModalResponse, url: URL?) {
        openPanelPresented = false
        guard response == .OK, let url else { return }
        if FilmtoneCapturePackageImporter.isCapturePackageCandidate(url) {
            do {
                let imported = try FilmtoneCapturePackageImporter.importPackage(from: url)
                state.setSource(
                    imported.sourceURL,
                    kind: .video,
                    importedCapturePackage: imported
                )
                resizeWindowToSourceAspect(url: imported.sourceURL, kind: .video)
            } catch {
                state.lastExportError = error.localizedDescription
            }
            return
        }
        if url.pathExtension.lowercased() == "drx" {
            Task { @MainActor in
                if let look = await importedGradeLibrary.importGrade(from: url) {
                    let sidecarURL = await importedGradeLibrary.sidecarURL(id: look.id)
                    state.applyImportedGrade(look, sidecarURL: sidecarURL)
                }
            }
            return
        }
        if isDirectory(url) {
            state.lastExportError = "Choose a folder that contains capture-package.json."
            return
        }
        if url.pathExtension.lowercased() == "json" {
            state.lastExportError = "Choose capture-package.json, a still, or a video."
            return
        }
        let kind = detectSourceKind(of: url)
        state.setSource(url, kind: kind)
        resizeWindowToSourceAspect(url: url, kind: kind)
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func resizeWindowToSourceAspect(url: URL, kind: FilmtoneSourceKind) {
        // New source selection must not inherit the prior source's geometry
        // while a still/video probe is pending or failed. In particular, video
        // `videoSession` arrives asynchronously, so `isPortraitSource` uses
        // this nil state as a neutral fallback until the probe below seeds the
        // actual display aspect.
        sourceAspectRatio = nil
        lastMediaDisplaySize = nil

        switch kind {
        case .still:
            guard let mediaSize = stillDisplaySize(url: url) else { return }
            // M5-M: capture still aspect for portrait detection before
            // resizing the window.
            sourceAspectRatio = mediaSize.width > 0 && mediaSize.height > 0
                ? mediaSize.width / mediaSize.height
                : nil
            resizeWindow(toMediaDisplaySize: mediaSize)
        case .video:
            Task {
                guard let probe = try? await FilmtoneSourceProber.probeVideo(sourceURL: url) else { return }
                let displayRect = CGRect(origin: .zero, size: probe.naturalSize)
                    .applying(probe.preferredTransform)
                let mediaSize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))
                await MainActor.run {
                    guard state.sourceURL == url else { return }
                    // M5-M follow-up: seed the same aspect cache used by stills
                    // so portrait overlay insets and initial window sizing are
                    // correct before `state.videoSession` attaches.
                    sourceAspectRatio = mediaSize.width > 0 && mediaSize.height > 0
                        ? mediaSize.width / mediaSize.height
                        : nil
                    resizeWindow(toMediaDisplaySize: mediaSize)
                }
            }
        }
    }

    private func resolveWindow(_ window: NSWindow?) {
        guard let window else { return }
        let firstResolve = (hostingWindow == nil)
        hostingWindow = window
        configureWindowForTransparentGlass(window)
        // M5-M follow-up: on first attach, anchor `contentMinSize` to the
        // compact floor and — if the user has not opened media yet — shrink
        // the actual frame to the compact opening size centered on screen.
        // After media opens, `resizeWindow(toMediaDisplaySize:)` updates both
        // the floor and the frame to fit the source.
        if firstResolve {
            window.contentMinSize = NSSize(
                width: minimumContentSize.width,
                height: minimumContentSize.height
            )
            if state.sourceURL == nil {
                applyCompactOpeningFrame(to: window)
            }
        }
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

    // M5-M follow-up: compact opening floor + initial frame. The empty-state
    // plate (`EmptyPreviewLabel`) plus toolbar chrome fits inside this frame
    // with breathing room; lowering the floor below this would let AppKit
    // shrink the window past where the plate stays legible.
    private static let compactOpeningMinimumSize = CGSize(width: 480, height: 400)
    private static let compactOpeningInitialSize = CGSize(width: 600, height: 500)

    private func applyCompactOpeningFrame(to window: NSWindow) {
        let openingContentSize = NSSize(
            width: Self.compactOpeningInitialSize.width,
            height: Self.compactOpeningInitialSize.height
        )
        let frameRect = window.frameRect(forContentRect: CGRect(
            origin: .zero,
            size: openingContentSize
        ))
        let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? window.frame
        let centerOrigin = CGPoint(
            x: screenFrame.midX - frameRect.width / 2,
            y: screenFrame.midY - frameRect.height / 2
        )
        window.contentAspectRatio = NSSize(width: 0, height: 0)
        window.resizeIncrements = NSSize(width: 1, height: 1)
        window.setFrame(
            CGRect(origin: centerOrigin, size: frameRect.size),
            display: true,
            animate: false
        )
    }

    private func applyCompactOpeningPosture() {
        guard let window = hostingWindow else { return }
        minimumContentSize = Self.compactOpeningMinimumSize
        window.contentMinSize = NSSize(
            width: Self.compactOpeningMinimumSize.width,
            height: Self.compactOpeningMinimumSize.height
        )
        // No source open → drop the cached media size so a future sidebar
        // toggle in the empty state does not try to re-apply media sizing.
        lastMediaDisplaySize = nil
        applyCompactOpeningFrame(to: window)
    }

    private func resizeWindow(toMediaDisplaySize mediaSize: CGSize) {
        guard let window = hostingWindow ?? NSApp.keyWindow,
              mediaSize.width > 0,
              mediaSize.height > 0
        else { return }
        // Cache the media size for source lifecycle bookkeeping. The sidebar
        // does not re-trigger sizing because it overlays the preview.
        lastMediaDisplaySize = mediaSize

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
        let mediaContentMinimum = minimumContentSize(
            forAspect: aspect,
            topChromeAllowance: topChromeAllowance,
            within: availableContentSize
        )
        let contentMinimum = mediaContentMinimum
        minimumContentSize = contentMinimum
        window.contentMinSize = contentMinimum

        var mediaSize = previewAreaAspectFitSize(
            aspect: aspect,
            topChromeAllowance: topChromeAllowance,
            in: preferredContentSize
        )
        if mediaSize.width < mediaContentMinimum.width || mediaSize.height < mediaContentMinimum.height {
            mediaSize = CGSize(
                width: max(mediaSize.width, mediaContentMinimum.width),
                height: max(mediaSize.height, mediaContentMinimum.height)
            )
        }
        // Window matches source aspect for both portrait and landscape so
        // the overlaid inspector / scrub bar refract the media itself instead
        // of a transparent right column or pillarbox black bar. The sidebar
        // overlap on portrait is accepted product behavior — the alternative
        // (widening the window for the inspector) creates exposed background
        // around the aspect-fit media that the user explicitly rejected.
        let contentSize = mediaSize
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

/// M5-A.3 / M5-D.2 / M5-I.2 / M5-K4: scrub bar for video preview. The
/// Slider drives `AVPlayer.seek(to:)` directly; the periodic time
/// observer in `FilmtoneDesktopVideoSession` pushes player time back
/// into `state.videoPreviewSeconds` so the thumb follows playback.
/// Manual drag flips `state.isScrubbing` so the observer doesn't yank
/// the thumb mid-drag, and pauses playback for the duration of the
/// drag. M5-I.2 added a 1×/2×/3× rate menu. M5-K4 adds a hover/drag
/// thumbnail overlay above the capsule, served by the session's
/// `FilmtoneVideoScrubThumbnailProvider`.
private struct VideoScrubBar: View {
    @Bindable var state: EditorState
    let duration: Double

    // Geometry needed to position the thumbnail overlay relative to the
    // bar's capsule. Captured via `PreferenceKey` so the overlay can sit
    // outside the capsule's `.glassEffect` clip without losing horizontal
    // alignment with the slider.
    @State private var sliderFrameInBar: CGRect = .zero
    // Measured capsule outer-bound, in the scrub bar's named coordinate
    // space. Drives the thumbnail's edge-clamp so narrow windows don't
    // place the card past the actual bar edge (the previous fallback to
    // `scrubBarMaxContentWidth` always assumed the max width).
    @State private var capsuleFrameInBar: CGRect = .zero
    @State private var hoverFraction: Double?

    // Latest delivered thumbnail. Holds across hover gaps so a brief
    // pause between hover events doesn't blink the card off-screen.
    @State private var thumbnailImage: NSImage?
    @State private var thumbnailDisplayedSeconds: Double?

    private static let capsuleCornerRadius: CGFloat = 16
    private static let scrubBarMaxContentWidth: CGFloat = 600
    private static let thumbnailDisplayHeight: CGFloat = 96
    private static let thumbnailDisplayMaxWidth: CGFloat = 170
    private static let thumbnailGapAboveCapsule: CGFloat = 12

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

    /// Active fraction (0…1) along the slider — hover wins over drag so
    /// a user dragging while still moving the cursor sees the thumbnail
    /// follow the cursor, not the slightly-laggier `videoPreviewSeconds`.
    private var activeThumbnailFraction: Double? {
        if let hoverFraction { return hoverFraction }
        if state.isScrubbing, duration > 0,
           let secs = state.videoPreviewSeconds {
            return min(1.0, max(0.0, secs / duration))
        }
        return nil
    }

    private var thumbnailVisible: Bool {
        activeThumbnailFraction != nil && thumbnailImage != nil
    }

    var body: some View {
        // M5-D.1: dark-tinted .clear posture matches the right-rail
        // panels so the scrub bar reads as the same chrome family and
        // stays visible on bright preview frames where untinted .clear
        // refracts into the backdrop.
        //
        // M5-K4 follow-up: thumbnail must be an overlay, not a ZStack
        // sibling. A ZStack sibling participates in layout at its
        // un-offset 170x96 size, so the bottom-anchored scrub bar jumps
        // upward as soon as a thumbnail appears.
        capsule
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ScrubBarCapsuleFrameKey.self,
                            value: proxy.frame(in: .named("scrubBar"))
                        )
                }
            )
            .overlay(alignment: .topLeading) {
                if thumbnailVisible,
                   let image = thumbnailImage,
                   let frac = activeThumbnailFraction {
                    thumbnailCard(image: image)
                        .offset(thumbnailOffset(forFraction: frac))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .coordinateSpace(name: "scrubBar")
            .frame(maxWidth: Self.scrubBarMaxContentWidth)
            .onPreferenceChange(SliderFrameInBarKey.self) { rect in
                sliderFrameInBar = rect
            }
            .onPreferenceChange(ScrubBarCapsuleFrameKey.self) { rect in
                capsuleFrameInBar = rect
            }
            // Drag-driven thumbnail refresh — when the user drags without
            // moving the cursor (e.g. paused on a fixed point), still keep
            // the thumbnail in sync with `videoPreviewSeconds`.
            .onChange(of: state.videoPreviewSeconds) { _, _ in
                guard hoverFraction == nil, state.isScrubbing else { return }
                requestActiveThumbnail()
            }
            // When scrub ends and hover already left, drop the cached image
            // so the next hover/scrub starts cleanly.
            .onChange(of: state.isScrubbing) { _, scrubbing in
                if !scrubbing, hoverFraction == nil {
                    thumbnailImage = nil
                    thumbnailDisplayedSeconds = nil
                }
            }
            .animation(.easeOut(duration: 0.12), value: thumbnailVisible)
    }

    private var capsule: some View {
        // M5-M.3: 2-row layout. The single-row capsule grew too dense once
        // bookmark + jump-prev / jump-next + speed were added, so the
        // controls split across two rows of related actions:
        //   Row 1 (transport): play | current time | slider | total time | speed
        //   Row 2 (markers):   add | (menu) | prev | next | spacer
        // The slider lives on row 1 next to the time bookends so the primary
        // scrubbing affordance stays large; the secondary marker controls
        // sit on row 2 left-aligned with a trailing spacer so the row stays
        // visually grounded even when no markers exist yet.
        VStack(spacing: 8) {
            transportRow
            markersRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(
            .clear.tint(.black.opacity(0.30)),
            in: RoundedRectangle(cornerRadius: Self.capsuleCornerRadius)
        )
    }

    private var transportRow: some View {
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
            sliderArea
            Text(format(duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .trailing)
            PlaybackRateMenu(state: state)
        }
    }

    private var markersRow: some View {
        HStack(spacing: 12) {
            Button {
                state.addHighlightMarker(at: seconds.wrappedValue)
            } label: {
                Image(systemName: "bookmark.fill")
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(FilmtoneGlassIconButtonStyle(isActive: !state.highlightMarkerList.isEmpty))
            .keyboardShortcut("m", modifiers: [])
            .help("Add highlight marker (M)")
            .filmtonePointingHandCursor()
            if !state.highlightMarkerList.isEmpty {
                HighlightMarkerMenu(state: state)
            }
            Button {
                state.jumpToPreviousHighlightMarker()
            } label: {
                Label("BACK", systemImage: "arrow.left.circle.fill")
            }
            .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
            .keyboardShortcut("j", modifiers: .shift)
            .disabled(state.highlightMarkerList.isEmpty)
            .help("Jump to previous highlight marker (Shift-J)")
            .filmtonePointingHandCursor(!state.highlightMarkerList.isEmpty)
            Button {
                state.jumpToNextHighlightMarker()
            } label: {
                Label("JUMP", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
            .keyboardShortcut("j", modifiers: [])
            .disabled(state.highlightMarkerList.isEmpty)
            .help("Jump to next highlight marker (J)")
            .filmtonePointingHandCursor(!state.highlightMarkerList.isEmpty)
            Spacer(minLength: 0)
        }
    }

    private var sliderArea: some View {
        GeometryReader { proxy in
            ZStack {
                FilmtoneGlassSlider(
                    value: seconds,
                    range: 0...max(duration, 0.001),
                    expandsOnHover: false,
                    onEditingChanged: { editing in
                        // Drag start: hold the periodic time observer off so it
                        // doesn't fight the user's finger; pause playback so
                        // AVPlayer doesn't keep advancing under the seek. Drag
                        // end: clear the flag and let the observer resume time
                        // updates. Resume must be explicit Play.
                        state.isScrubbing = editing
                        if editing {
                            state.videoSession?.pause()
                        }
                    }
                )

                highlightMarkerRail(width: proxy.size.width)

                ScrubHoverTrackingView { nextFraction in
                    if let nextFraction {
                        hoverFraction = nextFraction
                        requestActiveThumbnail()
                    } else {
                        hoverFraction = nil
                        // Keep the last delivered thumbnail until the drag
                        // (if any) ends or the user re-hovers, so a brief
                        // cursor exit doesn't blink the overlay off mid-action.
                        if !state.isScrubbing {
                            // Slight delay would feel laggy; drop immediately
                            // so the overlay tracks the user's actual intent.
                            thumbnailImage = nil
                            thumbnailDisplayedSeconds = nil
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(
                Color.clear
                    .preference(
                        key: SliderFrameInBarKey.self,
                        value: proxy.frame(in: .named("scrubBar"))
                    )
            )
        }
        .frame(height: 24)
    }

    private func highlightMarkerRail(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            ForEach(state.highlightMarkerList, id: \.id) { marker in
                let x = markerCenterX(for: marker.sourceTimeSec, width: width)
                Button {
                    state.jumpToHighlightMarker(id: marker.id)
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 8, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                        Capsule()
                            .frame(width: 2, height: 10)
                    }
                    .foregroundStyle(Color.yellow)
                    .shadow(color: Color.black.opacity(0.55), radius: 2, x: 0, y: 1)
                    .frame(width: 16, height: 24)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help("Jump to highlight marker")
                .filmtonePointingHandCursor()
                .offset(x: x - 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func markerCenterX(for sourceTimeSec: Double, width: CGFloat) -> CGFloat {
        guard duration.isFinite,
              duration > 0,
              sourceTimeSec.isFinite else {
            return 0
        }
        let knob: CGFloat = 18
        let usable = max(width - knob, 1)
        let ratio = min(1.0, max(0.0, sourceTimeSec / duration))
        return knob / 2 + CGFloat(ratio) * usable
    }

    private func thumbnailCard(image: NSImage) -> some View {
        // `.scaledToFit` over a neutral black backing letterboxes/pillar-
        // boxes inside a fixed 170×96 card. Filmtone supports portrait
        // iPhone footage, so `.scaledToFill` would crop most of the frame
        // away; the card frame stays stable so the overlay still tracks
        // the cursor cleanly.
        ZStack {
            Color.black
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        }
        .frame(
            width: Self.thumbnailDisplayMaxWidth,
            height: Self.thumbnailDisplayHeight
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 6)
    }

    private func thumbnailOffset(forFraction frac: Double) -> CGSize {
        guard sliderFrameInBar.width > 0 else { return .zero }
        let knob: CGFloat = 18
        let usable = max(sliderFrameInBar.width - knob, 1)
        let cursorXInBar = sliderFrameInBar.minX + knob / 2 + CGFloat(frac) * usable
        // Clamp against the capsule's *measured* bounds in the scrub bar's
        // named coordinate space. On a narrow window the capsule is < the
        // 600pt max-content cap, so the prior `max(slider.maxX,
        // scrubBarMaxContentWidth)` could place the overlay past the
        // actual capsule/window edge. Fall back to the slider frame only
        // if the capsule preference hasn't arrived yet (first paint).
        let barMinX: CGFloat
        let barMaxX: CGFloat
        if capsuleFrameInBar.width > 0 {
            barMinX = capsuleFrameInBar.minX
            barMaxX = capsuleFrameInBar.maxX
        } else {
            barMinX = sliderFrameInBar.minX
            barMaxX = sliderFrameInBar.maxX
        }
        let centerX = FilmtoneScrubThumbnailMath.clampThumbnailCenterX(
            cursorX: cursorXInBar,
            thumbnailWidth: Self.thumbnailDisplayMaxWidth,
            scrubBarMinX: barMinX,
            scrubBarMaxX: barMaxX
        )
        return CGSize(
            width: centerX - Self.thumbnailDisplayMaxWidth / 2,
            height: -(Self.thumbnailDisplayHeight + Self.thumbnailGapAboveCapsule)
        )
    }

    private func requestActiveThumbnail() {
        guard let frac = activeThumbnailFraction,
              let session = state.videoSession,
              duration > 0 else { return }
        let secs = duration * frac
        session.thumbnailProvider.requestThumbnail(
            atSeconds: secs
        ) { image, atSeconds in
            // Drop the result if the user has already moved past the
            // bucket this image represents — the provider already drops
            // by `latestRequestSeconds`, but a hover->ended transition
            // between the in-flight start and finish can still race here.
            thumbnailImage = image
            thumbnailDisplayedSeconds = atSeconds
        }
    }

    private func format(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "0:00.00" }
        let total = value
        let minutes = Int(total / 60)
        let secondsRemainder = total - Double(minutes * 60)
        return String(format: "%d:%05.2f", minutes, secondsRemainder)
    }
}

/// M5-K4 follow-up: mouse tracking for scrub thumbnails that does not
/// participate in hit-testing. SwiftUI `onContinuousHover` attached to the
/// slider view caused the slider's own hover affordance and tracking region
/// to churn together, which made the seek bar visually shake. This AppKit
/// tracker reports mouse movement while returning `nil` from `hitTest(_:)`,
/// so the underlying `FilmtoneGlassSlider` keeps owning click/drag gestures.
private struct ScrubHoverTrackingView: NSViewRepresentable {
    let onFractionChange: (Double?) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onFractionChange = onFractionChange
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onFractionChange = onFractionChange
    }

    final class TrackingView: NSView {
        var onFractionChange: ((Double?) -> Void)?

        private var trackingArea: NSTrackingArea?

        override var acceptsFirstResponder: Bool { false }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func updateTrackingAreas() {
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
            let next = NSTrackingArea(
                rect: .zero,
                options: [
                    .activeInActiveApp,
                    .inVisibleRect,
                    .mouseEnteredAndExited,
                    .mouseMoved
                ],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(next)
            trackingArea = next
            super.updateTrackingAreas()
        }

        override func mouseEntered(with event: NSEvent) {
            report(event)
        }

        override func mouseMoved(with event: NSEvent) {
            report(event)
        }

        override func mouseExited(with event: NSEvent) {
            onFractionChange?(nil)
        }

        private func report(_ event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            let width = max(bounds.width, 1)
            let fraction = FilmtoneScrubThumbnailMath.clampHoverFraction(
                x: point.x,
                width: width,
                knob: 18
            )
            onFractionChange?(fraction)
        }
    }
}

/// M5-K4: capsule frame key. Reserved for future overlay placement
/// against the capsule outer rect; not consumed by the current code
/// path but kept so a future iteration can place markers along the
/// capsule rather than the slider track.
private struct ScrubBarCapsuleFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// M5-K4: slider frame in the scrub bar's named coordinate space.
/// Drives the thumbnail's horizontal position so the overlay sits at
/// the cursor's slider-relative X regardless of the chrome around it.
private struct SliderFrameInBarKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Compact access to source-relative highlight markers without expanding the
/// floating scrub bar or disturbing hover thumbnail layout.
private struct HighlightMarkerMenu: View {
    @Bindable var state: EditorState

    var body: some View {
        Menu {
            ForEach(state.highlightMarkerList, id: \.id) { marker in
                Button {
                    state.jumpToHighlightMarker(id: marker.id)
                } label: {
                    Label(Self.label(for: marker.sourceTimeSec), systemImage: "arrow.right.circle")
                }

                Button(role: .destructive) {
                    state.removeHighlightMarker(id: marker.id)
                } label: {
                    Label("Delete \(Self.label(for: marker.sourceTimeSec))", systemImage: "trash")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bookmark.fill")
                Text("\(state.highlightMarkerList.count)")
                    .font(.caption.monospacedDigit())
            }
            .foregroundStyle(.white)
            .frame(minWidth: 34)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .controlSize(.small)
        .colorScheme(.dark)
        .help("Highlight markers")
    }

    private static func label(for value: Double) -> String {
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
    let gradeRecipeKey: FilmtoneGradeRecipeKey
    let sourceProfileSelection: CameraProfileSelection
    let probedSourceColorClass: SourceColorClassDTO?
    let compareEnabled: Bool
    /// M5-K3: drag-induced fraction changes must rebuild the AVPlayer
    /// composition so the next composed frame reflects the new split.
    /// The session itself debounces 100ms, so dragging during playback
    /// throttles to at most 10 rebuilds/sec.
    let compareSplitFraction: Double

    @MainActor
    init(state: EditorState) {
        self.gradeRecipeKey = state.currentGradeRecipe.key
        self.sourceProfileSelection = state.sourceProfileSelection
        self.probedSourceColorClass = state.probedSourceColorClass
        self.compareEnabled = state.isCompareEnabled
        self.compareSplitFraction = state.compareSplitFraction
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
