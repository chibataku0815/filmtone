// Filmtone V2 native camera capture — security-scoped file bookmark helper.
//
// Stateless helper used by:
//   - Capture session at finalize time: generate a bookmark for the
//     master file URL while the capture surface still holds folder
//     scope, store the bytes inside the capture package snapshot.
//   - Editor at export start: resolve the bookmark back to a URL and
//     start scoped access so the master file can be probed + read.
//
// Distinct from `FilmtoneExternalFolderBookmark`:
//   - `FilmtoneExternalFolderBookmark` lives in UserDefaults, tracks
//     the most recently picked SSD root, scoped to the capture
//     surface auto-restore. Cleared by the "Clear external storage"
//     button.
//   - `FilmtoneSecurityScopedBookmark` is stateless. The bytes it
//     produces travel with the capture package (`capture-package.json`
//     `masterBookmark` field) so each package carries its own
//     master-export key independent of the folder bookmark.

import Foundation

#if os(iOS)

enum FilmtoneSecurityScopedBookmark {

    /// Generate a minimal bookmark for `url` while the caller holds
    /// security-scope on it (or on a parent that propagates scope).
    /// Returns nil + NSLog on failure — capture finalize MUST NOT be
    /// blocked by a bookmark write because the master file is still
    /// the truth, the bookmark is only the export-side reachability key.
    ///
    /// `.minimalBookmark` keeps the stored bytes small (no resource
    /// values inlined). `.withSecurityScope` is macOS-only — on iOS
    /// the security scope is implicit when the URL came through a
    /// `UIDocumentPicker` selection, which is the only path that
    /// reaches a security-scoped file in this app.
    static func make(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            NSLog(
                "[FilmtoneSecurityScopedBookmark] make failed for %@: %@",
                url.path,
                error.localizedDescription
            )
            return nil
        }
    }

    /// Resolve a bookmark to a URL the caller can pass to
    /// `startAccessingSecurityScopedResource()`. Returns nil + NSLog
    /// when:
    ///   - resolution fails (SSD unmounted, file deleted),
    ///   - bookmark is stale (`bookmarkDataIsStale == true` — the
    ///     OS rotated the bookmark format or moved the file). The
    ///     M14-B path treats both as "fall back to proxy" rather
    ///     than try to repair, because export needs the exact master
    ///     bytes the package was built against.
    static func resolve(_ data: Data) -> URL? {
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
            NSLog(
                "[FilmtoneSecurityScopedBookmark] resolve failed: %@",
                error.localizedDescription
            )
            return nil
        }
        if stale {
            NSLog("[FilmtoneSecurityScopedBookmark] bookmark stale — caller should fall back")
            return nil
        }
        return url
    }
}

#endif
