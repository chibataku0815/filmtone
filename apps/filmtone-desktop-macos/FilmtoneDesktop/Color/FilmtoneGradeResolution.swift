import FilmLabSwiftCore
import Foundation

enum FilmtoneResolvedGradeSource: Equatable, Sendable {
    case builtIn(lookSlug: String?)
    case importedGrade(id: UUID, title: String, sourceKind: String)
}

struct FilmtoneResolvedGrade: Equatable, Sendable {
    let params: FilmtonePhase0Params
    let creativeLut: PreparedCreativeLut?
    let lutIntensity: Double
    let source: FilmtoneResolvedGradeSource
    let sourceGraph: FilmtoneImportedGradeSourceGraph?
    let unsupportedMetadata: [String]

    var sourceInfoForSidecar: [String: Any] {
        switch source {
        case .builtIn(let lookSlug):
            return [
                "kind": "built-in",
                "lookSlug": lookSlug as Any,
            ]
        case .importedGrade(let id, let title, let sourceKind):
            return [
                "kind": "imported-grade",
                "id": id.uuidString,
                "title": title,
                "sourceKind": sourceKind,
            ]
        }
    }
}

enum FilmtoneGradeResolution {
    static func resolve(recipe: FilmtoneGradeRecipe) -> FilmtoneResolvedGrade {
        switch recipe.selection {
        case .importedGrade(let importedGradeLook, let sidecarURL, let packageCreativeLut):
            let evaluated = FilmtoneImportedGradeEvaluator.evaluate(
                look: importedGradeLook,
                sidecarURL: sidecarURL
            )
            let withQuick = FilmtonePresetCatalog.applyQuickState(
                to: evaluated.params,
                quickState: recipe.quickState
            )
            let renderOverrides = FilmtoneOpticalFilterCatalog.renderParamOverrides(
                profileId: recipe.opticalFilterProfileId,
                intensity: recipe.opticalFilterIntensity,
                userOverrides: recipe.paramOverrides
            )
            let finalParams = renderOverrides.isEmpty
                ? withQuick
                : withQuick.applyingPatch(renderOverrides.normalized(over: withQuick))
            return FilmtoneResolvedGrade(
                params: finalParams,
                creativeLut: packageCreativeLut ?? evaluated.creativeLut,
                lutIntensity: packageCreativeLut.map { clamp01($0.intensity) } ?? evaluated.lutIntensity,
                source: .importedGrade(
                    id: importedGradeLook.id,
                    title: importedGradeLook.title,
                    sourceKind: importedGradeLook.source.sourceKindLabel
                ),
                sourceGraph: importedGradeLook.sourceGraph,
                unsupportedMetadata: evaluated.unsupportedMetadata
            )
        case .builtIn(let presetName, let presetStrength, let lookSlug, let packageCreativeLut):
            let params = FilmtonePresetCatalog.resolved(
                presetName: presetName,
                strength: presetStrength,
                lookSlug: lookSlug,
                quickState: recipe.quickState,
                opticalFilterProfileId: recipe.opticalFilterProfileId,
                opticalFilterIntensity: recipe.opticalFilterIntensity,
                paramOverrides: recipe.paramOverrides
            )
            return FilmtoneResolvedGrade(
                params: params,
                creativeLut: packageCreativeLut ?? bundledCreativeLut(lookSlug: lookSlug, strength: presetStrength),
                lutIntensity: packageCreativeLut.map { clamp01($0.intensity) }
                    ?? FilmtonePresetCatalog.clampStrength(presetStrength),
                source: .builtIn(lookSlug: lookSlug),
                sourceGraph: nil,
                unsupportedMetadata: []
            )
        }
    }

    static func resolve(
        presetName: String,
        presetStrength: Double,
        lookSlug: String?,
        quickState: FilmtoneQuickState,
        paramOverrides: FilmtonePhase0ParamsPatch,
        packageCreativeLut: PreparedCreativeLut?,
        importedGradeLook: FilmtoneImportedGradeLook?,
        opticalFilterProfileId: String?,
        opticalFilterIntensity: Double,
        importedGradeSidecarURL: URL? = nil
    ) -> FilmtoneResolvedGrade {
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
        return resolve(
            recipe: FilmtoneGradeRecipe(
                selection: selection,
                quickState: quickState,
                paramOverrides: paramOverrides,
                opticalFilterProfileId: opticalFilterProfileId,
                opticalFilterIntensity: opticalFilterIntensity
            )
        )
    }

    private static func bundledCreativeLut(
        lookSlug: String?,
        strength: Double
    ) -> PreparedCreativeLut? {
        guard let lookSlug,
              strength > 0,
              let look = FilmtoneCreativePackCatalog.find(slug: lookSlug) else {
            return nil
        }
        return FilmtoneCreativeLutLoader.load(look: look)
    }

    private static func clamp01(_ value: Double) -> Double {
        max(0, min(1, value.isFinite ? value : 1))
    }
}
