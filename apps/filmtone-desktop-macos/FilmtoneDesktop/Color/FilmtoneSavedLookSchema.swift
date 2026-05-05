import FilmLabSwiftCore
import Foundation

// M5-C.2a: Saved Look library schema for Native Desktop v2.
//
// Looks-only port of iOS `FilmtoneLibrarySchema.swift`. The LUT-import
// half (LutLibraryEntry / SavedLookEmbeddedLut full body / quota constants)
// is intentionally deferred to the M5-C.2c P1 slice. CreativeLutBinding
// keeps all three iOS cases (`.libraryRef` / `.embedded` / `.bundled`)
// because the disk format must round-trip whatever iOS or a future
// Desktop slice writes; the Desktop runtime only walks `.bundled` /
// `nil` paths in this slice.

/// Hard-coded constants for the Filmtone library subtree.
/// The library lives under
/// `~/Library/Application Support/Filmtone/library/` — same root as iOS,
/// so a future cross-device sync is path-compatible without migration.
enum FilmtoneLibraryConstants {
    /// Mirrors the iOS canonical entry schema version (v1.3 / v1.4 entries).
    /// Bump in lockstep with iOS when the on-wire shape changes.
    static let entrySchemaVersion = 2
    /// Bumped when `LibraryIndex` shape changes.
    static let indexSchemaVersion = 1
}

/// A Saved Look — a creative-state snapshot that travels with the user
/// across sources. Source-dependent normalization (input LUT, source URI,
/// source probe) is not part of the look — that lives on EditorState and
/// is intentionally re-derived for each source.
struct SavedLookEntry: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    let presetName: String
    /// `FilmtonePresetCatalog.presetVersion` at save time. Importers use
    /// this to detect preset-recipe drift across app updates.
    let presetVersion: String
    let strength: Double
    let quickState: FilmtoneQuickState
    /// Param-override patch (relative to the preset/strength resolve).
    /// `.empty` until M5-C.3 introduces per-parameter editing UX.
    let paramOverrides: FilmtonePhase0ParamsPatch
    /// Creative-LUT binding. `nil` means "no creative LUT" (preset-only).
    let creativeLut: CreativeLutBinding?
    var favorite: Bool
    /// `<uuid>.jpg` in `Caches/Filmtone/library/thumbs/`. Deferred to a
    /// later polish slice — written here so the on-wire shape stays
    /// iOS-compatible.
    var thumbnailRef: String?
    /// True for built-in catalog entries (Stone / Urban). User-saved
    /// looks always have `bundled == false`.
    var bundled: Bool = false
    /// True when the entry refuses rename / delete in
    /// `FilmtoneSavedLookStore`. All bundled entries are immutable.
    var immutable: Bool = false
    /// Stable namespace slug for built-in looks
    /// (e.g. "filmtone-creative-pack-01-stone"). nil for user-saved
    /// looks.
    var bundledSlug: String? = nil
}

extension SavedLookEntry {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, createdAt, updatedAt
        case presetName, presetVersion, strength, quickState, paramOverrides
        case creativeLut, favorite, thumbnailRef
        case bundled, immutable, bundledSlug
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        self.presetName = try c.decode(String.self, forKey: .presetName)
        self.presetVersion = try c.decode(String.self, forKey: .presetVersion)
        self.strength = try c.decode(Double.self, forKey: .strength)
        self.quickState = try c.decode(FilmtoneQuickState.self, forKey: .quickState)
        self.paramOverrides = try c.decode(FilmtonePhase0ParamsPatch.self, forKey: .paramOverrides)
        self.creativeLut = try c.decodeIfPresent(CreativeLutBinding.self, forKey: .creativeLut)
        self.favorite = try c.decode(Bool.self, forKey: .favorite)
        self.thumbnailRef = try c.decodeIfPresent(String.self, forKey: .thumbnailRef)
        self.bundled = try c.decodeIfPresent(Bool.self, forKey: .bundled) ?? false
        self.immutable = try c.decodeIfPresent(Bool.self, forKey: .immutable) ?? false
        self.bundledSlug = try c.decodeIfPresent(String.self, forKey: .bundledSlug)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(presetName, forKey: .presetName)
        try c.encode(presetVersion, forKey: .presetVersion)
        try c.encode(strength, forKey: .strength)
        try c.encode(quickState, forKey: .quickState)
        try c.encode(paramOverrides, forKey: .paramOverrides)
        try c.encodeIfPresent(creativeLut, forKey: .creativeLut)
        try c.encode(favorite, forKey: .favorite)
        try c.encodeIfPresent(thumbnailRef, forKey: .thumbnailRef)
        try c.encode(bundled, forKey: .bundled)
        try c.encode(immutable, forKey: .immutable)
        try c.encodeIfPresent(bundledSlug, forKey: .bundledSlug)
    }
}

/// Three flavors of creative-LUT reference inside a Saved Look. Mirrors
/// iOS verbatim so cross-platform round-trip stays clean.
/// - `.libraryRef`: refers to a user-imported library entry by id (P1,
///   not yet wired on Desktop — decode-only path).
/// - `.embedded`: inline LUT data for an "orphan-recovered" look (P1
///   self-healing path; decode-only on Desktop).
/// - `.bundled`: app-bundled `.cube` (Stone / Urban). The active path on
///   Desktop. Resolution is deterministic from `(filename, sha256)`.
enum CreativeLutBinding: Codable, Equatable, Sendable {
    case libraryRef(id: UUID, intensity: Double)
    case embedded(lut: SavedLookEmbeddedLut, intensity: Double)
    case bundled(slug: String, filename: String, sha256: String, intensity: Double)

    private enum CodingKeys: String, CodingKey {
        case kind
        case libraryId
        case lut
        case intensity
        case slug
        case filename
        case sha256
    }

    private enum Kind: String, Codable {
        case libraryRef
        case embedded
        case bundled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let intensity = try container.decode(Double.self, forKey: .intensity)
        switch kind {
        case .libraryRef:
            let id = try container.decode(UUID.self, forKey: .libraryId)
            self = .libraryRef(id: id, intensity: intensity)
        case .embedded:
            let lut = try container.decode(SavedLookEmbeddedLut.self, forKey: .lut)
            self = .embedded(lut: lut, intensity: intensity)
        case .bundled:
            let slug = try container.decode(String.self, forKey: .slug)
            let filename = try container.decode(String.self, forKey: .filename)
            let sha256 = try container.decode(String.self, forKey: .sha256)
            self = .bundled(slug: slug, filename: filename, sha256: sha256, intensity: intensity)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .libraryRef(let id, let intensity):
            try container.encode(Kind.libraryRef, forKey: .kind)
            try container.encode(id, forKey: .libraryId)
            try container.encode(intensity, forKey: .intensity)
        case .embedded(let lut, let intensity):
            try container.encode(Kind.embedded, forKey: .kind)
            try container.encode(lut, forKey: .lut)
            try container.encode(intensity, forKey: .intensity)
        case .bundled(let slug, let filename, let sha256, let intensity):
            try container.encode(Kind.bundled, forKey: .kind)
            try container.encode(slug, forKey: .slug)
            try container.encode(filename, forKey: .filename)
            try container.encode(sha256, forKey: .sha256)
            try container.encode(intensity, forKey: .intensity)
        }
    }

    var intensity: Double {
        switch self {
        case .libraryRef(_, let intensity),
             .embedded(_, let intensity),
             .bundled(_, _, _, let intensity):
            return intensity
        }
    }

    var bundledSlug: String? {
        if case .bundled(let slug, _, _, _) = self {
            return slug
        }
        return nil
    }
}

/// Inline LUT data for an "orphan-recovered" look. Field shape mirrors
/// iOS so cross-platform round-trip stays clean — the Desktop runtime
/// never produces a `.embedded` binding in M5-C.2a (LUT library lands in
/// the M5-C.2c P1 slice).
struct SavedLookEmbeddedLut: Codable, Equatable, Sendable {
    let title: String
    let size: Int
    let data: [Double]
    let sourceHash: String
}

/// Rebuildable index file. If missing, truncated, or schema-mismatched
/// the store falls back to a directory scan. Mirrors iOS for path
/// compatibility — `lutIds` is empty on Desktop until M5-C.2c.
struct LibraryIndex: Codable, Sendable {
    let schemaVersion: Int
    let lutIds: [UUID]
    let lookIds: [UUID]
    let recentLutIds: [UUID]
    let generatedAt: Date
}

/// Main-actor-friendly snapshot of the library state. Built-in Looks
/// are prepended by the store so the UI can render the snapshot directly.
struct LibrarySnapshot: Equatable, Sendable {
    let looks: [SavedLookEntry]

    static let empty = LibrarySnapshot(looks: [])

    func lookEntry(id: UUID) -> SavedLookEntry? {
        looks.first(where: { $0.id == id })
    }
}

// `FilmtoneQuickState` and `FilmtonePhase0ParamsPatch` declare
// Codable + Equatable + Sendable conformance in the FilmLabSwiftCore
// package (M4-B Phase 2) so Swift can synthesize the witnesses —
// Sendable in particular must live in the declaring file, and Codable
// synthesis only works from the same file as well.
