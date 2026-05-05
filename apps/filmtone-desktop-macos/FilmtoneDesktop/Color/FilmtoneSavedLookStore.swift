import FilmLabSwiftCore
import Foundation

// M5-C.2a: Native Desktop owner of
// `~/Library/Application Support/Filmtone/library/looks/{*.json,
// index.json}`. Looks-only subset of iOS `LibraryStoreActor` — the LUT
// half (luts/ subtree, quota, orphan-blob GC, embedded-LUT rewrite) is
// deferred to M5-C.2c (P1).
//
// All disk I/O routes through this actor. UI never touches FileManager
// directly. Atomic per-entry writes, a rebuildable index, and built-in
// catalog dispatch (Stone / Urban materialized at read time, never
// persisted to disk) keep the on-disk state self-healing.

actor FilmtoneSavedLookStore {
    enum StoreError: LocalizedError, Equatable {
        case lookNotFound(UUID)
        case immutableEntry(slug: String)
        case malformed(String)

        var errorDescription: String? {
            switch self {
            case .lookNotFound(let id):
                return "Saved Look not found in library: \(id.uuidString)."
            case .immutableEntry(let slug):
                return "Built-in entry \"\(slug)\" cannot be renamed or deleted."
            case .malformed(let detail):
                return "Library data is malformed: \(detail)."
            }
        }
    }

    /// UserDefaults key holding the array of UUID strings for built-in
    /// looks the user has favorited. Mirrors iOS's UserDefaults-backed
    /// favorite map for built-in entries — the catalog JSON itself stays
    /// immutable (rename / delete still refuse) but favorite is stored
    /// alongside the bundled materialized entry at snapshot time.
    static let builtInFavoritesUserDefaultsKey = "filmtone.library.builtInFavorites"

    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let rootURL: URL
    private let looksURL: URL
    private let indexURL: URL

    private var looks: [UUID: SavedLookEntry] = [:]
    private var didLoad = false

    init(fileManager: FileManager = .default,
         rootURL: URL? = nil,
         defaults: UserDefaults = .standard) throws {
        self.fileManager = fileManager
        self.defaults = defaults
        let resolvedRoot: URL
        if let rootURL {
            resolvedRoot = rootURL
        } else {
            let supportDir = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            resolvedRoot = supportDir.appendingPathComponent("Filmtone/library", isDirectory: true)
        }
        self.rootURL = resolvedRoot
        self.looksURL = resolvedRoot.appendingPathComponent("looks", isDirectory: true)
        self.indexURL = resolvedRoot.appendingPathComponent("index.json")

        try Self.ensureDirectory(at: resolvedRoot, fileManager: fileManager)
        try Self.ensureDirectory(at: looksURL, fileManager: fileManager)
    }

    private var builtInFavorites: Set<UUID> {
        let raw = defaults.array(forKey: Self.builtInFavoritesUserDefaultsKey) as? [String] ?? []
        return Set(raw.compactMap(UUID.init(uuidString:)))
    }

    private func setBuiltInFavorite(_ id: UUID, favorite: Bool) {
        var current = builtInFavorites
        if favorite {
            current.insert(id)
        } else {
            current.remove(id)
        }
        let strings = current.map { $0.uuidString }
        defaults.set(strings, forKey: Self.builtInFavoritesUserDefaultsKey)
    }

    // MARK: - Loading

    @discardableResult
    func loadOrRebuild() throws -> LibrarySnapshot {
        if didLoad {
            return currentSnapshot()
        }
        defer { didLoad = true }

        var loadedLooks: [UUID: SavedLookEntry] = [:]

        if let indexData = try? Data(contentsOf: indexURL),
           let index = try? Self.libraryDecoder.decode(LibraryIndex.self, from: indexData),
           index.schemaVersion == FilmtoneLibraryConstants.indexSchemaVersion {
            for id in index.lookIds {
                if let entry = try? loadLookEntry(id: id) {
                    loadedLooks[id] = entry
                }
            }
        }

        // Always rescan: catches new entries (restore-from-backup) and
        // missing entries (deleted out from under us) so the index can
        // never lie to UI for long.
        let scannedLookIds = scanIds(in: looksURL, suffix: ".json")
        for id in scannedLookIds where loadedLooks[id] == nil {
            if let entry = try? loadLookEntry(id: id) {
                loadedLooks[id] = entry
            }
        }
        for id in loadedLooks.keys where !scannedLookIds.contains(id) {
            loadedLooks.removeValue(forKey: id)
        }

        self.looks = loadedLooks
        try? saveIndex()
        return currentSnapshot()
    }

    func snapshot() -> LibrarySnapshot {
        currentSnapshot()
    }

    // MARK: - Saved Look operations

    func saveLook(
        name: String,
        presetName: String,
        presetVersion: String,
        strength: Double,
        quickState: FilmtoneQuickState,
        paramOverrides: FilmtonePhase0ParamsPatch,
        creativeLut: CreativeLutBinding?
    ) throws -> SavedLookEntry {
        if !didLoad {
            _ = try loadOrRebuild()
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? defaultLookName() : trimmed
        let now = Date()
        let entry = SavedLookEntry(
            schemaVersion: FilmtoneLibraryConstants.entrySchemaVersion,
            id: UUID(),
            name: resolvedName,
            createdAt: now,
            updatedAt: now,
            presetName: presetName,
            presetVersion: presetVersion,
            strength: strength,
            quickState: quickState,
            paramOverrides: paramOverrides,
            creativeLut: creativeLut,
            favorite: false,
            thumbnailRef: nil,
            bundled: false,
            immutable: false,
            bundledSlug: nil
        )
        try saveLookEntry(entry)
        looks[entry.id] = entry
        try? saveIndex()
        return entry
    }

    @discardableResult
    func deleteLook(id: UUID) throws -> LibrarySnapshot {
        if let slug = FilmtoneCreativePackCatalog.find(canonicalUUID: id)?.slug {
            throw StoreError.immutableEntry(slug: slug)
        }
        guard looks[id] != nil else {
            throw StoreError.lookNotFound(id)
        }
        try? fileManager.removeItem(at: lookEntryURL(id: id))
        looks.removeValue(forKey: id)
        try? saveIndex()
        return currentSnapshot()
    }

    /// Rename a user Saved Look. Built-in entries reject with
    /// `.immutableEntry`. Empty / whitespace-only input falls back to
    /// the existing default name. Atomic per-entry write so a crash mid-
    /// rename does not leave the on-disk JSON half-written.
    @discardableResult
    func renameLook(id: UUID, newName: String) throws -> SavedLookEntry {
        if let slug = FilmtoneCreativePackCatalog.find(canonicalUUID: id)?.slug {
            throw StoreError.immutableEntry(slug: slug)
        }
        if !didLoad {
            _ = try loadOrRebuild()
        }
        guard var entry = looks[id] else {
            throw StoreError.lookNotFound(id)
        }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? defaultLookName() : trimmed
        entry.name = resolved
        entry.updatedAt = Date()
        try saveLookEntry(entry)
        looks[id] = entry
        return entry
    }

    /// Toggle (or set) the favorite flag on a Saved Look. Both user
    /// entries and built-ins are accepted — built-ins keep their JSON
    /// immutable (rename / delete still refuse) but favorite persists in
    /// a UserDefaults map so the picker can surface it like any other
    /// favorite. iOS canonical does the same split.
    @discardableResult
    func setFavorite(id: UUID, favorite: Bool) throws -> SavedLookEntry {
        if let bundled = FilmtoneCreativePackCatalog.find(canonicalUUID: id) {
            setBuiltInFavorite(id, favorite: favorite)
            var entry = FilmtoneCreativePackCatalog.materializeAsSavedLookEntry(bundled)
            entry.favorite = favorite
            return entry
        }
        if !didLoad {
            _ = try loadOrRebuild()
        }
        guard var entry = looks[id] else {
            throw StoreError.lookNotFound(id)
        }
        entry.favorite = favorite
        entry.updatedAt = Date()
        try saveLookEntry(entry)
        looks[id] = entry
        return entry
    }

    /// Resolve a Saved Look by id. Built-in catalog ids materialize from
    /// `FilmtoneCreativePackCatalog` (no disk I/O); user-saved ids
    /// return the in-memory entry.
    func loadLook(id: UUID) throws -> SavedLookEntry {
        if let builtIn = FilmtoneCreativePackCatalog.find(canonicalUUID: id) {
            return FilmtoneCreativePackCatalog.materializeAsSavedLookEntry(builtIn)
        }
        guard let entry = looks[id] else {
            throw StoreError.lookNotFound(id)
        }
        return entry
    }

    // MARK: - Internal helpers

    private func currentSnapshot() -> LibrarySnapshot {
        // Built-in Stone / Urban prepended (mirrors iOS
        // `LibraryStoreActor.currentSnapshot`). User looks sorted by
        // favorite, then updatedAt desc, then name.
        // M5-H.2: built-in favorite is read from the UserDefaults map at
        // materialize time so the picker shows ★ on bundled entries the
        // user has favorited (the catalog JSON itself stays immutable).
        let favorites = builtInFavorites
        let builtInLooks: [SavedLookEntry] = FilmtoneCreativePackCatalog.all.map { cat in
            var entry = FilmtoneCreativePackCatalog.materializeAsSavedLookEntry(cat)
            if favorites.contains(entry.id) {
                entry.favorite = true
            }
            return entry
        }
        let sortedUserLooks = looks.values.sorted { lhs, rhs in
            if lhs.favorite != rhs.favorite {
                return lhs.favorite && !rhs.favorite
            }
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        return LibrarySnapshot(looks: builtInLooks + sortedUserLooks)
    }

    private func defaultLookName() -> String {
        let count = looks.count + 1
        return "Look \(count)"
    }

    private func saveLookEntry(_ entry: SavedLookEntry) throws {
        let url = lookEntryURL(id: entry.id)
        let data = try Self.libraryEncoder.encode(entry)
        try data.write(to: url, options: [.atomic])
    }

    private func loadLookEntry(id: UUID) throws -> SavedLookEntry {
        let url = lookEntryURL(id: id)
        let data = try Data(contentsOf: url)
        return try Self.libraryDecoder.decode(SavedLookEntry.self, from: data)
    }

    private func saveIndex() throws {
        let index = LibraryIndex(
            schemaVersion: FilmtoneLibraryConstants.indexSchemaVersion,
            lutIds: [],
            lookIds: Array(looks.keys),
            recentLutIds: [],
            generatedAt: Date()
        )
        let data = try Self.libraryEncoder.encode(index)
        try data.write(to: indexURL, options: [.atomic])
    }

    private func lookEntryURL(id: UUID) -> URL {
        looksURL.appendingPathComponent("\(id.uuidString.lowercased()).json")
    }

    private func scanIds(in directory: URL, suffix: String) -> Set<UUID> {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var ids: Set<UUID> = []
        for url in urls {
            let name = url.lastPathComponent
            guard name.hasSuffix(suffix) else { continue }
            let stem = String(name.dropLast(suffix.count))
            if let id = UUID(uuidString: stem) {
                ids.insert(id)
            }
        }
        return ids
    }

    // MARK: - Static helpers

    private static let libraryEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let libraryDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func ensureDirectory(at url: URL, fileManager: FileManager) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
