import AVFoundation
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

    func stillDisplayURI(isComparing: Bool) -> String? {
        guard case .still(let preview) = self else {
            return nil
        }
        if isComparing {
            return preview.originalPosterURI ?? preview.gradedPosterURI
        }
        return preview.gradedPosterURI ?? preview.originalPosterURI
    }
}

enum FilmtoneSaveToPhotosState: String {
    case notRun = "not-run"
    case saved
    case failed
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
    @Published var isCompareHeld = false
    @Published var exportProgress: Phase0ExportProgressDTO?
    @Published var exportResult: Phase0ExportResultDTO?
    @Published var saveToPhotosState: FilmtoneSaveToPhotosState = .notRun
    @Published var isBusy = false
    @Published var notice: String?
    @Published var error: String?

    let strings: FilmtoneStrings
    private let facade: FilmtoneEditorFacade
    private var previewTask: Task<Void, Never>?
    private var videoPreviewSession: FilmtoneVideoPreviewSession?

    init(facade: FilmtoneEditorFacade, strings: FilmtoneStrings = FilmtoneStringsCatalog.current) {
        self.facade = facade
        self.strings = strings

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

        if self.source != nil {
            schedulePreviewRender()
        }
    }

    deinit {
        previewTask?.cancel()
    }

    var sourceLabel: String? {
        source?.filename
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

    var previewInteractionHint: String {
        videoPreviewState != nil ? strings.previewVideoHint : strings.compareHint
    }

    var quickSummaryText: String {
        let entries: [(String, Double)] = [
            (strings.quickFilmCharacter, project.quickState.filmCharacter),
            (strings.quickEra, project.quickState.era),
            (strings.quickDynamics, project.quickState.dynamics),
        ]
        .filter { abs($0.1) >= 0.01 }

        if entries.isEmpty {
            return strings.quickHint
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

        return strings.quickHint
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

        return [dimensions, timing]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfEmpty
    }

    var sourceViolations: [String] {
        FilmtonePhase0Math.sourceCapViolations(for: probe)
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

    func isParamOverridden(_ key: String) -> Bool {
        project.paramOverrides.values[key] != nil
    }

    func attachPresenter(_ presenter: UIViewController) {
        facade.attachPresenter(presenter)
    }

    func pickSource(route: FilmtoneSourcePickerRoute = .photoLibrary) async {
        do {
            isBusy = true
            notice = nil
            error = nil

            guard let source = try await facade.pickSource(route: route) else {
                isBusy = false
                return
            }

            notice = strings.probePending
            let probe = try facade.probeSource(source)
            applyProbe(source: source, probe: probe)
            isBusy = false
            persist()
            schedulePreviewRender()
        } catch {
            isBusy = false
            self.error = strings.userMessage(for: error, context: .pickSource)
        }
    }

    func selectPreset(_ presetName: String) {
        project.presetName = presetName
        project.strength = FilmtonePhase0Math.presetStrengthDefault
        project.quickState = .zero
        recomputeProjectParams()
    }

    func setStrength(_ strength: Double) {
        project.strength = FilmtonePhase0Math.clampStrength(strength)
        recomputeProjectParams()
    }

    func setQuickValue(_ value: Double, for axis: WritableKeyPath<FilmtoneQuickState, Double>) {
        project.quickState[keyPath: axis] = max(-1, min(1, value))
        recomputeProjectParams()
    }

    func setParamOverride(_ value: Double, for key: String) {
        let base = FilmtonePhase0Math.deriveParams(
            presetName: project.presetName,
            strength: project.strength,
            quickState: project.quickState
        )
        project.paramOverrides = project.paramOverrides.settingValue(value, for: key, over: base)
        recomputeProjectParams()
    }

    func resetAdjustments() {
        project.quickState = .zero
        project.strength = FilmtonePhase0Math.presetStrengthDefault
        project.paramOverrides = .empty
        recomputeProjectParams()
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
            guard let lut = try await facade.pickInputLut() else {
                return
            }
            project.inputLut = lut
            project.updatedAt = FilmtonePhase0Math.isoTimestamp()
            persist()
            schedulePreviewRender()
        } catch {
            if let mediaError = error as? FilmtoneMediaError,
               mediaError.code == "UNSUPPORTED_SOURCE" {
                self.error = strings.lutParseError
            } else {
                self.error = strings.userMessage(for: error, context: .importLut)
            }
        }
    }

    func clearInputLut() {
        project.inputLut = nil
        project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        persist()
        schedulePreviewRender()
    }

    func export() async {
        do {
            let request = try FilmtonePhase0Math.buildExportRequest(
                source: source,
                probe: probe,
                project: project
            )

            isBusy = true
            error = nil
            notice = nil
            exportResult = nil
            exportProgress = nil
            saveToPhotosState = .notRun

            let result = try await facade.runExport(request: request) { [weak self] progress in
                self?.exportProgress = progress
            }

            isBusy = false
            exportProgress = nil
            exportResult = result
        } catch {
            isBusy = false
            exportProgress = nil
            self.error = strings.userMessage(for: error, context: .export)
        }
    }

    func saveToPhotos() async {
        guard let exportResult, saveToPhotosState != .saved else {
            return
        }

        do {
            try await facade.saveToPhotos(uri: exportResult.outputUri)
            saveToPhotosState = .saved
            notice = strings.saveToPhotosDone
            error = nil
        } catch {
            saveToPhotosState = .failed
            self.error = strings.userMessage(for: error, context: .saveToPhotos)
        }
    }

    func shareOutput() async {
        guard let exportResult else {
            return
        }

        do {
            try await facade.shareOutput(uri: exportResult.outputUri)
        } catch {
            self.error = strings.userMessage(for: error, context: .share)
        }
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
        self.source = source
        self.probe = probe
        self.preview = .empty
        self.videoPreviewSession = nil
        self.isCompareHeld = false
        self.saveToPhotosState = .notRun
        self.error = nil
        self.notice = nil
        self.exportResult = nil
        self.exportProgress = nil
    }

    private func schedulePreviewRender() {
        previewTask?.cancel()

        guard let source else {
            videoPreviewSession = nil
            preview = .empty
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
                    self.preview = .still(.init(isRendering: true))
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

                case .video:
                    do {
                        try await self.prepareVideoPreview(request: request, source: source)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        let fallbackError = self.strings.userMessage(for: error, context: .preview)
                        if let videoPreviewSession = self.videoPreviewSession,
                           videoPreviewSession.sourceURI == source.uri {
                            videoPreviewSession.setError(fallbackError)
                            self.syncPreviewFromVideoSession()
                        } else {
                            try await self.renderStillFallbackPreview(
                                request: request,
                                errorMessage: fallbackError
                            )
                        }
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                self.videoPreviewSession = nil
                self.preview = .still(.init(
                    originalPosterURI: nil,
                    gradedPosterURI: nil,
                    width: nil,
                    height: nil,
                    posterTimeSec: nil,
                    isRendering: false,
                    error: strings.userMessage(for: error, context: .preview)
                ))
            }
        }
    }

    private func prepareVideoPreview(
        request: Phase0ExportRequestDTO,
        source: SourceInfoDTO
    ) async throws {
        if let videoPreviewSession, videoPreviewSession.sourceURI == source.uri {
            videoPreviewSession.beginPreparing()
            videoPreviewSession.clearError()
            syncPreviewFromVideoSession()

            let graded = try await facade.makeGradedPreviewItem(request: request)
            try Task.checkCancellation()
            await videoPreviewSession.updatePreparedGradedItem(graded)
            syncPreviewFromVideoSession()
            return
        }

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
    }

    private func renderStillFallbackPreview(
        request: Phase0ExportRequestDTO,
        errorMessage: String
    ) async throws {
        videoPreviewSession = nil
        preview = .still(.init(isRendering: true))

        do {
            let result = try await facade.renderPreview(request: request)
            try Task.checkCancellation()
            preview = .still(.init(
                originalPosterURI: result.originalUri,
                gradedPosterURI: result.gradedUri,
                width: result.width,
                height: result.height,
                posterTimeSec: result.posterTimeSec,
                isRendering: false,
                error: errorMessage
            ))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            preview = .still(.init(
                originalPosterURI: nil,
                gradedPosterURI: nil,
                width: nil,
                height: nil,
                posterTimeSec: nil,
                isRendering: false,
                error: errorMessage
            ))
        }
    }

    private func syncPreviewFromVideoSession() {
        if let videoPreviewSession {
            preview = .video(videoPreviewSession.snapshot)
        } else if case .video = preview {
            preview = .empty
        }
    }

    private func persist() {
        FilmtonePersistence.save(project: project, source: source, probe: probe)
    }

    private static func signedPercentLabel(for value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(Int((value * 100).rounded()))%"
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
