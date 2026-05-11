import FilmLabSwiftCore
import Foundation

/// Phase 3A/3B-1: collaborator that owns the project-domain bookkeeping
/// the facade can move off `FilmtoneEditorStore` without disturbing
/// view-facing `@Published` storage. For this bundle that is the synchronous
/// `appliedSavedLookEntryCache` mirror used by the M10 live preview path
/// (`makeLivePreviewGradeProcessor()`) so it can resolve the active
/// Saved Look without awaiting the library actor.
///
/// `appliedSavedLookId` itself stays on the facade as `@Published` because
/// existing views (`FilmtoneRootView`, `FilmtoneFullscreenLutEditor`) read it
/// through `store.appliedSavedLookId` and SwiftUI redraws on its changes.
/// The facade's `didSet` continues to clear the controller's cache when
/// the id is cleared. Forwarding storage was kept on the facade per the
/// active.md compatibility rule for direct view access.
///
/// `resolveAppliedSavedLook(id:via:)` centralizes the sidecar/export
/// resolution path that used to live inline as
/// `resolveAppliedSavedLookForExport()` — the controller calls into the
/// `EditorLibraryController` rather than holding the actor reference twice.
@MainActor
final class EditorProjectController {
    private(set) var appliedSavedLookEntryCache: SavedLookEntry?

    init() {}

    func setAppliedSavedLookEntry(_ entry: SavedLookEntry?) {
        appliedSavedLookEntryCache = entry
    }

    func clearAppliedSavedLookEntry() {
        appliedSavedLookEntryCache = nil
    }

    func resolveAppliedSavedLook(
        id: UUID?,
        via library: EditorLibraryController
    ) async -> SavedLookEntry? {
        guard let id else {
            return nil
        }
        return try? await library.loadLook(id: id)
    }
}
