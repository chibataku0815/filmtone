import FilmLabSwiftCore
import Foundation

/// Single owner of `~/Library/Application Support/Filmtone/library/`.
///
/// All disk I/O for the LUT library and Saved Looks routes through this
/// actor — UI never touches `FileManager` directly. Atomic per-entry writes
/// (`Data.write(.atomic)`), rebuildable index, content-hash dedup, and an
/// orphan-blob GC pass at startup keep the on-disk state self-healing.
///
/// The store is the SSOT; consumers receive immutable `LibrarySnapshot`
/// values across the actor boundary and never hold internal references.
actor LibraryStoreActor {
    enum StoreError: LocalizedError, Equatable {
        case quotaExceeded(currentBytes: Int64, additionalBytes: Int64, capBytes: Int64)
        case lutNotFound(UUID)
        case lookNotFound(UUID)
        case malformed(String)
        /// Mutation refused on a built-in catalog entry (Item 2 Look pack /
        /// v1.4+ Camera Profile bundled fallback). The associated value is
        /// the catalog slug, surfaced for UI messaging and telemetry.
        case immutableEntry(slug: String)

        var errorDescription: String? {
            switch self {
            case .quotaExceeded(let current, let additional, let cap):
                let mb = { (bytes: Int64) -> String in
                    String(format: "%.1f", Double(bytes) / (1024.0 * 1024.0))
                }
                return String(
                    format: "LUT library would exceed the %@ MB cap (currently %@ MB, this import adds %@ MB).",
                    mb(cap), mb(current), mb(additional)
                )
            case .lutNotFound(let id):
                return "LUT not found in library: \(id.uuidString)."
            case .lookNotFound(let id):
                return "Saved Look not found in library: \(id.uuidString)."
            case .malformed(let detail):
                return "Library data is malformed: \(detail)."
            case .immutableEntry(let slug):
                return "Built-in entry \"\(slug)\" cannot be renamed or deleted."
            }
        }
    }

    private let fileManager: FileManager
    private let rootURL: URL
    private let lutsURL: URL
    private let looksURL: URL
    private let indexURL: URL

    private var luts: [UUID: LutLibraryEntry] = [:]
    private var looks: [UUID: SavedLookEntry] = [:]
    private var recentLutIds: [UUID] = []
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
        self.lutsURL = resolvedRoot.appendingPathComponent("luts", isDirectory: true)
        self.looksURL = resolvedRoot.appendingPathComponent("looks", isDirectory: true)
        self.indexURL = resolvedRoot.appendingPathComponent("index.json")

        try Self.ensureDirectory(at: resolvedRoot, fileManager: fileManager)
        try Self.ensureDirectory(at: lutsURL, fileManager: fileManager)
        try Self.ensureDirectory(at: looksURL, fileManager: fileManager)
    }

    // MARK: - Loading

    /// Read `index.json` if present, then walk the entry directories to repair
    /// any drift, prune orphan blobs, and rebuild the `recentLutIds` ordering.
    /// Always returns the fresh in-memory snapshot.
    @discardableResult
    func loadOrRebuild() throws -> LibrarySnapshot {
        if didLoad {
            return currentSnapshot()
        }
        defer { didLoad = true }

        // Best-effort hydrate via the index — used only as a hint for ordering.
        var loadedLuts: [UUID: LutLibraryEntry] = [:]
        var loadedLooks: [UUID: SavedLookEntry] = [:]

        if let indexData = try? Data(contentsOf: indexURL),
           let index = try? Self.libraryDecoder.decode(LibraryIndex.self, from: indexData),
           index.schemaVersion == FilmtoneLibraryConstants.indexSchemaVersion {
            for id in index.lutIds {
                if let entry = try? loadLutEntry(id: id) {
                    loadedLuts[id] = entry
                }
            }
            for id in index.lookIds {
                if let entry = try? loadLookEntry(id: id) {
                    loadedLooks[id] = entry
                }
            }
        }

        // Always rescan directories: catches both new entries (added externally
        // / via restore-from-backup) and missing entries (deleted out from
        // under us) so the index can never lie to UI for long.
        let scannedLutIds = scanIds(in: lutsURL, suffix: ".json")
        let scannedLookIds = scanIds(in: looksURL, suffix: ".json")

        for id in scannedLutIds where loadedLuts[id] == nil {
            if let entry = try? loadLutEntry(id: id) {
                loadedLuts[id] = entry
            }
        }
        for id in scannedLookIds where loadedLooks[id] == nil {
            if let entry = try? loadLookEntry(id: id) {
                loadedLooks[id] = entry
            }
        }
        for id in loadedLuts.keys where !scannedLutIds.contains(id) {
            loadedLuts.removeValue(forKey: id)
        }
        for id in loadedLooks.keys where !scannedLookIds.contains(id) {
            loadedLooks.removeValue(forKey: id)
        }

        self.luts = loadedLuts
        self.looks = loadedLooks
        rebuildRecentLuts()

        // Orphan blob GC: `.lutbin` files whose JSON sibling is missing.
        let scannedBlobIds = scanIds(in: lutsURL, suffix: ".lutbin")
        for id in scannedBlobIds where loadedLuts[id] == nil {
            try? fileManager.removeItem(at: lutBlobURL(id: id))
        }

        try? saveIndex()
        return currentSnapshot()
    }

    func snapshot() -> LibrarySnapshot {
        currentSnapshot()
    }

    /// Drops the entire on-disk subtree and resets in-memory state. Used by
    /// the snapshot-mode bootstrap so screenshot fixtures start from empty.
    func clear() {
        luts.removeAll()
        looks.removeAll()
        recentLutIds.removeAll()
        try? fileManager.removeItem(at: rootURL)
        try? Self.ensureDirectory(at: rootURL, fileManager: fileManager)
        try? Self.ensureDirectory(at: lutsURL, fileManager: fileManager)
        try? Self.ensureDirectory(at: looksURL, fileManager: fileManager)
        didLoad = true
    }

    // MARK: - LUT operations

    /// Returns the existing entry on a content-hash dedup hit, or creates a
    /// fresh entry (writing both the JSON metadata and the `.lutbin` blob)
    /// on a miss. The blob is marked `isExcludedFromBackup = true`; the JSON
    /// metadata is intentionally backed up so a restored device shows
    /// "missing LUT, re-import" placeholders rather than blank entries.
    func importLut(
        parsedLut: ParsedCubeLutDTO,
        originalFilename: String?,
        preferredSlot: SlotHint
    ) throws -> (entry: LutLibraryEntry, deduped: Bool) {
        if !didLoad {
            _ = try loadOrRebuild()
        }
        let hash = try FilmtoneLutBlobCodec.sourceHash(data: parsedLut.data, size: parsedLut.size)

        if var existing = luts.values.first(where: { $0.sourceHash == hash }) {
            existing.lastUsedAt = Date()
            existing.defaultIntensity = FilmtonePhase0Math.clampLutIntensity(parsedLut.intensity)
            // Refresh title from the freshly-parsed file — users who renamed
            // their LUT externally and re-import should see the new title.
            if !parsedLut.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                existing.title = parsedLut.title
            }
            if existing.originalFilename == nil {
                existing.originalFilename = originalFilename
            }
            try saveLutEntry(existing)
            luts[existing.id] = existing
            rebuildRecentLuts()
            try? saveIndex()
            return (existing, true)
        }

        let blob = try FilmtoneLutBlobCodec.encode(data: parsedLut.data, size: parsedLut.size)
        let blobBytes = Int64(blob.count)
        let currentBytes = computeSubtreeBytes()
        let cap = FilmtoneLibraryConstants.librarySubtreeQuotaBytes
        if currentBytes + blobBytes > cap {
            throw StoreError.quotaExceeded(
                currentBytes: currentBytes,
                additionalBytes: blobBytes,
                capBytes: cap
            )
        }

        let id = UUID()
        let blobURL = lutBlobURL(id: id)
        try blob.write(to: blobURL, options: [.atomic])
        try? Self.markBackupExcluded(blobURL)

        let entry = LutLibraryEntry(
            schemaVersion: FilmtoneLibraryConstants.entrySchemaVersion,
            id: id,
            title: parsedLut.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Imported LUT"
                : parsedLut.title,
            sourceHash: hash,
            size: parsedLut.size,
            createdAt: Date(),
            lastUsedAt: Date(),
            favorite: false,
            dataRef: "\(id.uuidString.lowercased()).lutbin",
            dataFormat: FilmtoneLibraryConstants.lutDataFormat,
            originalFilename: originalFilename,
            defaultIntensity: FilmtonePhase0Math.clampLutIntensity(parsedLut.intensity),
            preferredSlot: preferredSlot
        )
        try saveLutEntry(entry)
        luts[id] = entry
        rebuildRecentLuts()
        try? saveIndex()
        return (entry, false)
    }

    /// Materialize a `ParsedCubeLutDTO` from a library entry. The intensity
    /// argument lets callers override the entry's `defaultIntensity` (e.g.
    /// applying a Saved Look that pinned a specific intensity).
    func loadLut(id: UUID, intensity: Double? = nil) throws -> ParsedCubeLutDTO {
        guard let entry = luts[id] else {
            throw StoreError.lutNotFound(id)
        }
        let blob = try Data(contentsOf: lutBlobURL(id: id))
        let data = try FilmtoneLutBlobCodec.decode(blob: blob, size: entry.size)
        let resolvedIntensity = FilmtonePhase0Math.clampLutIntensity(
            intensity ?? entry.defaultIntensity
        )
        return ParsedCubeLutDTO(
            title: entry.title,
            size: entry.size,
            data: data,
            intensity: resolvedIntensity
        )
    }

    /// Update `lastUsedAt` so the LUT bubbles to the top of the Recent strip.
    /// Silently no-ops if the entry has been removed since (defensive — keeps
    /// the apply-Saved-Look path from throwing on a stale id).
    func touchLutLastUsed(id: UUID) {
        guard var entry = luts[id] else {
            return
        }
        entry.lastUsedAt = Date()
        luts[id] = entry
        try? saveLutEntry(entry)
        rebuildRecentLuts()
        try? saveIndex()
    }

    func renameLut(id: UUID, title: String) throws {
        guard var entry = luts[id] else {
            throw StoreError.lutNotFound(id)
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        entry.title = trimmed
        luts[id] = entry
        try saveLutEntry(entry)
        try? saveIndex()
    }

    func toggleFavoriteLut(id: UUID) throws {
        guard var entry = luts[id] else {
            throw StoreError.lutNotFound(id)
        }
        entry.favorite.toggle()
        luts[id] = entry
        try saveLutEntry(entry)
        try? saveIndex()
    }

    /// Self-healing delete: rewrites every `SavedLookEntry` whose creative-LUT
    /// binding pointed at this id, inlining the LUT data so those looks stay
    /// playable, then removes the JSON + `.lutbin`. Returns the fresh snapshot
    /// so the caller can refresh its view model in one step.
    @discardableResult
    func deleteLut(id: UUID) throws -> LibrarySnapshot {
        guard let entry = luts[id] else {
            throw StoreError.lutNotFound(id)
        }

        // Inline blob into every referencing look. If the blob is missing
        // (e.g. restore-from-backup state), surface a malformed error rather
        // than silently dropping the binding — the user picked a destructive
        // action, they should see the failure.
        let referencingLooks = looks.values.filter { look in
            if case .libraryRef(let refId, _) = look.creativeLut, refId == id {
                return true
            }
            return false
        }

        if !referencingLooks.isEmpty {
            let blobData = try Data(contentsOf: lutBlobURL(id: id))
            let lutValues = try FilmtoneLutBlobCodec.decode(blob: blobData, size: entry.size)
            let embedded = SavedLookEmbeddedLut(
                title: entry.title,
                size: entry.size,
                data: lutValues,
                sourceHash: entry.sourceHash
            )
            for var look in referencingLooks {
                guard case .libraryRef(_, let intensity) = look.creativeLut else {
                    continue
                }
                look = SavedLookEntry(
                    schemaVersion: look.schemaVersion,
                    id: look.id,
                    name: look.name,
                    createdAt: look.createdAt,
                    updatedAt: Date(),
                    presetName: look.presetName,
                    presetVersion: look.presetVersion,
                    strength: look.strength,
                    quickState: look.quickState,
                    paramOverrides: look.paramOverrides,
                    creativeLut: .embedded(lut: embedded, intensity: intensity),
                    favorite: look.favorite,
                    thumbnailRef: look.thumbnailRef
                )
                looks[look.id] = look
                try saveLookEntry(look)
            }
        }

        try? fileManager.removeItem(at: lutBlobURL(id: id))
        try? fileManager.removeItem(at: lutEntryURL(id: id))
        luts.removeValue(forKey: id)
        rebuildRecentLuts()
        try? saveIndex()
        return currentSnapshot()
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
            thumbnailRef: nil
        )
        try saveLookEntry(entry)
        looks[entry.id] = entry

        // Touch any library LUT the look references so it bubbles up to Recent.
        if case .libraryRef(let id, _) = creativeLut {
            touchLutLastUsed(id: id)
        }
        try? saveIndex()
        return entry
    }

    func renameLook(id: UUID, name: String) throws {
        if let slug = FilmtoneBuiltInCatalog.slug(for: id) {
            throw StoreError.immutableEntry(slug: slug)
        }
        guard var entry = looks[id] else {
            throw StoreError.lookNotFound(id)
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        entry.name = trimmed
        entry.updatedAt = Date()
        looks[id] = entry
        try saveLookEntry(entry)
        try? saveIndex()
    }

    /// Toggle favorite state for a Saved Look. Built-in catalog entries
    /// route through the UserDefaults-backed favorites map (Item 2);
    /// user-saved looks update the on-disk JSON entry.
    func toggleFavoriteLook(id: UUID) throws {
        if let slug = FilmtoneBuiltInCatalog.slug(for: id) {
            let current = loadBuiltInLookFavorites()[slug] ?? false
            writeBuiltInLookFavorite(slug: slug, favorite: !current)
            return
        }
        guard var entry = looks[id] else {
            throw StoreError.lookNotFound(id)
        }
        entry.favorite.toggle()
        entry.updatedAt = Date()
        looks[id] = entry
        try saveLookEntry(entry)
        try? saveIndex()
    }

    @discardableResult
    func deleteLook(id: UUID) throws -> LibrarySnapshot {
        if let slug = FilmtoneBuiltInCatalog.slug(for: id) {
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
    /// `FilmtoneBuiltInCatalog` (no disk I/O); user-saved ids return the
    /// in-memory entry.
    func loadLook(id: UUID) throws -> SavedLookEntry {
        if let builtIn = FilmtoneBuiltInCatalog.look(matching: id) {
            let favorites = loadBuiltInLookFavorites()
            return FilmtoneBuiltInCatalog.materializeAsSavedLookEntry(
                builtIn,
                favoriteOverride: favorites[builtIn.slug] ?? false,
                asOf: Self.builtInLookAsOfDate
            )
        }
        guard let entry = looks[id] else {
            throw StoreError.lookNotFound(id)
        }
        return entry
    }

    // MARK: - Internal helpers

    private func currentSnapshot() -> LibrarySnapshot {
        let sortedLuts = luts.values.sorted { lhs, rhs in
            let lhsDate = lhs.lastUsedAt ?? lhs.createdAt
            let rhsDate = rhs.lastUsedAt ?? rhs.createdAt
            if lhsDate == rhsDate {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhsDate > rhsDate
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
        // v1.3 Item 2: prepend built-in catalog Looks (Filmtone Signature,
        // Clean Base, Amber Glow, Soft Blue, Night Soft) so the chip strip
        // always shows them ahead of user-saved looks. Order follows
        // FilmtoneBuiltInCatalog.allLooks; favorite state lives in a
        // UserDefaults map and is reapplied at materialization.
        let favorites = loadBuiltInLookFavorites()
        let builtInLooks = FilmtoneBuiltInCatalog.allLooks.map { built in
            FilmtoneBuiltInCatalog.materializeAsSavedLookEntry(
                built,
                favoriteOverride: favorites[built.slug] ?? false,
                asOf: Self.builtInLookAsOfDate
            )
        }
        return LibrarySnapshot(
            luts: sortedLuts,
            looks: builtInLooks + sortedUserLooks,
            recentLutIds: recentLutIds
        )
    }

    // MARK: - Built-in Look favorites (Item 2)

    /// UserDefaults key for the built-in Look favorites map. Format:
    /// `[String: Bool]` where the key is the catalog slug
    /// (e.g. "filmtone-signature") and the value is the favorite flag.
    private static let builtInLookFavoritesKey = "filmtone.builtin.favorites.v1"

    /// Stable as-of date stamped onto materialized built-in `SavedLookEntry`
    /// values. Built-ins are pinned ahead of user looks by their position
    /// in `FilmtoneBuiltInCatalog.allLooks`, so this date is purely
    /// cosmetic — using the v1.3 catalog freeze date keeps sidecar /
    /// telemetry timestamps stable across re-launches.
    private static let builtInLookAsOfDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 30
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    private func loadBuiltInLookFavorites() -> [String: Bool] {
        UserDefaults.standard.dictionary(forKey: Self.builtInLookFavoritesKey) as? [String: Bool] ?? [:]
    }

    private func writeBuiltInLookFavorite(slug: String, favorite: Bool) {
        var map = loadBuiltInLookFavorites()
        map[slug] = favorite
        UserDefaults.standard.set(map, forKey: Self.builtInLookFavoritesKey)
    }

    private func rebuildRecentLuts() {
        let ranked = luts.values
            .filter { $0.lastUsedAt != nil }
            .sorted { lhs, rhs in
                guard let lhsDate = lhs.lastUsedAt else { return false }
                guard let rhsDate = rhs.lastUsedAt else { return true }
                return lhsDate > rhsDate
            }
            .prefix(FilmtoneLibraryConstants.recentLutCap)
        recentLutIds = ranked.map(\.id)
    }

    private func defaultLookName() -> String {
        let count = looks.count + 1
        return "Look \(count)"
    }

    private func saveLutEntry(_ entry: LutLibraryEntry) throws {
        let url = lutEntryURL(id: entry.id)
        let data = try Self.libraryEncoder.encode(entry)
        try data.write(to: url, options: [.atomic])
    }

    private func loadLutEntry(id: UUID) throws -> LutLibraryEntry {
        let url = lutEntryURL(id: id)
        let data = try Data(contentsOf: url)
        return try Self.libraryDecoder.decode(LutLibraryEntry.self, from: data)
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
            lutIds: Array(luts.keys),
            lookIds: Array(looks.keys),
            recentLutIds: recentLutIds,
            generatedAt: Date()
        )
        let data = try Self.libraryEncoder.encode(index)
        try data.write(to: indexURL, options: [.atomic])
    }

    private func lutEntryURL(id: UUID) -> URL {
        lutsURL.appendingPathComponent("\(id.uuidString.lowercased()).json")
    }

    private func lutBlobURL(id: UUID) -> URL {
        lutsURL.appendingPathComponent("\(id.uuidString.lowercased()).lutbin")
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
            guard name.hasSuffix(suffix) else {
                continue
            }
            let stem = String(name.dropLast(suffix.count))
            if let id = UUID(uuidString: stem) {
                ids.insert(id)
            }
        }
        return ids
    }

    private func computeSubtreeBytes() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey, .fileSizeKey,
            ])
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
        }
        return total
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

    private static func markBackupExcluded(_ url: URL) throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(resourceValues)
    }
}
