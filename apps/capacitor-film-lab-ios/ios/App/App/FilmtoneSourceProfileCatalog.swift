import Foundation

/// v1.3 Camera Profiles Phase D — compile-time catalog of the built-in
/// Camera Profile entries Filmtone ships with the app. Mirrors
/// `FilmtoneBuiltInCatalog` (Item 2 Look pack) in shape but lives in a
/// dedicated namespace per D-CP2 (Camera Profile entries are a sibling
/// ontology to `LutLibraryEntry`, not an extension of it).
///
/// v1.3 catalog cuts (D-CP1):
///
/// - `(P)` Apple Log → `nativePolicy(.appleLogToRec709)` — reuses the
///   existing `makeAppleLogToRec709Lut` Apple Log path in
///   `FilmtoneExportSession`.
/// - `(P)` Apple Log 2 → `nativePolicy(.appleLog2ToRec709)` — same path
///   under `rec2020GamutMap: true`. Apple Log 2 v1.3 ships with the
///   Rec.2020 matrix as a known limitation (D-CP6); v1.4 refines via
///   AVFoundation native gamut info.
/// - `(S)` V-Log → `synthesized(.panasonicVLog)` — Filmtone implements
///   the decoder + V-Gamut→Rec.709 matrix in `FilmtoneSourceProfileMath`.
///   Verified against `Tests/Fixtures/source-profile/panasonic-vlog/`.
/// - `(S)` S-Log3 → `synthesized(.sonySLog3)` — same shape, S-Gamut3.Cine
///   matrix. Verified against `Tests/Fixtures/source-profile/sony-slog3/`.
/// - Rec.709 → `nilProfile` — no input transform, source pixels assumed
///   to already live in the working color space.
///
/// `Auto` is intentionally NOT a catalog entry: it's a sentinel
/// `CameraProfileSelection.auto` that the UI / probe layer resolves at
/// export time. Treating it as a catalog row would conflate "user's
/// choice to defer" with "a concrete Source Profile" — the picker
/// (Phase F) renders it as a separate top-of-list item.
enum FilmtoneSourceProfileCatalog {
    static let allProfiles: [CameraProfileCatalogEntry] = [
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.apple-log",
            englishName: "Apple Log",
            curve: .appleLog,
            impl: .nativePolicy(.appleLogToRec709),
            detectionHint: .appleLog,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.apple-log-2",
            englishName: "Apple Log 2",
            curve: .appleLog2,
            impl: .nativePolicy(.appleLog2ToRec709),
            detectionHint: .appleLog2,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.panasonic-vlog",
            englishName: "V-Log",
            curve: .panasonicVLog,
            impl: .synthesized(.panasonicVLog),
            // V-Log cannot be reliably auto-detected from container
            // metadata (no logTransferFunction signal). detectionHint nil
            // means "user must explicitly pick it".
            detectionHint: nil,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.sony-slog3",
            englishName: "S-Log3",
            curve: .sonySLog3,
            impl: .synthesized(.sonySLog3),
            detectionHint: nil,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.rec709",
            englishName: "Rec.709",
            curve: nil,
            impl: .nilProfile,
            detectionHint: .sdrBt709,
            bundled: true,
            immutable: true
        ),
    ]

    static func entry(forCatalogId id: String) -> CameraProfileCatalogEntry? {
        allProfiles.first(where: { $0.id == id })
    }

    /// Resolve the catalog entry implied by a user selection. Returns nil
    /// for `.auto` (the auto path resolves through `entry(forColorClass:)`
    /// against the source probe instead) and for `.userImport` (no
    /// catalog row exists for user-imported `.cube` files).
    static func entry(for selection: CameraProfileSelection) -> CameraProfileCatalogEntry? {
        switch selection {
        case .auto, .userImport:
            return nil
        case .builtIn(let catalogId):
            return entry(forCatalogId: catalogId)
        }
    }

    /// `.auto` resolution — match a source probe's `colorClass` to the
    /// catalog entry whose `detectionHint` covers it. Returns nil when no
    /// entry has a matching hint (e.g. `unknown`/`unsupported` source —
    /// the export pipeline falls through to `nilProfile` semantics).
    static func entry(forColorClass colorClass: SourceColorClassDTO?) -> CameraProfileCatalogEntry? {
        guard let colorClass else { return nil }
        return allProfiles.first(where: { $0.detectionHint == colorClass })
    }
}
