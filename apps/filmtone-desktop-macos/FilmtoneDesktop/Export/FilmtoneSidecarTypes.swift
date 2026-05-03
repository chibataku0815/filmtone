import Foundation

enum FilmtoneSourceKind: String, Sendable {
    case still
    case video
}

protocol FilmtoneSidecarRequest: Sendable {
    var sourceURL: URL { get }
    var outputURL: URL { get }
    var presetName: String { get }
    var presetStrength: Double { get }
    /// M5-A.2: nil for the legacy preset-only path; a
    /// `FilmtoneCreativePackCatalog` slug when a Creative LUT Pack 01 Look
    /// is selected (Stone / Urban). The sidecar writer uses this to switch
    /// `lookId` namespace and emit the additive `creativeLut` block.
    var lookSlug: String? { get }
    var sourceKind: FilmtoneSourceKind { get }
}
