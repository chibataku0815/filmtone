import Foundation

/// Singleton for the currently-selected optical filter family id (e.g.
/// `"backlightVeil-1-2"` or nil = OFF). Decoupled from `Phase0ExportRequestDTO`
/// and `FilmtonePhase0Project` because the optical filter is iOS-side runtime
/// state, not a project-persisted parameter.
///
/// Written by `FilmtoneEditorStore.setOpticalFilterId(_:)` from the @MainActor
/// editor UI; read by `FilmtoneExportSession.currentBacklightVeilOptical()` at
/// composite time on the AVFoundation CIFilter dispatch queue. NSLock guards
/// concurrent access.
///
/// In-memory only — app restart resets to nil. Persistence across launches is
/// a follow-on (would need a project schema bump).
final class FilmtoneOpticalFilterSelectionStore: @unchecked Sendable {
    static let shared = FilmtoneOpticalFilterSelectionStore()

    private let lock = NSLock()
    private var _currentId: String?

    private init() {}

    var currentId: String? {
        lock.lock()
        defer { lock.unlock() }
        return _currentId
    }

    func setCurrentId(_ id: String?) {
        lock.lock()
        _currentId = id
        lock.unlock()
    }
}
