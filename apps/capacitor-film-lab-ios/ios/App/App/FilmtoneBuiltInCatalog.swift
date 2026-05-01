import Foundation

/// Static catalog of built-in Filmtone Looks shipped with the app bundle.
///
/// v1.3 (Item 2) ships 5 params-only Looks. None bundle a creative `.cube`
/// — every entry composes one of the 4 locked iOS preset names with a
/// curated Quick state and `FilmtonePhase0ParamsPatch`. v1.4+ may add
/// camera-profile fallback entries via `allLuts`.
///
/// Built-in entries are materialized into `SavedLookEntry` values at read
/// time via `LibraryStoreActor.savedLooksMerged()` (Phase C). They are not
/// persisted to `~/Library/Application Support/Filmtone/library/looks/` —
/// the catalog is the SSOT for both shape and identity. UserDefaults
/// holds favorite overrides keyed by `slug`.
enum FilmtoneBuiltInCatalog {
    /// v1.4 Creative LUT Pack 01 — pack identifier surfaced via
    /// `BuiltInLook.packId` and threaded into sidecar provenance as
    /// `bundledPackId`. v1.3 params-only entries leave `packId == nil`.
    static let creativePack01Id = "creative-pack-01"

    /// Catalog entry shape. Constructed inline in `allLooks` so adding a
    /// new built-in is a single struct literal plus its canonical UUID.
    struct BuiltInLook: Equatable, Sendable {
        let slug: String
        let canonicalUUID: UUID
        let englishName: String
        /// Must be one of `FilmtonePhase0Generated.paramsByName` keys
        /// (currently `reset` / `iphone` / `softBlue` / `amberGlow`).
        let presetName: String
        let strength: Double
        let quickState: FilmtoneQuickState
        let paramOverrides: FilmtonePhase0ParamsPatch
        /// nil for params-only entries. v1.4 Creative LUT Pack 01 entries
        /// carry a `.bundled` binding with the resource filename and the
        /// pinned SHA-256 of the cube bytes.
        let creativeLut: CreativeLutBinding?
        /// v1.4 Creative LUT Pack 01: pack identifier (e.g.
        /// `"creative-pack-01"`) used by `FilmtoneExportSidecarBuilder` to
        /// stamp `bundledPackId` onto the sidecar's `creativeLut` ref. nil
        /// for v1.3 params-only catalog entries.
        let packId: String?
    }

    /// v1.4+: bundled `.cube` Camera Profile catalog entries (V-Log,
    /// S-Log3, etc.). Empty in v1.3 — Source Profile work happens in the
    /// sibling Camera Profiles plan via `FilmtoneSourceProfileCatalog`.
    static let allLuts: [BuiltInLook] = []

    /// Built-in Looks that populate the Library Section chip strip.
    ///
    /// v1.3 originally shipped 5 entries. 4 of them (Filmtone Signature /
    /// Clean Base / Amber Glow / Soft Blue) were degenerate preset wrappers —
    /// `paramOverrides == .empty`, `quickState == .zero`, `creativeLut == nil`,
    /// so tapping the chip was byte-identical to tapping the underlying preset
    /// in the preset row. They were removed in v1.4 to keep the Look
    /// abstraction meaningful (a Look must add something to the preset:
    /// curated overrides, a bundled cube, or a non-zero quick state). UUIDs
    /// `...000001` – `...000004` are deprecated and intentionally not reused
    /// (see `BuiltInLookUUID`).
    ///
    /// Active catalog: two Creative LUTs. Stone is the Palermo Reference
    /// base; Urban is the Palermo Green Density derivative.
    static let allLooks: [BuiltInLook] = [
        // MARK: - Creative LUT Pack 01
        //
        // These entries bundle generated 65³ cubes under
        // `Resources/CreativeLuts/`. `paramOverrides` carries TWO things:
        //   1. The 12 color-only ops plus v2 split-tone strengths are pinned
        //      to neutral so the runtime kernel does not double-apply them on
        //      top of the cube — the cube is the SSOT for color expression.
        //   2. Lens-filter spatial overrides (rgbShift / halation / bloom /
        //      diffusion / lensSoftness / grain / vignette) provide the
        //      Filmtone optical signature around the cube. rgbShift (chromatic
        //      aberration) is a Filmtone signature effect — both built-in
        //      Looks pin a restrained value so the lens character is visible
        //      without crossing into novelty fringing.
        //
        // SHA-256 is pinned from `bun run scripts/build-creative-luts.ts
        // --regenerate` and mirrored in
        // `Tests/Fixtures/creative-pack-01/manifest.json`.
        BuiltInLook(
            slug: "filmtone-creative-pack-01-stone",
            canonicalUUID: BuiltInLookUUID.creativePack01Stone,
            englishName: "Stone",
            presetName: "reset",
            strength: 1.0,
            quickState: .zero,
            paramOverrides: FilmtoneBuiltInCatalog.creativePack01StonePatch,
            creativeLut: .bundled(
                slug: "filmtone-creative-pack-01-stone",
                filename: "filmtone-creative-pack-01-stone.cube",
                sha256: "005972db2dd07ff181e6256d11034ab76c8ef94782d1f2739e6c73971072bf45",
                intensity: 1.0
            ),
            packId: FilmtoneBuiltInCatalog.creativePack01Id
        ),
        BuiltInLook(
            slug: "filmtone-creative-pack-01-urban",
            canonicalUUID: BuiltInLookUUID.creativePack01Urban,
            englishName: "Urban",
            presetName: "reset",
            strength: 1.0,
            quickState: .zero,
            paramOverrides: FilmtoneBuiltInCatalog.creativePack01UrbanPatch,
            creativeLut: .bundled(
                slug: "filmtone-creative-pack-01-urban",
                filename: "filmtone-creative-pack-01-urban.cube",
                sha256: "9620492bf766675466da212f123289851d40f2420b2f51f56d4baf96f2dfb1ea",
                intensity: 1.0
            ),
            packId: FilmtoneBuiltInCatalog.creativePack01Id
        ),
    ]

    /// Color neutralization values shared by every Pack 01 patch.
    /// The cube is SSOT for color, so the runtime kernel must produce
    /// identity in these fields before the cube is sampled. `shadowTone`
    /// and `highlightTone` are included because v2 baseGrade applies them
    /// before the creative LUT stage.
    private static let creativePack01ColorOpNeutralEntries: [String: Double] = [
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

    /// Stone — generated 65³ cube plus a restrained optical
    /// baseline. Color stays in the cube; these values carry lens behavior.
    static let creativePack01StonePatch: FilmtonePhase0ParamsPatch = {
        var values = creativePack01ColorOpNeutralEntries
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

    /// Urban — generated 65³ cube plus a restrained optical baseline.
    /// Color stays in the cube; these values carry lens behavior.
    static let creativePack01UrbanPatch: FilmtonePhase0ParamsPatch = {
        var values = creativePack01ColorOpNeutralEntries
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

    /// Returns the built-in Look matching a canonical UUID, or `nil` for
    /// a UUID that belongs to a user-saved entry. Used by the library
    /// dispatch in Phase C to decide whether to materialize from the
    /// catalog or load from disk.
    static func look(matching id: UUID) -> BuiltInLook? {
        return allLooks.first { $0.canonicalUUID == id }
    }

    /// Returns the slug for a built-in Look's canonical UUID, or `nil`
    /// for non-built-in ids.
    static func slug(for id: UUID) -> String? {
        return look(matching: id)?.slug
    }

    /// Materialize a `BuiltInLook` into a `SavedLookEntry` so the library
    /// merge can return a uniform list to the UI. `favoriteOverride`
    /// comes from the UserDefaults built-in favorites map (set in
    /// Phase C); `asOf` lets callers pin createdAt/updatedAt to a stable
    /// date (typically the bundle build date) so re-launching doesn't
    /// reshuffle the chip strip.
    static func materializeAsSavedLookEntry(
        _ builtIn: BuiltInLook,
        favoriteOverride: Bool,
        asOf: Date
    ) -> SavedLookEntry {
        return SavedLookEntry(
            schemaVersion: FilmtoneLibraryConstants.entrySchemaVersion,
            id: builtIn.canonicalUUID,
            name: builtIn.englishName,
            createdAt: asOf,
            updatedAt: asOf,
            presetName: builtIn.presetName,
            presetVersion: FilmtonePhase0Math.presetVersion,
            strength: builtIn.strength,
            quickState: builtIn.quickState,
            paramOverrides: builtIn.paramOverrides,
            creativeLut: builtIn.creativeLut,
            favorite: favoriteOverride,
            thumbnailRef: nil,
            bundled: true,
            immutable: true,
            bundledSlug: builtIn.slug
        )
    }
}

enum FilmtoneCreativePack01Adaptation {
    struct Resolved {
        let intensity: Double
        let paramOverrides: FilmtonePhase0ParamsPatch
    }

    static func resolve(
        slug: String,
        descriptor: FilmtoneSourceToneDescriptor?
    ) -> Resolved? {
        // Material-adaptive adjustments stay disabled until the flagship LUT
        // is visually signed off on device.
        return nil
    }
}

/// Hardcoded canonical UUIDs for each built-in Look. UUIDv4 prefix
/// `FB1A` namespaces these so they cannot collide with random user
/// `LutLibraryEntry.id` UUIDs (collision probability ~2^-120). Stay
/// stable across app versions; bump `FilmtonePhase0Math.presetVersion`
/// instead when a built-in's recipe meaningfully changes.
private enum BuiltInLookUUID {
    // v1.3 deprecated reservations — degenerate preset wrappers removed in
    // v1.4. UUIDs are intentionally NOT reused so that any user upgrading
    // with these slugs in `filmtone.builtinLookFavorites` UserDefaults gets
    // a silent skip via `look(matching:) == nil` rather than colliding with
    // a different Look:
    //   FB1A0001-0000-4000-8000-000000000001 — Filmtone Signature (= preset iphone)
    //   FB1A0001-0000-4000-8000-000000000002 — Clean Base (= preset reset)
    //   FB1A0001-0000-4000-8000-000000000003 — Amber Glow (= preset amberGlow)
    //   FB1A0001-0000-4000-8000-000000000004 — Soft Blue (= preset softBlue)

    //   FB1A0001-0000-4000-8000-000000000005 — reserved by a retired low-light
    //   built-in Look while the base Creative LUT is being rebuilt.
    //
    // v1.4 Creative LUT Pack 01 reservations (active entries mirrored in
    // `packages/film-lab-core/src/creative-pack-01.ts` so TS / Swift / sidecar
    // share a single canonical id per Look).
    // `...000008` and `...000009` are intentionally not reused after CD
    // removal of the weak sampler entries.
    static let creativePack01Stone = UUID(uuidString: "FB1A0001-0000-4000-8000-000000000006")!
    static let creativePack01Urban = UUID(uuidString: "FB1A0001-0000-4000-8000-000000000007")!
}
