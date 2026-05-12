import AVFoundation
import CoreMedia
import FilmLabSwiftCore
import Foundation

// M5-I.2 AVPlayer preview route — session container.
//
// One session per opened video source. Owns the AVPlayer + the graded
// AVPlayerItem, builds and reassigns the AVMutableVideoComposition when
// edit params change, drives the scrub bar via a periodic time observer,
// and reports playback rate transitions back to EditorState.
//
// AVPlayer in macOS 26 is @MainActor, so the session stays on the main
// actor; the per-frame grade pipeline runs on AVFoundation's private
// dispatch queue inside the composition handler (see
// FilmtoneDesktopVideoComposition).

@MainActor
final class FilmtoneDesktopVideoSession {

    /// Sendable bundle returned by `prepare(sourceURL:)`. The AVAssetTrack
    /// itself is non-Sendable so it's consumed inline on construction —
    /// only Sendable scalars survive the actor hop.
    let sourceURL: URL
    let durationSeconds: Double
    let probedColorClass: SourceColorClassDTO?
    let cameraOptics: CameraOpticsDTO?

    let player: AVPlayer
    private let asset: AVURLAsset
    private let videoTrack: AVAssetTrack
    private let naturalSize: CGSize
    private let preferredTransform: CGAffineTransform
    private let nominalFrameRate: Float
    private let item: AVPlayerItem

    private var currentInputs: FilmtoneDesktopVideoRenderInputs
    private var refreshTask: Task<Void, Never>?
    private var timeObserver: Any?
    private var rateObservation: NSKeyValueObservation?

    /// M5-K4: graded scrub-bar thumbnail provider. Built lazily on first
    /// access so still preview / non-hovering video sessions don't pay
    /// for the AVAssetImageGenerator + thumbnail composition allocation.
    /// Inputs ride along with the live composition refresh below.
    private var _thumbnailProvider: FilmtoneVideoScrubThumbnailProvider?
    var thumbnailProvider: FilmtoneVideoScrubThumbnailProvider {
        if let existing = _thumbnailProvider { return existing }
        let provider = FilmtoneVideoScrubThumbnailProvider(
            asset: asset,
            videoTrack: videoTrack,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            nominalFrameRate: nominalFrameRate,
            durationSeconds: durationSeconds,
            inputs: currentInputs
        )
        _thumbnailProvider = provider
        return provider
    }

    /// Pushed each periodic tick. EditorState wires this to keep
    /// `videoPreviewSeconds` in sync so the scrub bar follows playback.
    var onTimeUpdate: ((Double) -> Void)?
    /// Pushed when AVPlayer.timeControlStatus transitions. EditorState
    /// wires this to mirror `isPlaying` for the Play/Pause button glyph.
    var onPlayingChange: ((Bool) -> Void)?

    private init(
        sourceURL: URL,
        asset: AVURLAsset,
        videoTrack: AVAssetTrack,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        nominalFrameRate: Float,
        durationSeconds: Double,
        probedColorClass: SourceColorClassDTO?,
        cameraOptics: CameraOpticsDTO?,
        inputs: FilmtoneDesktopVideoRenderInputs
    ) {
        self.sourceURL = sourceURL
        self.asset = asset
        self.videoTrack = videoTrack
        self.naturalSize = naturalSize
        self.preferredTransform = preferredTransform
        self.nominalFrameRate = nominalFrameRate
        self.durationSeconds = durationSeconds
        self.probedColorClass = probedColorClass
        self.cameraOptics = cameraOptics
        // M5-M (CC-B): EditorState builds the initial inputs before
        // the session attaches, so its `cameraOptics` field is nil at
        // this point. Substitute the probe-derived value so the first
        // composition handler sees the actual lens metadata.
        let resolvedInputs = Self.resolveInputs(inputs, cameraOptics: cameraOptics)
        self.currentInputs = resolvedInputs

        let playerItem = AVPlayerItem(asset: asset)
        // Force the item to wait until the freshly-assigned composition
        // produces a frame before resolving a seek; without this, swapping
        // the videoComposition mid-playback briefly shows the previous
        // graded frame at the new time.
        playerItem.seekingWaitsForVideoCompositionRendering = true
        if let composition = FilmtoneDesktopVideoComposition.make(
            asset: asset,
            videoTrack: videoTrack,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            nominalFrameRate: nominalFrameRate,
            inputs: resolvedInputs
        ) {
            playerItem.videoComposition = composition
        }
        self.item = playerItem

        let avPlayer = AVPlayer(playerItem: playerItem)
        // AVPlayer mutes audio by default only when the item lacks audio;
        // explicit `isMuted = false` covers the case where SwiftUI #Preview
        // contexts default mute the underlying engine.
        avPlayer.isMuted = false
        avPlayer.actionAtItemEnd = .pause
        self.player = avPlayer

        installTimeObserver()
        installRateObserver()
    }

    // No `deinit` — Swift 6 strict concurrency forbids reading
    // non-Sendable stored properties (e.g. `timeObserver: Any?`,
    // `player: AVPlayer`) from a nonisolated `deinit`. The session is
    // always released through `EditorState.setSource(...)` which calls
    // `teardown()` on the MainActor before dropping the reference, so
    // by the time deinit runs there is no observer left to remove and
    // no rate observation left to invalidate. NSKeyValueObservation
    // additionally invalidates itself on dealloc, so even a missed
    // teardown does not leak the rate observer indefinitely.

    // MARK: - Lifecycle

    /// Probe `sourceURL` and build a session if the asset has a usable
    /// video track. Returns `nil` for assets without video (audio-only
    /// files etc.) — caller falls back to the still-image code path or
    /// shows nothing.
    static func prepare(
        sourceURL: URL,
        inputs: FilmtoneDesktopVideoRenderInputs
    ) async throws -> FilmtoneDesktopVideoSession? {
        let probe = try await FilmtoneSourceProber.probeVideo(sourceURL: sourceURL)
        guard probe.naturalSize.width > 0, probe.naturalSize.height > 0 else {
            return nil
        }
        return FilmtoneDesktopVideoSession(
            sourceURL: sourceURL,
            asset: probe.asset,
            videoTrack: probe.track,
            naturalSize: probe.naturalSize,
            preferredTransform: probe.preferredTransform,
            nominalFrameRate: probe.nominalFrameRate,
            durationSeconds: probe.durationSeconds,
            probedColorClass: probe.colorClass,
            cameraOptics: probe.cameraOptics,
            inputs: inputs
        )
    }

    /// Stop playback, drop time observer, drop rate observer. Call before
    /// releasing the session so AVPlayer doesn't keep ticking against a
    /// stale source.
    func teardown() {
        refreshTask?.cancel()
        refreshTask = nil
        player.pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        rateObservation?.invalidate()
        rateObservation = nil
        // M5-K4: drop the AVAssetImageGenerator alongside the player so a
        // background generation does not finish writing into a freed
        // composition handler after the source flips.
        _thumbnailProvider?.teardown()
        _thumbnailProvider = nil
    }

    // MARK: - Playback control

    var isPlaying: Bool {
        player.timeControlStatus == .playing
    }

    /// M5-K3: oriented (post-`preferredTransform`) display aspect ratio
    /// for the loaded video. Used by the compare drag-handle overlay so
    /// it constrains itself to the AVPlayer's actual letterboxed rect
    /// instead of the full preview region. Falls back to 1:1 only when
    /// the probe returned a degenerate size — `prepare(...)` rejects
    /// zero-sized assets, so this floor is just a divide-by-zero guard.
    var displayAspectRatio: CGFloat {
        let oriented = naturalSize.applying(preferredTransform)
        let width = abs(oriented.width)
        let height = abs(oriented.height)
        guard width > 0, height > 0 else { return 1 }
        return width / height
    }

    func togglePlayback() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        // If the item already played to its end, AVPlayer needs an
        // explicit seek back to zero before play() will resume.
        if let item = player.currentItem,
           item.duration.isValid, item.duration.seconds > 0 {
            let now = CMTimeGetSeconds(player.currentTime())
            if now >= item.duration.seconds - 0.05 {
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
        player.play()
    }

    func pause() {
        player.pause()
    }

    func setRate(_ rate: Double) {
        let clamped = max(0.5, min(rate, 4.0))
        if isPlaying {
            player.rate = Float(clamped)
        } else {
            // AVPlayer.rate setter both starts playback AND sets rate.
            // When paused, just remember the user's intent for the next
            // play() — but since AVPlayer has no separate desiredRate
            // API, the simplest path is: store via play() at this rate.
            player.rate = Float(clamped)
            player.pause()
            // The rate property survives pause/play cycles, so the next
            // play() on the (now correctly rated) player picks it up.
            player.rate = Float(clamped)
        }
    }

    func seek(toSeconds seconds: Double) {
        let clamped = max(0, min(seconds, durationSeconds))
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Composition refresh

    /// Replace the captured render inputs and (debounced) rebuild the
    /// graded composition so the next composed frame reflects the new
    /// preset / strength / look / quick / overrides / source-profile.
    func updateInputs(_ inputs: FilmtoneDesktopVideoRenderInputs) {
        currentInputs = Self.resolveInputs(inputs, cameraOptics: cameraOptics)
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            // 100ms debounce keeps slider drags from spawning a rebuild
            // per Slider tick (each rebuild allocates a new
            // AVMutableVideoComposition + closure capture).
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard let self, !Task.isCancelled else { return }
            self.rebuildCompositionAndReseek()
        }
    }

    private func rebuildCompositionAndReseek() {
        guard let composition = FilmtoneDesktopVideoComposition.make(
            asset: asset,
            videoTrack: videoTrack,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            nominalFrameRate: nominalFrameRate,
            inputs: currentInputs
        ) else { return }
        item.videoComposition = composition
        // M5-K4: keep the (possibly already-built) thumbnail provider in
        // lockstep with the live composition so hovering reflects the
        // edit the user just made. Provider rebuild is cheap relative to
        // the live AVPlayerItem composition swap.
        _thumbnailProvider?.updateInputs(currentInputs)
        // Force the item to render the current frame through the new
        // composition. seekingWaitsForVideoCompositionRendering = true
        // (set in init) makes the seek block until the new composition
        // produces a frame, eliminating the 1-frame stale flash that
        // would otherwise appear when swapping compositions mid-playback.
        let currentTime = player.currentTime()
        player.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Observers

    private func installTimeObserver() {
        // 30 Hz UI refresh is dense enough for a smooth scrub-bar follow
        // without saturating the main thread.
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }
            // The .main queue callback already runs on the main thread,
            // but Swift 6 strict concurrency wants an explicit MainActor
            // hop because the closure type is @Sendable.
            Task { @MainActor [weak self] in
                self?.onTimeUpdate?(seconds)
            }
        }
    }

    private func installRateObserver() {
        rateObservation = player.observe(
            \.timeControlStatus,
            options: [.initial, .new]
        ) { [weak self] player, _ in
            let playing = player.timeControlStatus == .playing
            Task { @MainActor [weak self] in
                self?.onPlayingChange?(playing)
            }
        }
    }

    // M5-M (CC-B): EditorState builds render inputs without seeing the
    // session yet (the assignment back to `editor.videoSession` only
    // happens after `prepare(...)` completes), so its `cameraOptics`
    // field arrives nil. The session has the probe-derived metadata,
    // so substitute it into every composition / thumbnail input bundle.
    private static func resolveInputs(
        _ inputs: FilmtoneDesktopVideoRenderInputs,
        cameraOptics: CameraOpticsDTO?
    ) -> FilmtoneDesktopVideoRenderInputs {
        if inputs.cameraOptics != nil { return inputs }
        return FilmtoneDesktopVideoRenderInputs(
            presetName: inputs.presetName,
            presetStrength: inputs.presetStrength,
            lookSlug: inputs.lookSlug,
            sourceProfileSelection: inputs.sourceProfileSelection,
            probedColorClass: inputs.probedColorClass,
            quickState: inputs.quickState,
            paramOverrides: inputs.paramOverrides,
            packageCreativeLut: inputs.packageCreativeLut,
            compareEnabled: inputs.compareEnabled,
            compareSplitFraction: inputs.compareSplitFraction,
            sourceURL: inputs.sourceURL,
            opticalFilterProfileId: inputs.opticalFilterProfileId,
            opticalFilterIntensity: inputs.opticalFilterIntensity,
            cameraOptics: cameraOptics
        )
    }
}
