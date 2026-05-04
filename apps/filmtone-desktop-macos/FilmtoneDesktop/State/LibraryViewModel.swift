import Foundation
import Observation

// M5-C.2a: @MainActor @Observable wrapper around `FilmtoneSavedLookStore`.
// Owns the actor, holds the most-recent `LibrarySnapshot`, and bridges
// async store calls back to the SwiftUI render tree. UI views observe
// `snapshot` via @Bindable / @Observable and never touch the actor
// directly.

@MainActor
@Observable
final class LibraryViewModel {
    /// Most recent library snapshot pushed from the actor. Built-in Stone
    /// / Urban are prepended by the store, so this list is the SSOT for
    /// the picker.
    private(set) var snapshot: LibrarySnapshot = .empty

    /// User-visible error from the latest store mutation. UI surfaces
    /// this via an inline alert and clears it after acknowledgement.
    var lastError: String?

    @ObservationIgnored
    private let store: FilmtoneSavedLookStore

    @ObservationIgnored
    private var didBootstrap = false

    init() {
        do {
            self.store = try FilmtoneSavedLookStore()
        } catch {
            // The init only fails if Application Support is unavailable;
            // surface a placeholder snapshot and the error so the UI can
            // still render the built-in section after bootstrap is retried.
            self.lastError = "Library unavailable: \(error.localizedDescription)"
            // Re-init using a temporary directory so the actor exists
            // and snapshot calls don't crash. Persistence will be a no-op
            // until the user resolves the underlying error.
            self.store = (try? FilmtoneSavedLookStore(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("Filmtone/library", isDirectory: true)))
                ?? Self.unsafeStoreFallback()
        }
    }

    /// Loads the on-disk library state and updates `snapshot`. Idempotent
    /// — RootWindowView calls it on `task {}` so the first frame after
    /// app launch shows the built-ins even before disk I/O completes
    /// (built-ins ship via `currentSnapshot()`).
    func bootstrap() async {
        if didBootstrap {
            return
        }
        didBootstrap = true
        await refresh()
    }

    func refresh() async {
        do {
            let next = try await store.loadOrRebuild()
            self.snapshot = next
        } catch {
            self.lastError = error.localizedDescription
            self.snapshot = await store.snapshot()
        }
    }

    /// Snapshot the current EditorState into a SavedLookEntry on disk
    /// and return the stored entry so the caller can auto-select it.
    @discardableResult
    func saveCurrentLook(name: String, from state: EditorState) async -> SavedLookEntry? {
        let payload = state.currentLookSavePayload()
        do {
            let entry = try await store.saveLook(
                name: name,
                presetName: payload.presetName,
                presetVersion: payload.presetVersion,
                strength: payload.strength,
                quickState: payload.quickState,
                paramOverrides: payload.paramOverrides,
                creativeLut: payload.creativeLut
            )
            await refresh()
            return entry
        } catch {
            self.lastError = error.localizedDescription
            return nil
        }
    }

    /// Resolve an entry id (built-in or user) to its full
    /// `SavedLookEntry`. Used by the Picker `onChange` handler so the
    /// dispatch path is uniform across both kinds of entries.
    func loadLook(id: UUID) async -> SavedLookEntry? {
        do {
            return try await store.loadLook(id: id)
        } catch {
            self.lastError = error.localizedDescription
            return nil
        }
    }

    private static func unsafeStoreFallback() -> FilmtoneSavedLookStore {
        // Theoretical: both ApplicationSupport and the temporary
        // directory path failed init. Force-try here is acceptable
        // because the alternative is a broken UI that can't render the
        // built-ins; in practice neither path fails on a healthy macOS
        // install.
        return try! FilmtoneSavedLookStore(rootURL: URL(fileURLWithPath: NSTemporaryDirectory()))
    }
}
