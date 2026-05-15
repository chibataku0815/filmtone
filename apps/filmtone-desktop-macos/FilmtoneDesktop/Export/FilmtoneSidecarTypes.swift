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
    /// is selected (Stone / Urban / Noir). The sidecar writer uses this to switch
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
    /// Source-bound custom LUT from an imported iOS capture package.
    var packageCreativeLut: PreparedCreativeLut? { get }
    /// DB-M13: selected Imported Grade, if the render came from the
    /// DaVinci/Imported Grade library instead of a built-in Look.
    var importedGradeLook: FilmtoneImportedGradeLook? { get }
    var importedGradeSidecarURL: URL? { get }
    /// DB-M13+: canonical grade recipe consumed by preview/export/sidecar.
    /// Legacy protocol fields stay available during migration, but runtime
    /// surfaces should prefer this value object to avoid per-surface resolve
    /// drift.
    var gradeRecipe: FilmtoneGradeRecipe { get }
    /// iOS capture-package provenance to carry into Desktop sidecars.
    var capturePackageProvenance: FilmtoneCapturePackageProvenance? { get }
    /// Source-relative highlight markers shared with iOS and DaVinci.
    var highlightMarkers: FilmtoneHighlightMarkers? { get }
    /// M5-L3: optional named optical filter profile. Stored separately
    /// from `paramOverrides` so sidecar metadata can preserve identity
    /// while grade params still resolve through the existing patch path.
    var opticalFilterProfileId: String? { get }
    /// M5-M (CC-B): continuous intensity scalar for the optical filter profile
    /// (0…1). Default 1.0 → M5-L3 chip-only behavior. Omitted from sidecar
    /// when 1.0 for backward compatibility.
    var opticalFilterIntensity: Double { get }
    /// Explicit video timing mode for video exports. Stills default to normal.
    var videoTimingMode: FilmtoneVideoTimingMode { get }
}

extension FilmtoneSidecarRequest {
    var sourceProfileSelection: CameraProfileSelection { .auto }
    var quickState: FilmtoneQuickState { .zero }
    var paramOverrides: FilmtonePhase0ParamsPatch { .empty }
    var packageCreativeLut: PreparedCreativeLut? { nil }
    var importedGradeLook: FilmtoneImportedGradeLook? { nil }
    var importedGradeSidecarURL: URL? { nil }
    var gradeRecipe: FilmtoneGradeRecipe {
        let selection: FilmtoneGradeSelection
        if let importedGradeLook {
            selection = .importedGrade(
                look: importedGradeLook,
                sidecarURL: importedGradeSidecarURL,
                packageCreativeLut: packageCreativeLut
            )
        } else {
            selection = .builtIn(
                presetName: presetName,
                presetStrength: presetStrength,
                lookSlug: lookSlug,
                packageCreativeLut: packageCreativeLut
            )
        }
        return FilmtoneGradeRecipe(
            selection: selection,
            quickState: quickState,
            paramOverrides: paramOverrides,
            opticalFilterProfileId: opticalFilterProfileId,
            opticalFilterIntensity: opticalFilterIntensity
        )
    }
    var capturePackageProvenance: FilmtoneCapturePackageProvenance? { nil }
    var highlightMarkers: FilmtoneHighlightMarkers? { nil }
    var opticalFilterProfileId: String? { nil }
    var opticalFilterIntensity: Double { 1.0 }
    var videoTimingMode: FilmtoneVideoTimingMode { .normal }
}
