import AVFoundation
import CryptoKit
import Foundation
import SwiftUI
import UIKit

struct FilmtoneStillPreviewState {
    var originalPosterURI: String?
    var gradedPosterURI: String?
    var width: Int?
    var height: Int?
    var posterTimeSec: Double?
    var isRendering = false
    var error: String?

    static let empty = FilmtoneStillPreviewState()
}

struct FilmtoneComparePreviewFrame {
    let originalURI: String
    let gradedURI: String
    let width: Int?
    let height: Int?
    let posterTimeSec: Double?

    init?(
        originalURI: String?,
        gradedURI: String?,
        width: Int? = nil,
        height: Int? = nil,
        posterTimeSec: Double? = nil
    ) {
        guard let originalURI, let gradedURI else {
            return nil
        }
        self.originalURI = originalURI
        self.gradedURI = gradedURI
        self.width = width
        self.height = height
        self.posterTimeSec = posterTimeSec
    }
}

enum FilmtoneVideoCompareMode: String {
    case graded
    case original
}

struct FilmtoneVideoPreviewState {
    let player: AVPlayer
    let compareMode: FilmtoneVideoCompareMode
    let width: Int?
    let height: Int?
    let durationSec: Double?
    let isPreparing: Bool
    let error: String?
}

enum FilmtonePreviewState {
    case empty
    case still(FilmtoneStillPreviewState)
    case video(FilmtoneVideoPreviewState)

    var isRendering: Bool {
        switch self {
        case .empty:
            return false
        case .still(let preview):
            return preview.isRendering
        case .video(let preview):
            return preview.isPreparing
        }
    }

    var error: String? {
        switch self {
        case .empty:
            return nil
        case .still(let preview):
            return preview.error
        case .video(let preview):
            return preview.error
        }
    }

    var width: Int? {
        switch self {
        case .empty:
            return nil
        case .still(let preview):
            return preview.width
        case .video(let preview):
            return preview.width
        }
    }

    var height: Int? {
        switch self {
        case .empty:
            return nil
        case .still(let preview):
            return preview.height
        case .video(let preview):
            return preview.height
        }
    }

    var posterTimeSec: Double? {
        guard case .still(let preview) = self else {
            return nil
        }
        return preview.posterTimeSec
    }

    var durationSec: Double? {
        guard case .video(let preview) = self else {
            return nil
        }
        return preview.durationSec
    }

    var videoState: FilmtoneVideoPreviewState? {
        guard case .video(let preview) = self else {
            return nil
        }
        return preview
    }

    var comparePreviewFrame: FilmtoneComparePreviewFrame? {
        guard case .still(let preview) = self else {
            return nil
        }
        return FilmtoneComparePreviewFrame(
            originalURI: preview.originalPosterURI,
            gradedURI: preview.gradedPosterURI,
            width: preview.width,
            height: preview.height,
            posterTimeSec: preview.posterTimeSec
        )
    }

    func stillDisplayURI(isComparing: Bool) -> String? {
        guard case .still(let preview) = self else {
            return nil
        }
        if isComparing {
            return preview.originalPosterURI ?? preview.gradedPosterURI
        }
        return preview.gradedPosterURI ?? preview.originalPosterURI
    }

    var cacheURIs: [String] {
        switch self {
        case .empty, .video:
            return []
        case .still(let preview):
            return [
                preview.originalPosterURI,
                preview.gradedPosterURI,
            ].compactMap { $0 }
        }
    }
}

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

@MainActor
final class FilmtoneVideoPreviewSession {
    let sourceURI: String
    let player: AVPlayer

    private(set) var originalItem: AVPlayerItem
    private(set) var gradedItem: AVPlayerItem
    private(set) var compareMode: FilmtoneVideoCompareMode
    private(set) var currentTimeSec: Double
    private(set) var isPreparing: Bool
    private(set) var lastError: String?
    private(set) var width: Int
    private(set) var height: Int
    private(set) var durationSec: Double?

    private var timeObserver: Any?
    private var transitionGeneration: UInt64 = 0
    private var pendingPlaybackState: (time: CMTime, shouldPlay: Bool)?

    init(
        sourceURI: String,
        original: FilmtonePreparedVideoPreviewItem,
        graded: FilmtonePreparedVideoPreviewItem
    ) {
        self.sourceURI = sourceURI
        self.player = AVPlayer(playerItem: graded.item)
        self.originalItem = original.item
        self.gradedItem = graded.item
        self.compareMode = .graded
        self.currentTimeSec = 0
        self.isPreparing = false
        self.lastError = nil
        self.width = graded.width
        self.height = graded.height
        self.durationSec = graded.durationSec ?? original.durationSec
        self.player.actionAtItemEnd = .pause
        attachTimeObserver()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    var snapshot: FilmtoneVideoPreviewState {
        .init(
            player: player,
            compareMode: compareMode,
            width: width,
            height: height,
            durationSec: durationSec,
            isPreparing: isPreparing,
            error: lastError
        )
    }

    func beginPreparing() {
        isPreparing = true
    }

    func setError(_ message: String?) {
        lastError = message
        isPreparing = false
    }

    func clearError() {
        lastError = nil
    }

    func updatePreparedGradedItem(_ prepared: FilmtonePreparedVideoPreviewItem) async {
        gradedItem = prepared.item
        width = prepared.width
        height = prepared.height
        durationSec = prepared.durationSec ?? durationSec
        lastError = nil
        isPreparing = false

        guard compareMode == .graded else {
            return
        }

        let transition = beginTransition()
        await replaceCurrentItem(
            prepared.item,
            preserving: transition.playbackState,
            generation: transition.generation
        )
    }

    func refreshPreparedGradedComposition(_ prepared: FilmtonePreparedVideoPreviewComposition) async {
        let transition = compareMode == .graded && player.currentItem === gradedItem
            ? beginTransition()
            : nil

        width = prepared.width
        height = prepared.height
        durationSec = prepared.durationSec ?? durationSec
        lastError = nil
        isPreparing = false

        FilmtonePreviewRefreshDebug.log("assigning refreshed graded video composition")
        gradedItem.videoComposition = prepared.videoComposition
        gradedItem.seekingWaitsForVideoCompositionRendering = true

        guard let transition else {
            return
        }

        FilmtonePreviewRefreshDebug.log(
            "forcing graded preview redraw at \(CMTimeGetSeconds(transition.playbackState.time).filmtoneSanitizedSeconds)s"
        )
        await rerenderCurrentItem(
            preserving: transition.playbackState,
            generation: transition.generation
        )
    }

    func setCompareMode(_ mode: FilmtoneVideoCompareMode) async {
        guard compareMode != mode else {
            return
        }

        compareMode = mode
        let transition = beginTransition()
        await replaceCurrentItem(
            item(for: mode),
            preserving: transition.playbackState,
            generation: transition.generation
        )
    }

    private func item(for mode: FilmtoneVideoCompareMode) -> AVPlayerItem {
        switch mode {
        case .graded:
            return gradedItem
        case .original:
            return originalItem
        }
    }

    private func capturePlaybackState() -> (time: CMTime, shouldPlay: Bool) {
        let time = player.currentTime()
        let shouldPlay = player.timeControlStatus == .playing || player.rate > 0
        return (time: time, shouldPlay: shouldPlay)
    }

    private func beginTransition() -> (
        generation: UInt64,
        playbackState: (time: CMTime, shouldPlay: Bool)
    ) {
        transitionGeneration += 1
        let playbackState = pendingPlaybackState ?? capturePlaybackState()
        pendingPlaybackState = playbackState
        return (
            generation: transitionGeneration,
            playbackState: playbackState
        )
    }

    private func replaceCurrentItem(
        _ item: AVPlayerItem,
        preserving playbackState: (time: CMTime, shouldPlay: Bool),
        generation: UInt64
    ) async {
        player.pause()
        player.replaceCurrentItem(with: item)
        await player.filmtoneSeek(to: playbackState.time)
        completeTransition(playbackState, generation: generation)
    }

    private func rerenderCurrentItem(
        preserving playbackState: (time: CMTime, shouldPlay: Bool),
        generation: UInt64
    ) async {
        player.pause()
        await player.filmtoneSeek(to: playbackState.time)
        completeTransition(playbackState, generation: generation)
    }

    private func completeTransition(
        _ playbackState: (time: CMTime, shouldPlay: Bool),
        generation: UInt64
    ) {
        guard generation == transitionGeneration else {
            return
        }
        currentTimeSec = CMTimeGetSeconds(playbackState.time).filmtoneSanitizedSeconds
        pendingPlaybackState = nil
        if playbackState.shouldPlay {
            player.play()
        }
    }

    private func attachTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTimeSec = CMTimeGetSeconds(time).filmtoneSanitizedSeconds
            }
        }
    }
}

@MainActor
final class FilmtoneEditorStore: ObservableObject {
    @Published var project: FilmtoneProjectState
    @Published var source: SourceInfoDTO?
    @Published var probe: SourceProbeDTO?
    @Published var preview: FilmtonePreviewState = .empty
    @Published var comparePreviewFrame: FilmtoneComparePreviewFrame?
    @Published var isCompareHeld = false
    @Published var exportProgress: Phase0ExportProgressDTO?
    @Published var exportResult: Phase0ExportResultDTO?
    @Published var exportLocalAvailability: FilmtoneExportLocalAvailability = .none
    @Published var saveToPhotosState: FilmtoneSaveToPhotosState = .notRun
    @Published var isSavingToPhotos = false
    @Published var sourceLoadState: FilmtoneSourceLoadState?
    @Published var isBusy = false
    @Published var notice: String?
    @Published var error: String?
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
    private(set) var appliedSavedLookId: UUID?

    let strings: FilmtoneStrings
    private let facade: FilmtoneEditorFacade
    private let libraryStore: LibraryStoreActor?
    private var previewTask: Task<Void, Never>?
    private var videoPreviewSession: FilmtoneVideoPreviewSession?
    private var toastDismissTask: Task<Void, Never>?
    private var libraryBootstrapTask: Task<Void, Never>?

    init(
        facade: FilmtoneEditorFacade,
        strings: FilmtoneStrings = FilmtoneStringsCatalog.current,
        libraryStore: LibraryStoreActor? = nil
    ) {
        self.facade = facade
        self.strings = strings
        // Fall back to a library-disabled mode if Application Support is not
        // reachable — the editor still works, the Recent / Saved-Looks UI
        // simply stays empty. We do not hard-fail bootstrap.
        self.libraryStore = libraryStore ?? (try? LibraryStoreActor())

        if let snapshot = FilmtonePersistence.load() {
            self.project = snapshot.project
            self.source = snapshot.source
            self.probe = snapshot.probe
        } else {
            self.project = FilmtonePhase0Math.createProjectState()
            self.source = nil
            self.probe = nil
        }

        if let source, !facade.fileExists(uri: source.uri) {
            self.source = nil
            self.probe = nil
            persist()
        }

        reclaimCacheForCurrentState()

        if self.source != nil {
            schedulePreviewRender()
        }

        bootstrapLibraryAsync()
    }

    deinit {
        previewTask?.cancel()
        toastDismissTask?.cancel()
        libraryBootstrapTask?.cancel()
    }

    private func bootstrapLibraryAsync() {
        guard let libraryStore else {
            return
        }
        libraryBootstrapTask?.cancel()
        libraryBootstrapTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await libraryStore.loadOrRebuild()
                self.library = snapshot
            } catch {
                // Library is non-load-bearing for editor function — keep the
                // empty snapshot rather than surfacing a setup error.
                self.library = .empty
            }
        }
    }

    private func refreshLibrarySnapshot() async {
        guard let libraryStore else {
            return
        }
        let snapshot = await libraryStore.snapshot()
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
        preview.stillDisplayURI(isComparing: isCompareHeld)
    }

    var videoPreviewState: FilmtoneVideoPreviewState? {
        preview.videoState
    }

    var previewError: String? {
        preview.error
    }

    var quickSummaryText: String {
        let entries: [(String, Double)] = [
            (strings.quickFilmCharacter, project.quickState.dynamics),
            (strings.quickEra, -project.quickState.era),
            (strings.quickDynamics, project.quickState.filmCharacter),
        ]
        .filter { abs($0.1) >= 0.01 }

        if entries.isEmpty {
            return ""
        }

        return entries
            .map { "\($0.0) \(Self.signedPercentLabel(for: $0.1))" }
            .joined(separator: " · ")
    }

    var hasQuickAdjustments: Bool {
        abs(project.quickState.filmCharacter) >= 0.01 ||
            abs(project.quickState.era) >= 0.01 ||
            abs(project.quickState.dynamics) >= 0.01
    }

    var hasAdvancedAdjustments: Bool {
        !project.paramOverrides.isEmpty
    }

    var hasAnyAdjustments: Bool {
        hasQuickAdjustments || hasAdvancedAdjustments
    }

    var hasPresetCustomValues: Bool {
        abs(project.strength - FilmtonePhase0Math.presetStrengthDefault) >= FilmtonePhase0Math.paramEqualityTolerance ||
            abs(project.quickState.filmCharacter) >= FilmtonePhase0Math.paramEqualityTolerance ||
            abs(project.quickState.era) >= FilmtonePhase0Math.paramEqualityTolerance ||
            abs(project.quickState.dynamics) >= FilmtonePhase0Math.paramEqualityTolerance ||
            hasAdvancedAdjustments
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

        return [dimensions, timing, cameraOpticsLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfEmpty
    }

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
        persist()
        schedulePreviewRender()
    }

    /// D-CP4 retention rule on source change. Called from `applyProbe`.
    ///
    /// - `.auto`: always re-derives at export time, no state change here.
    /// - `.builtIn(.appleLog | .appleLog2)`: if the new probe's color class
    ///   doesn't match the selection, fall back to `.auto` and surface a
    ///   toast — the user picked a profile that the new clip can't honor.
    /// - `.builtIn(.panasonicVLog | .sonySLog3 | .rec709)`: persist (cannot
    ///   be auto-detected from container metadata, so the user's prior
    ///   pick stays sticky across source swaps).
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
            // Sticky cases first — V-Log, S-Log3, Rec.709 cannot be
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
        previewTask?.cancel()
        previewTask = nil

        let fixture = FilmtoneSnapshotFixture.make(scene: scene)
        project = fixture.project
        source = fixture.source
        probe = fixture.probe
        preview = fixture.preview
        comparePreviewFrame = fixture.preview.comparePreviewFrame
        videoPreviewSession = nil
        isCompareHeld = false
        exportProgress = nil
        exportResult = fixture.exportResult
        exportLocalAvailability = fixture.exportResult == nil ? .none : .available
        saveToPhotosState = fixture.saveToPhotosState
        isSavingToPhotos = false
        sourceLoadState = fixture.sourceLoadState
        isBusy = false
        notice = nil
        error = nil
        toastDismissTask?.cancel()
        toastDismissTask = nil
        toast = nil
        appliedSavedLookId = nil
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
        guard let videoPreviewSession else {
            return
        }
        await videoPreviewSession.setCompareMode(mode)
        syncPreviewFromVideoSession()
    }

    func importInputLut() async {
        do {
            guard let lut = try await facade.pickCubeLut() else {
                return
            }
            await persistImportedLutToLibrary(lut, slot: .input)
            appliedSavedLookId = nil
            applyLutMutation {
                $0.inputLut = lut
            }
        } catch {
            if let mediaError = error as? FilmtoneMediaError,
               mediaError.code == "UNSUPPORTED_SOURCE" {
                self.error = strings.lutParseError
            } else {
                self.error = strings.userMessage(for: error, context: .importLut)
            }
        }
    }

    func importCreativeLut() async {
        do {
            guard let lut = try await facade.pickCubeLut() else {
                return
            }
            await persistImportedLutToLibrary(lut, slot: .creative)
            appliedSavedLookId = nil
            applyLutMutation {
                $0.creativeLut = lut
            }
        } catch {
            if let mediaError = error as? FilmtoneMediaError,
               mediaError.code == "UNSUPPORTED_SOURCE" {
                self.error = strings.lookLutParseError
            } else {
                self.error = strings.userMessage(for: error, context: .importCreativeLut)
            }
        }
    }

    /// Persist a freshly-picked LUT into the library so it shows up in
    /// Recent. Quota / dedup logic lives in the actor; if persistence fails
    /// we still apply the LUT to the project — library-disabled mode is a
    /// degraded but acceptable state, never a hard editor failure.
    private func persistImportedLutToLibrary(
        _ lut: ParsedCubeLutDTO,
        slot: SlotHint
    ) async {
        guard let libraryStore else {
            return
        }
        do {
            _ = try await libraryStore.importLut(
                parsedLut: lut,
                originalFilename: nil,
                preferredSlot: slot
            )
            await refreshLibrarySnapshot()
        } catch let storeError as LibraryStoreActor.StoreError {
            // Surface quota errors but never block the in-memory LUT apply —
            // the user can keep working, they just won't see the entry in
            // Recent until they free up space and re-import.
            if case .quotaExceeded = storeError {
                self.error = strings.libraryQuotaExceeded
            }
        } catch {
            // Swallow other library errors (disk write failure etc.); they
            // are non-load-bearing for the in-memory editor.
        }
    }

    /// Apply a LUT from the library to the named slot. Tap-to-apply path on
    /// the Recent strip routes through here so we (a) reuse the existing
    /// `applyLutMutation` invalidate/persist path, (b) bump the entry's
    /// `lastUsedAt`, and (c) touch the slot's intensity according to the
    /// entry's `defaultIntensity`.
    func applyLibraryLut(libraryId: UUID, slot: SlotHint) async {
        guard let libraryStore else {
            return
        }
        do {
            let parsed = try await libraryStore.loadLut(id: libraryId)
            await libraryStore.touchLutLastUsed(id: libraryId)
            await refreshLibrarySnapshot()
            appliedSavedLookId = nil
            applyLutMutation { state in
                switch slot {
                case .input:
                    state.inputLut = parsed
                case .creative, .any:
                    state.creativeLut = parsed
                }
            }
        } catch {
            self.error = strings.libraryLutMissingOnApply
        }
    }

    /// Snapshot the current creative state into a Saved Look. Source-side
    /// (input LUT / source URI / source probe) is intentionally **not**
    /// captured — those are source-locally re-derived per `applyProbe`.
    @discardableResult
    func saveCurrentLook(name: String) async -> SavedLookEntry? {
        guard let libraryStore else {
            return nil
        }
        let creativeBinding = await currentCreativeLutBinding()
        // Stamp optics + glow into the Look's identity. Built-in Looks
        // (Stone / Urban) hardcode these; user-saved Looks would otherwise
        // omit any key the user did not personally tune, leaving the Look's
        // optical signature dependent on whichever preset baseline applies it.
        let densifiedOverrides = project.paramOverrides
            .densifyingOpticsGlow(from: project.params)
        do {
            let entry = try await libraryStore.saveLook(
                name: name,
                presetName: project.presetName,
                presetVersion: FilmtonePhase0Math.presetVersion,
                strength: project.strength,
                quickState: project.quickState,
                paramOverrides: densifiedOverrides,
                creativeLut: creativeBinding
            )
            await refreshLibrarySnapshot()
            appliedSavedLookId = entry.id
            presentToast(
                String(format: strings.lookSavedToastFormat, entry.name),
                kind: .success
            )
            return entry
        } catch {
            self.error = strings.userMessage(for: error, context: .importLut)
            return nil
        }
    }

    /// Find or create the `CreativeLutBinding` that represents the current
    /// `project.creativeLut`. We prefer a `libraryRef` when the LUT's content
    /// hash matches an existing library entry; otherwise we register the LUT
    /// as a new library entry so the look survives delete-from-library.
    private func currentCreativeLutBinding() async -> CreativeLutBinding? {
        guard let creativeLut = project.creativeLut else {
            return nil
        }
        guard let libraryStore else {
            return nil
        }
        do {
            let result = try await libraryStore.importLut(
                parsedLut: creativeLut,
                originalFilename: nil,
                preferredSlot: .creative
            )
            // result.entry.id always represents the canonical library entry
            // for this hash — dedup hit reuses the existing one, miss creates.
            if !result.deduped {
                await refreshLibrarySnapshot()
            }
            return .libraryRef(id: result.entry.id, intensity: creativeLut.intensity)
        } catch {
            // If the import itself failed (quota etc.), embed the data
            // inline so the look still saves and stays applicable.
            let hash = (try? FilmtoneLutBlobCodec.sourceHash(
                data: creativeLut.data,
                size: creativeLut.size
            )) ?? ""
            let embedded = SavedLookEmbeddedLut(
                title: creativeLut.title,
                size: creativeLut.size,
                data: creativeLut.data,
                sourceHash: hash
            )
            return .embedded(lut: embedded, intensity: creativeLut.intensity)
        }
    }

    /// Apply a saved Look's creative state to the project.
    ///
    /// Per the Item 3 plan §"Apply-Saved-Look Semantics":
    /// - Overwrites: `presetName`, `strength`, `quickState`, `paramOverrides`
    ///   (and the resolved `params` derived from them), `creativeLut`,
    ///   creative-LUT intensity.
    /// - Does NOT touch: `project.inputLut`, source URI, source probe.
    ///   The source-side normalization is deliberately source-local — the
    ///   look survives source swaps, the camera profile does not.
    func applySavedLook(id: UUID) async {
        guard let libraryStore else {
            return
        }
        do {
            let entry = try await libraryStore.loadLook(id: id)
            var resolvedCreativeLut: ParsedCubeLutDTO?
            var creativePack01Adaptation: FilmtoneCreativePack01Adaptation.Resolved?
            var lutMissingForApply = false

            switch entry.creativeLut {
            case .libraryRef(let lutId, let intensity):
                if let _ = library.lutEntry(id: lutId) {
                    do {
                        resolvedCreativeLut = try await libraryStore.loadLut(
                            id: lutId,
                            intensity: intensity
                        )
                        await libraryStore.touchLutLastUsed(id: lutId)
                    } catch {
                        lutMissingForApply = true
                    }
                } else {
                    lutMissingForApply = true
                }
            case .embedded(let lut, let intensity):
                resolvedCreativeLut = ParsedCubeLutDTO(
                    title: lut.title,
                    size: lut.size,
                    data: lut.data,
                    intensity: FilmtonePhase0Math.clampLutIntensity(intensity)
                )
            case .bundled(let slug, let filename, let pinnedSha256, let intensity):
                // v1.4 Creative LUT Pack 01: resolve from Bundle.main under
                // `Resources/CreativeLuts/`. fail-closed — if the resource is
                // missing or its SHA-256 does not match the pinned value, we
                // surface the same `lutMissingForApply` toast as for a deleted
                // library entry rather than silently degrading
                // (`feedback_no_fallback_bug_hotbed`).
                if let resolved = FilmtoneEditorStore.loadBundledCreativeLut(
                    slug: slug,
                    filename: filename,
                    pinnedSha256: pinnedSha256,
                    intensity: intensity,
                    packId: FilmtoneBuiltInCatalog.creativePack01Id
                ) {
                    resolvedCreativeLut = resolved
                    creativePack01Adaptation = FilmtoneCreativePack01Adaptation.resolve(
                        slug: slug,
                        descriptor: probe?.sourceToneDescriptor
                    )
                } else {
                    lutMissingForApply = true
                }
            case .none:
                resolvedCreativeLut = nil
            }

            applyLutMutation { state in
                state.presetName = FilmtonePhase0Math.safePresetName(entry.presetName)
                // v1.4 backward compat — stamp the saved Look's preset version
                // onto the project so the export pipeline dispatches v1 kernel
                // for v1 saves and v2 kernel for v2 saves. handoff §10 guard.
                state.presetVersion = entry.presetVersion
                state.strength = FilmtonePhase0Math.clampStrength(entry.strength)
                state.quickState = entry.quickState.clamped()
                var paramOverrides = entry.paramOverrides
                if let creativePack01Adaptation {
                    for (key, value) in creativePack01Adaptation.paramOverrides.values {
                        paramOverrides.values[key] = value
                    }
                }
                state.paramOverrides = paramOverrides
                if let creativePack01Adaptation, let resolvedCreativeLut {
                    state.creativeLut = resolvedCreativeLut.withIntensity(creativePack01Adaptation.intensity)
                } else {
                    state.creativeLut = resolvedCreativeLut
                }
                // Note: state.inputLut is intentionally untouched — the look
                // is source-independent. See applySavedLook docs above.
            }
            recomputeProjectParams()
            appliedSavedLookId = entry.id
            await refreshLibrarySnapshot()

            if lutMissingForApply {
                self.error = strings.libraryLutMissingOnApply
            } else {
                presentToast(
                    String(format: strings.lookAppliedToastFormat, entry.name),
                    kind: .info
                )
            }
        } catch {
            self.error = strings.userMessage(for: error, context: .importCreativeLut)
        }
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

    func renameSavedLook(id: UUID, name: String) async {
        guard let libraryStore else {
            return
        }
        try? await libraryStore.renameLook(id: id, name: name)
        await refreshLibrarySnapshot()
    }

    func deleteSavedLook(id: UUID) async {
        guard let libraryStore else {
            return
        }
        _ = try? await libraryStore.deleteLook(id: id)
        if appliedSavedLookId == id {
            appliedSavedLookId = nil
        }
        await refreshLibrarySnapshot()
    }

    func toggleFavoriteSavedLook(id: UUID) async {
        guard let libraryStore else {
            return
        }
        try? await libraryStore.toggleFavoriteLook(id: id)
        await refreshLibrarySnapshot()
    }

    func renameLibraryLut(id: UUID, title: String) async {
        guard let libraryStore else {
            return
        }
        try? await libraryStore.renameLut(id: id, title: title)
        await refreshLibrarySnapshot()
    }

    func deleteLibraryLut(id: UUID) async {
        guard let libraryStore else {
            return
        }
        _ = try? await libraryStore.deleteLut(id: id)
        await refreshLibrarySnapshot()
    }

    func toggleFavoriteLibraryLut(id: UUID) async {
        guard let libraryStore else {
            return
        }
        try? await libraryStore.toggleFavoriteLut(id: id)
        await refreshLibrarySnapshot()
    }

    func clearInputLut() {
        appliedSavedLookId = nil
        applyLutMutation {
            $0.inputLut = nil
        }
    }

    func clearCreativeLut() {
        appliedSavedLookId = nil
        applyLutMutation {
            $0.creativeLut = nil
        }
    }

    func setInputLutIntensity(_ intensity: Double) {
        let clampedIntensity = FilmtonePhase0Math.clampLutIntensity(intensity)
        guard let currentLut = project.inputLut, currentLut.intensity != clampedIntensity else {
            return
        }
        appliedSavedLookId = nil
        applyLutMutation {
            guard let lut = $0.inputLut else {
                return
            }
            $0.inputLut = lut.withIntensity(clampedIntensity)
        }
    }

    func setCreativeLutIntensity(_ intensity: Double) {
        let clampedIntensity = FilmtonePhase0Math.clampLutIntensity(intensity)
        guard let currentLut = project.creativeLut, currentLut.intensity != clampedIntensity else {
            return
        }
        appliedSavedLookId = nil
        applyLutMutation {
            guard let lut = $0.creativeLut else {
                return
            }
            $0.creativeLut = lut.withIntensity(clampedIntensity)
        }
    }

    func export() async {
        guard !isBusy && !isSavingToPhotos else {
            return
        }

        do {
            let request = try FilmtonePhase0Math.buildExportRequest(
                source: source,
                probe: probe,
                project: project
            )

            // v1.3 Item 2 Phase E: resolve the active Saved Look (if any) so
            // the sidecar can record provenance. Built-in catalog entries
            // materialize from `FilmtoneBuiltInCatalog` without disk I/O;
            // user-saved entries are read from the in-memory actor state.
            // Resolution failures surface as "no provenance" — never block
            // the export — because the look might have been deleted between
            // apply and export, and a missing block is preferable to a hard
            // export failure (CLAUDE.md §11 `feedback_no_fallback_bug_hotbed`
            // permits this: provenance absence is explicit, not silent
            // success-with-degraded-output).
            let resolvedSavedLook = await resolveAppliedSavedLookForExport()
            // v1.3 Camera Profiles Phase E: thread the project's selected
            // Camera Profile through facade.runExport. Stored OFF the wire
            // DTO because it's iOS-side state, not bridge data.
            let cameraProfileSelection = project.cameraProfile

            isBusy = true
            error = nil
            notice = nil
            exportResult = nil
            exportProgress = nil
            exportLocalAvailability = .none
            saveToPhotosState = .notRun

            let cacheProtection = protectedCacheURIs
            let result = try await facade.runExport(
                request: request,
                protectedCacheURIs: cacheProtection,
                appliedSavedLook: resolvedSavedLook,
                cameraProfile: cameraProfileSelection
            ) { [weak self] progress in
                self?.exportProgress = progress
            }

            isBusy = false
            exportProgress = nil
            exportResult = result
            exportLocalAvailability = .available
            reclaimCacheForCurrentState()
            presentToast(strings.toastExportComplete, kind: .success)
        } catch {
            isBusy = false
            exportProgress = nil
            isSavingToPhotos = false
            self.error = strings.userMessage(for: error, context: .export)
        }
    }

    func exportAndSave() async {
        guard !isBusy && !isSavingToPhotos else {
            return
        }

        do {
            let request = try FilmtonePhase0Math.buildExportRequest(
                source: source,
                probe: probe,
                project: project
            )

            // v1.3 Item 2 Phase E + Camera Profiles Phase E: see `export()`
            // above for the resolveAppliedSavedLook + cameraProfile rationale.
            let resolvedSavedLook = await resolveAppliedSavedLookForExport()
            let cameraProfileSelection = project.cameraProfile

            isBusy = true
            isSavingToPhotos = false
            error = nil
            notice = nil
            exportResult = nil
            exportProgress = nil
            exportLocalAvailability = .none
            saveToPhotosState = .notRun

            let cacheProtection = protectedCacheURIs
            let result = try await facade.runExport(
                request: request,
                protectedCacheURIs: cacheProtection,
                appliedSavedLook: resolvedSavedLook,
                cameraProfile: cameraProfileSelection
            ) { [weak self] progress in
                self?.exportProgress = progress
            }

            isBusy = false
            exportProgress = nil
            exportResult = result
            exportLocalAvailability = .available
            reclaimCacheForCurrentState()
            await saveExportResultToPhotos(result)
        } catch {
            isBusy = false
            exportProgress = nil
            isSavingToPhotos = false
            self.error = strings.userMessage(for: error, context: .export)
        }
    }

    func saveToPhotos() async {
        guard let exportResult,
              canUseLocalExport,
              saveToPhotosState != .saved,
              !isSavingToPhotos else {
            return
        }

        await saveExportResultToPhotos(exportResult)
    }

    private func saveExportResultToPhotos(_ result: Phase0ExportResultDTO) async {
        guard !isSavingToPhotos else {
            return
        }

        isSavingToPhotos = true
        defer {
            isSavingToPhotos = false
        }

        do {
            try await facade.saveToPhotos(uri: result.outputUri)
            saveToPhotosState = .saved
            // Keep the local export package available after Photos save so the
            // same result can still be shared or inspected from the app cache.
            notice = strings.saveToPhotosDone
            error = nil
            presentToast(strings.toastSaveSuccess, kind: .success)
        } catch {
            saveToPhotosState = .failed
            self.error = strings.userMessage(for: error, context: .saveToPhotos)
        }
    }

    func shareOutput() async {
        guard let exportResult, canUseLocalExport else {
            return
        }

        do {
            let completed = try await facade.shareOutput(
                mediaURI: exportResult.outputUri,
                sidecarURI: exportResult.sidecarUri,
                packageFileURIs: exportResult.packageFileUris
            )
            if completed {
                notice = nil
                error = nil
            }
        } catch {
            self.error = strings.userMessage(for: error, context: .share)
            presentToast(strings.toastShareFailed, kind: .error)
        }
    }

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

    func reclaimCacheForBackground() {
        guard !isBusy && !isSavingToPhotos else {
            return
        }
        reclaimCacheForCurrentState()
    }

    private var protectedCacheURIs: [String] {
        var uris: [String] = []
        if let source {
            uris.append(source.uri)
        }
        if canUseLocalExport, let exportResult {
            uris.append(contentsOf: localExportURIs(for: exportResult))
        }
        uris.append(contentsOf: preview.cacheURIs)
        if let comparePreviewFrame {
            uris.append(comparePreviewFrame.originalURI)
            uris.append(comparePreviewFrame.gradedURI)
        }
        return uniqueURIs(uris)
    }

    private func reclaimCacheForCurrentState() {
        facade.reclaimCache(protecting: protectedCacheURIs)
    }

    /// v1.3 Item 2 Phase E: resolve `appliedSavedLookId` to a full
    /// `SavedLookEntry` for sidecar provenance. Returns nil when the project
    /// has been dirtied since `applySavedLook` (the apply path nils
    /// `appliedSavedLookId` on every mutation), when no Saved Look was
    /// applied, when the library actor is unavailable, or when the entry
    /// fails to load (e.g. user-saved entry deleted between apply and
    /// export). Built-in catalog entries materialize without disk I/O via
    /// `FilmtoneBuiltInCatalog`, so the read is cheap.
    private func resolveAppliedSavedLookForExport() async -> SavedLookEntry? {
        guard let lookId = appliedSavedLookId, let store = libraryStore else {
            return nil
        }
        return try? await store.loadLook(id: lookId)
    }

    private func discardLocalExportFiles(_ result: Phase0ExportResultDTO) {
        exportLocalAvailability = .removed
        _ = facade.removeLocalFiles(uris: localExportURIs(for: result))
        reclaimCacheForCurrentState()
    }

    private func localExportURIs(for result: Phase0ExportResultDTO) -> [String] {
        if let packageFileUris = result.packageFileUris, !packageFileUris.isEmpty {
            return uniqueURIs(packageFileUris)
        }
        return [
            result.outputUri,
            result.sidecarUri,
        ].compactMap { $0 }
    }

    private func uniqueURIs(_ uris: [String]) -> [String] {
        var seen: Set<String> = []
        var unique: [String] = []
        for uri in uris where !uri.isEmpty {
            guard !seen.contains(uri) else {
                continue
            }
            seen.insert(uri)
            unique.append(uri)
        }
        return unique
    }

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

    private func applyProbe(source: SourceInfoDTO, probe: SourceProbeDTO) {
        let isSourceReplacement = self.source?.uri != source.uri
        self.source = source
        self.probe = probe
        // Camera/input LUTs are source-specific. Carrying one across clips can
        // mis-normalize non-log footage when replacing a prior log source.
        if isSourceReplacement, project.inputLut != nil {
            project.inputLut = nil
            project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        }
        // v1.3 Camera Profiles Phase F (D-CP4) — apply the retention rule
        // for the selected Camera Profile against the new probe. Sticky
        // for V-Log / S-Log3 / Rec.709, reset for Apple Log mismatches.
        if isSourceReplacement {
            applyCameraProfileSourceChangeRule(probe: probe)
        }
        self.preview = .empty
        self.comparePreviewFrame = nil
        self.videoPreviewSession = nil
        self.isCompareHeld = false
        self.saveToPhotosState = .notRun
        self.isSavingToPhotos = false
        self.error = nil
        self.notice = nil
        self.exportResult = nil
        self.exportProgress = nil
        self.exportLocalAvailability = .none
        self.sourceLoadState = nil
    }

    private func applyLutMutation(_ mutate: (inout FilmtoneProjectState) -> Void) {
        mutate(&project)
        project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        invalidateRenderedOutputState()
        persist()
        schedulePreviewRender()
    }

    private func invalidateRenderedOutputState() {
        previewTask?.cancel()
        previewTask = nil
        preview = .empty
        comparePreviewFrame = nil
        videoPreviewSession = nil
        isCompareHeld = false
        exportResult = nil
        exportProgress = nil
        exportLocalAvailability = .none
        saveToPhotosState = .notRun
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

    private func schedulePreviewRender() {
        previewTask?.cancel()

        guard let source else {
            videoPreviewSession = nil
            preview = .empty
            comparePreviewFrame = nil
            return
        }

        previewTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let violations = FilmtonePhase0Math.sourceCapViolations(for: self.probe)
            if !violations.isEmpty {
                self.videoPreviewSession = nil
                self.preview = .still(.init(
                    originalPosterURI: nil,
                    gradedPosterURI: nil,
                    width: nil,
                    height: nil,
                    posterTimeSec: nil,
                    isRendering: false,
                    error: violations.joined(separator: "\n")
                ))
                self.comparePreviewFrame = nil
                return
            }

            do {
                try await Task.sleep(nanoseconds: FilmtonePhase0Math.previewRenderDebounceNanoseconds)
                try Task.checkCancellation()

                let request = try FilmtonePhase0Math.buildExportRequest(
                    source: self.source,
                    probe: self.probe,
                    project: self.project
                )

                switch source.kind {
                case .image:
                    self.videoPreviewSession = nil
                    self.markStillPreviewRendering()
                    let result = try await self.facade.renderPreview(request: request)
                    try Task.checkCancellation()
                    self.preview = .still(.init(
                        originalPosterURI: result.originalUri,
                        gradedPosterURI: result.gradedUri,
                        width: result.width,
                        height: result.height,
                        posterTimeSec: result.posterTimeSec,
                        isRendering: false,
                        error: nil
                    ))
                    self.comparePreviewFrame = self.makeCompareFrame(from: result)
                    self.reclaimCacheForCurrentState()

                case .video:
                    do {
                        try await self.prepareVideoPreview(request: request, source: source)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        let fallbackError = self.strings.userMessage(for: error, context: .preview)
                        FilmtonePreviewRefreshDebug.log(
                            "video preview failed for \(source.filename): \(error.localizedDescription); falling back to still preview"
                        )
                        try await self.renderStillFallbackPreview(
                            request: request,
                            errorMessage: fallbackError
                        )
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                self.applyPreviewError(self.strings.userMessage(for: error, context: .preview))
            }
        }
    }

    private func prepareVideoPreview(
        request: Phase0ExportRequestDTO,
        source: SourceInfoDTO
    ) async throws {
        if let videoPreviewSession, videoPreviewSession.sourceURI == source.uri {
            try await refreshExistingVideoPreviewSession(videoPreviewSession, request: request)
            return
        }

        FilmtonePreviewRefreshDebug.log("creating initial video preview session for \(source.filename)")
        videoPreviewSession = nil
        preview = .still(.init(isRendering: true))

        async let originalPrepared = facade.makeOriginalPreviewItem(request: request)
        async let gradedPrepared = facade.makeGradedPreviewItem(request: request)

        let original = try await originalPrepared
        let graded = try await gradedPrepared
        try Task.checkCancellation()

        let session = FilmtoneVideoPreviewSession(
            sourceURI: source.uri,
            original: original,
            graded: graded
        )
        videoPreviewSession = session
        syncPreviewFromVideoSession()
        try await renderComparePreviewFrame(request: request)
    }

    private func refreshExistingVideoPreviewSession(
        _ videoPreviewSession: FilmtoneVideoPreviewSession,
        request: Phase0ExportRequestDTO
    ) async throws {
        FilmtonePreviewRefreshDebug.log("refreshing existing graded video preview item")
        videoPreviewSession.beginPreparing()
        videoPreviewSession.clearError()
        syncPreviewFromVideoSession()

        if FilmtonePreviewRefreshDebug.shouldForceVideoRefreshFailure {
            FilmtonePreviewRefreshDebug.log("forcing video preview refresh failure via debug flag")
            throw FilmtoneMediaError.exportFailed("Forced video preview refresh failure.")
        }

        let composition = try await facade.makeGradedPreviewComposition(
            request: request,
            asset: videoPreviewSession.gradedItem.asset
        )
        try Task.checkCancellation()
        await videoPreviewSession.refreshPreparedGradedComposition(composition)
        syncPreviewFromVideoSession()
        try await renderComparePreviewFrame(request: request)
    }

    private func renderStillFallbackPreview(
        request: Phase0ExportRequestDTO,
        errorMessage: String
    ) async throws {
        let hadDisplayablePreview = hasDisplayablePreviewContent
        if !hadDisplayablePreview {
            videoPreviewSession = nil
            markStillPreviewRendering()
        }

        do {
            let result = try await facade.renderPreview(request: request)
            try Task.checkCancellation()
            videoPreviewSession = nil
            preview = .still(.init(
                originalPosterURI: result.originalUri,
                gradedPosterURI: result.gradedUri,
                width: result.width,
                height: result.height,
                posterTimeSec: result.posterTimeSec,
                isRendering: false,
                error: errorMessage
            ))
            comparePreviewFrame = makeCompareFrame(from: result)
            reclaimCacheForCurrentState()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            applyPreviewError(errorMessage)
        }
    }

    private func renderComparePreviewFrame(request: Phase0ExportRequestDTO) async throws {
        do {
            let result = try await facade.renderPreview(request: request)
            try Task.checkCancellation()
            comparePreviewFrame = makeCompareFrame(from: result)
            reclaimCacheForCurrentState()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            FilmtonePreviewRefreshDebug.log(
                "compare preview frame failed: \(error.localizedDescription)"
            )
        }
    }

    private func makeCompareFrame(
        from result: Phase0PreviewRenderResultDTO
    ) -> FilmtoneComparePreviewFrame? {
        FilmtoneComparePreviewFrame(
            originalURI: result.originalUri,
            gradedURI: result.gradedUri,
            width: result.width,
            height: result.height,
            posterTimeSec: result.posterTimeSec
        )
    }

    private func syncPreviewFromVideoSession() {
        if let videoPreviewSession {
            preview = .video(videoPreviewSession.snapshot)
        } else if case .video = preview {
            preview = .empty
        }
    }

    private var hasDisplayablePreviewContent: Bool {
        if comparePreviewFrame != nil {
            return true
        }

        switch preview {
        case .empty:
            return false
        case .still(let preview):
            return preview.originalPosterURI != nil || preview.gradedPosterURI != nil
        case .video:
            return true
        }
    }

    private func markStillPreviewRendering() {
        guard case .still(let current) = preview else {
            preview = .still(.init(isRendering: true))
            return
        }

        preview = .still(.init(
            originalPosterURI: current.originalPosterURI,
            gradedPosterURI: current.gradedPosterURI,
            width: current.width,
            height: current.height,
            posterTimeSec: current.posterTimeSec,
            isRendering: true,
            error: current.error
        ))
    }

    private func applyPreviewError(_ message: String) {
        guard hasDisplayablePreviewContent else {
            videoPreviewSession = nil
            preview = .still(.init(
                originalPosterURI: nil,
                gradedPosterURI: nil,
                width: nil,
                height: nil,
                posterTimeSec: nil,
                isRendering: false,
                error: message
            ))
            comparePreviewFrame = nil
            return
        }

        if let videoPreviewSession {
            videoPreviewSession.setError(message)
            syncPreviewFromVideoSession()
            return
        }

        guard case .still(let current) = preview else {
            return
        }

        preview = .still(.init(
            originalPosterURI: current.originalPosterURI,
            gradedPosterURI: current.gradedPosterURI,
            width: current.width,
            height: current.height,
            posterTimeSec: current.posterTimeSec,
            isRendering: false,
            error: message
        ))
    }

    private func persist() {
        FilmtonePersistence.save(project: project, source: source, probe: probe)
    }

    private static func signedPercentLabel(for value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(Int((value * 100).rounded()))%"
    }
}

private extension ParsedCubeLutDTO {
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

private extension AVPlayer {
    func filmtoneSeek(to time: CMTime) async {
        await withCheckedContinuation { continuation in
            seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                continuation.resume()
            }
        }
    }
}

private extension Double {
    var filmtoneSanitizedSeconds: Double {
        guard isFinite, !isNaN else {
            return 0
        }
        return max(self, 0)
    }
}

private enum FilmtonePreviewRefreshDebug {
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
