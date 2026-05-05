import Foundation

// M5-C.1: Camera Profile catalog parity with iOS canonical
// `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift`.
//
// Slug parity ("built-in:source-profile.<slug>") and englishName parity are
// the contract — Desktop and iOS must surface identical profile identities so
// the same source grades to the same color truth on both platforms.
//
// Desktop omits iOS's `.userImport` selection variant for P0 (no LUT library
// surface yet) and folds iOS's `.nativePolicy` / `.synthesized` impl
// distinction into a single `curve`-driven dispatch in
// FilmtoneSourceInputTransform — the user-visible contract is the slug, not
// the impl shape.

// MARK: - Selection (project state)

/// User-facing source profile selection. Auto resolves at probe time via
/// `FilmtoneSourceProfileCatalog.entry(forColorClass:)`. `.builtIn` carries
/// the `built-in:source-profile.<slug>` namespaced id.
enum CameraProfileSelection: Equatable, Sendable, Codable, Hashable {
    case auto
    case builtIn(catalogId: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case catalogId
    }

    private enum Kind: String, Codable {
        case auto
        case builtIn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .auto:
            self = .auto
        case .builtIn:
            let id = try container.decode(String.self, forKey: .catalogId)
            self = .builtIn(catalogId: id)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .auto:
            try container.encode(Kind.auto, forKey: .kind)
        case .builtIn(let id):
            try container.encode(Kind.builtIn, forKey: .kind)
            try container.encode(id, forKey: .catalogId)
        }
    }

    /// Sidecar/UI-facing identifier. `.auto` returns "auto"; `.builtIn`
    /// returns the catalog id (`built-in:source-profile.<slug>`).
    var identifierString: String {
        switch self {
        case .auto: return "auto"
        case .builtIn(let id): return id
        }
    }
}

// MARK: - Curves

/// Per-curve dispatch identifier. `nil` curve in a catalog entry means
/// "no input transform" (Rec.709 passthrough).
enum SourceProfileCurve: String, Codable, CaseIterable, Sendable {
    case appleLog              = "apple-log"
    case appleLog2             = "apple-log-2"
    case djiDLog               = "dji-dlog"
    case djiDLogM              = "dji-dlog-m"
    case canonCLog             = "canon-clog"
    case canonLog3CinemaGamut  = "canon-log3-cinema-gamut"
    case panasonicVLog         = "panasonic-vlog"
    case sonySLog3             = "sony-slog3"
}

// MARK: - Catalog entry

struct CameraProfileCatalogEntry: Equatable, Sendable {
    let id: String
    let englishName: String
    let curve: SourceProfileCurve?
    let detectionHint: SourceColorClassDTO?
    let bundled: Bool
    let immutable: Bool
}

// MARK: - Catalog

enum FilmtoneSourceProfileCatalog {
    /// Built-in entries. Order matters: this is the order the right-rail
    /// Picker presents them in (after the Auto sentinel row injected by UI).
    static let allProfiles: [CameraProfileCatalogEntry] = [
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.apple-log",
            englishName: "Apple Log",
            curve: .appleLog,
            detectionHint: .appleLog,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.apple-log-2",
            englishName: "Apple Log 2",
            curve: .appleLog2,
            detectionHint: .appleLog2,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.dji-dlog",
            englishName: "DJI D-Log",
            curve: .djiDLog,
            detectionHint: nil,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.dji-dlog-m",
            englishName: "DJI D-Log M",
            curve: .djiDLogM,
            detectionHint: nil,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.canon-clog",
            englishName: "Canon C-Log",
            curve: .canonCLog,
            detectionHint: nil,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.canon-log3-cinema-gamut",
            englishName: "Canon Log 3 / Cinema Gamut",
            curve: .canonLog3CinemaGamut,
            detectionHint: nil,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.panasonic-vlog",
            englishName: "V-Log",
            curve: .panasonicVLog,
            detectionHint: nil,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.sony-slog3",
            englishName: "S-Log3",
            curve: .sonySLog3,
            detectionHint: nil,
            bundled: true,
            immutable: true
        ),
        CameraProfileCatalogEntry(
            id: "built-in:source-profile.rec709",
            englishName: "Rec.709",
            curve: nil,
            detectionHint: .sdrBt709,
            bundled: true,
            immutable: true
        ),
    ]

    static func entry(forCatalogId id: String) -> CameraProfileCatalogEntry? {
        allProfiles.first(where: { $0.id == id })
    }

    /// Resolve a `.builtIn` selection. `.auto` returns nil — the auto path
    /// resolves through `entry(forColorClass:)` against the source probe.
    static func entry(for selection: CameraProfileSelection) -> CameraProfileCatalogEntry? {
        switch selection {
        case .auto:
            return nil
        case .builtIn(let catalogId):
            return entry(forCatalogId: catalogId)
        }
    }

    /// `.auto` resolution — match a source probe's `colorClass` to the
    /// catalog entry whose `detectionHint` covers it. Returns nil when no
    /// entry has a matching hint (the export pipeline falls through to
    /// passthrough semantics).
    static func entry(forColorClass colorClass: SourceColorClassDTO?) -> CameraProfileCatalogEntry? {
        guard let colorClass else { return nil }
        return allProfiles.first(where: { $0.detectionHint == colorClass })
    }
}
