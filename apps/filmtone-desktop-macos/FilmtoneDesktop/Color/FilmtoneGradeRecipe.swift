import FilmLabSwiftCore
import Foundation

enum FilmtoneGradeSelection: Equatable, Sendable {
    case builtIn(
        presetName: String,
        presetStrength: Double,
        lookSlug: String?,
        packageCreativeLut: PreparedCreativeLut?
    )
    case importedGrade(
        look: FilmtoneImportedGradeLook,
        sidecarURL: URL?,
        packageCreativeLut: PreparedCreativeLut?
    )

    var presetName: String {
        switch self {
        case .builtIn(let presetName, _, _, _):
            return presetName
        case .importedGrade:
            return FilmtonePresetCatalog.defaultName
        }
    }

    var presetStrength: Double {
        switch self {
        case .builtIn(_, let presetStrength, _, _):
            return FilmtonePresetCatalog.clampStrength(presetStrength)
        case .importedGrade:
            return FilmtonePresetCatalog.presetStrengthDefault
        }
    }

    var lookSlug: String? {
        switch self {
        case .builtIn(_, _, let lookSlug, _):
            return lookSlug
        case .importedGrade:
            return nil
        }
    }

    var packageCreativeLut: PreparedCreativeLut? {
        switch self {
        case .builtIn(_, _, _, let packageCreativeLut):
            return packageCreativeLut
        case .importedGrade(_, _, let packageCreativeLut):
            return packageCreativeLut
        }
    }

    var importedGradeLook: FilmtoneImportedGradeLook? {
        switch self {
        case .builtIn:
            return nil
        case .importedGrade(let look, _, _):
            return look
        }
    }

    var importedGradeSidecarURL: URL? {
        switch self {
        case .builtIn:
            return nil
        case .importedGrade(_, let sidecarURL, _):
            return sidecarURL
        }
    }

    var key: FilmtoneGradeSelectionKey {
        switch self {
        case .builtIn(let presetName, let presetStrength, let lookSlug, let packageCreativeLut):
            return .builtIn(
                presetName: presetName,
                presetStrength: FilmtonePresetCatalog.clampStrength(presetStrength),
                lookSlug: lookSlug,
                packageCreativeLutKey: packageCreativeLut?.identityKey
            )
        case .importedGrade(let look, let sidecarURL, let packageCreativeLut):
            return .importedGrade(
                id: look.id,
                fingerprint: Self.fingerprint(look),
                sidecarPath: sidecarURL?.standardizedFileURL.path,
                packageCreativeLutKey: packageCreativeLut?.identityKey
            )
        }
    }

    private static func fingerprint(_ look: FilmtoneImportedGradeLook) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(look) {
            return data.base64EncodedString()
        }
        return [
            look.id.uuidString,
            look.title,
            look.source.sourceKindLabel,
            look.unsupportedMetadata.joined(separator: "|"),
        ].joined(separator: "::")
    }
}

enum FilmtoneGradeSelectionKey: Hashable, Sendable {
    case builtIn(
        presetName: String,
        presetStrength: Double,
        lookSlug: String?,
        packageCreativeLutKey: String?
    )
    case importedGrade(
        id: UUID,
        fingerprint: String,
        sidecarPath: String?,
        packageCreativeLutKey: String?
    )
}

struct FilmtoneGradeRecipe: Equatable, Sendable {
    let selection: FilmtoneGradeSelection
    let quickState: FilmtoneQuickState
    let paramOverrides: FilmtonePhase0ParamsPatch
    let opticalFilterProfileId: String?
    let opticalFilterIntensity: Double

    init(
        selection: FilmtoneGradeSelection,
        quickState: FilmtoneQuickState = .zero,
        paramOverrides: FilmtonePhase0ParamsPatch = .empty,
        opticalFilterProfileId: String? = nil,
        opticalFilterIntensity: Double = 1.0
    ) {
        self.selection = selection
        self.quickState = quickState.clamped()
        self.paramOverrides = paramOverrides
        self.opticalFilterProfileId = opticalFilterProfileId
        self.opticalFilterIntensity = max(0, min(1, opticalFilterIntensity.isFinite ? opticalFilterIntensity : 1))
    }

    var key: FilmtoneGradeRecipeKey {
        FilmtoneGradeRecipeKey(
            selection: selection.key,
            quickState: quickState,
            paramOverrides: paramOverrides,
            opticalFilterProfileId: opticalFilterProfileId,
            opticalFilterIntensity: opticalFilterIntensity
        )
    }

    var presetName: String { selection.presetName }
    var presetStrength: Double { selection.presetStrength }
    var lookSlug: String? { selection.lookSlug }
    var packageCreativeLut: PreparedCreativeLut? { selection.packageCreativeLut }
    var importedGradeLook: FilmtoneImportedGradeLook? { selection.importedGradeLook }
    var importedGradeSidecarURL: URL? { selection.importedGradeSidecarURL }
}

struct FilmtoneGradeRecipeKey: Hashable, Sendable {
    let selection: FilmtoneGradeSelectionKey
    let quickState: FilmtoneQuickState
    let paramOverrides: FilmtonePhase0ParamsPatch
    let opticalFilterProfileId: String?
    let opticalFilterIntensity: Double
}
