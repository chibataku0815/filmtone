import AVFoundation
import Combine
import CryptoKit
import FilmLabSwiftCore
import Foundation
import SwiftUI
import UIKit

enum FilmtoneSaveToPhotosState: String {
    case notRun = "not-run"
    case saved
    case failed
}

enum FilmtoneExportLocalAvailability {
    case none
    case available
    case removed
}

/// Lightweight, viewport-level transient notification model.
///
/// Lives next to `notice` / `error` (which are inline ScrollView panels) but is
/// rendered as a root-overlay toast in `FilmtoneRootView` so users notice
/// save / export / share feedback regardless of scroll position.
struct FilmtoneToast: Identifiable, Equatable {
    enum Kind: Equatable {
        case success
        case info
        case error
    }

    let id: UUID
    let kind: Kind
    let message: String
    let durationMs: Int

    init(
        id: UUID = UUID(),
        kind: Kind,
        message: String,
        durationMs: Int = 2500
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.durationMs = durationMs
    }
}

struct FilmtoneSourceLoadState {
    enum Stage {
        case importing
        case probing
    }

    let stage: Stage
    let route: FilmtoneSourcePickerRoute
    let message: String
    let progress: Double?
    let isDeterminate: Bool

    var clampedProgress: Double? {
        guard let progress, progress.isFinite, !progress.isNaN else {
            return nil
        }
        return max(0, min(1, progress))
    }
}

/// In-progress AVCaptureMovieFileOutput recording snapshot. Set by
/// `FilmtoneEditorStore.recordProductClip(durationSeconds:)` when the
/// capture call begins and cleared the moment it returns; nil at any
/// other time. The view uses `startedAt` against `TimelineView`'s tick
/// to compute the visible countdown. Capture surface itself is locked
/// to fixed-duration (M7 owner-locked design) — there is no stop
/// affordance in M8.
struct FilmtoneRecordingUIState: Equatable {
    let startedAt: Date
    let durationSeconds: Double
}


@MainActor
final class FilmtoneEditorStore: ObservableObject {
    @Published var project: FilmtoneProjectState
    @Published var source: SourceInfoDTO?
    @Published var probe: SourceProbeDTO?
    #if DEBUG
    @Published private var sourceAudioDebugLabel: String?
    private var sourceAudioDebugTask: Task<Void, Never>?
    #endif
    @Published var highlightMarkers: FilmtoneHighlightMarkers?
    @Published var sourceLoadState: FilmtoneSourceLoadState?
    @Published var isBusy = false
    @Published var notice: String?
    @Published var error: String?
    /// Set true when the user picks a video longer than the iOS source
    /// duration cap (`PHASE0_MAX_SOURCE_DURATION_SEC`, 300s). Surfaces a
    /// dedicated Desktop handoff sheet instead of routing the clip through
    /// the generic source-cap error so users get a clear path to Filmtone
    /// Desktop. Existing source / project state is preserved while this is
    /// set — the picker import is discarded by `reclaimCacheForCurrentState`.
    @Published var desktopHandoffPromptPresented = false
    /// Viewport-level transient toast. Coexists with `notice` / `error`
    /// (inline panels) so neither path is broken; toast surfaces save /
    /// export / share feedback above the ScrollView. Never set directly by
    /// callers — use ``presentToast(_:kind:durationMs:)`` instead.
    @Published var toast: FilmtoneToast?
    /// Mirror of the LUT library + Saved Looks. Refreshed after every actor
    /// mutation so SwiftUI redraws the Recent strip / Saved Looks chips
    /// without per-render disk reads.
    @Published var library: LibrarySnapshot = .empty
    /// Set when an `applySavedLook` mutation lands; cleared by every other
    /// project mutation. Read by the export pipeline so the sidecar can
    /// record which Saved Look produced the export. (Sidecar field-set is
    /// MVP-deferred — see Item 3 plan §"Sidecar V1 Additions".)
    ///
    /// `didSet` clears the project controller's cached entry when the id is
    /// reset to `nil`; non-nil assignments must also populate the cache at
    /// the apply site so M10 live preview
    /// (`makeLivePreviewGradeProcessor()`, synchronous) can read the
    /// resolved entry without async I/O.
    ///
    /// Phase 3B: writable from `EditorProjectMutationCoordinator` (internal
    /// access). Views still treat this as read-only — verified by grep that
    /// no view-side file writes to `store.appliedSavedLookId`.
    var appliedSavedLookId: UUID? {
        didSet {
            if appliedSavedLookId == nil {
                projectController.clearAppliedSavedLookEntry()
            }
        }
    }

    /// Backlight Veil Phase 1c — currently selected optical filter family id
    /// (e.g. `"backlightVeil-1-2"`) or nil = OFF. Mirrors
    /// `project.opticalFilterProfileId` for SwiftUI observation; render paths
    /// consume the persisted project value through `Phase0ExportRequestDTO`.
    @Published private(set) var selectedOpticalFilterId: String?
    /// Explicit video timing mode. Normal is the default; slow24 is enabled
    /// only for video sources with a probed frame rate above 24fps.
    @Published var videoTimingMode: FilmtoneVideoTimingMode = .normal

    let strings: FilmtoneStrings
    private let facade: FilmtoneEditorFacade
    private let projectController: EditorProjectController
    private let libraryController: EditorLibraryController
    let previewOrchestrator: EditorPreviewOrchestrator
    let projectMutationCoordinator: EditorProjectMutationCoordinator
    let exportCoordinator: EditorExportCoordinator
    let captureRelay: EditorCaptureRelay
    private var toastDismissTask: Task<Void, Never>?
    private var libraryBootstrapTask: Task<Void, Never>?
    private var previewCancellable: AnyCancellable?
    private var exportCancellable: AnyCancellable?
    private var captureRelayCancellable: AnyCancellable?

    var preview: FilmtonePreviewState {
        previewOrchestrator.preview
    }

    var comparePreviewFrame: FilmtoneComparePreviewFrame? {
        previewOrchestrator.comparePreviewFrame
    }

    var isCompareHeld: Bool {
        get { previewOrchestrator.isCompareHeld }
        set { previewOrchestrator.isCompareHeld = newValue }
    }

    // MARK: - Phase 3B export/cache forwards
    //
    // Forwarding so view code (`FilmtoneExportPanel`, `FilmtoneSourceProfileSheet`,
    // `FilmtoneSnapshotSupport`) keeps reading `store.exportResult` etc.
    // unchanged. `@Published` storage lives on `EditorExportCoordinator`; the
    // Combine `objectWillChange.sink` bridge in `init` re-emits its change
    // notifications through this store so SwiftUI redraws fire as before.

    var exportProgress: Phase0ExportProgressDTO? {
        get { exportCoordinator.exportProgress }
        set { exportCoordinator.exportProgress = newValue }
    }

    var exportResult: Phase0ExportResultDTO? {
        get { exportCoordinator.exportResult }
        set { exportCoordinator.exportResult = newValue }
    }

    var exportLocalAvailability: FilmtoneExportLocalAvailability {
        get { exportCoordinator.exportLocalAvailability }
        set { exportCoordinator.exportLocalAvailability = newValue }
    }

    var saveToPhotosState: FilmtoneSaveToPhotosState {
        get { exportCoordinator.saveToPhotosState }
        set { exportCoordinator.saveToPhotosState = newValue }
    }

    var isSavingToPhotos: Bool {
        get { exportCoordinator.isSavingToPhotos }
        set { exportCoordinator.isSavingToPhotos = newValue }
    }

    var cacheInventory: CacheInventoryDTO? {
        exportCoordinator.cacheInventory
    }

    var isReleasingCache: Bool {
        exportCoordinator.isReleasingCache
    }

    // MARK: - Phase 3C capture relay forwards
    //
    // Forwarding so view code (`FilmtoneRootView`'s recording overlay /
    // `.alert($recordingError)` Binding(get:set:)) and the export
    // coordinator (`store.lastCapturePackage`) keep their existing access
    // paths. `@Published` storage lives on `EditorCaptureRelay`; the
    // Combine `objectWillChange.sink` bridge in `init` re-emits its change
    // notifications through this store so SwiftUI redraws fire as before.

    /// Live during the AVCaptureMovieFileOutput phase of `recordProductClip`
    /// only. Drives the recording-in-progress overlay (ring + countdown +
    /// label) in `FilmtoneRootView`. Cleared the moment capture returns —
    /// the post-capture probe / applyProbe phase is covered by
    /// `sourceLoadState` instead.
    var recordingState: FilmtoneRecordingUIState? {
        captureRelay.recordingState
    }

    /// Localized detail of the most recent product-capture failure. Bound
    /// to a `.alert` in `FilmtoneRootView`; cleared when the user dismisses
    /// the alert or starts a new recording. Distinct from the generic
    /// `error` bag so the recording surface alert never picks up
    /// pickSource / export / library errors.
    var recordingError: String? {
        get { captureRelay.recordingError }
        set { captureRelay.recordingError = newValue }
    }

    #if os(iOS)
    /// Most-recent native capture surface (M10) result. Holds master /
    /// proxy URLs and the storage policy that produced them. The editor is
    /// editing the proxy after `adoptCaptureResult(_:)`; the master stays
    /// on the security-scoped external folder (or in the local package
    /// directory for internal mode) and is reachable through this property
    /// when downstream operations need it.
    var lastCapturePackage: FilmtoneCapturePackage? {
        captureRelay.lastCapturePackage
    }

    /// Local filesystem path to the `capture-package.json` written by the
    /// M10 capture pipeline alongside the proxy. Persisted on the editor
    /// snapshot so a relaunch can re-hydrate `lastCapturePackage` without
    /// depending on a future "reconnect SSD" walkthrough. Decoupled from
    /// `SourceInfoDTO` so the source identity remains a pure media-input
    /// concept (B-anchor per M10 review, 2026-05-08).
    var currentCapturePackageRef: String? {
        captureRelay.currentCapturePackageRef
    }
    #endif

    init(
        facade: FilmtoneEditorFacade,
        strings: FilmtoneStrings = FilmtoneStringsCatalog.current,
        libraryStore: LibraryStoreActor? = nil
    ) {
        self.facade = facade
        self.strings = strings
        let projectController = EditorProjectController()
        self.projectController = projectController
        // Fall back to a library-disabled mode if Application Support is not
        // reachable — the editor still works, the Recent / Saved-Looks UI
        // simply stays empty. We do not hard-fail bootstrap.
        let resolvedLibraryStore = libraryStore ?? (try? LibraryStoreActor())
        let libraryController = EditorLibraryController(libraryStore: resolvedLibraryStore)
        self.libraryController = libraryController
        self.previewOrchestrator = EditorPreviewOrchestrator(facade: facade, strings: strings)
        self.projectMutationCoordinator = EditorProjectMutationCoordinator(
            facade: facade,
            libraryController: libraryController,
            projectController: projectController,
            strings: strings
        )
        self.exportCoordinator = EditorExportCoordinator(
            facade: facade,
            projectController: projectController,
            libraryController: libraryController,
            strings: strings
        )
        self.captureRelay = EditorCaptureRelay(
            facade: facade,
            libraryController: libraryController,
            projectController: projectController,
            strings: strings
        )

        let snapshotCaptureRef: String?
        if let snapshot = FilmtonePersistence.load() {
            self.project = snapshot.project
            self.source = snapshot.source
            self.probe = snapshot.probe
            snapshotCaptureRef = snapshot.currentCapturePackageRef
        } else {
            self.project = FilmtonePhase0Math.createProjectState()
            self.source = nil
            self.probe = nil
            snapshotCaptureRef = nil
        }
        self.selectedOpticalFilterId = self.project.opticalFilterProfileId

        #if os(iOS)
        captureRelay.rehydrate(currentCapturePackageRef: snapshotCaptureRef)
        #endif

        if let source, !facade.fileExists(uri: source.uri) {
            self.source = nil
            self.probe = nil
            #if os(iOS)
            captureRelay.clearLinkage()
            #endif
            persist()
        }

        #if DEBUG
        refreshSourceAudioDebugLabel(for: source)
        #endif

        if let source {
            facade.prewarmMezzanines(for: source)
        }

        reclaimCacheForCurrentState()

        previewOrchestrator.attach(self)
        previewCancellable = previewOrchestrator.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
        projectMutationCoordinator.attach(self)
        exportCoordinator.attach(self)
        exportCancellable = exportCoordinator.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
        captureRelay.attach(self)
        captureRelayCancellable = captureRelay.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }

        // M1A visible-pass correction: persisted projects can carry an old
        // baked Pack 01 overlay from a prior build. Re-resolve once at launch
        // so installing a stronger catalog / Look Director actually reaches
        // the current preview/export state without requiring the owner to
        // re-tap Stone or swap sources.
        let refreshedCreativePack01OnLaunch = refreshCreativePack01AdaptationIfApplicable()

        if self.source != nil {
            if !refreshedCreativePack01OnLaunch {
                schedulePreviewRender()
            }
        }

        bootstrapLibraryAsync()
    }

    deinit {
        toastDismissTask?.cancel()
        libraryBootstrapTask?.cancel()
        #if DEBUG
        sourceAudioDebugTask?.cancel()
        #endif
    }

    private func bootstrapLibraryAsync() {
        guard libraryController.isAvailable else {
            return
        }
        libraryBootstrapTask?.cancel()
        libraryBootstrapTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.library = await self.libraryController.loadOrRebuildSnapshot()
        }
    }

    func refreshLibrarySnapshot() async {
        guard let snapshot = await libraryController.snapshot() else {
            return
        }
        self.library = snapshot
    }

    var sourceLabel: String? {
        source?.filename
    }

    var canUseLocalExport: Bool {
        exportResult != nil && exportLocalAvailability == .available
    }

    var activePresetLabel: String {
        FilmtonePresetCatalog.descriptor(named: project.presetName)?.label ?? project.presetName
    }

    var selectedPreviewURI: String? {
        previewOrchestrator.selectedPreviewURI
    }

    var videoPreviewState: FilmtoneVideoPreviewState? {
        previewOrchestrator.videoPreviewState
    }

    var sourceVideoFPS: Double? {
        FilmtoneVideoTimingPolicy.validFPS(
            probe?.frameRate ?? probe?.sourceVideoMetadata?.timing?.nominalFrameRate
        )
    }

    var videoTimingPolicy: FilmtoneVideoTimingPolicy {
        FilmtoneVideoTimingPolicy(
            mode: videoTimingMode,
            sourceFPS: sourceVideoFPS
        )
    }

    var resolvedVideoTimingMode: FilmtoneVideoTimingMode {
        videoTimingPolicy.resolvedMode
    }

    var canUseSlow24VideoTiming: Bool {
        source?.kind == .video && FilmtoneVideoTimingPolicy.isSlow24Eligible(sourceFPS: sourceVideoFPS)
    }

    var highlightMarkerList: [FilmtoneHighlightMarker] {
        highlightMarkers?.markers ?? []
    }

    var canCreateHighlightReel: Bool {
        guard source?.kind == .video,
              sourceViolations.isEmpty,
              !isBusy,
              !isSavingToPhotos,
              let segments = exportHighlightMarkers?.highlightReelSegments() else {
            return false
        }
        return !segments.isEmpty
    }

    var previewError: String? {
        previewOrchestrator.previewError
    }

    /// Param keys surfaced through the Adjust ("調整") quick section. Slider
    /// edits there write these directly into `paramOverrides`; the Advanced
    /// section's "基本" group exposes the same keys plus extras at full kernel
    /// range. Splitting them lets the two disclosure sections each report
    /// their own activity state without double-counting.
    private static let quickParamKeys: Set<String> = ["exposure", "contrast", "saturation"]

    private func quickDelta(for key: String) -> Double {
        let raw = project.params.value(for: key)
        return key == "exposure" ? raw : raw - 1.0
    }

    var quickSummaryText: String {
        let entries: [(label: String, key: String)] = [
            (strings.quickFilmCharacter, "exposure"),
            (strings.quickEra, "contrast"),
            (strings.quickDynamics, "saturation"),
        ]
        .filter { project.paramOverrides.values[$0.key] != nil }

        if entries.isEmpty {
            return ""
        }

        return entries
            .map { "\($0.label) \(Self.signedPercentLabel(for: quickDelta(for: $0.key)))" }
            .joined(separator: " · ")
    }

    var hasQuickAdjustments: Bool {
        Self.quickParamKeys.contains { project.paramOverrides.values[$0] != nil }
    }

    var hasAdvancedAdjustments: Bool {
        project.paramOverrides.values.contains { !Self.quickParamKeys.contains($0.key) }
    }

    var hasAnyAdjustments: Bool {
        !project.paramOverrides.isEmpty
    }

    var hasPresetCustomValues: Bool {
        abs(project.strength - FilmtonePhase0Math.presetStrengthDefault) >= FilmtonePhase0Math.paramEqualityTolerance ||
            !project.paramOverrides.isEmpty ||
            abs(project.quickState.filmCharacter) >= FilmtonePhase0Math.paramEqualityTolerance ||
            abs(project.quickState.era) >= FilmtonePhase0Math.paramEqualityTolerance ||
            abs(project.quickState.dynamics) >= FilmtonePhase0Math.paramEqualityTolerance
    }

    var advancedSummaryText: String {
        hasAdvancedAdjustments ? strings.advancedAdjustmentsActive : strings.advancedParamsHint
    }

    var adjustmentSummaryText: String {
        if hasQuickAdjustments && hasAdvancedAdjustments {
            return "\(quickSummaryText) · \(strings.advancedAdjustmentsActive)"
        }

        if hasQuickAdjustments {
            return quickSummaryText
        }

        if hasAdvancedAdjustments {
            return strings.advancedAdjustmentsActive
        }

        return ""
    }

    var previewMetaLabel: String? {
        let width = preview.width ?? probe?.width
        let height = preview.height ?? probe?.height
        let dimensions: String? = {
            if let width, let height {
                return "\(width)×\(height)"
            }
            return nil
        }()

        let timing: String? = {
            if let durationSec = preview.durationSec ?? probe?.durationSec {
                return strings.compactDurationLabel(durationSec)
            }
            return preview.posterTimeSec.map(strings.compactDurationLabel)
        }()

        #if DEBUG
        let audioDebug = sourceAudioDebugLabel
        #else
        let audioDebug: String? = nil
        #endif

        return [dimensions, timing, cameraOpticsLabel, audioDebug]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfEmpty
    }

    #if DEBUG
    private func refreshSourceAudioDebugLabel(for source: SourceInfoDTO?) {
        sourceAudioDebugTask?.cancel()
        sourceAudioDebugLabel = nil
        guard let source else {
            return
        }

        let isVideo = source.kind == .video
        let filename = source.filename
        let sourceURI = source.uri
        sourceAudioDebugTask = Task { @MainActor [weak self] in
            let label = await Self.makeSourceAudioDebugLabel(
                isVideo: isVideo,
                sourceURI: sourceURI
            )
            guard !Task.isCancelled else {
                return
            }
            self?.sourceAudioDebugLabel = label
            NSLog("[FilmtoneAudioDebug] editor source=\(filename) \(label ?? "audio unavailable") uri=\(sourceURI)")
        }
    }

    private static func makeSourceAudioDebugLabel(
        isVideo: Bool,
        sourceURI: String
    ) async -> String? {
        guard isVideo,
              let sourceURL = URL(string: sourceURI),
              sourceURL.isFileURL
        else {
            return nil
        }

        do {
            let audioTrackCount = try await AVURLAsset(url: sourceURL)
                .loadTracks(withMediaType: .audio)
                .count
            return "audio \(audioTrackCount)"
        } catch {
            return "audio unreadable"
        }
    }
    #endif

    var sourceViolations: [String] {
        FilmtonePhase0Math.sourceCapViolations(for: probe)
    }

    var cameraProfileLabel: String {
        if project.inputLut != nil {
            return strings.cameraCustom
        }
        // v1.3 Camera Profiles Phase F — when the user explicitly picked a
        // built-in source profile, surface that name. `.auto` falls through
        // to the existing detection-suffix logic so iPhone Apple Log /
        // Apple Log 2 sources still surface "Auto -> ... detected".
        switch project.cameraProfile {
        case .builtIn(let catalogId):
            if let name = strings.builtInSourceProfileName(for: catalogId) {
                return name
            }
            return strings.cameraAuto
        case .userImport:
            return strings.cameraCustom
        case .auto:
            switch probe?.inputTransformPolicy?.strategy ?? probe?.sourceVideoMetadata?.inputTransformPolicy?.strategy {
            case .appleLogToRec709:
                return strings.cameraAutoAppleLogDetected
            case .appleLog2ToRec709:
                return strings.cameraAutoAppleLog2Detected
            default:
                return strings.cameraAuto
            }
        }
    }

    // MARK: - v1.3 Camera Profiles Phase F (D-CP4 retention rule)

    /// Apply a Camera Profile selection from the picker. Marks the project
    /// state dirty + reschedules preview / persists. Mirrors the surface
    /// of `clearInputLut()` so SwiftUI's Menu callbacks compose cleanly.
    func applyCameraProfile(_ selection: CameraProfileSelection) {
        guard project.cameraProfile != selection else { return }
        project.cameraProfile = selection
        // The Camera Profile changes how the source is normalized; any
        // user-imported `.cube` was implicitly chosen against the prior
        // profile, so swapping profiles clears it (mirrors source-change
        // rule below). The Saved Look stays applied — looks are
        // source-independent (see Item 3 contract).
        project.inputLut = nil
        project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        // M1 Max Quality Look Director — Camera Profile is one half of
        // the adaptation input. Re-resolve so a Pack 01 Look picks up
        // the new sourceProfileId / sourceDetailBias signals. When the
        // refresher mutates state it already persists + schedules a
        // render, so we skip the redundant calls below.
        if !refreshCreativePack01AdaptationIfApplicable() {
            persist()
            schedulePreviewRender()
        }
    }

    /// D-CP4 retention rule on source change. Called from `applyProbe`.
    ///
    /// - `.auto`: always re-derives at export time, no state change here.
    /// - `.builtIn(.appleLog | .appleLog2)`: if the new probe's color class
    ///   doesn't match the selection, fall back to `.auto` and surface a
    ///   toast — the user picked a profile that the new clip can't honor.
    /// - `.builtIn(.arriLogC3 | .djiDLog | .djiDLogM | .canonCLog | .canonLog3CinemaGamut | .panasonicVLog | .sonySLog3 | .rec709)`:
    ///   persist (cannot be auto-detected from container metadata, so the
    ///   user's prior pick stays sticky across source swaps).
    /// - `.userImport`: the existing inputLut clear rule above already
    ///   wipes the user-imported `.cube`; we reset to `.auto` here for
    ///   consistency.
    private func applyCameraProfileSourceChangeRule(probe: SourceProbeDTO) {
        switch project.cameraProfile {
        case .auto:
            return
        case .builtIn(let catalogId):
            guard let entry = FilmtoneSourceProfileCatalog.entry(forCatalogId: catalogId) else {
                project.cameraProfile = .auto
                return
            }
            // Sticky cases first — ARRI LogC3, D-Log, D-Log M, C-Log,
            // C-Log 3 + Cinema Gamut, V-Log, S-Log3, Rec.709 cannot be
            // auto-detected, so persist them across swaps.
            if entry.detectionHint == nil {
                return
            }
            // Apple Log / Apple Log 2 — verify the new probe matches the
            // selection. If it doesn't, fall back to .auto so the new clip
            // is normalized correctly.
            if probe.sourceVideoMetadata?.colorClass == entry.detectionHint {
                return
            }
            project.cameraProfile = .auto
            presentToast(strings.cameraAuto, kind: .info)
        case .userImport:
            // The matching `inputLut` clear rule below resets the import
            // anyway; reset the selection so the picker doesn't keep the
            // user-import label after the .cube is gone.
            project.cameraProfile = .auto
        }
    }

    var lookProfileLabel: String {
        guard let creativeLut = project.creativeLut else {
            return strings.lookFilmtone
        }

        return creativeLut.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? strings.lookCustom
    }

    /// Live capture preview grade applier (M10 / S8-F F3).
    ///
    /// Build a `FilmtoneSharedGradeProcessor` pinned to the editor's
    /// current request + source URL so the capture surface can apply
    /// byte-parity grading to live VDO frames.  Returns `nil` when:
    ///
    /// - no source is loaded (entering capture from empty state — there
    ///   is nothing for the grade chain to anchor its stable seed
    ///   against, and the look-reference panel will already be hidden
    ///   for the same reason in S8-D),
    /// - the request DTO can't be built (probe / project state in an
    ///   intermediate edit), or
    /// - the runtime can't open the source URL (deleted / unreachable).
    ///
    /// Failure is silent — the live preview falls back to ungraded
    /// pass-through, which matches the F2 behavior the user already
    /// validated.  This is `feedback_no_fallback_bug_hotbed`-compatible
    /// because the absence of grading on the live preview is never
    /// confused with a successful grade: the surface displays without
    /// the user thinking "the export will look like this," because
    /// captured masters still go through the editor on adopt and the
    /// editor reapplies the canonical grade for export.
    func makeLivePreviewGradeProcessor() -> FilmtoneLivePreviewBundle? {
        guard source != nil else { return nil }
        do {
            let request = try FilmtonePhase0Math.buildExportRequest(
                source: source,
                probe: probe,
                project: project
            )
            // F3-Fix #1: forward Saved Look entry + camera profile so the
            // live preview's `FilmtoneExportSession` matches the export
            // path's input-LUT auto-injection and Saved Look provenance.
            // Saved Look entry is read sync from `projectController.appliedSavedLookEntryCache`,
            // populated at the two apply paths (`saveLookFromCurrentState` /
            // `applySavedLook`); the export path uses the async resolver,
            // but live preview cannot await without restructuring the
            // fullScreenCover capture path.
            let savedLookEntry = projectController.appliedSavedLookEntryCache
            let cameraProfile = project.cameraProfile
            let processor = try facade.makeLivePreviewGradeProcessor(
                request: request,
                appliedSavedLook: savedLookEntry,
                cameraProfile: cameraProfile
            )
            let diagnostics = makeLivePreviewDiagnostics(
                request: request,
                forwardedSavedLook: savedLookEntry,
                forwardedCameraProfile: cameraProfile
            )
            return FilmtoneLivePreviewBundle(
                processor: processor,
                diagnostics: diagnostics
            )
        } catch {
            return nil
        }
    }

    /// M11 / S11-C: live capture preview with a chip-strip override.
    ///
    /// `nil` defers to the argument-less variant — the chip-strip's
    /// "Filmtone" entry maps to nil so tapping it shows the editor's
    /// current pre-capture grade (custom adjustments, applied saved
    /// Look, etc.) without forcing a reset to a clean baseline.
    ///
    /// A non-nil built-in (Stone / Urban) builds a transient
    /// `FilmtoneProjectState` carrying the catalog entry's
    /// `presetName` / `strength` / `quickState` / `paramOverrides` /
    /// `creativeLut` and forwards the materialized `SavedLookEntry` so
    /// `FilmtoneSharedGradeProcessor` runs the same 3-layer wiring
    /// (`appliedSavedLook` + camera profile) the export path uses.
    ///
    /// The store's persisted state is intentionally untouched —
    /// capture-time chip changes only mutate the editor on
    /// `adoptCaptureResult` (S11-E).  Cancelling capture leaves the
    /// editor's pre-capture Look intact (M11 cancel-preservation).
    func makeLivePreviewGradeProcessor(
        overridingBuiltInLook builtIn: FilmtoneBuiltInCatalog.BuiltInLook?
    ) -> FilmtoneLivePreviewBundle? {
        guard let builtIn else {
            return makeLivePreviewGradeProcessor()
        }
        // Cold-start capture surface: the editor has no loaded source
        // yet (owner walked into capture before picking / recording),
        // but the live VDO frames are well-known by the M10 contract
        // — 4K24 ProRes 422 HQ Apple Log 2.  Synthesize a source +
        // probe describing exactly that stream so the chip-strip's
        // Stone / Urban grade chain can still be built and applied to
        // the live preview without forcing a record-first round trip.
        // The Filmtone default chip path (`builtIn == nil` above)
        // intentionally keeps the original nil-return because that
        // chip means "no Look applied" — falling back to raw camera
        // is the correct semantic there.
        let effectiveSource: SourceInfoDTO
        let effectiveProbe: SourceProbeDTO?
        if let source {
            effectiveSource = source
            effectiveProbe = probe
        } else {
            let synthetic = Self.liveCaptureSyntheticSource()
            effectiveSource = synthetic.source
            effectiveProbe = synthetic.probe
        }
        do {
            var transient = project
            transient.presetName = FilmtonePhase0Math.safePresetName(builtIn.presetName)
            transient.presetVersion = FilmtonePhase0Math.presetVersion
            transient.strength = FilmtonePhase0Math.clampStrength(builtIn.strength)
            transient.quickState = builtIn.quickState.clamped()

            var paramOverrides = builtIn.paramOverrides
            var resolvedCreativeLut: ParsedCubeLutDTO?
            let sourceProfileId = FilmtoneLookDirector.sourceProfileId(
                for: project.cameraProfile
            )
            let sourceColorClassRaw = FilmtoneLookDirector.sourceColorClassRaw(
                probe: effectiveProbe
            )
            resolvedCreativeLut = FilmtoneEditorStore.loadBundledCreativeLut(
                binding: FilmtoneBuiltInCatalog.creativeLutBinding(
                    for: builtIn,
                    sourceProfileId: sourceProfileId,
                    sourceColorClassRaw: sourceColorClassRaw
                ),
                packId: builtIn.packId ?? FilmtoneBuiltInCatalog.creativePack01Id
            )
            if let adaptation = FilmtoneCreativePack01Adaptation.resolve(
                slug: builtIn.slug,
                descriptor: effectiveProbe?.sourceToneDescriptor,
                sourceProfileId: sourceProfileId,
                sourceDetailBias: FilmtoneLookDirector.resolveSourceDetailBias(
                    probe: effectiveProbe,
                    cameraProfile: project.cameraProfile
                ),
                sourceColorClassRaw: sourceColorClassRaw
            ) {
                for (key, value) in adaptation.paramOverrides.values {
                    paramOverrides.values[key] = value
                }
                if let cube = resolvedCreativeLut {
                    resolvedCreativeLut = cube.withIntensity(adaptation.intensity)
                }
            }
            transient.paramOverrides = paramOverrides
            let base = FilmtonePhase0Math.deriveParams(
                presetName: transient.presetName,
                strength: transient.strength,
                quickState: transient.quickState
            )
            transient.params = base.applyingPatch(paramOverrides)
            transient.creativeLut = resolvedCreativeLut

            let request = try FilmtonePhase0Math.buildExportRequest(
                source: effectiveSource,
                probe: effectiveProbe,
                project: transient
            )
            let savedLookEntry = FilmtoneBuiltInCatalog.materializeAsSavedLookEntry(
                builtIn,
                favoriteOverride: false,
                asOf: Date()
            )
            let cameraProfile = project.cameraProfile
            let processor = try facade.makeLivePreviewGradeProcessor(
                request: request,
                appliedSavedLook: savedLookEntry,
                cameraProfile: cameraProfile
            )
            let diagnostics = makeLivePreviewDiagnostics(
                request: request,
                forwardedSavedLook: savedLookEntry,
                forwardedCameraProfile: cameraProfile
            )
            return FilmtoneLivePreviewBundle(
                processor: processor,
                diagnostics: diagnostics
            )
        } catch {
            return nil
        }
    }

    /// S7: live capture preview for an owner-imported creative LUT.
    /// The LUT is treated as a creative Look LUT; source conversion
    /// remains app-owned through the synthetic Apple Log 2 capture
    /// source / probe when capture starts without an editor source.
    func makeLivePreviewGradeProcessor(
        captureCreativeLut lut: ParsedCubeLutDTO
    ) -> FilmtoneLivePreviewBundle? {
        let effectiveSource: SourceInfoDTO
        let effectiveProbe: SourceProbeDTO?
        if let source {
            effectiveSource = source
            effectiveProbe = probe
        } else {
            let synthetic = Self.liveCaptureSyntheticSource()
            effectiveSource = synthetic.source
            effectiveProbe = synthetic.probe
        }
        do {
            var transient = project
            transient.creativeLut = lut
            let request = try FilmtonePhase0Math.buildExportRequest(
                source: effectiveSource,
                probe: effectiveProbe,
                project: transient
            )
            let cameraProfile = project.cameraProfile
            let processor = try facade.makeLivePreviewGradeProcessor(
                request: request,
                appliedSavedLook: nil,
                cameraProfile: cameraProfile
            )
            let diagnostics = makeLivePreviewDiagnostics(
                request: request,
                forwardedSavedLook: nil,
                forwardedCameraProfile: cameraProfile
            )
            return FilmtoneLivePreviewBundle(
                processor: processor,
                diagnostics: diagnostics
            )
        } catch {
            return nil
        }
    }

    /// S3 take-picker preview: build a lightweight processor against the
    /// recorded proxy itself, then apply the capture-time Look metadata to
    /// thumbnail samples. This keeps the chooser visually aligned with the
    /// editor adoption path without putting AVPlayers in every take row.
    #if os(iOS)
    func makeCapturePackagePreviewGradeProcessor(
        _ package: FilmtoneCapturePackage
    ) async -> FilmtoneSharedGradeProcessor? {
        await captureRelay.makeCapturePackagePreviewGradeProcessor(package)
    }
    #endif

    /// Source / probe descriptor for the live capture VDO stream when
    /// the editor has no loaded source (cold-start chip preview).
    ///
    /// Hard-coded against the M10 capture contract — the live VDO
    /// frames are guaranteed to be 4K24 ProRes 422 HQ Apple Log 2 by
    /// `FilmtoneCaptureSession.prepare(lens:)` (locked codec + Apple
    /// Log 2 colorSpace + 24fps device format), so the descriptor can
    /// be a static fixture instead of probing at runtime.  The grade
    /// chain only needs `inputTransformPolicy.strategy =
    /// .appleLog2ToRec709` to wire the correct input LUT — every
    /// other field is filled in to a defensible default so
    /// `Phase0ExportRequestDTO` and downstream sidecar/diagnostic
    /// readers don't trip on nil branches that never fire for real
    /// editor sources.  The placeholder uri uses a `file://` scheme
    /// (not a custom `filmtone://`) because `FilmtoneMediaRuntime.
    /// resolveFileURL` returns any URL whose `isFileURL == true`
    /// directly without an existence check — and the
    /// `FilmtoneSharedGradeProcessor.applyForLivePreview` path never
    /// reads from disk (frames come from the live VDO sink), so the
    /// path itself is irrelevant.  A custom scheme would throw inside
    /// `resolveFileURL` and silently nil out the chip preview.
    private static func liveCaptureSyntheticSource() -> (
        source: SourceInfoDTO,
        probe: SourceProbeDTO
    ) {
        let inputPolicy = SourceInputTransformPolicyDTO(
            strategy: .appleLog2ToRec709,
            reason: "source-is-apple-log2",
            requiresFixtureValidation: false,
            warning: nil
        )
        let display = SourceDisplayGeometryDTO(
            rawWidth: 3840,
            rawHeight: 2160,
            displayWidth: 3840,
            displayHeight: 2160,
            rotationDeg: 0,
            source: "raw"
        )
        let color = SourceColorMetadataDTO(
            colorRange: "tv",
            colorSpace: "bt2020nc",
            colorTransfer: "smpte2084",
            colorPrimaries: "bt2020",
            logTransferFunction: .appleLog2,
            hasMasteringDisplayMetadata: false,
            hasContentLightMetadata: false
        )
        let videoMetadata = SourceVideoMetadataDTO(
            display: display,
            color: color,
            colorClass: .appleLog2,
            hdrPreparationPolicy: nil,
            timing: SourceVideoTimingMetadataDTO(
                nominalFrameRate: 24.0,
                estimatedFrameRate: nil,
                sourceFrameRateTrusted: true,
                trustReason: "nominal-only"
            ),
            codecFamily: .prores422,
            logTransferFunction: .appleLog2,
            inputTransformPolicy: inputPolicy
        )
        let probe = SourceProbeDTO(
            uri: "file:///filmtone-capture-live-preview.mov",
            filename: "capture-live-preview.mov",
            kind: .video,
            mimeType: "video/quicktime",
            width: 3840,
            height: 2160,
            durationSec: 0,
            fileSizeBytes: 0,
            codec: "apch",
            codecFamily: .prores422,
            frameRate: 24.0,
            logTransferFunction: .appleLog2,
            inputTransformPolicy: inputPolicy,
            cameraOptics: nil,
            sourceVideoMetadata: videoMetadata,
            sourceToneDescriptor: nil
        )
        let source = SourceInfoDTO(
            uri: "file:///filmtone-capture-live-preview.mov",
            filename: "capture-live-preview.mov",
            kind: .video,
            mimeType: "video/quicktime",
            mezzanineStatus: nil,
            hasDepth: false
        )
        return (source, probe)
    }

    /// S8-F F3-R / F3-Fix #1: snapshot the editor's grade chain inputs
    /// at the moment the capture surface presents.
    ///
    /// `forwardedSavedLook` / `forwardedCameraProfile` are the values
    /// actually handed to `facade.makeLivePreviewGradeProcessor` —
    /// reflecting whether the wiring carried them through (post-fix:
    /// always `true` for camera profile; `true` for Saved Look iff one
    /// is currently applied and its entry resolved into the cache).
    /// Pre-fix these were hard-coded `false`; the chip's red `[!]
    /// camProf:N savedLook:N` warning was the F3-R wiring-gap signal.
    private func makeLivePreviewDiagnostics(
        request: Phase0ExportRequestDTO,
        forwardedSavedLook: SavedLookEntry?,
        forwardedCameraProfile: CameraProfileSelection?
    ) -> FilmtoneLivePreviewDiagnostics {
        let creative = request.creativeLut
        // Mirrors the input-LUT selection inside
        // `ExportInputLutBuilder.makeActiveInputLut(for:probe:)`: explicit
        // built-in Camera Profiles use the catalog, while Auto falls back
        // to the probe's native inputTransformPolicy.
        let detectedTransform =
            probe?.inputTransformPolicy?.strategy.rawValue
            ?? probe?.sourceVideoMetadata?.inputTransformPolicy?.strategy.rawValue

        let inputLutWillApply: Bool = {
            if request.inputLut != nil { return true }
            if case .builtIn(let catalogId) = forwardedCameraProfile,
               let entry = FilmtoneSourceProfileCatalog.entry(forCatalogId: catalogId) {
                switch entry.impl {
                case .nilProfile:
                    return false
                case .nativePolicy, .synthesized, .bundledCube:
                    return true
                }
            }
            switch detectedTransform {
            case "appleLogToRec709", "appleLog2ToRec709":
                return true
            default:
                return false
            }
        }()

        let savedLookIdShort: String? = appliedSavedLookId.map {
            String($0.uuidString.prefix(8).lowercased())
        }

        return FilmtoneLivePreviewDiagnostics(
            lookLabel: lookProfileLabel,
            creativeLutPresent: creative != nil,
            creativeLutSize: creative?.size,
            creativeLutIntensity: creative?.intensity,
            creativeLutBundledSlug: creative?.bundledSlug,
            cameraProfileLabel: cameraProfileLabel,
            cameraProfilePassedToProcessor: forwardedCameraProfile != nil,
            savedLookId: savedLookIdShort,
            savedLookPassedToProcessor: forwardedSavedLook != nil,
            detectedInputTransform: detectedTransform,
            inputLutWillApply: inputLutWillApply,
            presetVersion: request.grade.presetVersion,
            exposure: request.grade.params.exposure,
            contrast: request.grade.params.contrast,
            saturation: request.grade.params.saturation,
            temperature: request.grade.params.temperature
        )
    }

    /// Current HDR preparation policy derived from the active source probe.
    ///
    /// Field path: `probe?.sourceVideoMetadata?.hdrPreparationPolicy`.
    /// Refreshes automatically whenever `probe` is reassigned (SwiftUI picks
    /// it up via the `@Published probe` publisher; no separate publisher is
    /// needed).
    var hdrPolicy: HdrPreparationPolicyDTO? {
        probe?.sourceVideoMetadata?.hdrPreparationPolicy
    }

    /// Compact optics label for preview / export chips.
    /// Returns `nil` when no optics metadata is available.
    var cameraOpticsLabel: String? {
        FilmtoneCameraOpticsFormatter.formatCompact(probe?.cameraOptics, strings: strings)
    }

    /// Accessibility-friendly optics label for VoiceOver.
    var cameraOpticsAccessibilityLabel: String? {
        FilmtoneCameraOpticsFormatter.formatAccessibility(probe?.cameraOptics, strings: strings)
    }

    var bannerError: String? {
        if let error {
            return error
        }

        guard sourceViolations.isEmpty else {
            return nil
        }

        return preview.error
    }

    func effectiveParamValue(for key: String) -> Double {
        project.params.value(for: key)
    }

    func baseParamsForCurrentAdjustments() -> FilmtonePhase0Params {
        FilmtonePhase0Math.deriveParams(
            presetName: project.presetName,
            strength: project.strength,
            quickState: project.quickState
        )
    }

    func isParamOverridden(_ key: String) -> Bool {
        project.paramOverrides.values[key] != nil
    }

    func attachPresenter(_ presenter: UIViewController) {
        facade.attachPresenter(presenter)
    }

    func applySnapshotScene(_ scene: FilmtoneSnapshotScene) {
        let fixture = FilmtoneSnapshotFixture.make(scene: scene)
        project = fixture.project
        source = fixture.source
        probe = fixture.probe
        previewOrchestrator.applyFixture(preview: fixture.preview)
        exportCoordinator.applyFixture(
            exportResult: fixture.exportResult,
            saveToPhotosState: fixture.saveToPhotosState
        )
        sourceLoadState = fixture.sourceLoadState
        isBusy = false
        notice = nil
        error = nil
        toastDismissTask?.cancel()
        toastDismissTask = nil
        toast = nil
        appliedSavedLookId = nil
        highlightMarkers = nil
        // Library subtree is wiped by AppDelegate on snapshot bootstrap; this
        // mirrors that on the in-memory side so the snapshot fixture starts
        // with an empty Recent / Saved Looks state.
        library = .empty
    }

    func pickSource(route: FilmtoneSourcePickerRoute = .photoLibrary) async {
        do {
            isBusy = true
            notice = nil
            error = nil
            sourceLoadState = nil

            guard let source = try await facade.pickSource(
                route: route,
                protectedCacheURIs: protectedCacheURIs,
                onImportProgress: { [weak self] progress in
                    self?.applySourceImportProgress(progress, route: route)
                }
            ) else {
                isBusy = false
                sourceLoadState = nil
                return
            }

            sourceLoadState = .init(
                stage: .probing,
                route: route,
                message: strings.probePending,
                progress: nil,
                isDeterminate: false
            )
            let probe = try facade.probeSource(source)
            // iOS caps source video duration at PHASE0_MAX_SOURCE_DURATION_SEC
            // (300s). For >5:00 video, route to a dedicated Desktop handoff
            // sheet instead of replacing the existing source with one that
            // would fail the export request build with a generic source-cap
            // error. We deliberately skip applyProbe / persist /
            // schedulePreviewRender so the prior source (if any) keeps
            // displaying; the orphaned imported file is reclaimed by
            // `reclaimCacheForCurrentState` because `protectedCacheURIs`
            // derives from the unchanged `source`.
            if probe.kind == .video,
               let durationSec = probe.durationSec,
               durationSec > FilmtonePhase0Math.sourceDurationCapSec
            {
                isBusy = false
                sourceLoadState = nil
                reclaimCacheForCurrentState()
                desktopHandoffPromptPresented = true
                return
            }
            applyProbe(source: source, probe: probe)
            isBusy = false
            sourceLoadState = nil
            persist()
            reclaimCacheForCurrentState()
            schedulePreviewRender()
        } catch {
            isBusy = false
            sourceLoadState = nil
            self.error = strings.userMessage(for: error, context: .pickSource)
        }
    }

    /// Records one fixed-duration ProRes 422 HQ Apple Log 2 clip with
    /// AVFoundation `cinematicExtendedEnhanced` stabilization, then adopts
    /// the resulting `clip.mov` as the active source — same downstream
    /// pipeline as `pickSource` (probe → applyProbe → persist → reclaim →
    /// schedulePreviewRender).
    func recordProductClip(durationSeconds: Double = 5.0) async {
        await captureRelay.recordProductClip(durationSeconds: durationSeconds)
    }

    #if os(iOS)
    /// Adopts a `FilmtoneCapturePackage` produced by the M10 native capture
    /// surface. Probes the **proxy** (not the master) and applies the
    /// resulting probe through the same downstream pipeline as `pickSource`
    /// / `recordProductClip` (probe → applyProbe → persist → reclaim →
    /// schedulePreviewRender). The capture package itself is retained on
    /// `lastCapturePackage` so downstream operations (export-from-master /
    /// share-master) can resolve the security-scoped external folder URL
    /// when needed.
    func adoptCaptureResult(_ package: FilmtoneCapturePackage) async {
        await captureRelay.adoptCaptureResult(package)
    }
    #endif

    func selectPreset(_ presetName: String) {
        appliedSavedLookId = nil
        project.presetName = presetName
        project.strength = FilmtonePhase0Math.presetStrengthDefault
        project.quickState = .zero
        recomputeProjectParams()
    }

    func setStrength(_ strength: Double) {
        appliedSavedLookId = nil
        project.strength = FilmtonePhase0Math.clampStrength(strength)
        recomputeProjectParams()
    }

    func setQuickValue(_ value: Double, for axis: WritableKeyPath<FilmtoneQuickState, Double>) {
        appliedSavedLookId = nil
        project.quickState[keyPath: axis] = max(-1, min(1, value))
        recomputeProjectParams()
    }

    /// Backlight Veil Phase 1c — segmented Picker writes a profile id (or
    /// nil = OFF) into the project/request state. `recomputeProjectParams()`
    /// reschedules the preview so the new kernel branch picks up on the next
    /// frame without dirtying the currently-applied Saved Look provenance.
    func setOpticalFilterId(_ id: String?) {
        guard selectedOpticalFilterId != id else {
            return
        }
        selectedOpticalFilterId = id
        project.opticalFilterProfileId = id
        recomputeProjectParams()
    }

    func setParamOverride(_ value: Double, for key: String) {
        if FilmtonePreviewRefreshDebug.isProcessParam(key), source?.kind == .video {
            FilmtonePreviewRefreshDebug.log("process param override changed: \(key)=\(value)")
        }
        appliedSavedLookId = nil
        let base = baseParamsForCurrentAdjustments()
        project.paramOverrides = project.paramOverrides.settingValue(value, for: key, over: base)
        recomputeProjectParams()
    }

    func clearParamOverrides(for keys: [String]) {
        var next = project.paramOverrides
        for key in keys {
            next = next.removingValue(for: key)
        }
        guard next != project.paramOverrides else {
            return
        }
        appliedSavedLookId = nil
        project.paramOverrides = next
        recomputeProjectParams()
    }

    func applyParamPreset(values: [String: Double], for keys: [String]) {
        let base = baseParamsForCurrentAdjustments()
        var next = project.paramOverrides
        for key in keys {
            if let value = values[key] {
                next = next.settingValue(value, for: key, over: base)
            } else {
                next = next.removingValue(for: key)
            }
        }
        guard next != project.paramOverrides else {
            return
        }
        appliedSavedLookId = nil
        project.paramOverrides = next
        recomputeProjectParams()
    }

    func restoreActivePresetDefaults() {
        appliedSavedLookId = nil
        project.quickState = .zero
        project.strength = FilmtonePhase0Math.presetStrengthDefault
        project.paramOverrides = .empty
        recomputeProjectParams()
    }

    func resetAdjustments() {
        restoreActivePresetDefaults()
    }

    func setCompareHeld(_ isHeld: Bool) {
        guard videoPreviewState == nil else {
            return
        }
        isCompareHeld = isHeld
    }

    func setVideoCompareMode(_ mode: FilmtoneVideoCompareMode) async {
        await previewOrchestrator.setVideoCompareMode(mode)
    }

    func addHighlightMarker(at sourceTimeSec: Double) {
        guard source?.kind == .video,
              let sourceIdentity = currentMarkerSourceIdentity() else {
            return
        }
        let duration = probe?.durationSec ?? videoPreviewState?.durationSec
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

        let marker = FilmtoneHighlightMarker(
            id: "filmtone-marker-\(UUID().uuidString)",
            sourceTimeSec: clampedTime,
            sourceFps: sourceIdentity.fps,
            createdOnPlatform: "ios",
            createdAtIso: ISO8601DateFormatter.filmtoneSidecar.string(from: Date())
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

    // MARK: - Project mutation forwards (EditorProjectMutationCoordinator)

    func importInputLut() async {
        await projectMutationCoordinator.importInputLut()
    }

    func importCreativeLut() async {
        await projectMutationCoordinator.importCreativeLut()
    }

    /// S7: capture-surface import path. Unlike `importCreativeLut()`,
    /// this does not mutate the editor project immediately. It persists
    /// the cube into the LUT library and returns a capture Look record
    /// the capture surface can preview and stamp into the package.
    func importCaptureUserLut() async -> FilmtoneCaptureLook? {
        await projectMutationCoordinator.importCaptureUserLut()
    }

    func loadCaptureUserLut(entry: LutLibraryEntry) async -> FilmtoneCaptureLook? {
        await projectMutationCoordinator.loadCaptureUserLut(entry: entry)
    }

    func applyLibraryLut(libraryId: UUID, slot: SlotHint) async {
        await projectMutationCoordinator.applyLibraryLut(libraryId: libraryId, slot: slot)
    }

    @discardableResult
    func saveCurrentLook(name: String) async -> SavedLookEntry? {
        await projectMutationCoordinator.saveCurrentLook(name: name)
    }

    func applySavedLook(id: UUID) async {
        await projectMutationCoordinator.applySavedLook(id: id)
    }

    func applyCaptureCustomLut(_ record: FilmtoneCaptureCustomLutRecord) async {
        await projectMutationCoordinator.applyCaptureCustomLut(record)
    }

    /// Resolve a `CreativeLutBinding.bundled` payload from the app bundle
    /// under `Resources/CreativeLuts/`. The bundled cube's pinned SHA-256
    /// (over the raw `.cube` file bytes — see
    /// `scripts/build-creative-luts.ts`) is verified against the catalog
    /// entry; mismatch returns nil (caller surfaces `lutMissingForApply`).
    /// Returns a `ParsedCubeLutDTO` carrying the slug + packId provenance
    /// so downstream `transportLut` can stamp the sidecar.
    static func loadBundledCreativeLut(
        slug: String,
        filename: String,
        pinnedSha256: String,
        intensity: Double,
        packId: String
    ) -> ParsedCubeLutDTO? {
        guard let url = Bundle.main.url(
            forResource: filename,
            withExtension: nil,
            subdirectory: "CreativeLuts"
        ) else {
            return nil
        }
        guard let fileData = try? Data(contentsOf: url) else {
            return nil
        }
        let digest = SHA256.hash(data: fileData)
        let actualHex = digest.map { String(format: "%02x", $0) }.joined()
        guard actualHex == pinnedSha256.lowercased() else {
            return nil
        }
        guard let text = String(data: fileData, encoding: .utf8) else {
            return nil
        }
        let parsed: ParsedCubeLutDTO
        do {
            parsed = try FilmtoneCubeParser.parse(text: text, defaultTitle: filename)
        } catch {
            return nil
        }
        return ParsedCubeLutDTO(
            title: parsed.title,
            size: parsed.size,
            data: parsed.data,
            intensity: FilmtonePhase0Math.clampLutIntensity(intensity),
            bundledSlug: slug,
            bundledPackId: packId
        )
    }

    static func loadBundledCreativeLut(
        binding: CreativeLutBinding?,
        packId: String
    ) -> ParsedCubeLutDTO? {
        guard case let .bundled(slug, filename, pinnedSha256, intensity) = binding else {
            return nil
        }
        return loadBundledCreativeLut(
            slug: slug,
            filename: filename,
            pinnedSha256: pinnedSha256,
            intensity: intensity,
            packId: packId
        )
    }

    func renameSavedLook(id: UUID, name: String) async {
        await libraryController.renameLook(id: id, name: name)
        await refreshLibrarySnapshot()
    }

    func deleteSavedLook(id: UUID) async {
        await libraryController.deleteLook(id: id)
        if appliedSavedLookId == id {
            appliedSavedLookId = nil
        }
        await refreshLibrarySnapshot()
    }

    func toggleFavoriteSavedLook(id: UUID) async {
        await libraryController.toggleFavoriteLook(id: id)
        await refreshLibrarySnapshot()
    }

    func renameLibraryLut(id: UUID, title: String) async {
        await libraryController.renameLut(id: id, title: title)
        await refreshLibrarySnapshot()
    }

    func deleteLibraryLut(id: UUID) async {
        await libraryController.deleteLut(id: id)
        await refreshLibrarySnapshot()
    }

    func toggleFavoriteLibraryLut(id: UUID) async {
        await libraryController.toggleFavoriteLut(id: id)
        await refreshLibrarySnapshot()
    }

    func clearInputLut() {
        projectMutationCoordinator.clearInputLut()
    }

    func clearCreativeLut() {
        projectMutationCoordinator.clearCreativeLut()
    }

    func setInputLutIntensity(_ intensity: Double) {
        projectMutationCoordinator.setInputLutIntensity(intensity)
    }

    func setCreativeLutIntensity(_ intensity: Double) {
        projectMutationCoordinator.setCreativeLutIntensity(intensity)
    }

    // MARK: - Phase 3B export/cache forwards (EditorExportCoordinator)

    func export() async {
        await exportCoordinator.export()
    }

    func exportAndSave() async {
        await exportCoordinator.exportAndSave()
    }

    func saveToPhotos() async {
        await exportCoordinator.saveToPhotos()
    }

    func shareOutput() async {
        await exportCoordinator.shareOutput()
    }

    func exportHighlightReel() async {
        await exportCoordinator.exportHighlightReel()
    }

    func loadCacheInventory() async {
        await exportCoordinator.loadCacheInventory()
    }

    func releaseCache() async {
        await exportCoordinator.releaseCache()
    }

    func reclaimCacheForBackground() {
        exportCoordinator.reclaimCacheForBackground()
    }

    func reclaimCacheForCurrentState() {
        exportCoordinator.reclaimCacheForCurrentState()
    }

    var protectedCacheURIs: [String] {
        exportCoordinator.protectedCacheURIs
    }

    // MARK: - Toast

    /// Show a viewport-level toast.
    ///
    /// - Cancels any pending auto-dismiss task so the latest toast wins.
    /// - If the same message is already on screen, behaves as a no-op so
    ///   rapid repeated calls (e.g. double-tap save) don't flicker.
    /// - Posts a VoiceOver announcement so the message is accessible.
    /// - Schedules an auto-dismiss after `durationMs` milliseconds; UI may
    ///   also call ``dismissToast()`` to dismiss earlier.
    func presentToast(
        _ message: String,
        kind: FilmtoneToast.Kind = .info,
        durationMs: Int = 2500
    ) {
        toastDismissTask?.cancel()

        if let current = toast,
           current.message == message,
           current.kind == kind {
            // Same message already presented; do not flicker.
            return
        }

        let next = FilmtoneToast(kind: kind, message: message, durationMs: durationMs)
        toast = next

        UIAccessibility.post(notification: .announcement, argument: message)

        let nanoseconds = UInt64(max(0, durationMs)) * 1_000_000
        let targetId = next.id
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            await MainActor.run {
                guard let self else { return }
                if self.toast?.id == targetId {
                    self.toast = nil
                }
            }
        }
    }

    /// Immediately dismiss the current toast (if any) and cancel its
    /// pending auto-dismiss task. Safe to call from UI gestures.
    func dismissToast() {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        toast = nil
    }

    // MARK: - Project recompute helpers

    private func recomputeProjectParams() {
        project.quickState = project.quickState.clamped()
        let resolved = FilmtonePhase0Math.resolveParams(
            presetName: project.presetName,
            strength: project.strength,
            quickState: project.quickState,
            paramOverrides: project.paramOverrides
        )
        project.paramOverrides = resolved.overrides
        project.params = resolved.effective
        project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        persist()
        schedulePreviewRender()
    }

    /// Variant of `recomputeProjectParams` that keeps optics + glow keys
    /// explicit in `paramOverrides` even if their value matches the resolved
    /// baseline. Used by `applySavedLook` so the Look's optical signature
    /// surfaces in Adjust-sheet UI signals — without it, a Look whose optics
    /// happen to align with the active preset's defaults would normalize away
    /// into an empty patch and the user would see "no adjustments" UI even
    /// though the kernel is rendering with the Look's chosen optics values.
    func recomputeProjectParamsPreservingOpticsGlow() {
        project.quickState = project.quickState.clamped()
        let base = FilmtonePhase0Math.deriveParams(
            presetName: project.presetName,
            strength: project.strength,
            quickState: project.quickState
        )
        project.paramOverrides = project.paramOverrides
            .normalizedPreservingOpticsGlow(over: base)
        project.params = base.applyingPatch(project.paramOverrides)
        project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        persist()
        schedulePreviewRender()
    }

    /// M1 Max Quality Look Director — re-resolve adaptation when source
    /// or Camera Profile changes so a previously-applied Creative Pack 01
    /// Look re-adapts to the new context instead of staying baked from
    /// apply-time. No-op when the current `creativeLut` is not a Pack 01
    /// bundled Look. Returns `true` when it mutated state and already
    /// persisted + scheduled a re-render via
    /// `recomputeProjectParamsPreservingOpticsGlow`.
    ///
    /// M1C: the merge now writes the FULL catalog baseline first (every
    /// Pack 01 key, not just the adaptation overlay subset), then layers
    /// the Look Director overlay on top. This is the migration mechanism
    /// for persisted projects from earlier builds: their stale
    /// `grainIntensity`, `lensSoftness`, `bloomRadius`, etc. get
    /// overwritten with the current M1C catalog values without needing a
    /// `Profile.version` bump. User-side tweaks on Pack 01 baseline keys
    /// are reset on every refresh by design — bundled Looks are owned by
    /// the catalog, custom variants belong in saved Looks.
    @discardableResult
    fileprivate func refreshCreativePack01AdaptationIfApplicable() -> Bool {
        guard
            let creativeLut = project.creativeLut,
            let slug = creativeLut.bundledSlug,
            let builtIn = FilmtoneBuiltInCatalog.look(matchingSlug: slug)
        else {
            return false
        }

        let sourceProfileId = FilmtoneLookDirector.sourceProfileId(
            for: project.cameraProfile
        )
        let sourceColorClassRaw = FilmtoneLookDirector.sourceColorClassRaw(
            probe: probe
        )
        let adaptation = FilmtoneCreativePack01Adaptation.resolve(
            slug: slug,
            descriptor: probe?.sourceToneDescriptor,
            sourceProfileId: sourceProfileId,
            sourceDetailBias: FilmtoneLookDirector.resolveSourceDetailBias(
                probe: probe,
                cameraProfile: project.cameraProfile
            ),
            sourceColorClassRaw: sourceColorClassRaw
        )
        let selectedBinding = FilmtoneBuiltInCatalog.creativeLutBinding(
            for: builtIn,
            sourceProfileId: sourceProfileId,
            sourceColorClassRaw: sourceColorClassRaw
        )
        let selectedCreativeLut = FilmtoneEditorStore.loadBundledCreativeLut(
            binding: selectedBinding,
            packId: builtIn.packId ?? FilmtoneBuiltInCatalog.creativePack01Id
        )

        guard let mergedValues = FilmtoneCreativePack01Patches.refreshedParamOverrides(
            existing: project.paramOverrides.values,
            slug: slug,
            adaptation: adaptation
        ) else {
            return false
        }

        var nextOverrides = project.paramOverrides
        nextOverrides.values = mergedValues

        let nextIntensity = adaptation?.intensity ?? 1.0
        let nextCreativeLut = selectedCreativeLut?.withIntensity(nextIntensity)
        let intensityChanged = abs(creativeLut.intensity - nextIntensity) > 1e-6
        let lutVariantChanged = nextCreativeLut.map {
            $0.title != creativeLut.title ||
            $0.size != creativeLut.size ||
            $0.data.count != creativeLut.data.count
        } ?? false
        let overridesChanged = nextOverrides.values != project.paramOverrides.values
        guard intensityChanged || overridesChanged || lutVariantChanged else {
            return false
        }

        project.paramOverrides = nextOverrides
        project.creativeLut = nextCreativeLut ?? creativeLut.withIntensity(nextIntensity)
        recomputeProjectParamsPreservingOpticsGlow()
        return true
    }

    func applyProbe(source: SourceInfoDTO, probe: SourceProbeDTO) {
        let isSourceReplacement = self.source?.uri != source.uri
        self.source = source
        self.probe = probe
        #if DEBUG
        refreshSourceAudioDebugLabel(for: source)
        #endif
        // Camera/input LUTs are source-specific. Carrying one across clips can
        // mis-normalize non-log footage when replacing a prior log source.
        if isSourceReplacement, project.inputLut != nil {
            project.inputLut = nil
            project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        }
        // v1.3 Camera Profiles Phase F (D-CP4) — apply the retention rule
        // for the selected Camera Profile against the new probe. Sticky
        // for manual profiles, reset for Apple Log mismatches.
        if isSourceReplacement {
            applyCameraProfileSourceChangeRule(probe: probe)
            #if os(iOS)
            captureRelay.dropLinkageIfNotProxy(of: source)
            #endif
        }
        previewOrchestrator.reset()
        exportCoordinator.resetForSourceChange()
        // M1 Max Quality Look Director — new probe means a new
        // `sourceToneDescriptor`. If a Pack 01 bundled Look is current,
        // re-resolve so the night / high-key / Log / digital signals from
        // the new clip drive intensity + overlay overrides. Caller's own
        // persist/reclaim path runs after this returns; the refresher's
        // recompute (if it mutated) also persists + schedules. Placing
        // this after the orchestrator reset so the scheduled render is
        // not immediately canceled.
        refreshCreativePack01AdaptationIfApplicable()
        if isSourceReplacement || !canUseSlow24VideoTiming {
            videoTimingMode = .normal
        }
        self.error = nil
        self.notice = nil
        self.sourceLoadState = nil
        self.highlightMarkers = nil
        facade.prewarmMezzanines(for: source)
    }

    func invalidateRenderedOutputState() {
        previewOrchestrator.invalidateForProjectChange()
        exportCoordinator.invalidateForProjectChange()
    }

    func setVideoTimingMode(_ mode: FilmtoneVideoTimingMode) {
        let nextMode: FilmtoneVideoTimingMode = mode == .slow24 && canUseSlow24VideoTiming
            ? .slow24
            : .normal
        guard videoTimingMode != nextMode else {
            return
        }
        videoTimingMode = nextMode
        previewOrchestrator.applyVideoTimingPolicy(videoTimingPolicy)
        exportCoordinator.invalidateExportPackageState()
    }

    private func invalidateExportPackageState() {
        exportCoordinator.invalidateExportPackageState()
    }

    var exportHighlightMarkers: FilmtoneHighlightMarkers? {
        guard let highlightMarkers, !highlightMarkers.isEmpty else {
            return nil
        }
        return highlightMarkers
    }

    private func currentMarkerSourceIdentity() -> FilmtoneMarkerSourceIdentity? {
        guard let source else {
            return nil
        }
        let fps = FilmtoneHighlightMarker.validFPS(
            probe?.frameRate ?? probe?.sourceVideoMetadata?.timing?.nominalFrameRate
        )
        let filename: String = {
            if let probeFilename = probe?.filename, !probeFilename.isEmpty {
                return probeFilename
            }
            return source.filename
        }()
        return FilmtoneMarkerSourceIdentity(
            filename: filename,
            durationSec: probe?.durationSec,
            fps: fps,
            fileSizeBytes: probe?.fileSizeBytes.map { Int64($0) }
        )
    }

    private func applySourceImportProgress(
        _ progress: FilmtoneSourceImportProgress,
        route: FilmtoneSourcePickerRoute
    ) {
        sourceLoadState = .init(
            stage: .importing,
            route: route,
            message: strings.sourceImportMessage(for: progress.phase, route: route),
            progress: progress.fractionCompleted,
            isDeterminate: progress.isDeterminate
        )
    }

    func schedulePreviewRender() {
        previewOrchestrator.schedule()
    }

    func persist() {
        #if os(iOS)
        let captureRef = currentCapturePackageRef
        #else
        let captureRef: String? = nil
        #endif
        FilmtonePersistence.save(
            project: project,
            source: source,
            probe: probe,
            currentCapturePackageRef: captureRef
        )
    }

    private static func signedPercentLabel(for value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(Int((value * 100).rounded()))%"
    }
}

extension ParsedCubeLutDTO {
    func withIntensity(_ intensity: Double) -> ParsedCubeLutDTO {
        ParsedCubeLutDTO(
            title: title,
            size: size,
            data: data,
            intensity: FilmtonePhase0Math.clampLutIntensity(intensity),
            bundledSlug: bundledSlug,
            bundledPackId: bundledPackId
        )
    }
}

extension AVPlayer {
    func filmtoneSeek(to time: CMTime) async {
        await withCheckedContinuation { continuation in
            seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                continuation.resume()
            }
        }
    }
}

extension Double {
    var filmtoneSanitizedSeconds: Double {
        guard isFinite, !isNaN else {
            return 0
        }
        return max(self, 0)
    }
}

enum FilmtonePreviewRefreshDebug {
    private static let processParamKeys: Set<String> = [
        "cyan",
        "magenta",
        "yellow",
        "printContrast",
        "compressionAmount",
        "compressionRange",
    ]

    static func isProcessParam(_ key: String) -> Bool {
        processParamKeys.contains(key)
    }

    static var shouldForceVideoRefreshFailure: Bool {
        #if DEBUG
        let processInfo = ProcessInfo.processInfo
        return processInfo.arguments.contains("-filmtoneDebugForceVideoPreviewRefreshFailure")
            || processInfo.environment["FILMTONE_DEBUG_FORCE_VIDEO_PREVIEW_REFRESH_FAILURE"] == "1"
        #else
        return false
        #endif
    }

    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[FilmtonePreview] \(message())")
        #endif
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
