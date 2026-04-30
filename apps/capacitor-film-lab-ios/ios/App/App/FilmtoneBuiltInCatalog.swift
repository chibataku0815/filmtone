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
        /// nil for v1.3 (params-only). v1.4 may add bundled creative
        /// `.cube` looks; in that case `creativeLut` would carry an
        /// `.embedded` binding pointing at bundle resource data.
        let creativeLut: CreativeLutBinding?
    }

    /// v1.4+: bundled `.cube` Camera Profile catalog entries (V-Log,
    /// S-Log3, etc.). Empty in v1.3 — Source Profile work happens in the
    /// sibling Camera Profiles plan via `FilmtoneSourceProfileCatalog`.
    static let allLuts: [BuiltInLook] = []

    /// 5 built-in Looks that populate the Library Section chip strip.
    /// Order is the visual order in the chip strip (Filmtone Signature
    /// pinned first as the canonical reference look).
    static let allLooks: [BuiltInLook] = [
        BuiltInLook(
            slug: "filmtone-signature",
            canonicalUUID: BuiltInLookUUID.filmtoneSignature,
            englishName: "Filmtone Signature",
            presetName: "iphone",
            strength: 1.0,
            quickState: .zero,
            paramOverrides: .empty,
            creativeLut: nil
        ),
        BuiltInLook(
            slug: "clean-base",
            canonicalUUID: BuiltInLookUUID.cleanBase,
            englishName: "Clean Base",
            presetName: "reset",
            strength: 1.0,
            quickState: .zero,
            paramOverrides: .empty,
            creativeLut: nil
        ),
        BuiltInLook(
            slug: "amber-glow",
            canonicalUUID: BuiltInLookUUID.amberGlow,
            englishName: "Amber Glow",
            presetName: "amberGlow",
            strength: 1.0,
            quickState: .zero,
            paramOverrides: .empty,
            creativeLut: nil
        ),
        BuiltInLook(
            slug: "soft-blue",
            canonicalUUID: BuiltInLookUUID.softBlue,
            englishName: "Soft Blue",
            presetName: "softBlue",
            strength: 1.0,
            quickState: .zero,
            paramOverrides: .empty,
            creativeLut: nil
        ),
        // Night Soft is the one curated variant in v1.3 — softBlue base
        // with elevated halation/bloom + slight desat for low-light
        // scenes (street lights, lit windows). Quick state stays neutral
        // for v1.3; refinement on real low-light footage scheduled.
        BuiltInLook(
            slug: "night-soft",
            canonicalUUID: BuiltInLookUUID.nightSoft,
            englishName: "Night Soft",
            presetName: "softBlue",
            strength: 1.0,
            quickState: .zero,
            // v1.4 Night Soft — flipped from "cool low-light" to "warm
            // intimate candlelight" per CD reference (Mourning Mirror frames:
            // 93% pure black + warm amber rembrandt key light). Pulls down to
            // softBlue base then overrides nearly every tonal/spatial field
            // because Mourning is the inverse of Cinestill — same low-light
            // class, opposite color temperature. shadowTone=0 so blacks stay
            // pure black (no shadow lift / no shadow color injection — the
            // dramatic chiaroscuro reads as such).
            paramOverrides: FilmtonePhase0ParamsPatch(values: [
                "exposure": 0.06,
                "contrast": 1.18,
                "saturation": 0.94,
                "temperature": 0.10,
                "halationIntensity": 0.18,
                "halationHue": 35,
                "bloomStrength": 0.36,
                "fade": 0.02,
                "shadowTone": 0,
                "highlightTone": 0.22,
                "highlightHue": 30,
                "compressionAmount": 0.55,
            ]),
            creativeLut: nil
        ),
    ]

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

/// Hardcoded canonical UUIDs for each built-in Look. UUIDv4 prefix
/// `FB1A` namespaces these so they cannot collide with random user
/// `LutLibraryEntry.id` UUIDs (collision probability ~2^-120). Stay
/// stable across app versions; bump `FilmtonePhase0Math.presetVersion`
/// instead when a built-in's recipe meaningfully changes.
private enum BuiltInLookUUID {
    static let filmtoneSignature = UUID(uuidString: "FB1A0001-0000-4000-8000-000000000001")!
    static let cleanBase         = UUID(uuidString: "FB1A0001-0000-4000-8000-000000000002")!
    static let amberGlow         = UUID(uuidString: "FB1A0001-0000-4000-8000-000000000003")!
    static let softBlue          = UUID(uuidString: "FB1A0001-0000-4000-8000-000000000004")!
    static let nightSoft         = UUID(uuidString: "FB1A0001-0000-4000-8000-000000000005")!
}
