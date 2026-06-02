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
    /// Nominal source fps used to derive Resolve-friendly marker frame ids.
    var videoNominalFrameRate: Double?
    /// Display-oriented video dimensions after preferredTransform. Used by the
    /// export inspector so FHD can be the default and 4K appears only when the
    /// source can actually support it.
    var videoDisplaySize: CGSize? {
        didSet {
            if !canExportVideo4K && videoExportResolution == .fourK {
                videoExportResolution = .fhd
            }
        }
    }
    /// Normal Desktop export defaults to FHD. 4K is an explicit opt-in for
    /// 4K-capable sources because it materially increases render time.
    var videoExportResolution: FilmtoneVideoExportResolution = .fhd {
        didSet {
            if videoExportResolution == .fourK && !canExportVideo4K {
                videoExportResolution = .fhd
            }
        }
    }
    /// Explicit video timing mode for preview + normal video export.
    var videoTimingMode: FilmtoneVideoTimingMode = .normal
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
    /// M5-L1: source-change profile retention/reset is applied exactly once
    /// per opened source after the first still/video probe lands.
    @ObservationIgnored
    var sourceProfilePolicyAppliedURL: URL?
    /// M5-C.2a: which library entry is shown selected in the Look picker.
    /// nil = "None" (no Look). Built-in Stone / Urban appear here via
    /// their canonical catalog UUIDs (`FilmtoneCreativePackCatalog.find
    /// (canonicalUUID:)`). User-saved entries use the UUID minted by
    /// `FilmtoneSavedLookStore.saveLook`. Live render state stays driven
    /// by `lookSlug` / `presetName` / `presetStrength`; this property is
    /// UI-tracking sugar so the Picker remains consistent across
    /// re-selection of the same Look.
    var selectedSavedLookId: UUID?
    /// DB-M13: selected normalized Imported Grade entry. This is separate
    /// from Saved Look selection because Imported Grade is a DaVinci/source
    /// bridge object, not a user-authored Filmtone Look snapshot.
    var selectedImportedGradeId: UUID?
    var selectedImportedGrade: FilmtoneImportedGradeLook?
    var selectedImportedGradeSidecarURL: URL?
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
    /// Source-relative highlight markers shared with iOS and DaVinci.
    var highlightMarkers: FilmtoneHighlightMarkers?
    /// M5-L3: named optical filter profile selection. `nil` means no
    /// filter. Backlight Veil profiles resolve to a render-time patch
    /// that manual `paramOverrides` can still override key-by-key.
    var opticalFilterProfileId: String?
    /// M5-M (CC-B): continuous intensity scalar for the Backlight Veil profile.
    /// Range 0…1; default 1.0 so selecting a density chip matches M5-L3
    /// chip-only behavior byte-for-byte. At 0.0 the profile contribution is
    /// zeroed (only explicit `paramOverrides` remain). Has no effect when
    /// `opticalFilterProfileId` is nil (chip = None). Folded into
    /// `renderParamOverrides` so `VideoCompositionRefreshKey` picks up
    /// changes automatically.
    var opticalFilterIntensity: Double = 1.0 {
        didSet {
            let clamped = max(0, min(1, opticalFilterIntensity))
            if clamped != opticalFilterIntensity { opticalFilterIntensity = clamped }
        }
    }
    /// iOS capture package provenance for the currently opened source. Nil
    /// for normal image/video opens.
    var capturePackageProvenance: FilmtoneCapturePackageProvenance?
    /// Package-local custom LUT prepared from an iOS capture package. This is
    /// source-bound and intentionally separate from the Desktop Saved Look
    /// library.
    var packageCreativeLut: PreparedCreativeLut?
    /// Non-nil when an iOS package references a custom LUT but does not carry
    /// a readable package-local payload. Export is blocked so the package does
    /// not silently grade as a different look.
    var capturePackageCustomLutMissingReason: String?
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
    /// M5-J.2: Before/After 50:50 compare. When true the still preview
    /// composes left=source / right=graded via FilmtoneCompareCompose,
    /// and the video composition handler does the same for each
    /// composed frame. Preview-only — does not affect export or sidecar.
    var isCompareEnabled: Bool = false
    /// M5-K3: horizontal split position the compare overlay is anchored
    /// to, in [0, 1]. didSet collapses non-finite drags and out-of-range
    /// values back into `FilmtoneCompareSplitMath.range` so the still
    /// composer and video composition handler always receive a sane
    /// fraction. Default mirrors the M5-J.2 fixed 50:50 starting point.
    var compareSplitFraction: Double = FilmtoneCompareSplitMath.default {
        didSet {
            let clamped = FilmtoneCompareSplitMath.clamp(compareSplitFraction)
            if clamped != compareSplitFraction { compareSplitFraction = clamped }
        }
    }

    /// M5-M follow-up (Look × Veil energy max-merge): pass the Veil profile
    /// id + intensity directly into `resolved()` so its 3-stage layering
    /// (base+Look → Quick → Veil[max-merge energy / overwrite structural]
    /// → user paramOverrides) keeps Look-raised energy keys (e.g. Stone's
    /// `lensSoftness 0.095`) from being knocked back down by the Veil
    /// profile's reset-baseline-authored values (`lensSoftness 0.08`).
    /// `paramOverrides` here is the *raw* user manual overrides — Veil
    /// patch resolution moved into `resolved()` itself.
    var currentGradeSelection: FilmtoneGradeSelection {
        if let selectedImportedGrade {
            return .importedGrade(
                look: selectedImportedGrade,
                sidecarURL: selectedImportedGradeSidecarURL,
                packageCreativeLut: packageCreativeLut
            )
        }
        return .builtIn(
            presetName: presetName,
            presetStrength: presetStrength,
            lookSlug: lookSlug,
            packageCreativeLut: packageCreativeLut
        )
    }

    var currentGradeRecipe: FilmtoneGradeRecipe {
        FilmtoneGradeRecipe(
            selection: currentGradeSelection,
            quickState: quickState,
            paramOverrides: paramOverrides,
            opticalFilterProfileId: opticalFilterProfileId,
            opticalFilterIntensity: opticalFilterIntensity
        )
    }

    var videoTimingPolicy: FilmtoneVideoTimingPolicy {
        FilmtoneVideoTimingPolicy(
            mode: videoTimingMode,
            sourceFPS: videoNominalFrameRate
        )
    }

    var resolvedVideoTimingMode: FilmtoneVideoTimingMode {
        videoTimingPolicy.resolvedMode
    }

    var canUseSlow24VideoTiming: Bool {
        sourceKind == .video && FilmtoneVideoTimingPolicy.isSlow24Eligible(sourceFPS: videoNominalFrameRate)
    }

    var canExportVideo4K: Bool {
        sourceKind == .video
            && FilmtoneVideoExportResolution.isFourKCapable(displaySize: videoDisplaySize)
    }

    var resolvedVideoExportResolution: FilmtoneVideoExportResolution {
        videoExportResolution == .fourK && canExportVideo4K ? .fourK : .fhd
    }

    var videoExportOutputLongEdgeLimit: Double? {
        guard sourceKind == .video else { return nil }
        return resolvedVideoExportResolution.outputLongEdgeLimit
    }

    var videoDisplayDurationSeconds: Double? {
        videoTimingPolicy.displayDuration(sourceDuration: videoDurationSeconds)
    }

    var videoDisplayPreviewSeconds: Double? {
        guard let videoPreviewSeconds else { return nil }
        return videoTimingPolicy.displayTime(forSourceTime: videoPreviewSeconds)
    }

    var presetParams: FilmtonePhase0Params {
        FilmtoneGradeResolution.resolve(recipe: currentGradeRecipe).params
    }

    /// Flat (Veil + user) paramOverrides patch consumed by callers that
    /// don't go through `presetParams` — sidecar serialization,
    /// VideoCompositionRefreshKey hashing, and any non-Veil-aware
    /// resolved() callsite. Behavior here is unchanged from M5-M: Veil
    /// energy keys are intensity-scaled, structural keys pass through,
    /// user overrides win at full strength. The new max-merge semantics
    /// live exclusively in `FilmtonePresetCatalog.resolved()` so cache-key
    /// equality and sidecar payloads stay byte-stable.
    var renderParamOverrides: FilmtonePhase0ParamsPatch {
        FilmtoneOpticalFilterCatalog.renderParamOverrides(
            profileId: opticalFilterProfileId,
            intensity: opticalFilterIntensity,
            userOverrides: paramOverrides
        )
    }

    /// M5-C.3a: true when any legacy Quick axis carries a non-zero offset.
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
        FilmtoneGradeResolution.resolve(recipe: currentGradeRecipe).creativeLut
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

    func setSource(
        _ url: URL?,
        kind: FilmtoneSourceKind,
        importedCapturePackage: FilmtoneImportedCapturePackage? = nil
    ) {
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
        videoNominalFrameRate = nil
        videoDisplaySize = nil
        videoExportResolution = .fhd
        videoTimingMode = .normal
        if let url, kind == .video {
            highlightMarkers = FilmtoneSidecarWriter.readHighlightMarkers(matchingSourceURL: url)
        } else {
            highlightMarkers = nil
        }
        // M5-C.1: clear the previous probe's color class so the gate /
        // Picker resolved-Auto label don't misreport stale state until the
        // PreviewSurface re-probes the new source.
        probedSourceColorClass = nil
        sourceProfilePolicyAppliedURL = nil
        // M5-C.4: previous export's snapshot belonged to the previous
        // source — clear so the inspector returns to ready state for
        // the new source.
        lastExportResult = nil
        lastExportError = nil
        lastExportSummary = nil
        exportStartedAt = nil
        exportProgress = 0

        capturePackageProvenance = importedCapturePackage?.provenance
        packageCreativeLut = importedCapturePackage?.packageCreativeLut
        capturePackageCustomLutMissingReason = importedCapturePackage?.customLutMissingReason
        if let importedCapturePackage {
            sourceProfileSelection = importedCapturePackage.sourceProfileSelection
            presetName = FilmtonePresetCatalog.defaultName
            presetStrength = FilmtonePresetCatalog.presetStrengthDefault
            quickState = .zero
            paramOverrides = .empty
            if let slug = importedCapturePackage.selectedLookSlug {
                lookSlug = slug
                selectedSavedLookId = importedCapturePackage.selectedLookId
            } else {
                lookSlug = nil
                selectedSavedLookId = nil
            }
        }

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
            self.applyProbedSourceColorClass(session.probedColorClass, for: url)
            // Apply the playback rate the user previously selected before
            // a new source replaced the prior session.
            session.setTimingPolicy(self.videoTimingPolicy)
            session.setRate(self.playbackRate)
            session.onTimeUpdate = { [weak self] seconds in
                guard let self else { return }
                if self.isScrubbing { return }
                self.videoPreviewSeconds = seconds
            }
            session.onPlayingChange = { [weak self] playing in
                self?.isPlaying = playing
            }
            if let previewSeconds = self.videoPreviewSeconds,
               previewSeconds.isFinite,
               previewSeconds > 0,
               !session.isPlaying {
                session.seek(toSeconds: previewSeconds)
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
            gradeRecipe: currentGradeRecipe,
            sourceProfileSelection: sourceProfileSelection,
            probedColorClass: probedSourceColorClass,
            compareEnabled: isCompareEnabled,
            compareSplitFraction: compareSplitFraction,
            sourceURL: url ?? sourceURL ?? URL(fileURLWithPath: "/"),
            // M5-M (CC-B): grade identity and optical filter state are
            // captured in `currentGradeRecipe`; only probed camera optics
            // is session-owned and patched in below.
            cameraOptics: videoSession?.cameraOptics
        )
    }

    func applyProbedSourceColorClass(_ colorClass: SourceColorClassDTO?, for url: URL) {
        guard sourceURL == url else { return }
        probedSourceColorClass = colorClass
        guard sourceProfilePolicyAppliedURL != url else { return }
        sourceProfilePolicyAppliedURL = url

        let retained = FilmtoneSourceProfileCatalog.selectionAfterSourceChange(
            sourceProfileSelection,
            probedColorClass: colorClass
        )
        if retained != sourceProfileSelection {
            sourceProfileSelection = retained
        }
    }

    /// M5-J.2: flip the compare toggle. Toolbar disables the button when
    /// no source is loaded, so this is only called in a meaningful state;
    /// the value still flips for either source kind to keep the binding
    /// behavior simple.
    func toggleCompare() {
        isCompareEnabled.toggle()
    }

    /// M5-A.3: probes video duration off the main actor and seeds
    /// `videoPreviewSeconds = duration × 0.5` so the first preview frame
    /// after open matches the pre-M5-A.3 midpoint behavior. Failures are
    /// swallowed silently — the scrub bar simply stays hidden and
    /// `PreviewSurface` falls back to the legacy midpoint loader.
    private func startVideoDurationProbe(for url: URL) {
        currentDurationProbeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let videoProbe = try? await FilmtoneSourceProber.probeVideo(sourceURL: url)
            if let videoProbe,
               !Task.isCancelled,
               self.sourceURL == url {
                let displayRect = CGRect(origin: .zero, size: videoProbe.naturalSize)
                    .applying(videoProbe.preferredTransform)
                self.videoDisplaySize = CGSize(
                    width: abs(displayRect.width),
                    height: abs(displayRect.height)
                )
                if videoProbe.nominalFrameRate.isFinite,
                   videoProbe.nominalFrameRate > 0 {
                    self.videoNominalFrameRate = Double(videoProbe.nominalFrameRate)
                }
            }
            var probedDuration = videoProbe?.durationSeconds
            if probedDuration == nil {
                probedDuration = try? await FilmtoneVideoFramePreviewLoader.loadDurationSeconds(from: url)
            }
            guard !Task.isCancelled,
                  self.sourceURL == url,
                  let probedDuration,
                  probedDuration.isFinite,
                  probedDuration > 0 else {
                return
            }
            self.videoDurationSeconds = probedDuration
            let initialPreviewSeconds = probedDuration * 0.5
            self.videoPreviewSeconds = initialPreviewSeconds
            if let session = self.videoSession,
               !session.isPlaying,
               !self.isScrubbing {
                session.seek(toSeconds: initialPreviewSeconds)
            }
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

    func seekVideo(toDisplaySeconds seconds: Double) {
        let sourceSeconds = videoTimingPolicy.sourceTime(forDisplayTime: seconds)
        videoPreviewSeconds = sourceSeconds
        videoSession?.seek(toSeconds: sourceSeconds)
    }

    /// Update playback rate (1×/2×/3×). Stored on EditorState so the
    /// rate menu binding is stable across session rebuilds.
    func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
        videoSession?.setRate(rate)
    }

    func setVideoTimingMode(_ mode: FilmtoneVideoTimingMode) {
        let nextMode: FilmtoneVideoTimingMode = mode == .slow24 && canUseSlow24VideoTiming
            ? .slow24
            : .normal
        guard videoTimingMode != nextMode else { return }
        videoTimingMode = nextMode
        videoSession?.setTimingPolicy(videoTimingPolicy)
        videoSession?.setRate(playbackRate)
        lastExportResult = nil
        lastExportError = nil
    }

    func setVideoExportResolution(_ resolution: FilmtoneVideoExportResolution) {
        let nextResolution: FilmtoneVideoExportResolution = resolution == .fourK && canExportVideo4K
            ? .fourK
            : .fhd
        guard videoExportResolution != nextResolution else { return }
        videoExportResolution = nextResolution
        lastExportResult = nil
        lastExportError = nil
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

    var highlightMarkerList: [FilmtoneHighlightMarker] {
        highlightMarkers?.markers ?? []
    }

    var exportHighlightMarkers: FilmtoneHighlightMarkers? {
        guard let highlightMarkers, !highlightMarkers.isEmpty else {
            return nil
        }
        return highlightMarkers
    }

    var canCreateHighlightReel: Bool {
        guard sourceKind == .video,
              sourceURL != nil,
              !isExporting,
              sourceCapViolations.isEmpty,
              let segments = exportHighlightMarkers?.highlightReelSegments(),
              !segments.isEmpty else {
            return false
        }
        return true
    }

    func addHighlightMarker(at sourceTimeSec: Double) {
        guard sourceKind == .video,
              let sourceIdentity = currentMarkerSourceIdentity() else {
            return
        }
        let duration = videoDurationSeconds
        let clampedTime: Double
        if let duration, duration.isFinite, duration > 0 {
            clampedTime = min(max(sourceTimeSec, 0), duration)
        } else {
            clampedTime = max(sourceTimeSec, 0)
        }
        let current = highlightMarkers ?? FilmtoneHighlightMarkers(
            sourceIdentity: sourceIdentity,
            markers: []
        )
        if current.marker(near: clampedTime) != nil {
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let marker = FilmtoneHighlightMarker(
            id: "filmtone-marker-\(UUID().uuidString)",
            sourceTimeSec: clampedTime,
            sourceFps: sourceIdentity.fps,
            createdOnPlatform: "macos",
            createdAtIso: formatter.string(from: Date())
        )
        highlightMarkers = current.replacingOrAppending(marker)
        invalidateExportPackageState()
    }

    func removeHighlightMarker(id: String) {
        guard let current = highlightMarkers else {
            return
        }
        let remaining = current.markers.filter { $0.id != id }
        highlightMarkers = remaining.isEmpty
            ? nil
            : FilmtoneHighlightMarkers(
                schema: current.schema,
                sourceIdentity: current.sourceIdentity,
                defaults: current.defaults,
                markers: remaining
        )
        invalidateExportPackageState()
    }

    func jumpToHighlightMarker(id: String) {
        guard let marker = highlightMarkerList.first(where: { $0.id == id }) else {
            return
        }
        videoSession?.pause()
        isPlaying = false
        let duration = videoDurationSeconds
        let targetSeconds: Double
        if let duration, duration.isFinite, duration > 0 {
            targetSeconds = min(max(marker.sourceTimeSec, 0), duration)
        } else {
            targetSeconds = max(marker.sourceTimeSec, 0)
        }
        videoPreviewSeconds = targetSeconds
        seekVideo(toSeconds: targetSeconds)
    }

    func jumpToNextHighlightMarker() {
        let markers = sortedHighlightMarkerList()
        guard !markers.isEmpty else {
            return
        }
        let currentTime = videoPreviewSeconds ?? 0
        let nextThreshold = currentTime + 0.01
        let target = markers.first { $0.sourceTimeSec > nextThreshold } ?? markers[0]
        jumpToHighlightMarker(id: target.id)
    }

    func jumpToPreviousHighlightMarker() {
        let markers = sortedHighlightMarkerList()
        guard let lastMarker = markers.last else {
            return
        }
        let currentTime = videoPreviewSeconds ?? 0
        let previousThreshold = currentTime - 0.01
        let target = markers.last { $0.sourceTimeSec < previousThreshold } ?? lastMarker
        jumpToHighlightMarker(id: target.id)
    }

    private func sortedHighlightMarkerList() -> [FilmtoneHighlightMarker] {
        highlightMarkerList.sorted {
            if $0.sourceTimeSec == $1.sourceTimeSec {
                return $0.id < $1.id
            }
            return $0.sourceTimeSec < $1.sourceTimeSec
        }
    }

    private func currentMarkerSourceIdentity() -> FilmtoneMarkerSourceIdentity? {
        guard let sourceURL else {
            return nil
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = attributes?[.size] as? Int64
        return FilmtoneMarkerSourceIdentity(
            filename: sourceURL.lastPathComponent,
            durationSec: videoDurationSeconds,
            fps: FilmtoneHighlightMarker.validFPS(videoNominalFrameRate),
            fileSizeBytes: fileSize
        )
    }

    private func invalidateExportPackageState() {
        lastExportResult = nil
        lastExportError = nil
        lastExportSummary = nil
        exportProgress = 0
    }

    // MARK: - M5-C.4 Export inspector

    /// Single source-cap reason rendered as the inspector's blocked
    /// state. Mirrors iOS `store.sourceViolations` shape (array) so the
    /// View's ForEach can stay identical even if Desktop later surfaces
    /// multiple violations.
    var sourceCapViolations: [String] {
        guard sourceURL != nil else { return [] }
        var violations: [String] = []
        if let reason = FilmtoneSourceInputTransform.sourceCapReason(
            probedColorClass: probedSourceColorClass
        ),
           FilmtoneSourceInputTransform.sourceExceedsCapacity(
            selection: sourceProfileSelection,
            probedColorClass: probedSourceColorClass
           ) {
            violations.append(reason)
        }
        if let capturePackageCustomLutMissingReason {
            violations.append(capturePackageCustomLutMissingReason)
        }
        return violations
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
    /// nil binding clear the lookSlug. The visible editor now exposes
    /// direct Adjust parameters instead of Quick axes, so legacy saved
    /// Quick offsets are folded into `paramOverrides` on load.
    func applySavedLook(_ entry: SavedLookEntry) {
        packageCreativeLut = nil
        capturePackageCustomLutMissingReason = nil
        selectedImportedGradeId = nil
        selectedImportedGrade = nil
        selectedImportedGradeSidecarURL = nil
        selectedSavedLookId = entry.id
        presetName = entry.presetName
        presetStrength = entry.strength
        let bundledSlug = entry.creativeLut?.bundledSlug
        if let bundledSlug {
            lookSlug = bundledSlug
        } else {
            lookSlug = nil
        }
        quickState = .zero
        paramOverrides = Self.adjustPatchForAppliedSavedLook(
            entry,
            lookSlug: bundledSlug
        )
    }

    private static func adjustPatchForAppliedSavedLook(
        _ entry: SavedLookEntry,
        lookSlug: String?
    ) -> FilmtonePhase0ParamsPatch {
        if entry.bundled {
            return .empty
        }

        let zeroQuickBase = FilmtonePresetCatalog.resolved(
            presetName: entry.presetName,
            strength: entry.strength,
            lookSlug: lookSlug,
            quickState: .zero,
            paramOverrides: .empty
        )
        let savedVisibleParams = FilmtonePresetCatalog.resolved(
            presetName: entry.presetName,
            strength: entry.strength,
            lookSlug: lookSlug,
            quickState: entry.quickState.clamped(),
            paramOverrides: entry.paramOverrides
        )

        var values: [String: Double] = [:]
        for key in FilmtonePhase0Params.keyPaths.keys {
            let visible = AdvancedAdjustCatalog.clamp(savedVisibleParams.value(for: key), for: key)
            if abs(visible - zeroQuickBase.value(for: key)) >= AdvancedAdjustCatalog.paramEqualityTolerance {
                values[key] = visible
            }
        }
        return FilmtonePhase0ParamsPatch(values: values)
    }

    /// Reset the Look picker to "None". Mirrors what tapping the None
    /// row does — clears slug + selection. M5-C.3a: also drops live
    /// Quick state and paramOverrides back to defaults so the next
    /// Save isn't contaminated by a previous Look's offsets.
    func clearSavedLookSelection() {
        packageCreativeLut = nil
        capturePackageCustomLutMissingReason = nil
        selectedSavedLookId = nil
        selectedImportedGradeId = nil
        selectedImportedGrade = nil
        selectedImportedGradeSidecarURL = nil
        lookSlug = nil
        quickState = .zero
        paramOverrides = .empty
    }

    func applyImportedGrade(_ look: FilmtoneImportedGradeLook, sidecarURL: URL? = nil) {
        selectedImportedGradeId = look.id
        selectedImportedGrade = look
        selectedImportedGradeSidecarURL = sidecarURL
        selectedSavedLookId = nil
        lookSlug = nil
        presetName = FilmtonePresetCatalog.defaultName
        presetStrength = FilmtonePresetCatalog.presetStrengthDefault
        packageCreativeLut = nil
        capturePackageCustomLutMissingReason = nil
    }

    func clearImportedGradeSelection() {
        selectedImportedGradeId = nil
        selectedImportedGrade = nil
        selectedImportedGradeSidecarURL = nil
    }
}
