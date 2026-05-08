# Archived: M14-B — Security-Scoped Bookmark for SSD Masters

Status: **PASS** — owner accepted 2026-05-09 ("OK"). New
`FilmtoneSecurityScopedBookmark` stateless helper, additive optional
`masterBookmark: Data?` on package + snapshot (no schemaVersion bump),
capture session writes bookmark when external storage, editor resolves
+ holds scope across export run via `ResolvedExportSource.release()`
deferred at the call site. App-relaunch SSD master export now lands
on the master path; SSD-unmounted falls back to proxy with the
existing M14-A toast wording.

Acceptance authorized the next milestone (Empty View Liquid Glass
parity) — owner-supplied screenshot identified the editor empty
surface (saved-Look chips + bottom CTA stack) as still using the
pre-Liquid-Glass opaque-tint vocabulary. Sidecar provenance (M14-C)
is deferred until the empty-view lane lands.

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status: **installed on iPhone 17 Pro #7, ready for owner walk** — autonomous execution complete 2026-05-09 01:56 JST

## Why this active exists

M14-A landed the master/proxy decision plumbing on iPhone 17 Pro #7
with owner acceptance, but its SSD path is still a fallback in
practice: at editor export time, no `startAccessingSecurityScopedResource()`
is held on the SSD folder URL, so `facade.probeSource(masterSource)`
fails with permission-denied and the export falls back to proxy with
the "Exported from proxy — master not reachable" toast. The owner sees
honest UI, but the high-quality master path is not yet usable for the
SSD workflow that the app's sustained-capture mode is designed for.

M14-B closes that gap by persisting a security-scoped bookmark of the
master file URL into the capture-package snapshot at finalize time.
The editor resolves the bookmark at export start, holds scope across
the export run, and releases it deterministically on every exit path.

## Decision: per-package bookmark, not per-folder

We already have `FilmtoneExternalFolderBookmark` (UserDefaults-keyed,
tracks the most-recently-picked SSD folder for the auto-restore on
the capture surface). M14-B uses a **separate** bookmark stored
inside the capture package's `capture-package.json`.

Why two bookmarks instead of reusing the folder one:

1. **Lifetime independence** — the capture surface's "Clear external
   storage" button intentionally clears the folder bookmark. Reusing
   it would mean a single owner action breaks every previously-recorded
   package's export-from-master path.
2. **Granularity** — file-level bookmarks scope to the master file
   itself; folder-level scope grants access to the entire SSD, which
   is more privilege than export needs.
3. **Round-trip semantics** — the per-package bookmark travels with
   the package JSON, so a relaunch's `currentCapturePackageRef`
   re-hydration carries enough state to export from master. Today,
   `lastCapturePackage` rebuilt from disk has only the master path —
   not the bookmark — so SSD masters fall to proxy on every relaunch.

## Scope

### A. New file — `FilmtoneSecurityScopedBookmark.swift`

Stateless helper, ~40 lines:

```swift
enum FilmtoneSecurityScopedBookmark {
    /// Generate a minimal bookmark for `url` while the caller holds
    /// scope. Returns nil + NSLog on failure; never throws so capture
    /// finalize is not blocked by a bookmark write.
    static func make(for url: URL) -> Data?

    /// Resolve a bookmark to a URL. Returns nil + NSLog when the
    /// bookmark is stale, the SSD is unmounted, or the OS rotated the
    /// bookmark format. Caller still must call
    /// `startAccessingSecurityScopedResource()` on the returned URL.
    static func resolve(_ data: Data) -> URL?
}
```

Pure helper. No state. No file I/O. Used both at capture-finalize
(write bookmark) and editor-export (read bookmark).

### B. `FilmtoneCapturePackage` + `FilmtoneCapturePackageSnapshotV1`

Add additive optional `masterBookmark: Data?`:

- On the in-memory `FilmtoneCapturePackage` struct.
- On the `FilmtoneCapturePackageSnapshotV1` Codable struct (Data
  encodes as base64 in JSON automatically — human-inspectable too).
- Update `makeSnapshot(from:)` to copy from package → snapshot.
- Update `makePackage(from:)` to copy from snapshot → package.

**No schemaVersion bump.** The existing convention
(`FilmtoneCapturePackagePersistence.swift:79-80,113`) is "additive
optional fields allowed inside the current schemaVersion, only bump on
non-additive changes." Pre-M14-B snapshots decode with
`masterBookmark = nil` (silently treated as "no bookmark, fall back
to M14-A behavior").

### C. Capture session — `FilmtoneCaptureSession.swift`

In the package construction path (around line 1105 — proxy generation
success branch), call `FilmtoneSecurityScopedBookmark.make(for:
masterURL)` when `storagePolicy == .externalSecurityScopedFolder(...)`.
Internal masters: pass `masterBookmark = nil`.

The capture session still holds scope at this point (the SSD folder
was acquired during `applyPickedFolder` and held by the owning
`FilmtoneCaptureView` until the view dismisses). The bookmark
generation must happen **before** the view dismisses scope. Today the
proxy task runs off-main, but the bookmark is generated synchronously
inside the proxy success branch, which routes through a `MainActor.run`
back inside the view's lifetime — so the scope is still held.

### D. Editor — `FilmtoneEditorStore.swift`

Update `ResolvedExportSource` to carry a `scopedURL: URL?` and a
`release()` method:

```swift
struct ResolvedExportSource {
    let source: SourceInfoDTO?
    let probe: SourceProbeDTO?
    let decision: ExportSourceDecision
    /// URL on which we currently hold a security-scoped resource
    /// access. nil for internal masters / proxy fallbacks.
    private let scopedURL: URL?
    func release() { scopedURL?.stopAccessingSecurityScopedResource() }
}
```

Update `resolveExportSource()` flow:

1. If package has `masterBookmark` data → resolve via
   `FilmtoneSecurityScopedBookmark.resolve(_:)`. If nil (stale), skip
   to existence check (fileExists may still pass for internal-style
   paths; if not, fallback to proxy with `.usingProxyMasterMissing`).
2. If resolved URL exists → call
   `url.startAccessingSecurityScopedResource()`. If false, treat as
   `.usingProxyMasterUnreadable(reason: "scope acquire denied")`.
3. With scope held, run existing fileExists + probe gates. On
   `.usingMaster`, the `ResolvedExportSource` carries `scopedURL = url`.
   On any fallback branch, scope is stopped immediately + `scopedURL = nil`.

Update `export()` and `exportAndSave()` call sites:

```swift
let resolved = resolveExportSource()
defer { resolved.release() }
// ...
```

The `defer` guarantees scope is dropped on every exit path (success,
throw, early return). Even when the export is a proxy fallback,
`release()` on a nil scopedURL is a no-op.

### Edit Targets

- NEW `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSecurityScopedBookmark.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCapturePackage.swift`
  — add `masterBookmark: Data?`.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCapturePackagePersistence.swift`
  — add field to snapshot, round-trip in makeSnapshot / makePackage.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureSession.swift`
  — generate bookmark when external, pass into package constructor.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
  — extend `ResolvedExportSource` with `scopedURL` + `release()`,
  acquire scope in `resolveExportSource()`, defer release at call sites.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  — 4-section registration for the new helper file.

Do NOT edit:
- `FilmtoneStrings.swift` (the existing `toastExportUsedMaster` and
  `toastExportUsedProxyMasterUnavailable` cover the M14-B outcomes).
- `FilmtoneExternalFolderBookmark.swift` (separate concern, unchanged).
- writer / movie output / facade internals.
- React / Capacitor surfaces.

## Verification

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/.claude/worktrees/feature+ios-m9-recording-export-completion

# pbxproj 4-section grep gate
grep -c FilmtoneSecurityScopedBookmark.swift apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
# expect 4

xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS' \
  -configuration Debug -derivedDataPath /tmp/filmtone-m14b-dd build
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /tmp/filmtone-m14b-dd/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

## Owner walk (acceptance gate)

Each must be clearly true before M14-B archives:

1. **SSD master export from same session works** — record to SSD,
   immediately edit + export without dismissing the capture view in
   between. Toast = "Exported from master". Output file is the
   ProRes 422 HQ Apple Log 2 master quality.
2. **SSD master export from new session works** — record to SSD,
   dismiss capture, return to editor with the proxy already loaded,
   tap export. Toast = "Exported from master". This is the
   M14-A → M14-B improvement: today the same flow falls back to
   proxy because no scope is held.
3. **App relaunch + SSD master export works** — record to SSD,
   force-quit + relaunch the app. The editor opens to the proxy
   (rehydrated via `currentCapturePackageRef`). Tap export. Toast =
   "Exported from master". This is the relaunch case the per-package
   bookmark unlocks.
4. **SSD unmounted falls back gracefully** — record to SSD, unmount
   the SSD, tap export. Toast = "Exported from proxy — master not
   reachable". Bookmark resolution returns nil; the M14-A
   `usingProxyMasterMissing` / `usingProxyMasterUnreadable` branches
   still drive the toast wording.
5. **Internal-Documents capture unaffected** — record without SSD,
   edit + export. Toast = "Exported from master" (same as M14-A;
   internal masters never go through the bookmark path because
   `masterBookmark = nil`).
6. **Photos / Files edits unaffected** — Photos source export
   continues to read "書き出し完了" / "Export complete".

If any FAIL: iterate before commit.

## Stop Conditions

- Any edit to capture writer / movie output / facade internals.
- Two simulator build failures from the same root cause.
- pbxproj 4-section grep returns < 4 for the new helper file.
- Master export output regression vs. M14-A internal master export
  (same package, same Look → different artifact).
- Owner reports scope leak symptoms (system "Files" prompts after
  export, persistent "Documents in use" indicator, etc.).

## Out of Scope (deferred to later M14-C)

- Sidecar `export.json` provenance fields recording the master/proxy
  decision (M14-C).
- Reconnect-prompt UI for SSD-unmounted master export (today's toast
  message is honest enough; UI affordance is a polish lane).
- Highlight reel export resolution alignment.
- Export pipeline format-specific master handling (e.g.
  Apple Log 2 → BT.709 LUT during export — separate lane).

## Execution log (autonomous run 2026-05-09)

- 01:38-01:56 JST: Step 1-6 executed continuously per active scope.
- M14-A archived as PASS to
  `archive/2026-05-09-m14-a-master-proxy-decision.md`. Strategy log
  + Sub-milestone entries appended for both M14-A PASS and M14-B open.
- New file `FilmtoneSecurityScopedBookmark.swift` (~85 lines): pure
  stateless helper with `make(for: URL) -> Data?` and
  `resolve(_ Data) -> URL?`. NSLog on failure / stale; no throws so
  capture finalize is never blocked.
- `FilmtoneCapturePackage.swift`: additive optional
  `masterBookmark: Data?` (in-memory).
- `FilmtoneCapturePackagePersistence.swift`:
  - additive optional `masterBookmark: Data?` on
    `FilmtoneCapturePackageSnapshotV1` (no schemaVersion bump per
    existing convention; `Data` round-trips as base64 in JSON).
  - `makeSnapshot(from:)` and `makePackage(from:)` round-trip the
    field.
- `FilmtoneCaptureSession.swift`: in the proxy-success branch where
  the package is constructed, generate `masterBookmark` via the new
  helper when `storagePolicy == .externalSecurityScopedFolder`;
  internal masters stay nil. The capture surface still holds folder
  scope at this point so iOS accepts the bookmark generation.
- `FilmtoneEditorStore.swift`:
  - `ResolvedExportSource` extended with `fileprivate scopedURL: URL?`
    and a `release()` method that calls
    `stopAccessingSecurityScopedResource()`.
  - `resolveExportSource()` reordered: bookmark resolve + scope
    acquire happens before fileExists / probe gates. Every fallback
    branch drops scope before returning; only `.usingMaster` retains
    it for the caller to release later.
  - `export()` and `exportAndSave()` both moved the
    `resolveExportSource()` call out of the inner `do` so a
    `defer { resolved.release() }` covers throw paths too.
- pbxproj 4-section gate: PASS — `FilmtoneSecurityScopedBookmark.swift`
  appears 4 times.
- Simulator build: PASS.
- Device build: PASS (signed).
- Install + launch: PASS — running on iPhone 17 Pro #7.

## Owner walk pending — six reads

(See "Owner walk (acceptance gate)" above.) The 6 reads validate
SSD same-session, SSD new-session, SSD post-relaunch, SSD unmounted,
internal-only, and Photos / Files parity.

If all 6 PASS: archive this active.md →
`2026-05-09-m14-b-master-bookmark.md`, append 1-3 line strategy.md
Completion Log entry, open M14-C (sidecar provenance for the
master/proxy decision in `export.json`).

If any FAIL: iterate before commit.

## Outcome

(Filled at archive time after owner walk acceptance.)
