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

    private let fileManager: FileManager
    private let rootURL: URL
    private let looksURL: URL
    private let indexURL: URL

    private var looks: [UUID: SavedLookEntry] = [:]
    private var didLoad = false

    init(fileManager: FileManager = .default, rootURL: URL? = nil) throws {
        self.fileManager = fileManager
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
        let builtInLooks = FilmtoneCreativePackCatalog.all.map {
            FilmtoneCreativePackCatalog.materializeAsSavedLookEntry($0)
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
