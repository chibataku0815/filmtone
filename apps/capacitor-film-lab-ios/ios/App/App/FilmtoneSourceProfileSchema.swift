import Foundation

// MARK: - Camera Profile selection (project state)

/// v1.3 Camera Profiles Phase A — user-facing Camera Profile selection that
/// lives on `FilmtoneProjectState`. Distinct from `LutLibraryEntry`'s
/// content-addressed model on purpose (D-CP2): (P) Apple Log paths and (S)
/// V-Log/S-Log3 synthesized curves do not have a `dataRef` blob, so mixing
/// the two ontologies into a single `LutLibraryEntry` would pollute the
/// content-hash invariants enforced by `FilmtoneLutBlobCodec`.
///
/// Wire format is a discriminated union — `kind` selects the case, the
/// associated payload follows. Encoded bytes:
///
///     { "kind": "auto" }
///     { "kind": "builtIn",      "catalogId": "built-in:source-profile.panasonic-vlog" }
///     { "kind": "userImport",   "libraryId": "12345678-..." }
///
/// V1.2 saves decode unchanged because `cameraProfile` is an additive
/// optional on `FilmtoneProjectState` with `decodeIfPresent ?? .auto`.
/// `Profile.version` stays at 4 (CLAUDE.md §5).
enum CameraProfileSelection: Equatable, Sendable, Codable {
    /// Automatic detection — current behaviour. Resolves to Apple Log /
    /// Apple Log 2 / Rec.709 from the source probe at export time. v1.3 does
    /// not auto-detect V-Log / S-Log3 (no reliable container metadata).
    case auto
    /// Built-in catalog entry. The `catalogId` is the namespaced string
    /// (`"built-in:source-profile.<slug>"`) — kept as a `String` rather than
    /// a `UUID` to avoid collision concern with user `LutLibraryEntry.id`
    /// UUID v4 random space.
    case builtIn(catalogId: String)
    /// User-imported `.cube` from the LUT library. Held as a UUID so the
    /// library actor can resolve the entry directly.
    case userImport(libraryId: UUID)

    private enum CodingKeys: String, CodingKey {
        case kind
        case catalogId
        case libraryId
    }

    private enum Kind: String, Codable {
        case auto
        case builtIn
        case userImport
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
        case .userImport:
            let id = try container.decode(UUID.self, forKey: .libraryId)
            self = .userImport(libraryId: id)
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
        case .userImport(let id):
            try container.encode(Kind.userImport, forKey: .kind)
            try container.encode(id, forKey: .libraryId)
        }
    }
}

// MARK: - Source Profile curves

/// Manufacturer log curves Filmtone implements internally as `(S)
/// Synthesized` — the math is transcribed from manufacturer reference docs
/// and verified against calibrated ramp + Macbeth ΔE2000 fixtures (D-CP5).
/// Apple Log / Apple Log 2 are present here so the catalog entry can name
/// the curve uniformly even though their pipeline is `(P) nativePolicy`.
enum SourceProfileCurve: String, Codable, CaseIterable, Sendable {
    case appleLog       = "apple-log"
    case appleLog2      = "apple-log-2"
    case panasonicVLog  = "panasonic-vlog"
    case sonySLog3      = "sony-slog3"
}

// MARK: - Source Profile implementation strategy

/// Discriminator for how a Camera Profile entry actually drives the export
/// pipeline. The four cases are:
///
/// - `.nilProfile` — no input transform; the source pixels are already in
///   the working color space (Rec.709 SDR passthrough).
/// - `.nativePolicy` — reuse the existing `SourceInputTransformStrategyDTO`
///   path. Apple Log / Apple Log 2 ride this lane, sharing
///   `makeAppleLogToRec709Lut` from `FilmtoneExportSession`.
/// - `.synthesized` — Filmtone-implemented decoder + gamut matrix +
///   `filmtoneSdrShoulder` + Rec.709 encode. V-Log and S-Log3 ride this
///   lane (Camera Profiles Phases B and C). Each (S) curve must ship with
///   a math doc + accuracy fixture + accuracy test in the same PR.
/// - `.bundledCube` — bundled `.cube` resolved from the LUT library by id.
///   Reserved for v1.4+ (e.g. ARRI LogC4 once licensed); v1.3 catalog
///   never selects this case.
enum SourceProfileImpl: Equatable, Sendable, Codable {
    case nilProfile
    case nativePolicy(SourceInputTransformStrategyDTO)
    case synthesized(SourceProfileCurve)
    case bundledCube(libraryId: UUID)

    private enum CodingKeys: String, CodingKey {
        case kind
        case strategy
        case curve
        case libraryId
    }

    private enum Kind: String, Codable {
        case nilProfile
        case nativePolicy
        case synthesized
        case bundledCube
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .nilProfile:
            self = .nilProfile
        case .nativePolicy:
            let strategy = try container.decode(SourceInputTransformStrategyDTO.self, forKey: .strategy)
            self = .nativePolicy(strategy)
        case .synthesized:
            let curve = try container.decode(SourceProfileCurve.self, forKey: .curve)
            self = .synthesized(curve)
        case .bundledCube:
            let id = try container.decode(UUID.self, forKey: .libraryId)
            self = .bundledCube(libraryId: id)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .nilProfile:
            try container.encode(Kind.nilProfile, forKey: .kind)
        case .nativePolicy(let strategy):
            try container.encode(Kind.nativePolicy, forKey: .kind)
            try container.encode(strategy, forKey: .strategy)
        case .synthesized(let curve):
            try container.encode(Kind.synthesized, forKey: .kind)
            try container.encode(curve, forKey: .curve)
        case .bundledCube(let id):
            try container.encode(Kind.bundledCube, forKey: .kind)
            try container.encode(id, forKey: .libraryId)
        }
    }
}

// MARK: - Catalog entry

/// One Camera Profile catalog row. The catalog itself lives in
/// `FilmtoneSourceProfileCatalog` (Phase D) and is purely compile-time —
/// these structs are never persisted, so they don't need to be `Codable`.
///
/// `id` is the namespaced string identifier (`"built-in:source-profile.<slug>"`)
/// — it's what `CameraProfileSelection.builtIn` carries on the wire and what
/// `FilmtoneStrings.builtInSourceProfileName(slug:)` resolves to a localized
/// display name.
///
/// `detectionHint` is consulted only when the user's selection is `.auto`;
/// the export pipeline matches it against the source probe's `colorClass`
/// to decide which catalog entry to materialize. nil means "this entry
/// cannot be inferred from the probe" — the (S) V-Log / S-Log3 entries set
/// this to nil because container metadata cannot reliably distinguish those
/// curves (D-CP4 retention rule keeps them sticky once the user picks them).
struct CameraProfileCatalogEntry: Equatable, Sendable {
    let id: String
    let englishName: String
    let curve: SourceProfileCurve?
    let impl: SourceProfileImpl
    let detectionHint: SourceColorClassDTO?
    let bundled: Bool
    let immutable: Bool
}
