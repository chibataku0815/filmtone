import Foundation

// Hand-port of the iOS Creative LUT Pack 01 catalog
// (`FilmtoneBuiltInCatalog.swift`). Only the two active built-in Looks are
// included — Stone and Urban. UUIDs and pinned SHA-256 mirror the iOS
// fixtures manifest at
// `apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json`,
// so a Look's identity is stable across iOS / Desktop / sidecar.
//
// `paramOverrides` carries TWO things (mirrored from iOS comments):
//   1. The 12 color-only ops plus v2 split-tone strengths are pinned to
//      neutral so the runtime grade kernel does not double-apply them on
//      top of the cube — the cube is the SSOT for color expression.
//   2. Lens-filter spatial overrides (rgbShift / halation / bloom /
//      diffusion / lensSoftness / grain / vignette) provide the Filmtone
//      optical signature around the cube.

enum FilmtoneCreativePackCatalog {
    static let cubeSize = 65
    static let packId = "creative-pack-01"

    struct BuiltInLook: Equatable {
        let slug: String
        let canonicalUUID: UUID
        let englishName: String
        /// Bundled cube filename inside `Resources/CreativeLuts/`. Always
        /// resolved via `Bundle.main.url(forResource:withExtension:
        /// subdirectory:"CreativeLuts")` so a yellow-folder PBXGroup is
        /// required (blue folder references break the resolver).
        let bundledFilename: String
        let pinnedSha256: String
        /// Cube intensity is pinned to 1.0 for v1.4 Pack 01 — the cube is
        /// the SSOT for color expression and there is no UI for a second
        /// intensity axis. Strength slider operates in preset-blend space.
        let intensity: Double
        let packId: String
        let paramOverridesPatch: FilmtonePhase0ParamsPatch
    }

    /// Color-op neutralization shared by every Pack 01 patch. Mirrors
    /// `creativePack01ColorOpNeutralEntries` in iOS.
    private static let colorOpNeutralEntries: [String: Double] = [
        "exposure": 0,
        "contrast": 1,
        "saturation": 1,
        "temperature": 0,
        "tint": 0,
        "fade": 0,
        "compressionAmount": 0,
        "compressionRange": 0.5,
        "printContrast": 0,
        "cyan": 0,
        "magenta": 0,
        "yellow": 0,
        "shadowTone": 0,
        "highlightTone": 0,
    ]

    private static let stonePatch: FilmtonePhase0ParamsPatch = {
        var values = colorOpNeutralEntries
        values["rgbShift"] = 0.0032
        values["bloomThreshold"] = 0.64
        values["bloomStrength"] = 0.20
        values["bloomRadius"] = 0.62
        values["halationIntensity"] = 0.07
        values["halationHue"] = 24
        values["diffusion"] = 0.06
        values["lensSoftness"] = 0.095
        values["grainIntensity"] = 0.0045
        values["grainSize"] = 0.13
        values["vignette"] = 0.055
        return FilmtonePhase0ParamsPatch(values: values)
    }()

    private static let urbanPatch: FilmtonePhase0ParamsPatch = {
        var values = colorOpNeutralEntries
        values["rgbShift"] = 0.0028
        values["bloomThreshold"] = 0.66
        values["bloomStrength"] = 0.18
        values["bloomRadius"] = 0.58
        values["halationIntensity"] = 0.055
        values["halationHue"] = 20
        values["diffusion"] = 0.065
        values["lensSoftness"] = 0.095
        values["grainIntensity"] = 0.0045
        values["grainSize"] = 0.13
        values["vignette"] = 0.06
        return FilmtonePhase0ParamsPatch(values: values)
    }()

    static let all: [BuiltInLook] = [
        BuiltInLook(
            slug: "filmtone-creative-pack-01-stone",
            canonicalUUID: UUID(uuidString: "FB1A0001-0000-4000-8000-000000000006")!,
            englishName: "Stone",
            bundledFilename: "filmtone-creative-pack-01-stone.cube",
            pinnedSha256: "2f9e0240450b1b5fe1e78ca88017509eb1c50a050c4a02723a36ac651c9393c4",
            intensity: 1.0,
            packId: packId,
            paramOverridesPatch: stonePatch
        ),
        BuiltInLook(
            slug: "filmtone-creative-pack-01-urban",
            canonicalUUID: UUID(uuidString: "FB1A0001-0000-4000-8000-000000000007")!,
            englishName: "Urban",
            bundledFilename: "filmtone-creative-pack-01-urban.cube",
            pinnedSha256: "fefd48a796ff724fb23b2741ac14ed0c4453b24215ca7535680ad4ca043aaa44",
            intensity: 1.0,
            packId: packId,
            paramOverridesPatch: urbanPatch
        ),
    ]

    static func find(slug: String) -> BuiltInLook? {
        all.first { $0.slug == slug }
    }

    static func find(canonicalUUID id: UUID) -> BuiltInLook? {
        all.first { $0.canonicalUUID == id }
    }

    /// Stable as-of date stamped onto materialized built-in
    /// `SavedLookEntry` values so re-launching doesn't reshuffle the
    /// chip strip ordering. Mirrors the iOS Pack 01 freeze date.
    private static let pack01FreezeDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 30
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return Calendar(identifier: .gregorian).date(from: components)
            ?? Date(timeIntervalSince1970: 0)
    }()

    /// Materialize a built-in catalog entry as a `SavedLookEntry` so the
    /// library snapshot can return a uniform list to the UI. Mirrors iOS
    /// `FilmtoneBuiltInCatalog.materializeAsSavedLookEntry`. Built-ins
    /// are never persisted to disk — they live in code; this adapter
    /// exists only so the snapshot list shape is uniform.
    static func materializeAsSavedLookEntry(_ builtIn: BuiltInLook) -> SavedLookEntry {
        return SavedLookEntry(
            schemaVersion: FilmtoneLibraryConstants.entrySchemaVersion,
            id: builtIn.canonicalUUID,
            name: builtIn.englishName,
            createdAt: pack01FreezeDate,
            updatedAt: pack01FreezeDate,
            presetName: FilmtonePresetCatalog.defaultName,
            presetVersion: FilmtonePresetCatalog.presetVersion,
            strength: 1.0,
            quickState: .zero,
            paramOverrides: builtIn.paramOverridesPatch,
            creativeLut: .bundled(
                slug: builtIn.slug,
                filename: builtIn.bundledFilename,
                sha256: builtIn.pinnedSha256,
                intensity: builtIn.intensity
            ),
            favorite: false,
            thumbnailRef: nil,
            bundled: true,
            immutable: true,
            bundledSlug: builtIn.slug
        )
    }
}
