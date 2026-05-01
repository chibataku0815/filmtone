import AVFoundation
import AVKit
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
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying: Bool = false
    @Published var isScrubbing: Bool = false

    private weak var attachedPlayer: AVPlayer?
    private var timeObserverToken: Any?

    func attach(_ player: AVPlayer) {
        if attachedPlayer === player { return }
        detach()
        attachedPlayer = player
        let interval = CMTime(value: 1, timescale: 4)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // The .main queue guarantees main-thread execution; assumeIsolated
            // narrows the actor isolation so we can mutate the @MainActor
            // properties without spawning a Task per tick.
            MainActor.assumeIsolated {
                guard let self else { return }
                if !self.isScrubbing {
                    self.currentTime = time.seconds
                }
                if let item = player.currentItem {
                    let raw = item.duration.seconds
                    self.duration = raw.isFinite && raw > 0 ? raw : self.duration
                }
                self.isPlaying = player.timeControlStatus == .playing || player.rate > 0
            }
        }
    }

    func detach() {
        if let token = timeObserverToken, let attachedPlayer {
            attachedPlayer.removeTimeObserver(token)
        }
        timeObserverToken = nil
        attachedPlayer = nil
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
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
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
// On iOS 26+ uses Apple's Liquid Glass material via `.glassEffect()`, which
// renders real-time refraction, specular highlights, motion-reactive
// shimmer, and adaptive tint. On older iOS we degrade to `.ultraThinMaterial`
// (frosted blur) — explicitly NOT pretending to be Liquid Glass.

private struct LiquidGlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glassConfig, in: shape)
        } else {
            content
                .background(shape.fill(.ultraThinMaterial))
                .overlay(shape.strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
        }
    }

    @available(iOS 26.0, *)
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

// MARK: - Glass-styled buttons (OS-branched)
//
// `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` ship in iOS 26
// only. For older iOS we fall back to bordered styles. Tint is **only**
// applied when this represents an active / primary state per Apple HIG —
// decorative tinting is forbidden.

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
        if #available(iOS 26.0, *) {
            modernButton
        } else {
            legacyButton
        }
    }

    @available(iOS 26.0, *)
    private var modernButton: some View {
        let raw = Button(action: action, label: label)
            .controlSize(controlSize)
        return Group {
            if isProminent {
                raw.buttonStyle(.glassProminent)
            } else {
                raw.buttonStyle(.glass)
            }
        }
    }

    private var legacyButton: some View {
        let raw = Button(action: action, label: label)
            .controlSize(controlSize)
        return Group {
            if isProminent {
                raw.buttonStyle(.borderedProminent)
            } else {
                raw.buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - GlassEffectContainer wrapper (OS-branched)

private struct GlassGroup<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing, content: content)
        } else {
            content()
        }
    }
}

// MARK: - Main view

struct FilmtoneFullscreenLutEditor: View {
    @ObservedObject var store: FilmtoneEditorStore
    let onClose: () -> Void

    @State private var controlsHidden = false
    @StateObject private var videoController = FullscreenVideoController()

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
        .statusBarHidden(controlsHidden)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("filmtone.fullscreen.lut.editor")
        .onAppear {
            if let player = store.videoPreviewState?.player {
                videoController.attach(player)
            }
        }
        .onChange(of: store.videoPreviewState?.player) { _, newPlayer in
            if let newPlayer {
                videoController.attach(newPlayer)
            } else {
                videoController.detach()
            }
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

            // Tap surface: anywhere on the preview toggles the chrome
            // (Apple Photos / TV / standard video player idiom). For video,
            // play/pause goes through the on-screen button — single-tap is
            // reserved for chrome reveal so the user can always recover the
            // UI after hiding it.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        controlsHidden.toggle()
                    }
                }
                .accessibilityHidden(true)
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

    // MARK: Chrome (top + scrubber + dock)

    private var chromeLayer: some View {
        ZStack {
            // Top + bottom chrome stack — fills the screen so the bottom
            // dock anchors to the safe area while the top bar anchors to
            // the top.
            VStack(spacing: 0) {
                topRow
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                if let videoPreview = store.videoPreviewState {
                    compareSegment(videoPreview)
                        .padding(.top, 12)
                }

                Spacer(minLength: 0)

                if store.videoPreviewState != nil {
                    videoScrubberPill
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

    // MARK: Top row (close / title / hide-controls)

    private var topRow: some View {
        GlassGroup(spacing: 24) {
            HStack(spacing: 12) {
                GlassActionButton(
                    isProminent: false,
                    controlSize: .large
                ) {
                    Image(systemName: "xmark")
                } action: {
                    onClose()
                }
                .accessibilityLabel(Text(store.strings.fullscreenCloseAccessibility))
                .accessibilityIdentifier("filmtone.fullscreen.close")

                Spacer(minLength: 0)

                Text(store.strings.fullscreenTitle)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .liquidGlassSurface(in: Capsule())

                Spacer(minLength: 0)

                GlassActionButton(
                    isProminent: false,
                    controlSize: .large
                ) {
                    Image(systemName: controlsHidden ? "eye" : "eye.slash")
                } action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        controlsHidden.toggle()
                    }
                }
                .accessibilityLabel(Text(store.strings.fullscreenToggleControlsAccessibility))
                .accessibilityIdentifier("filmtone.fullscreen.toggleControls")
            }
        }
    }

    // MARK: Compare segment (video only)

    private func compareSegment(_ videoPreview: FilmtoneVideoPreviewState) -> some View {
        GlassGroup(spacing: 6) {
            HStack(spacing: 6) {
                GlassActionButton(
                    isProminent: videoPreview.compareMode == .graded,
                    controlSize: .regular
                ) {
                    Text(store.strings.previewGradedLabel)
                        .font(.caption.weight(.semibold))
                } action: {
                    Task { await store.setVideoCompareMode(.graded) }
                }

                GlassActionButton(
                    isProminent: videoPreview.compareMode == .original,
                    controlSize: .regular
                ) {
                    Text(store.strings.compareLabel)
                        .font(.caption.weight(.semibold))
                } action: {
                    Task { await store.setVideoCompareMode(.original) }
                }
            }
        }
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

            Slider(
                value: bind,
                in: 0...upper,
                onEditingChanged: { editing in
                    videoController.isScrubbing = editing
                }
            )

            Text(fullscreenFormatRemaining(videoController.currentTime, videoController.duration))
                .font(.caption.monospacedDigit())
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlassSurface(in: Capsule(), interactive: true)
        .accessibilityIdentifier("filmtone.fullscreen.video.scrubber")
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
        ScrollView(.horizontal, showsIndicators: false) {
            GlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    GlassActionButton(
                        isProminent: !hasCreativeLut,
                        controlSize: .regular
                    ) {
                        Label(strings.fullscreenNoLookLabel, systemImage: "circle.dashed")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                    } action: {
                        onClear()
                    }
                    .accessibilityIdentifier("filmtone.fullscreen.lookChip.none")

                    ForEach(entries) { entry in
                        GlassActionButton(
                            isProminent: activeLookId == entry.id,
                            controlSize: .regular
                        ) {
                            Label(
                                strings.displayName(for: entry),
                                systemImage: entry.bundled ? "sparkles" : "camera.aperture"
                            )
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                        } action: {
                            onApply(entry)
                        }
                        .accessibilityIdentifier(
                            "filmtone.fullscreen.lookChip.\(entry.id.uuidString.lowercased())"
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .accessibilityIdentifier("filmtone.fullscreen.lookCarousel")
    }
}
