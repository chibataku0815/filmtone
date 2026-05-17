import FilmLabSwiftCore
import Foundation

// Hand-port of the iOS Creative LUT Pack 01 catalog
// (`FilmtoneBuiltInCatalog.swift`). UUIDs and pinned SHA-256 mirror the iOS
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
    static let expectedProcessSpace = "display-rec709-normalized"

    struct BuiltInLook: Equatable {
        let slug: String
        let canonicalUUID: UUID
        let englishName: String
        let expectedProcessSpace: String
        let rec709SafeIntensityCeiling: Double
        /// Bundled cube filename inside `Resources/CreativeLuts/`. Always
        /// resolved via `Bundle.main.url(forResource:withExtension:
        /// subdirectory:"CreativeLuts")` so a yellow-folder PBXGroup is
        /// required (blue folder references break the resolver).
        let bundledFilename: String
        let pinnedSha256: String
        /// Source-aware Rec.709 / unknown-display safe color variant.
        /// Optical / glow parameters stay in `paramOverridesPatch`; this
        /// binding changes only the bundled color cube selected at render time.
        let rec709SafeBundledFilename: String
        let rec709SafePinnedSha256: String
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
        "toeContrast": 0,
        "blackPoint": 0,
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

    private static let noirPatch: FilmtonePhase0ParamsPatch = {
        var values = colorOpNeutralEntries
        values["rgbShift"] = 0
        values["bloomThreshold"] = 0.56
        values["bloomStrength"] = 0.2
        values["bloomRadius"] = 0.64
        values["halationIntensity"] = 0.028
        values["halationHue"] = 36
        values["diffusion"] = 0.13
        values["lensSoftness"] = 0.16
        values["grainRadialMix"] = 0.9
        values["grainIntensity"] = 0.075
        values["grainSize"] = 0.48
        values["vignette"] = 0.16
        return FilmtonePhase0ParamsPatch(values: values)
    }()

    static let all: [BuiltInLook] = [
        BuiltInLook(
            slug: "filmtone-creative-pack-01-stone",
            canonicalUUID: UUID(uuidString: "FB1A0001-0000-4000-8000-000000000006")!,
            englishName: "Stone",
            expectedProcessSpace: expectedProcessSpace,
            rec709SafeIntensityCeiling: 0.86,
            bundledFilename: "filmtone-creative-pack-01-stone.cube",
            pinnedSha256: "b533a08cdc7ad7f563865bce758ec589bad966860d539d39b9d08165ee6e37ad",
            rec709SafeBundledFilename: "filmtone-creative-pack-01-stone-rec709-safe.cube",
            rec709SafePinnedSha256: "65aa4c8294361cf1c55fcb9c5c7bb357b9e6ead08778c043885e86d336e49dbe",
            intensity: 1.0,
            packId: packId,
            paramOverridesPatch: stonePatch
        ),
        BuiltInLook(
            slug: "filmtone-creative-pack-01-urban",
            canonicalUUID: UUID(uuidString: "FB1A0001-0000-4000-8000-000000000007")!,
            englishName: "Urban",
            expectedProcessSpace: expectedProcessSpace,
            rec709SafeIntensityCeiling: 0.84,
            bundledFilename: "filmtone-creative-pack-01-urban.cube",
            pinnedSha256: "880737a9f73f2e171779328707daef92a98bce3c612fa83c9817fc0980105760",
            rec709SafeBundledFilename: "filmtone-creative-pack-01-urban-rec709-safe.cube",
            rec709SafePinnedSha256: "e958a500f0d7f9ffe4c77143be60691b248ccf688a727c8ee4b8b09110805505",
            intensity: 1.0,
            packId: packId,
            paramOverridesPatch: urbanPatch
        ),
        BuiltInLook(
            slug: "filmtone-creative-pack-01-noir",
            canonicalUUID: UUID(uuidString: "FB1A0001-0000-4000-8000-000000000010")!,
            englishName: "Noir",
            expectedProcessSpace: expectedProcessSpace,
            rec709SafeIntensityCeiling: 0.92,
            bundledFilename: "filmtone-creative-pack-01-noir.cube",
            pinnedSha256: "50f4d1d14b4cec964c6e100d86af5777a32c6dd976a13e9fc6b4b261bf7a72fa",
            rec709SafeBundledFilename: "filmtone-creative-pack-01-noir-rec709-safe.cube",
            rec709SafePinnedSha256: "f8f321d576f17045861e81441c0e17d303ec31b6243c26b59c31734c7d6057ea",
            intensity: 1.0,
            packId: packId,
            paramOverridesPatch: noirPatch
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
