// Filmtone V2 native camera capture — external folder bookmark store.
//
// Persists the user-picked SSD folder across app launches so the owner
// does not have to re-pick the SSD via the Files importer every time
// they open the capture surface.  iOS-style minimal bookmark stored in
// UserDefaults; resolution returns a URL on which the caller still
// owns `startAccessingSecurityScopedResource()` / `stop…()` for the
// run window (matches the existing single-launch security-scope model
// in `FilmtoneCaptureView.applyPickedFolder` / `releaseExternalFolderScope`).
//
// On stale or unreadable bookmark (SSD physically disconnected,
// folder removed, OS rotated the bookmark), `loadAndResolve` clears
// the stored data and returns nil so the surface silently falls back
// to internal mode.  No alert / banner — the storage pill already
// shows "Internal master" and the SSD button stays available for a
// re-pick.

import Foundation

#if os(iOS)

enum FilmtoneExternalFolderBookmark {

    /// UserDefaults key.  `external_folder` distinguishes from any
    /// future internal-mode preference; `bookmark_v1` lets us bump
    /// the storage shape without colliding with stale data if iOS
    /// ever changes bookmark format requirements.
    private static let defaultsKey = "filmtone.capture.external_folder.bookmark_v1"

    /// Save a minimal bookmark for the user-picked external folder.
    /// Called from `applyPickedFolder` after preflight passes so we
    /// only persist URLs that already cleared the external/write/
    /// capacity gates.  Failures are logged and ignored — capture
    /// still works for the current run via the in-memory URL; only
    /// the auto-resolve next launch is lost.
    static func save(url: URL) {
        do {
            // iOS supports `.minimalBookmark` to reduce storage; the
            // `.withSecurityScope` option is macOS-only — on iOS the
            // security scope is implicit when the URL came from a
            // `UIDocumentPicker` selection (which is the only path
            // that reaches this helper).
            let data = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            NSLog("[FilmtoneExternalFolderBookmark] save failed: \(error.localizedDescription)")
        }
    }

    /// Resolve the persisted bookmark to a URL the caller can pass to
    /// `startAccessingSecurityScopedResource()`.  Returns nil and
    /// clears the stored data when:
    ///   - no bookmark stored,
    ///   - resolution fails (SSD disconnected, folder deleted),
    ///   - bookmark is stale (`bookmarkDataIsStale == true`).
    /// The caller is responsible for running preflight on the
    /// returned URL — bookmark resolution does not re-validate
    /// capacity / external-volume status.
    static func loadAndResolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return nil
        }
        var stale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        } catch {
            NSLog("[FilmtoneExternalFolderBookmark] resolve failed: \(error.localizedDescription) — clearing")
            clear()
            return nil
        }
        if stale {
            NSLog("[FilmtoneExternalFolderBookmark] bookmark stale — clearing")
            clear()
            return nil
        }
        return url
    }

    /// Drop the persisted bookmark.  Called from `clearExternalFolder`
    /// in the capture view (explicit owner opt-out via the "Clear"
    /// button) and internally on stale / failed resolution so the
    /// next launch starts from a clean state.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

#endif
