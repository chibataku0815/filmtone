import FilmLabSwiftCore
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
    /// M5-C.1: source profile selection — `.auto` (resolves at probe time)
    /// or `.builtIn(catalogId:)`. Default = `.auto` for protocol-level
    /// backward compatibility; existing callers see no behavior change.
    var sourceProfileSelection: CameraProfileSelection { get }
    /// M5-C.3a: Quick adjust 3-axis offsets folded into the resolved
    /// render params. Default = `.zero` so existing callers see no
    /// behavior change; new export call sites thread live state through.
    var quickState: FilmtoneQuickState { get }
    /// M5-C.3a: per-key parameter override patch applied between the
    /// preset/look resolve and the quick-state pass. Default = `.empty`.
    var paramOverrides: FilmtonePhase0ParamsPatch { get }
}

extension FilmtoneSidecarRequest {
    var sourceProfileSelection: CameraProfileSelection { .auto }
    var quickState: FilmtoneQuickState { .zero }
    var paramOverrides: FilmtonePhase0ParamsPatch { .empty }
}
