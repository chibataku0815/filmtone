import AVFoundation
import FilmLabSwiftCore
import Foundation

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
    let videoTimingPolicy: FilmtoneVideoTimingPolicy
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
    private(set) var videoTimingPolicy: FilmtoneVideoTimingPolicy

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
        self.videoTimingPolicy = .init(mode: .normal, sourceFPS: nil)
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
            durationSec: videoTimingPolicy.displayDuration(sourceDuration: durationSec),
            videoTimingPolicy: videoTimingPolicy,
            isPreparing: isPreparing,
            error: lastError
        )
    }

    func applyVideoTimingPolicy(_ policy: FilmtoneVideoTimingPolicy) {
        videoTimingPolicy = policy
        player.defaultRate = Float(policy.speedMultiplier)
        if player.timeControlStatus == .playing || player.rate > 0 {
            player.rate = Float(policy.speedMultiplier)
        }
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
            player.defaultRate = Float(videoTimingPolicy.speedMultiplier)
            player.rate = Float(videoTimingPolicy.speedMultiplier)
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

/// Phase 3A: preview lifecycle collaborator owning the still + video
/// preview state, the per-source `previewTask`, and the
/// `FilmtoneVideoPreviewSession` handle. Hosts the render dispatch
/// (`schedule()`), the AVAssetReader / AVAssetWriter-free preview path
/// (`facade.renderPreview(request:)`), the video preview session
/// preparation, the still fallback, the compare-frame render, and the
/// preview error projection.
///
/// `FilmtoneEditorStore` keeps owning project / library / capture-relay /
/// export / cache state. It binds itself to this orchestrator via
/// `attach(_:)` so the orchestrator can read `source`, `probe`, and
/// `project` at schedule time without duplicating @Published storage.
/// SwiftUI observation flows by forwarding the orchestrator's
/// `objectWillChange` into the editor store's own publisher; this avoids
/// rewriting the view layer's `@EnvironmentObject var store:
/// FilmtoneEditorStore` contract.
///
/// Public state surface:
/// - `preview` / `comparePreviewFrame`: storage moved off the store.
///   Views still read them through the store's computed forwards
///   (`store.preview` / `store.comparePreviewFrame`).
/// - `isCompareHeld`: storage moved off the store; the store keeps
///   `setCompareHeld(_:)` as a 1-line forward.
/// - `videoPreviewState` / `selectedPreviewURI` / `previewError`:
///   computed helpers used by views via the store's forwards.
///
/// Private state surface:
/// - `previewTask`: the in-flight `Task<Void, Never>?` representing the
///   most-recent debounced render. Cancelled on every `schedule()`,
///   `reset()`, `invalidateForProjectChange()`, and store deinit.
/// - `videoPreviewSession`: the AVPlayer-backed graded/original pair
///   that `FilmtoneFullscreenLutEditor` keeps alive between renders.
@MainActor
final class EditorPreviewOrchestrator: ObservableObject {
    @Published private(set) var preview: FilmtonePreviewState = .empty
    @Published private(set) var comparePreviewFrame: FilmtoneComparePreviewFrame?
    @Published var isCompareHeld = false

    private let facade: FilmtoneEditorFacade
    private let strings: FilmtoneStrings
    private weak var store: FilmtoneEditorStore?

    private var previewTask: Task<Void, Never>?
    private var videoPreviewSession: FilmtoneVideoPreviewSession?

    init(facade: FilmtoneEditorFacade, strings: FilmtoneStrings) {
        self.facade = facade
        self.strings = strings
    }

    deinit {
        previewTask?.cancel()
    }

    func attach(_ store: FilmtoneEditorStore) {
        self.store = store
    }

    var videoPreviewState: FilmtoneVideoPreviewState? {
        preview.videoState
    }

    var selectedPreviewURI: String? {
        preview.stillDisplayURI(isComparing: isCompareHeld)
    }

    var previewError: String? {
        preview.error
    }

    var previewCacheURIs: [String] {
        preview.cacheURIs
    }

    var comparePreviewFrameURIs: [String] {
        guard let comparePreviewFrame else { return [] }
        return [comparePreviewFrame.originalURI, comparePreviewFrame.gradedURI]
    }

    var hasActiveVideoPreviewSession: Bool {
        videoPreviewSession != nil
    }

    func setVideoCompareMode(_ mode: FilmtoneVideoCompareMode) async {
        guard let videoPreviewSession else { return }
        await videoPreviewSession.setCompareMode(mode)
        syncPreviewFromVideoSession()
    }

    func applyVideoTimingPolicy(_ policy: FilmtoneVideoTimingPolicy) {
        videoPreviewSession?.applyVideoTimingPolicy(policy)
        syncPreviewFromVideoSession()
    }

    func reset() {
        previewTask?.cancel()
        previewTask = nil
        preview = .empty
        comparePreviewFrame = nil
        videoPreviewSession = nil
        isCompareHeld = false
    }

    /// Snapshot/UI-fixture hook used by `FilmtoneEditorStore.applySnapshotScene(_:)`.
    /// Cancels the in-flight render task and forces the preview surface to
    /// the supplied fixture without touching project/source/probe state.
    func applyFixture(preview: FilmtonePreviewState) {
        previewTask?.cancel()
        previewTask = nil
        self.preview = preview
        comparePreviewFrame = preview.comparePreviewFrame
        videoPreviewSession = nil
        isCompareHeld = false
    }

    func invalidateForProjectChange() {
        previewTask?.cancel()
        previewTask = nil
        preview = .empty
        comparePreviewFrame = nil
        videoPreviewSession = nil
        isCompareHeld = false
    }

    func schedule() {
        previewTask?.cancel()
        guard let store else {
            return
        }
        let source = store.source
        let probe = store.probe
        let project = store.project
        let videoTimingMode = store.resolvedVideoTimingMode

        guard let source else {
            videoPreviewSession = nil
            preview = .empty
            comparePreviewFrame = nil
            return
        }

        previewTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let violations = FilmtonePhase0Math.sourceCapViolations(for: probe)
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
                    source: source,
                    probe: probe,
                    project: project,
                    videoTimingMode: videoTimingMode
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
                    self.store?.reclaimCacheForCurrentState()

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
        session.applyVideoTimingPolicy(request.videoTimingPolicy)
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
        videoPreviewSession.applyVideoTimingPolicy(request.videoTimingPolicy)
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
            store?.reclaimCacheForCurrentState()
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
            store?.reclaimCacheForCurrentState()
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
}
