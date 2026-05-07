import Foundation

/// Legacy singleton for the currently-selected optical filter family id.
///
/// Backlight Veil now travels through `FilmtoneProjectState` and
/// `Phase0ExportRequestDTO`; this type stays in the target only for
/// backward-compatible source stability while older call sites are removed.
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
