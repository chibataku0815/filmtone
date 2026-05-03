import AppKit
import CoreImage
import Foundation
import Observation

@Observable
final class EditorState {
    var sourceURL: URL?
    var sourceKind: FilmtoneSourceKind = .still
    var presetName: String = FilmtonePresetCatalog.defaultName
    var isExporting: Bool = false
    var exportProgress: Double = 0
    var exportProgressMessage: String?
    var lastExportSummary: String?

    @ObservationIgnored
    var currentExportTask: Task<Void, Never>?

    var presetParams: FilmtonePhase0Params {
        FilmtonePresetCatalog.params(for: presetName)
    }

    var lookId: String {
        FilmtonePresetCatalog.lookId(for: presetName)
    }

    var lookVersion: String {
        FilmtonePresetCatalog.presetVersion
    }

    func setSource(_ url: URL?, kind: FilmtoneSourceKind) {
        sourceURL = url
        sourceKind = kind
    }

    func cancelExport() {
        currentExportTask?.cancel()
    }
}
