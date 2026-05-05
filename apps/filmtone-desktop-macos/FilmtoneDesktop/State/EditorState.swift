import AppKit
import CoreImage
import FilmLabSwiftCore
import Foundation
import Observation

@MainActor
@Observable
final class EditorState {
    var sourceURL: URL?
    var sourceKind: FilmtoneSourceKind = .still
    var presetName: String = FilmtonePresetCatalog.defaultName
    var presetStrength: Double = FilmtonePresetCatalog.presetStrengthDefault
    /// M5-A.2: nil means "no Creative LUT" (legacy 4-preset path); set
    /// to a `FilmtoneCreativePackCatalog` slug (Stone / Urban) to engage
    /// the bundled cube + paramOverrides at strength 1.0 by default.
    var lookSlug: String?
    /// M5-A.3: scrub-bar value in seconds for the currently loaded video.
    /// `nil` for stills or before duration is probed. Seeded to
    /// `duration × 0.5` once the duration probe completes so the first
    /// preview frame after open matches the pre-M5-A.3 midpoint behavior.
    var videoPreviewSeconds: Double?
    /// M5-A.3: probed video duration in seconds. `nil` for stills or
    /// before the probe completes. Drives the scrub bar range.
    var videoDurationSeconds: Double?
    /// M5-I.2: mirrors `videoSession?.player.timeControlStatus == .playing`,
    /// pushed via the session's `onPlayingChange` callback so the
    /// Play/Pause button glyph stays in sync with the AVPlayer rather
    /// than being driven by a timer Task. `togglePlayback()` /
    /// `Space-key` flip the underlying player; the observer flips this.
    var isPlaying: Bool = false
    /// M5-I.2: user-selected playback rate (1× / 2× / 3×). Default 1×.
    /// Pushed into `videoSession.setRate(_:)` on change. Stored on
    /// EditorState so the rate menu binding survives session rebuilds
    /// (open new source → reuse the previously-selected rate).
    var playbackRate: Double = 1.0
    /// M5-C.1: source profile selection. `.auto` resolves at probe time
    /// (matches iOS canonical detection-hint catalog) — sticky on `.builtIn`
    /// because container metadata cannot reliably distinguish the synthesized
    /// log curves (D-CP4 retention rule).
    var sourceProfileSelection: CameraProfileSelection = .auto
    /// M5-C.1: latest probed source color class. Updated by PreviewSurface
    /// after the source is opened so the right-rail Source Profile Picker
    /// can mirror Auto's resolved choice and the source-cap gate can decide
    /// whether to disable Export.
    var probedSourceColorClass: SourceColorClassDTO?
    /// M5-C.2a: which library entry is shown selected in the Look picker.
    /// nil = "None" (no Look). Built-in Stone / Urban appear here via
    /// their canonical catalog UUIDs (`FilmtoneCreativePackCatalog.find
    /// (canonicalUUID:)`). User-saved entries use the UUID minted by
    /// `FilmtoneSavedLookStore.saveLook`. Live render state stays driven
    /// by `lookSlug` / `presetName` / `presetStrength`; this property is
    /// UI-tracking sugar so the Picker remains consistent across
    /// re-selection of the same Look.
    var selectedSavedLookId: UUID?
    /// M5-C.3a: Quick adjust 3-axis state (filmCharacter / era / dynamics)
    /// each in [-1, 1]. Folded into the resolved render params via
    /// `FilmtonePresetCatalog.applyQuickState`. Saved/restored as part of
    /// the saved-Look round-trip and emitted to the export sidecar.
    var quickState: FilmtoneQuickState = .zero
    /// M5-C.3a: per-key parameter override patch (sparse, additive on top
    /// of the preset/look-resolved params, evaluated before quickState).
    /// UI editing surface lands in M5-C.3b; the storage / save-load
    /// round-trip lights up here so a Look saved with overrides restores
    /// them on recall the moment the editing UI exists.
    var paramOverrides: FilmtonePhase0ParamsPatch = .empty
    var isExporting: Bool = false
    var exportProgress: Double = 0
    var exportProgressMessage: String?
    var lastExportSummary: String?

    /// M5-C.4: pre-export format selection (still only — video stays h264).
    /// Default `.png` matches the previous implicit default (NSSavePanel
    /// prefilled `.png`).
    var exportFormat: StillExportFormat = .png
    /// M5-C.4: JPEG quality (0.5...1.0). Default 0.95 preserves the
    /// pre-M5-C.4 hardcoded value bytewise. Ignored when `exportFormat`
    /// is `.png`. didSet clamps so UI can't push the value out of range.
    var jpegQuality: Double = 0.95 {
        didSet {
            let clamped = min(1.0, max(0.5, jpegQuality))
            if clamped != jpegQuality { jpegQuality = clamped }
        }
    }
    /// M5-C.4: stamped at NSSavePanel-OK so the finished state can show
    /// elapsed seconds. Cleared when the result snapshot is reset.
    @ObservationIgnored
    var exportStartedAt: Date?
    /// M5-C.4: persists across renders — drives the inspector's
    /// "finished" state. Cleared by `resetExportResult()` (Export Again
    /// button) or by the next export start.
    var lastExportResult: ExportResultSnapshot?
    /// M5-C.4: separated from `lastExportSummary` so the inspector can
    /// surface failures without erasing the previous successful result.
    var lastExportError: String?

    @ObservationIgnored
    var currentExportTask: Task<Void, Never>?
    @ObservationIgnored
    var currentDurationProbeTask: Task<Void, Never>?
    /// M5-I.2: AVPlayer-backed playback session for the currently loaded
    /// video. Built async after `setSource(.video)` via
    /// `currentSessionPrepareTask`; released to nil on still / no source.
    /// The session owns the AVPlayer + AVPlayerItem and the periodic time
    /// observer that pushes back into `videoPreviewSeconds`. NOT
    /// `@ObservationIgnored` — `PreviewSurface` reads it to swap from the
    /// black bridging backdrop to the AVPlayer view as soon as the session
    /// lands, so the body must re-evaluate when the assignment changes.
    var videoSession: FilmtoneDesktopVideoSession?
    @ObservationIgnored
    var currentSessionPrepareTask: Task<Void, Never>?
    /// M5-I.2: guards against the periodic time observer fighting an
    /// active scrub drag — when the scrub bar is in `onEditingChanged
    /// (true)` the observer's writes back into `videoPreviewSeconds`
    /// would yank the slider thumb away from the user's finger.
    @ObservationIgnored
    var isScrubbing: Bool = false

    var presetParams: FilmtonePhase0Params {
        FilmtonePresetCatalog.resolved(
            presetName: presetName,
            strength: presetStrength,
            lookSlug: lookSlug,
            quickState: quickState,
            paramOverrides: paramOverrides
        )
    }

    /// M5-C.3a: true when any Quick axis carries a non-zero offset.
    /// Drives "Reset Quick" button enablement.
    var quickStateIsActive: Bool {
        quickState.filmCharacter != 0 ||
        quickState.era != 0 ||
        quickState.dynamics != 0
    }

    /// M5-C.3a: clear all 3 axes back to zero without touching Look /
    /// strength / paramOverrides.
    func resetQuickState() {
        quickState = .zero
    }

    /// D4-ii: when a Look is selected and strength > 0, resolve the cube
    /// once. strength == 0 gates the cube off so the bareline render is
    /// pure preset-reset (no Look identity bleed). nil otherwise.
    var resolvedCreativeLut: PreparedCreativeLut? {
        guard let lookSlug,
              presetStrength > 0,
              let look = FilmtoneCreativePackCatalog.find(slug: lookSlug) else {
            return nil
        }
        return FilmtoneCreativeLutLoader.load(look: look)
    }

    var lookId: String {
        if let lookSlug {
            return FilmtonePresetCatalog.lookId(forSlug: lookSlug)
        }
        return FilmtonePresetCatalog.lookId(for: presetName)
    }

    var lookVersion: String {
        FilmtonePresetCatalog.presetVersion
    }

    func setSource(_ url: URL?, kind: FilmtoneSourceKind) {
        sourceURL = url
        sourceKind = kind
        // M5-A.3: drop any stale scrub state from the previous video and
        // cancel any in-flight duration probe so we don't seed seconds
        // from the previous source.
        currentDurationProbeTask?.cancel()
        currentDurationProbeTask = nil
        // M5-I.2: tear down the previous session so its AVPlayer stops
        // ticking and the periodic time observer is removed before the
        // next session takes over. A residual session would race the
        // new source's videoPreviewSeconds writes.
        currentSessionPrepareTask?.cancel()
        currentSessionPrepareTask = nil
        videoSession?.teardown()
        videoSession = nil
        isPlaying = false
        videoPreviewSeconds = nil
        videoDurationSeconds = nil
        // M5-C.1: clear the previous probe's color class so the gate /
        // Picker resolved-Auto label don't misreport stale state until the
        // PreviewSurface re-probes the new source.
        probedSourceColorClass = nil
        // M5-C.4: previous export's snapshot belonged to the previous
        // source — clear so the inspector returns to ready state for
        // the new source.
        lastExportResult = nil
        lastExportError = nil
        lastExportSummary = nil
        exportStartedAt = nil
        exportProgress = 0

        if let url, kind == .video {
            startVideoDurationProbe(for: url)
            startVideoSessionPrepare(for: url)
        }
    }

    /// M5-I.2: spin up the AVPlayer-backed session for `url`. Probes the
    /// asset off-actor (FilmtoneSourceProber.probeVideo), captures track
    /// metadata + color class, builds the session, wires its time +
    /// playing-status observers back into EditorState, and pushes the
    /// initial render inputs so the first composed frame matches the
    /// editor's current preset / look / quick / overrides / profile.
    private func startVideoSessionPrepare(for url: URL) {
        let initialInputs = currentVideoRenderInputs(for: url)
        currentSessionPrepareTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let session = try? await FilmtoneDesktopVideoSession.prepare(
                sourceURL: url,
                inputs: initialInputs
            )
            guard !Task.isCancelled,
                  self.sourceURL == url,
                  let session else {
                return
            }
            self.videoSession = session
            self.probedSourceColorClass = session.probedColorClass
            // Apply the playback rate the user previously selected before
            // a new source replaced the prior session.
            session.setRate(self.playbackRate)
            session.onTimeUpdate = { [weak self] seconds in
                guard let self else { return }
                if self.isScrubbing { return }
                self.videoPreviewSeconds = seconds
            }
            session.onPlayingChange = { [weak self] playing in
                self?.isPlaying = playing
            }
        }
    }

    /// Snapshot the current edit state into a Sendable bundle for the
    /// composition factory. Captured at composition-build time and
    /// closed over by the per-frame handler so each rebuild renders a
    /// coherent set of params (no mid-frame state tear).
    func currentVideoRenderInputs(
        for url: URL? = nil
    ) -> FilmtoneDesktopVideoRenderInputs {
        FilmtoneDesktopVideoRenderInputs(
            presetName: presetName,
            presetStrength: presetStrength,
            lookSlug: lookSlug,
            sourceProfileSelection: sourceProfileSelection,
            probedColorClass: probedSourceColorClass,
            quickState: quickState,
            paramOverrides: paramOverrides,
            sourceURL: url ?? sourceURL ?? URL(fileURLWithPath: "/")
        )
    }

    /// M5-A.3: probes video duration off the main actor and seeds
    /// `videoPreviewSeconds = duration × 0.5` so the first preview frame
    /// after open matches the pre-M5-A.3 midpoint behavior. Failures are
    /// swallowed silently — the scrub bar simply stays hidden and
    /// `PreviewSurface` falls back to the legacy midpoint loader.
    private func startVideoDurationProbe(for url: URL) {
        currentDurationProbeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let probedDuration = try? await FilmtoneVideoFramePreviewLoader
                .loadDurationSeconds(from: url)
            guard !Task.isCancelled,
                  self.sourceURL == url,
                  let probedDuration,
                  probedDuration.isFinite,
                  probedDuration > 0 else {
                return
            }
            self.videoDurationSeconds = probedDuration
            self.videoPreviewSeconds = probedDuration * 0.5
        }
    }

    func cancelExport() {
        currentExportTask?.cancel()
    }

    // MARK: - M5-I.2 AVPlayer-backed playback

    /// Toggle real AVPlayer playback. Delegates to the live session's
    /// `togglePlayback()`; `isPlaying` is then updated by the session's
    /// `onPlayingChange` callback so this stays in lockstep with
    /// `AVPlayer.timeControlStatus`.
    func togglePlayback() {
        videoSession?.togglePlayback()
    }

    /// Seek the AVPlayer (used by the scrub bar). Holds `isScrubbing`
    /// so the session's periodic time observer doesn't fight the drag.
    func seekVideo(toSeconds seconds: Double) {
        videoSession?.seek(toSeconds: seconds)
    }

    /// Update playback rate (1×/2×/3×). Stored on EditorState so the
    /// rate menu binding is stable across session rebuilds.
    func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
        videoSession?.setRate(rate)
    }

    /// Push the current edit state snapshot into the live video
    /// session's composition. Called from RootWindowView's onChange
    /// hooks for preset / strength / look / quick / overrides /
    /// sourceProfileSelection so a video user sees the edit roll
    /// through to the next composed frame within the session's 100ms
    /// debounce window.
    func refreshVideoCompositionIfNeeded() {
        guard let videoSession else { return }
        videoSession.updateInputs(currentVideoRenderInputs())
    }

    // MARK: - M5-C.4 Export inspector

    /// Single source-cap reason rendered as the inspector's blocked
    /// state. Mirrors iOS `store.sourceViolations` shape (array) so the
    /// View's ForEach can stay identical even if Desktop later surfaces
    /// multiple violations.
    var sourceCapViolations: [String] {
        guard sourceURL != nil,
              let reason = FilmtoneSourceInputTransform.sourceCapReason(
                probedColorClass: probedSourceColorClass
              ),
              FilmtoneSourceInputTransform.sourceExceedsCapacity(
                selection: sourceProfileSelection,
                probedColorClass: probedSourceColorClass
              )
        else { return [] }
        return [reason]
    }

    /// Clear the finished-state snapshot so the inspector returns to
    /// the ready state. Called by the inspector's "Export Again" button
    /// and by `setSource(...)` when a new source is loaded.
    func resetExportResult() {
        lastExportResult = nil
        lastExportError = nil
        lastExportSummary = nil
        exportStartedAt = nil
        exportProgress = 0
    }

    // MARK: - M5-C.2a Saved Look bridge

    /// Build a `SaveLookPayload` snapshot from the live render state.
    /// `LibraryViewModel.saveCurrentLook(name:payload:)` consumes this;
    /// the payload type itself lives in `SaveLookPayload.swift` (M5-G.1
    /// lift) so the library feature does not transitively depend on
    /// the whole `EditorState`.
    func currentLookSavePayload() -> SaveLookPayload {
        let creativeLut: CreativeLutBinding?
        if let slug = lookSlug,
           let look = FilmtoneCreativePackCatalog.find(slug: slug) {
            creativeLut = .bundled(
                slug: look.slug,
                filename: look.bundledFilename,
                sha256: look.pinnedSha256,
                intensity: look.intensity
            )
        } else {
            creativeLut = nil
        }
        return SaveLookPayload(
            presetName: presetName,
            presetVersion: FilmtonePresetCatalog.presetVersion,
            strength: presetStrength,
            quickState: quickState,
            paramOverrides: paramOverrides,
            creativeLut: creativeLut
        )
    }

    /// Apply a SavedLookEntry to live render state. Built-in entries
    /// land via `creativeLut.bundledSlug`; user-saved entries with a
    /// nil binding clear the lookSlug. M5-C.3a: also restores the
    /// entry's `quickState` and `paramOverrides` so a Look saved with
    /// Quick offsets / per-key overrides round-trips faithfully.
    func applySavedLook(_ entry: SavedLookEntry) {
        selectedSavedLookId = entry.id
        presetName = entry.presetName
        presetStrength = entry.strength
        if let bundledSlug = entry.creativeLut?.bundledSlug {
            lookSlug = bundledSlug
        } else {
            lookSlug = nil
        }
        quickState = entry.quickState.clamped()
        paramOverrides = entry.paramOverrides
    }

    /// Reset the Look picker to "None". Mirrors what tapping the None
    /// row does — clears slug + selection. M5-C.3a: also drops live
    /// Quick state and paramOverrides back to defaults so the next
    /// Save isn't contaminated by a previous Look's offsets.
    func clearSavedLookSelection() {
        selectedSavedLookId = nil
        lookSlug = nil
        quickState = .zero
        paramOverrides = .empty
    }
}
