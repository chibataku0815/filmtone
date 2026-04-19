import Foundation
import SwiftUI
import UIKit

struct FilmtonePreviewState {
    var originalPosterURI: String?
    var gradedPosterURI: String?
    var width: Int?
    var height: Int?
    var posterTimeSec: Double?
    var isRendering = false
    var error: String?

    static let empty = FilmtonePreviewState()
}

enum FilmtoneSaveToPhotosState: String {
    case notRun = "not-run"
    case saved
    case failed
}

@MainActor
final class FilmtoneEditorStore: ObservableObject {
    @Published var project: FilmtoneProjectState
    @Published var source: SourceInfoDTO?
    @Published var probe: SourceProbeDTO?
    @Published var preview = FilmtonePreviewState.empty
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
        if isCompareHeld {
            return preview.originalPosterURI ?? preview.gradedPosterURI
        }
        return preview.gradedPosterURI ?? preview.originalPosterURI
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
        let posterTime = preview.posterTimeSec.map(Self.compactDurationLabel)
        return [dimensions, posterTime]
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
            self.error = error.localizedDescription
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
        isCompareHeld = isHeld
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
            self.error = "\(strings.lutImportError): \(error.localizedDescription)"
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
            self.error = error.localizedDescription
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
            self.error = error.localizedDescription
        }
    }

    func shareOutput() async {
        guard let exportResult else {
            return
        }

        do {
            try await facade.shareOutput(uri: exportResult.outputUri)
        } catch {
            self.error = error.localizedDescription
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
        preview = .empty
        isCompareHeld = false
        saveToPhotosState = .notRun
        error = nil
        notice = nil
        exportResult = nil
        exportProgress = nil
    }

    private func schedulePreviewRender() {
        previewTask?.cancel()

        guard source != nil else {
            preview = .empty
            return
        }

        previewTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let violations = FilmtonePhase0Math.sourceCapViolations(for: self.probe)
            if !violations.isEmpty {
                self.preview = .init(
                    originalPosterURI: nil,
                    gradedPosterURI: nil,
                    width: nil,
                    height: nil,
                    posterTimeSec: nil,
                    isRendering: false,
                    error: violations.joined(separator: "\n")
                )
                return
            }

            self.preview.isRendering = true
            self.preview.error = nil

            do {
                try await Task.sleep(nanoseconds: FilmtonePhase0Math.previewRenderDebounceNanoseconds)
                try Task.checkCancellation()
                let request = try FilmtonePhase0Math.buildExportRequest(
                    source: self.source,
                    probe: self.probe,
                    project: self.project
                )
                let result = try await self.facade.renderPreview(request: request)
                try Task.checkCancellation()
                self.preview = .init(
                    originalPosterURI: result.originalUri,
                    gradedPosterURI: result.gradedUri,
                    width: result.width,
                    height: result.height,
                    posterTimeSec: result.posterTimeSec,
                    isRendering: false,
                    error: nil
                )
            } catch is CancellationError {
                return
            } catch {
                self.preview.isRendering = false
                self.preview.error = error.localizedDescription
            }
        }
    }

    private func persist() {
        FilmtonePersistence.save(project: project, source: source, probe: probe)
    }

    private static func compactDurationLabel(_ durationSec: Double) -> String {
        let roundedTenth = (durationSec * 10).rounded() / 10
        if roundedTenth < 60 {
            return String(format: "%.1fs", roundedTenth)
        }
        let totalSeconds = Int(durationSec.rounded())
        return "\(totalSeconds / 60)m \(totalSeconds % 60)s"
    }

    private static func signedPercentLabel(for value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(Int((value * 100).rounded()))%"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
