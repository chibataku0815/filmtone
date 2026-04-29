import Foundation

/// Hard-coded constants for the Filmtone library subtree.
/// The library lives under `~/Library/Application Support/Filmtone/library/`
/// and is the durable store for imported LUTs and Saved Looks. SSOT is the
/// per-entry JSON files; `index.json` is a derived cache, rebuildable by a
/// directory scan if it is missing or version-mismatched.
enum FilmtoneLibraryConstants {
    /// Bumped when `LutLibraryEntry` / `SavedLookEntry` shape changes.
    static let entrySchemaVersion = 1
    /// Bumped when `LibraryIndex` shape changes.
    static let indexSchemaVersion = 1
    /// `dataFormat` payload for `.lutbin` blobs — little-endian Float32 RGB triples,
    /// `size³ × 3 × 4` bytes, no header (size lives in the JSON metadata).
    static let lutDataFormat = "f32le-rgb-v1"
    /// Cap for `recentLutIds` carried in the index. UI surfaces `recentLutDisplayCap`.
    static let recentLutCap = 12
    static let recentLutDisplayCap = 6
    /// Hard refusal threshold for the library subtree size. Beyond this the
    /// importer fails with a user-visible explanation rather than silently
    /// over-running Application Support quota.
    static let librarySubtreeQuotaBytes: Int64 = 200 * 1024 * 1024
}

/// UI hint for which slot an entry was originally imported into. Not enforced —
/// users can apply any LUT to either slot. Drives default-slot selection in
/// the Recent strip when no other signal is available.
enum SlotHint: String, Codable {
    case input
    case creative
    case any
}

/// Durable metadata for an imported LUT. The raw RGB triples live in the
/// sibling `.lutbin` blob (see `dataRef`); this struct never carries the data
/// payload itself so the JSON stays small and human-inspectable.
struct LutLibraryEntry: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let id: UUID
    var title: String
    /// SHA-256 of the normalized Float32 RGB stream. Whitespace-invariant
    /// across equivalent `.cube` files (parser produces the same data array
    /// regardless of source whitespace / comments). Used for dedup on import.
    let sourceHash: String
    let size: Int
    let createdAt: Date
    var lastUsedAt: Date?
    var favorite: Bool
    /// Filename of the binary blob in the same `luts/` directory.
    let dataRef: String
    /// `FilmtoneLibraryConstants.lutDataFormat` at write time.
    let dataFormat: String
    let originalFilename: String?
    var defaultIntensity: Double
    var preferredSlot: SlotHint
}

/// A Saved Look — a creative-state snapshot that travels with the user across
/// sources. Source-dependent normalization (input LUT, source URI, source
/// probe) is **not** part of the look — that lives on the project state and
/// is intentionally re-derived for each source.
struct SavedLookEntry: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    let presetName: String
    /// `FilmtonePhase0Math.presetVersion` at save time — used by importers to
    /// detect preset-recipe drift across app updates.
    let presetVersion: String
    let strength: Double
    let quickState: FilmtoneQuickState
    /// Param-override patch (relative to `deriveParams(presetName, strength,
    /// quickState)`). Replayed via `FilmtonePhase0Math.resolveParams` on apply.
    let paramOverrides: FilmtonePhase0ParamsPatch
    /// Creative-LUT binding. `nil` means the look explicitly clears any
    /// creative LUT (i.e. "this look uses Filmtone-only").
    let creativeLut: CreativeLutBinding?
    var favorite: Bool
    /// `<uuid>.jpg` in `Caches/Filmtone/library/thumbs/`. Deferred to Polish.
    var thumbnailRef: String?
}

/// Two flavors of creative-LUT reference inside a Saved Look:
/// - `.libraryRef` is the normal path — the look refers to a library entry
///   by id, with a per-look intensity. The library is SSOT for the LUT data.
/// - `.embedded` is the self-healing path — when a library LUT is deleted,
///   we inline the data into every look that referenced it. The look stays
///   playable even after the user wipes their library.
enum CreativeLutBinding: Codable, Equatable, Sendable {
    case libraryRef(id: UUID, intensity: Double)
    case embedded(lut: SavedLookEmbeddedLut, intensity: Double)

    private enum CodingKeys: String, CodingKey {
        case kind
        case libraryId
        case lut
        case intensity
    }

    private enum Kind: String, Codable {
        case libraryRef
        case embedded
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
        }
    }

    var intensity: Double {
        switch self {
        case .libraryRef(_, let intensity), .embedded(_, let intensity):
            return intensity
        }
    }

    var libraryId: UUID? {
        if case .libraryRef(let id, _) = self {
            return id
        }
        return nil
    }
}

/// Inline LUT data for an "orphan-recovered" look — only used when the
/// library entry behind a `libraryRef` was deleted and the look's binding
/// was rewritten in-place. Equivalent in shape to a parsed `.cube` body so
/// `applySavedLook` can treat it identically to a freshly-loaded library LUT.
struct SavedLookEmbeddedLut: Codable, Equatable, Sendable {
    let title: String
    let size: Int
    let data: [Double]
    let sourceHash: String
}

/// Rebuildable index file. If this file is missing, truncated, or the
/// `schemaVersion` doesn't match, the store falls back to a directory scan.
struct LibraryIndex: Codable, Sendable {
    let schemaVersion: Int
    let lutIds: [UUID]
    let lookIds: [UUID]
    let recentLutIds: [UUID]
    let generatedAt: Date
}

/// Main-actor-friendly snapshot of the library state, suitable for binding
/// to SwiftUI. All collections are pre-sorted by the store so the UI can
/// render directly without further work.
struct LibrarySnapshot: Equatable, Sendable {
    let luts: [LutLibraryEntry]
    let looks: [SavedLookEntry]
    let recentLutIds: [UUID]

    static let empty = LibrarySnapshot(luts: [], looks: [], recentLutIds: [])

    var lutById: [UUID: LutLibraryEntry] {
        var map: [UUID: LutLibraryEntry] = [:]
        for entry in luts {
            map[entry.id] = entry
        }
        return map
    }

    var recentLuts: [LutLibraryEntry] {
        let map = lutById
        return recentLutIds.compactMap { map[$0] }
    }

    func lutEntry(id: UUID) -> LutLibraryEntry? {
        luts.first(where: { $0.id == id })
    }

    func lookEntry(id: UUID) -> SavedLookEntry? {
        looks.first(where: { $0.id == id })
    }
}
