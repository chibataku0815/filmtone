import FilmLabSwiftCore
import Foundation

/// Phase 3A/3B-1: collaborator that owns the optional
/// `LibraryStoreActor` and offers `@MainActor` async passthroughs for the
/// library mutations the editor calls. The facade keeps `library`,
/// `cacheInventory`, and `isReleasingCache` as `@Published` storage so
/// SwiftUI keeps observing the same surface; this controller just
/// internalizes the `guard let libraryStore else { return }` boilerplate
/// and the optional-actor unwrap at every site.
///
/// `loadOrRebuildSnapshot()` is the task body the facade
/// `bootstrapLibraryAsync()` schedules; the facade still owns the
/// outstanding `Task<Void, Never>?` so `deinit` cancellation does not
/// have to hop actors. Every read-style call returns `nil` (or throws
/// through) when the actor is unavailable so callers can early-return
/// without re-checking the optional store.
@MainActor
final class EditorLibraryController {
    private let store: LibraryStoreActor?

    init(libraryStore: LibraryStoreActor?) {
        self.store = libraryStore
    }

    var isAvailable: Bool {
        store != nil
    }

    func loadOrRebuildSnapshot() async -> LibrarySnapshot {
        guard let store else {
            return .empty
        }
        do {
            return try await store.loadOrRebuild()
        } catch {
            return .empty
        }
    }

    func snapshot() async -> LibrarySnapshot? {
        await store?.snapshot()
    }

    func loadLook(id: UUID) async throws -> SavedLookEntry? {
        try await store?.loadLook(id: id)
    }

    func loadLut(id: UUID, intensity: Double? = nil) async throws -> ParsedCubeLutDTO? {
        try await store?.loadLut(id: id, intensity: intensity)
    }

    func touchLutLastUsed(id: UUID) async {
        await store?.touchLutLastUsed(id: id)
    }

    func importLut(
        parsedLut: ParsedCubeLutDTO,
        originalFilename: String?,
        preferredSlot: SlotHint
    ) async throws -> (entry: LutLibraryEntry, deduped: Bool)? {
        try await store?.importLut(
            parsedLut: parsedLut,
            originalFilename: originalFilename,
            preferredSlot: preferredSlot
        )
    }

    func saveLook(
        name: String,
        presetName: String,
        presetVersion: String,
        strength: Double,
        quickState: FilmtoneQuickState,
        paramOverrides: FilmtonePhase0ParamsPatch,
        creativeLut: CreativeLutBinding?
    ) async throws -> SavedLookEntry? {
        try await store?.saveLook(
            name: name,
            presetName: presetName,
            presetVersion: presetVersion,
            strength: strength,
            quickState: quickState,
            paramOverrides: paramOverrides,
            creativeLut: creativeLut
        )
    }

    func renameLook(id: UUID, name: String) async {
        guard let store else { return }
        try? await store.renameLook(id: id, name: name)
    }

    func deleteLook(id: UUID) async {
        guard let store else { return }
        _ = try? await store.deleteLook(id: id)
    }

    func toggleFavoriteLook(id: UUID) async {
        guard let store else { return }
        try? await store.toggleFavoriteLook(id: id)
    }

    func renameLut(id: UUID, title: String) async {
        guard let store else { return }
        try? await store.renameLut(id: id, title: title)
    }

    func deleteLut(id: UUID) async {
        guard let store else { return }
        _ = try? await store.deleteLut(id: id)
    }

    func toggleFavoriteLut(id: UUID) async {
        guard let store else { return }
        try? await store.toggleFavoriteLut(id: id)
    }
}
