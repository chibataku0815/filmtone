import AVFoundation
import AVKit
import FilmLabSwiftCore
import SwiftUI
import UIKit

/// File-private mirror of `FilmtonePreviewView.filmtonePreviewImage(from:)`
/// — the original is `private` to that file, so we reproduce the helper here
/// to avoid widening the surface.
private func fullscreenPreviewImage(from uri: String) -> UIImage? {
    guard let url = URL(string: uri), url.isFileURL else {
        return nil
    }
    return UIImage(contentsOfFile: url.path)
}

// MARK: - Custom video controls

/// Drives custom video chrome inside the fullscreen LUT editor. The default
/// `AVPlayerViewController` chrome (AirPlay button, native play/pause,
/// scrubber) collides with the editor's top bar / bottom dock, so we
/// disable it (`showsPlaybackControls = false` on the embedded
/// `FilmtonePreviewPlayerView`) and surface our own Liquid-Glass styled
/// controls that compose cleanly with the LUT carousel.
@MainActor
final class FullscreenVideoController: ObservableObject {
    /// TikTok-style boost state machine. The view owns the gesture and tells
    /// the controller which transition to take; the controller owns the
    /// AVPlayer rate / defaultRate side effects.
    enum BoostState: Equatable {
        case idle
        case pressing
        case boosting
        case locked
    }

    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying: Bool = false
    @Published var isScrubbing: Bool = false
    @Published var boostState: BoostState = .idle

    static let boostRate: Float = 2.0
    static let normalRate: Float = 1.0

    private weak var attachedPlayer: AVPlayer?
    private var timeObserverToken: Any?
    private var timingPolicy = FilmtoneVideoTimingPolicy(mode: .normal, sourceFPS: nil)

    func attach(_ player: AVPlayer) {
        if attachedPlayer === player { return }
        detach()
        attachedPlayer = player
        player.defaultRate = Float(timingPolicy.speedMultiplier)
        let interval = CMTime(value: 1, timescale: 4)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // The .main queue guarantees main-thread execution; assumeIsolated
            // narrows the actor isolation so we can mutate the @MainActor
            // properties without spawning a Task per tick.
            MainActor.assumeIsolated {
                guard let self else { return }
                if !self.isScrubbing {
                    self.currentTime = self.timingPolicy.displayTime(forSourceTime: time.seconds)
                }
                if let item = player.currentItem {
                    let raw = item.duration.seconds
                    let displayDuration = self.timingPolicy.displayDuration(sourceDuration: raw)
                    self.duration = displayDuration?.isFinite == true && (displayDuration ?? 0) > 0
                        ? displayDuration ?? self.duration
                        : self.duration
                }
                self.isPlaying = player.timeControlStatus == .playing || player.rate > 0
            }
        }
    }

    func setTimingPolicy(_ policy: FilmtoneVideoTimingPolicy) {
        timingPolicy = policy
        if let player = attachedPlayer {
            player.defaultRate = Float(policy.speedMultiplier)
            if player.timeControlStatus == .playing || player.rate > 0 {
                player.rate = Float(policy.speedMultiplier)
            }
            let sourceSeconds = CMTimeGetSeconds(player.currentTime())
            currentTime = policy.displayTime(forSourceTime: sourceSeconds)
            let rawDuration = player.currentItem?.duration.seconds
            if let displayDuration = policy.displayDuration(sourceDuration: rawDuration),
               displayDuration.isFinite,
               displayDuration > 0 {
                duration = displayDuration
            }
        }
    }

    func detach() {
        // Always restore a sane rate before letting the player go — the same
        // AVPlayer instance is shared with FilmtonePreviewView (inline) via
        // FilmtoneVideoPreviewSession, so a stale 2x would carry over to
        // inline preview after the fullscreen editor closes.
        if let player = attachedPlayer {
            let normalRate = Float(timingPolicy.speedMultiplier)
            player.defaultRate = normalRate
            if player.rate > normalRate {
                player.rate = normalRate
            }
        }
        if let token = timeObserverToken, let attachedPlayer {
            attachedPlayer.removeTimeObserver(token)
        }
        timeObserverToken = nil
        attachedPlayer = nil
        boostState = .idle
    }

    func togglePlayPause() {
        guard let player = attachedPlayer else { return }
        if player.timeControlStatus == .playing || player.rate > 0 {
            player.pause()
        } else {
            player.play()
        }
    }

    func seek(to seconds: Double) {
        guard let player = attachedPlayer else { return }
        let clamped = max(0, min(duration > 0 ? duration : seconds, seconds))
        let sourceSeconds = timingPolicy.sourceTime(forDisplayTime: clamped)
        player.seek(
            to: CMTime(seconds: sourceSeconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func sourceTime(forDisplayTime displayTime: Double) -> Double {
        timingPolicy.sourceTime(forDisplayTime: displayTime)
    }

    func displayTime(forSourceTime sourceTime: Double) -> Double {
        timingPolicy.displayTime(forSourceTime: sourceTime)
    }

    // MARK: - Boost (TikTok-style 2x)

    func setPressing() {
        // Only enter .pressing from .idle. .locked presses are tracked by the
        // view (pressStartedWhileLocked) so a tap can unlock without dropping
        // out of .locked prematurely.
        if boostState == .idle {
            boostState = .pressing
        }
    }

    func cancelPress() {
        // Press cancelled before the long-press timer fired (user dragged far
        // enough to count as a swipe, not a hold). No rate to restore yet.
        if boostState == .pressing {
            boostState = .idle
        }
    }

    func engageBoost() {
        guard let player = attachedPlayer else { return }
        // Set BOTH rate and defaultRate. FilmtoneVideoPreviewSession.swap
        // does pause → replaceCurrentItem → play() during graded↔original
        // compare, and play() resumes at defaultRate — without setting it,
        // a compare swap mid-2x would silently drop back to 1x.
        let rate = Self.boostRate * Float(timingPolicy.speedMultiplier)
        player.defaultRate = rate
        player.rate = rate
        boostState = .boosting
    }

    func engageLock() {
        if boostState == .boosting {
            boostState = .locked
        }
    }

    func resetToIdle() {
        guard let player = attachedPlayer else {
            boostState = .idle
            return
        }
        let normalRate = Float(timingPolicy.speedMultiplier)
        if player.rate > normalRate {
            player.rate = normalRate
        }
        player.defaultRate = normalRate
        boostState = .idle
    }
}

private func fullscreenFormatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded(.down))
    let m = total / 60
    let s = total % 60
    return String(format: "%d:%02d", m, s)
}

private func fullscreenFormatRemaining(_ current: Double, _ duration: Double) -> String {
    let remaining = max(0, duration - current)
    return "-" + fullscreenFormatTime(remaining)
}

// MARK: - Liquid Glass surface helper
//
// Apple's Liquid Glass material via `.glassEffect()` — real-time refraction,
// specular highlights, motion-reactive shimmer, and adaptive tint.

private struct LiquidGlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        content.glassEffect(glassConfig, in: shape)
    }

    private var glassConfig: Glass {
        var g: Glass = .regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
}

private extension View {
    func liquidGlassSurface<S: InsettableShape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(LiquidGlassSurface(shape: shape, tint: tint, interactive: interactive))
    }
}

// MARK: - Glass-styled buttons
//
// Tint is **only** applied when this represents an active / primary state per
// Apple HIG — decorative tinting is forbidden.

private struct GlassActionButton<Label: View>: View {
    let isProminent: Bool
    let controlSize: ControlSize
    let label: () -> Label
    let action: () -> Void

    init(
        isProminent: Bool,
        controlSize: ControlSize = .large,
        @ViewBuilder label: @escaping () -> Label,
        action: @escaping () -> Void
    ) {
        self.isProminent = isProminent
        self.controlSize = controlSize
        self.label = label
        self.action = action
    }

    var body: some View {
        let raw = Button(action: action, label: label)
            .controlSize(controlSize)
        Group {
            if isProminent {
                raw.buttonStyle(.glassProminent)
            } else {
                raw.buttonStyle(.glass)
            }
        }
    }
}

// MARK: - GlassEffectContainer wrapper

private struct GlassGroup<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GlassEffectContainer(spacing: spacing, content: content)
    }
}

// MARK: - Main view

struct FilmtoneFullscreenLutEditor: View {
    @ObservedObject var store: FilmtoneEditorStore
    let onClose: () -> Void
    var onSaveLook: () -> Void = {}
    var onExport: () -> Void = {}
    var onSourceTap: () -> Void = {}
    var onAdvancedTap: () -> Void = {}
    var onRecord: () -> Void = {}
    var isRecordSupported: Bool = true
    var recordUnsupportedMessage: String? = nil

    @State private var controlsHidden = false
    @StateObject private var videoController = FullscreenVideoController()

    /// Press-and-hold gesture state — see `handleDragChanged` /
    /// `handleDragEnded`. We use a single `DragGesture(minimumDistance: 0)`
    /// rather than `LongPressGesture` + `DragGesture` simultaneously so the
    /// touch-down → boost → swipe-lock transitions stay in one place.
    @State private var pressStartTime: Date?
    @State private var pressInitialLocation: CGPoint?
    @State private var boostTask: Task<Void, Never>?
    @State private var pressStartedWhileLocked: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            previewLayer

            bottomScrim
                .opacity(controlsHidden ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: controlsHidden)

            chromeLayer
                .opacity(controlsHidden ? 0 : 1)
                .allowsHitTesting(!controlsHidden)
                .animation(.easeInOut(duration: 0.25), value: controlsHidden)
        }
        .overlay(alignment: .top) { topOverlays }
        .overlay(alignment: .bottom) { bottomFloatingOverlays }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: store.toast?.id)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: shouldShowUnsavedExportPrompt)
        .animation(.easeInOut(duration: 0.2), value: videoController.boostState)
        .sensoryFeedback(trigger: videoController.boostState) { old, new in
            switch (old, new) {
            case (.pressing, .boosting): return .impact(weight: .light)
            case (.boosting, .locked):   return .impact(weight: .medium)
            default:                     return nil
            }
        }
        .statusBarHidden(controlsHidden)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("filmtone.fullscreen.lut.editor")
        .onAppear {
            if let player = store.videoPreviewState?.player {
                videoController.attach(player)
                videoController.setTimingPolicy(store.videoTimingPolicy)
            }
        }
        .onChange(of: store.videoPreviewState?.player) { _, newPlayer in
            if let newPlayer {
                videoController.attach(newPlayer)
                videoController.setTimingPolicy(store.videoTimingPolicy)
            } else {
                videoController.detach()
            }
        }
        .onChange(of: store.videoTimingMode) { _, _ in
            videoController.setTimingPolicy(store.videoTimingPolicy)
        }
        .onChange(of: store.sourceVideoFPS) { _, _ in
            videoController.setTimingPolicy(store.videoTimingPolicy)
        }
        .onDisappear {
            videoController.detach()
        }
    }

    // MARK: Preview

    @ViewBuilder
    private var previewLayer: some View {
        ZStack {
            previewMedia
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Touch surface: TikTok-style press-and-hold for 2x, swipe to
            // lock 2x, tap to toggle chrome (also used to unlock from .locked).
            // Implemented as a single DragGesture with a state machine — see
            // FullscreenVideoController.BoostState.
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragChanged(value)
                        }
                        .onEnded { value in
                            handleDragEnded(value)
                        }
                )
                .accessibilityHidden(true)
        }
    }

    // MARK: Boost gesture handlers
    //
    // Tuning constants — kept inline rather than file-private statics because
    // they belong to the FilmtoneFullscreenLutEditor surface and aren't
    // reused. 0.18s threshold matches FilmtonePreviewView still-compare
    // long-press for codebase consistency.
    private static let pressBoostDelayNs: UInt64 = 180_000_000  // 0.18s — matches FilmtonePreviewView still-compare long-press
    private static let cancelDistanceThreshold: CGFloat = 24
    private static let lockDistanceThreshold: CGFloat = 30
    private static let unlockTapMaxDuration: TimeInterval = 0.4

    private func handleDragChanged(_ value: DragGesture.Value) {
        if pressStartTime == nil {
            pressStartTime = Date()
            pressInitialLocation = value.location

            // Press while locked: don't disturb the locked state — a short
            // tap will unlock in handleDragEnded.
            if videoController.boostState == .locked {
                pressStartedWhileLocked = true
                return
            }
            pressStartedWhileLocked = false

            // Boost is video-only. Stills fall through to plain tap-toggle.
            guard store.videoPreviewState != nil else { return }

            videoController.setPressing()
            boostTask?.cancel()
            boostTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.pressBoostDelayNs)
                guard !Task.isCancelled else { return }
                if videoController.boostState == .pressing {
                    videoController.engageBoost()
                }
            }
            return
        }

        guard let initial = pressInitialLocation else { return }
        let dx = value.location.x - initial.x
        let dy = value.location.y - initial.y
        let distanceSq = dx * dx + dy * dy

        switch videoController.boostState {
        case .pressing:
            // Significant movement before boost timer fires → user is
            // swiping, not pressing. Cancel boost intent so release acts
            // as a no-op (not a chrome toggle).
            if distanceSq > Self.cancelDistanceThreshold * Self.cancelDistanceThreshold {
                boostTask?.cancel()
                videoController.cancelPress()
            }
        case .boosting:
            // Drag past lock threshold during boost → lock 2x.
            if distanceSq > Self.lockDistanceThreshold * Self.lockDistanceThreshold {
                videoController.engageLock()
            }
        case .locked, .idle:
            break
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        boostTask?.cancel()
        boostTask = nil

        let elapsed = pressStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let translation = value.translation
        let translationMag = sqrt(
            translation.width * translation.width + translation.height * translation.height
        )
        let startedWhileLocked = pressStartedWhileLocked
        let priorState = videoController.boostState
        pressStartTime = nil
        pressInitialLocation = nil
        pressStartedWhileLocked = false

        // Tap on locked surface → unlock (back to 1x).
        if startedWhileLocked {
            if elapsed < Self.unlockTapMaxDuration && translationMag < Self.cancelDistanceThreshold {
                videoController.resetToIdle()
            }
            return
        }

        switch priorState {
        case .locked:
            // Already locked via mid-press swipe — release stays locked.
            break
        case .boosting:
            // Held for boost without swipe-lock → release returns to 1x.
            videoController.resetToIdle()
        case .pressing:
            // Released before boost timer fired. Treat as tap iff stationary.
            if translationMag < Self.cancelDistanceThreshold {
                withAnimation(.easeInOut(duration: 0.25)) {
                    controlsHidden.toggle()
                }
            }
            videoController.cancelPress()
        case .idle:
            // .idle here means cancelPress already fired (drag during
            // .pressing) — or the preview is a still (no boost was ever
            // armed). For stills, surface tap-to-toggle-chrome.
            if translationMag < Self.cancelDistanceThreshold {
                withAnimation(.easeInOut(duration: 0.25)) {
                    controlsHidden.toggle()
                }
            }
        }
    }

    @ViewBuilder
    private var previewMedia: some View {
        if let videoPreview = store.videoPreviewState {
            FilmtonePreviewPlayerView(
                player: videoPreview.player,
                showsPlaybackControls: false
            )
            .ignoresSafeArea()
        } else if let displayURI = store.selectedPreviewURI,
                  let image = fullscreenPreviewImage(from: displayURI) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        } else {
            Text(store.strings.previewEmptyHint)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: Chrome (upper + lower + scrubber + dock)
    //
    // Two-segment top chrome (CD-confirmed IA): upperChrome holds back +
    // compare segment (video only) + active preset title + hide + save +
    // export. lowerChrome holds the two sheet triggers (Camera / Adjust)
    // — Recipe was removed when preset chips were folded into the bottom
    // Look carousel. Each segment is its own GlassEffectContainer so glass
    // cohesion stays within a row — `glass cannot sample glass`, so we
    // never nest GlassEffectContainer.

    private var chromeLayer: some View {
        ZStack {
            VStack(spacing: 8) {
                upperChrome
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                lowerChrome
                    .padding(.horizontal, 16)

                Spacer(minLength: 0)

                if store.videoPreviewState != nil {
                    videoScrubberPill
                        .padding(.horizontal, 12)
                    highlightMarkerStrip
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }

                bottomDock
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

            // Centered play/pause button — absolute screen center, not
            // squeezed between top/bottom chrome.
            if store.videoPreviewState != nil {
                centerPlayPauseButton
            }
        }
    }

    // MARK: Upper chrome (back / compare / title / hide / save / export)

    private var upperChrome: some View {
        GlassGroup(spacing: 12) {
            HStack(spacing: 10) {
                GlassActionButton(
                    isProminent: false,
                    controlSize: .regular
                ) {
                    Image(systemName: "chevron.backward")
                } action: {
                    onClose()
                }
                .accessibilityLabel(Text(store.strings.fullscreenCloseAccessibility))
                .accessibilityIdentifier("filmtone.fullscreen.close")

                if let activeLookTitle = activeAppliedLookTitle {
                    Text(activeLookTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.tail)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: 132)
                        .liquidGlassSurface(in: Capsule())
                        .accessibilityIdentifier("filmtone.fullscreen.title")
                }

                Spacer(minLength: 6)

                // Inline 2× boost indicator — sits next to playback-related
                // chrome (compare/save/export) so it reads as part of the
                // playback state, never obstructing the preview area.
                boostChip

                // Re-record entry. Sits inside the right-edge action cluster
                // (between the boost chip and compare/save/export), well clear
                // of the chevron-back affordance on the left so it does not
                // read as "back" or "close" — it is an explicit Record action.
                // Reuses the existing `recordProductClip` string ("録画する" /
                // "Record"). On tap, presents the M10 capture surface; cancel
                // returns to this editor without disturbing the current
                // source (handled in `FilmtoneRootView`'s capture cover).
                GlassActionButton(
                    isProminent: false,
                    controlSize: .regular
                ) {
                    Image(systemName: "video.badge.plus")
                } action: {
                    guard isRecordSupported else { return }
                    onRecord()
                }
                .accessibilityLabel(Text(store.strings.recordProductClip))
                .accessibilityHint(Text(recordUnsupportedMessage ?? ""))
                .accessibilityIdentifier("filmtone.fullscreen.action.record")
                .disabled(!isRecordSupported)
                .opacity(isRecordSupported ? 1 : 0.38)

                if let videoPreview = store.videoPreviewState {
                    GlassActionButton(
                        isProminent: videoPreview.compareMode == .original,
                        controlSize: .regular
                    ) {
                        Image(systemName: "arrow.left.arrow.right.square")
                    } action: {
                        let next: FilmtoneVideoCompareMode =
                            videoPreview.compareMode == .graded ? .original : .graded
                        Task { await store.setVideoCompareMode(next) }
                    }
                    .accessibilityLabel(Text(store.strings.compareLabel))
                    .accessibilityIdentifier("filmtone.fullscreen.compare")
                }

                GlassActionButton(
                    isProminent: false,
                    controlSize: .regular
                ) {
                    Image(systemName: "square.and.arrow.down")
                } action: {
                    onSaveLook()
                }
                .accessibilityLabel(Text("Save"))
                .accessibilityIdentifier("filmtone.fullscreen.action.save")

                GlassActionButton(
                    isProminent: true,
                    controlSize: .regular
                ) {
                    Image(systemName: "square.and.arrow.up")
                } action: {
                    onExport()
                }
                .accessibilityLabel(Text("Export"))
                .accessibilityIdentifier("filmtone.fullscreen.action.export")
            }
        }
        .accessibilityIdentifier("filmtone.fullscreen.upperChrome")
    }

    /// Resolves the currently applied saved-Look's display name. When no Look
    /// is applied (`appliedSavedLookId == nil`) returns nil so the title pill
    /// hides entirely — we deliberately do NOT show the app section name
    /// ("LUT Browser") because the user is already inside the LUT browser.
    private var activeAppliedLookTitle: String? {
        guard let id = store.appliedSavedLookId,
              let entry = store.library.looks.first(where: { $0.id == id })
        else { return nil }
        return store.strings.displayName(for: entry)
    }

    // MARK: Lower chrome (Camera / Advanced sheet triggers)
    //
    // Recipe trigger was removed when the Recipe concept was absorbed into
    // Look. The preset catalog still exists at the data layer (each Look
    // serializes a preset name) but is no longer surfaced as a UI picker —
    // Looks (built-in + saved) are the single vibe-selection surface.

    private var lowerChrome: some View {
        let ja = store.strings.usesJapaneseTypography
        return GlassGroup(spacing: 6) {
            HStack(spacing: 6) {
                cameraTriggerButton {
                    onSourceTap()
                }

                triggerButton(
                    label: ja ? "調整" : "Adjust",
                    systemImage: "slider.horizontal.3",
                    identifier: "filmtone.fullscreen.trigger.advanced"
                ) {
                    onAdvancedTap()
                }
            }
        }
        .accessibilityIdentifier("filmtone.fullscreen.lowerChrome")
    }

    private var hasManualCameraProfile: Bool {
        store.project.inputLut != nil || store.project.cameraProfile != .auto
    }

    private func cameraTriggerButton(action: @escaping () -> Void) -> some View {
        GlassActionButton(
            isProminent: hasManualCameraProfile,
            controlSize: .regular
        ) {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.filters")
                        .font(.caption.weight(.semibold))
                    Text(store.strings.cameraLabel)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }

                Text(store.cameraProfileLabel)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .truncationMode(.tail)
                    .opacity(0.78)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
        } action: {
            action()
        }
        .accessibilityLabel(Text("\(store.strings.cameraLabel): \(store.cameraProfileLabel)"))
        .accessibilityIdentifier("filmtone.fullscreen.trigger.source")
    }

    private func triggerButton(
        label: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        GlassActionButton(
            isProminent: false,
            controlSize: .regular
        ) {
            Label(label, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
        } action: {
            action()
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: Top + bottom floating overlays
    //
    // These were previously hosted by FilmtoneRootView's safeAreaInset /
    // bottomOverlay. After the IA pivot they belong inside the fullscreen
    // editor so they overlay the live preview directly. Toast + unsaved
    // export prompt animate from bottom; HDR policy notice sits at top.

    @ViewBuilder
    private var topOverlays: some View {
        if FilmtoneHdrPolicyNotice.shouldSurface(store.hdrPolicy) {
            FilmtoneHdrPolicyNotice(
                policy: store.hdrPolicy,
                strings: store.strings
            )
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .opacity(controlsHidden ? 0 : 1)
            .allowsHitTesting(!controlsHidden)
            .animation(.easeInOut(duration: 0.25), value: controlsHidden)
        }
    }

    /// Inline 2× chip rendered inside `upperChrome`. Lives in chrome space
    /// (not over the preview) so it never obstructs preview confirmation.
    /// Pure Liquid Glass — no tint, no foregroundStyle override. Locked
    /// state is signalled by the `lock.fill` glyph alone.
    @ViewBuilder
    private var boostChip: some View {
        if videoController.boostState == .boosting || videoController.boostState == .locked {
            let isLocked = videoController.boostState == .locked
            HStack(spacing: 4) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.bold))
                }
                Text("2×")
                    .font(.subheadline.monospacedDigit().weight(.bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .liquidGlassSurface(in: Capsule())
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
            .accessibilityIdentifier("filmtone.fullscreen.video.speedIndicator")
        }
    }

    private var shouldShowUnsavedExportPrompt: Bool {
        store.canUseLocalExport && store.saveToPhotosState != .saved && !store.isBusy
    }

    private var bottomFloatingOverlays: some View {
        VStack(spacing: 10) {
            if let toast = store.toast {
                FilmtoneToastView(toast: toast)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1000)
            }

            if shouldShowUnsavedExportPrompt {
                UnsavedExportPrompt(
                    message: store.strings.unsavedExportPrompt,
                    saveLabel: store.strings.saveToPhotos,
                    shareLabel: store.strings.shareOutput,
                    isSaving: store.isSavingToPhotos
                ) {
                    Task { await store.saveToPhotos() }
                } onShare: {
                    Task { await store.shareOutput() }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(900)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .opacity(controlsHidden ? 0 : 1)
        .allowsHitTesting(!controlsHidden)
        .animation(.easeInOut(duration: 0.25), value: controlsHidden)
    }

    // MARK: Center play/pause (video only)

    private var centerPlayPauseButton: some View {
        // Stock iOS glass button — no amber tint. Liquid Glass adapts the
        // symbol color automatically against the underlying preview.
        GlassActionButton(
            isProminent: false,
            controlSize: .extraLarge
        ) {
            Image(systemName: videoController.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 32, height: 32)
        } action: {
            videoController.togglePlayPause()
        }
        .accessibilityIdentifier("filmtone.fullscreen.video.playPause")
    }

    // MARK: Scrubber (video only)

    private var videoScrubberPill: some View {
        let bind = Binding<Double>(
            get: { videoController.currentTime },
            set: { newValue in
                videoController.currentTime = newValue
                videoController.seek(to: newValue)
            }
        )
        let upper = max(videoController.duration, max(videoController.currentTime, 0.01))
        return HStack(spacing: 12) {
            Text(fullscreenFormatTime(videoController.currentTime))
                .font(.caption.monospacedDigit())
                .frame(width: 42, alignment: .leading)

            markerSlider(value: bind, upper: upper)

            Text(fullscreenFormatRemaining(videoController.currentTime, videoController.duration))
                .font(.caption.monospacedDigit())
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlassSurface(in: Capsule(), interactive: true)
        .accessibilityIdentifier("filmtone.fullscreen.video.scrubber")
    }

    private func markerSlider(value: Binding<Double>, upper: Double) -> some View {
        GeometryReader { proxy in
            ZStack {
                Slider(
                    value: value,
                    in: 0...upper,
                    onEditingChanged: { editing in
                        videoController.isScrubbing = editing
                    }
                )

                highlightMarkerRail(width: proxy.size.width)
            }
        }
        .frame(height: 32)
    }

    private func highlightMarkerRail(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            ForEach(store.highlightMarkerList, id: \.id) { marker in
                let x = markerCenterX(for: marker.sourceTimeSec, width: width)
                VStack(spacing: 1) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 8, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                    Capsule()
                        .frame(width: 2, height: 10)
                }
                .foregroundStyle(Color.yellow)
                .shadow(color: Color.black.opacity(0.55), radius: 2, x: 0, y: 1)
                .frame(width: 18, height: 28)
                .offset(x: x - 9)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func markerCenterX(for sourceTimeSec: Double, width: CGFloat) -> CGFloat {
        guard videoController.duration.isFinite,
              videoController.duration > 0,
              sourceTimeSec.isFinite else {
            return 0
        }
        let knob: CGFloat = 28
        let usable = max(width - knob, 1)
        let displayTimeSec = videoController.displayTime(forSourceTime: sourceTimeSec)
        let ratio = min(1.0, max(0.0, displayTimeSec / videoController.duration))
        return knob / 2 + CGFloat(ratio) * usable
    }

    @ViewBuilder
    private var highlightMarkerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                markerStripControls

                ForEach(store.highlightMarkerList, id: \.id) { marker in
                    HStack(spacing: 4) {
                        Button {
                            jumpToHighlightMarker(marker)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "bookmark.fill")
                                Text(verbatim: fullscreenFormatTime(videoController.displayTime(forSourceTime: marker.sourceTimeSec)))
                                    .font(.caption.monospacedDigit().weight(.semibold))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: "Jump to highlight marker"))

                        Button {
                            store.removeHighlightMarker(id: marker.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: "Delete highlight marker"))
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 6)
                    .padding(.vertical, 7)
                    .liquidGlassSurface(in: Capsule(), interactive: true)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("filmtone.fullscreen.video.marker.strip")
    }

    private var markerStripControls: some View {
        HStack(spacing: 6) {
            markerStripControlButton(
                systemName: "bookmark.fill",
                isProminent: isAtExistingHighlightMarker
            ) {
                store.addHighlightMarker(at: videoController.sourceTime(forDisplayTime: videoController.currentTime))
            }
            .keyboardShortcut("m", modifiers: [])
            .accessibilityLabel(Text(verbatim: "Add highlight marker"))
            .accessibilityIdentifier("filmtone.fullscreen.video.marker.add")

            markerStripControlButton(
                systemName: "arrow.left.circle.fill",
                isDisabled: store.highlightMarkerList.isEmpty
            ) {
                jumpToPreviousHighlightMarker()
            }
            .keyboardShortcut("j", modifiers: .shift)
            .accessibilityLabel(Text(verbatim: "Jump to previous highlight marker"))
            .accessibilityIdentifier("filmtone.fullscreen.video.marker.previous")

            markerStripControlButton(
                systemName: "arrow.right.circle.fill",
                isDisabled: store.highlightMarkerList.isEmpty
            ) {
                jumpToNextHighlightMarker()
            }
            .keyboardShortcut("j", modifiers: [])
            .accessibilityLabel(Text(verbatim: "Jump to next highlight marker"))
            .accessibilityIdentifier("filmtone.fullscreen.video.marker.next")
        }
        .padding(.vertical, 1)
    }

    private var isAtExistingHighlightMarker: Bool {
        store.highlightMarkerList.contains {
            abs($0.sourceTimeSec - videoController.sourceTime(forDisplayTime: videoController.currentTime)) <= FilmtoneHighlightMarker.duplicateToleranceSec
        }
    }

    private func markerStripControlButton(
        systemName: String,
        isProminent: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isProminent ? Color.yellow : Color.primary)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .contentShape(Circle())
        .liquidGlassSurface(
            in: Circle(),
            tint: isProminent ? Color.yellow.opacity(0.22) : nil,
            interactive: !isDisabled
        )
    }

    private func jumpToHighlightMarker(_ marker: FilmtoneHighlightMarker) {
        let displayTarget = videoController.displayTime(forSourceTime: marker.sourceTimeSec)
        let target = max(0, min(displayTarget, max(videoController.duration, displayTarget)))
        videoController.currentTime = target
        videoController.seek(to: target)
    }

    private func jumpToNextHighlightMarker() {
        let markers = sortedHighlightMarkerList()
        guard !markers.isEmpty else { return }
        let nextThreshold = videoController.sourceTime(forDisplayTime: videoController.currentTime) + 0.01
        let target = markers.first { $0.sourceTimeSec > nextThreshold } ?? markers[0]
        jumpToHighlightMarker(target)
    }

    private func jumpToPreviousHighlightMarker() {
        let markers = sortedHighlightMarkerList()
        guard let lastMarker = markers.last else { return }
        let previousThreshold = videoController.sourceTime(forDisplayTime: videoController.currentTime) - 0.01
        let target = markers.last { $0.sourceTimeSec < previousThreshold } ?? lastMarker
        jumpToHighlightMarker(target)
    }

    private func sortedHighlightMarkerList() -> [FilmtoneHighlightMarker] {
        store.highlightMarkerList.sorted {
            if $0.sourceTimeSec == $1.sourceTimeSec {
                return $0.id < $1.id
            }
            return $0.sourceTimeSec < $1.sourceTimeSec
        }
    }

    // MARK: Bottom dock — chips + sliders, no card-in-card.
    //
    // The bottom area sits directly on the preview with a subtle bottom-edge
    // scrim (`bottomScrim`) for legibility. Each chip is its own glass
    // capsule; sliders are stock SwiftUI controls so they auto-adopt the
    // iOS 26 Liquid Glass treatment during interaction.

    private var bottomDock: some View {
        VStack(alignment: .leading, spacing: 16) {
            FullscreenLookCarousel(
                entries: store.library.looks,
                activeLookId: store.appliedSavedLookId,
                hasCreativeLut: store.project.creativeLut != nil,
                strings: store.strings,
                onApply: { entry in
                    Task { await store.applySavedLook(id: entry.id) }
                },
                onClear: {
                    store.clearCreativeLut()
                }
            )

            intensityRow

            strengthRow
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var intensityRow: some View {
        if let creativeLut = store.project.creativeLut {
            let clamped = FilmtonePhase0Math.clampLutIntensity(creativeLut.intensity)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(store.strings.fullscreenLookIntensityLabel)
                        .font(.caption.weight(.semibold))

                    Spacer()

                    Text(percentLabel(clamped))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .accessibilityIdentifier("filmtone.fullscreen.lookIntensity.value")
                }

                Slider(
                    value: Binding(
                        get: { clamped },
                        set: { store.setCreativeLutIntensity($0) }
                    ),
                    in: 0...1
                )
                .accessibilityIdentifier("filmtone.fullscreen.lookIntensity.slider")
                .accessibilityLabel(store.strings.fullscreenLookIntensityLabel)
                .accessibilityValue(percentLabel(clamped))
            }
        }
    }

    /// Strength interpolates `reset → activePreset` linearly. When the
    /// active preset IS `reset` itself the interpolation collapses to
    /// zero — moving the slider has no visible effect. Skip the row in
    /// that case so the user does not see a non-functional control.
    /// Mirrors the `intensityRow` conditional pattern.
    @ViewBuilder
    private var strengthRow: some View {
        if store.project.presetName != FilmtonePhase0Generated.presetDefault {
            let clamped = FilmtonePhase0Math.clampStrength(store.project.strength)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(store.strings.fullscreenStrengthLabel)
                        .font(.caption.weight(.semibold))

                    Spacer()

                    Text(percentLabel(clamped))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .accessibilityIdentifier("filmtone.fullscreen.strength.value")
                }

                Slider(
                    value: Binding(
                        get: { clamped },
                        set: { store.setStrength($0) }
                    ),
                    in: 0...1
                )
                .accessibilityIdentifier("filmtone.fullscreen.strength.slider")
                .accessibilityLabel(store.strings.fullscreenStrengthLabel)
                .accessibilityValue(percentLabel(clamped))
            }
        }
    }

    private func percentLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    /// Subtle vertical gradient at the bottom of the screen so chip + slider
    /// labels stay legible when the underlying preview is bright. Apple's
    /// own Photos / Camera editing UIs use the same scrim pattern instead of
    /// a card around controls (which would cause card-in-card with the chip
    /// glass capsules).
    private var bottomScrim: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Carousel

private struct FullscreenLookCarousel: View {
    let entries: [SavedLookEntry]
    let activeLookId: UUID?
    let hasCreativeLut: Bool
    let strings: FilmtoneStrings
    let onApply: (SavedLookEntry) -> Void
    let onClear: () -> Void

    var body: some View {
        Group {
            if entries.count <= 2 {
                fixedLookRow
            } else {
                scrollingLookRow
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var fixedLookRow: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                clearLookChip(fillsWidth: true)
                    .frame(maxWidth: .infinity)

                ForEach(entries) { entry in
                    lookChip(entry, fillsWidth: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
        .accessibilityIdentifier("filmtone.fullscreen.lookCarousel")
    }

    private var scrollingLookRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    clearLookChip(fillsWidth: false)

                    ForEach(entries) { entry in
                        lookChip(entry, fillsWidth: false)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .accessibilityIdentifier("filmtone.fullscreen.lookCarousel")
    }

    private func clearLookChip(fillsWidth: Bool) -> some View {
        GlassActionButton(
            isProminent: !hasCreativeLut && activeLookId == nil,
            controlSize: .regular
        ) {
            lookChipLabel(
                title: strings.fullscreenNoLookLabel,
                systemImage: "circle.dashed",
                fillsWidth: fillsWidth
            )
        } action: {
            onClear()
        }
        .accessibilityIdentifier("filmtone.fullscreen.lookChip.none")
    }

    private func lookChip(_ entry: SavedLookEntry, fillsWidth: Bool) -> some View {
        GlassActionButton(
            isProminent: activeLookId == entry.id,
            controlSize: .regular
        ) {
            lookChipLabel(
                title: strings.displayName(for: entry),
                systemImage: entry.bundled ? "sparkles" : "camera.aperture",
                fillsWidth: fillsWidth
            )
        } action: {
            onApply(entry)
        }
        .accessibilityIdentifier(
            "filmtone.fullscreen.lookChip.\(entry.id.uuidString.lowercased())"
        )
    }

    private func lookChipLabel(title: String, systemImage: String, fillsWidth: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 18)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .center)
    }
}
