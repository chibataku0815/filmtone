# Filmtone iOS — React / Capacitor Purge Strategy

Date: 2026-05-09 JST

## Why this lane exists

The iOS app's runtime entry point is native SwiftUI:
`AppDelegate.didFinishLaunchingWithOptions` constructs
`FilmtoneRootHostingController(store: store)` and uses it as the root
view controller. Per the project memory
`feedback_ios_app_is_swiftui_not_capacitor` (2026-05-08, M7 closeout):

> `apps/capacitor-film-lab-ios/` の live UI は SwiftUI
> (`FilmtoneRootView`)。React/MobilePhase0Editor は dead code、
> 編集しても画面に出ない。

The React + Capacitor stack survives purely as build-time artifacts:

- `apps/capacitor-film-lab-ios/src/` — React + TypeScript Phase 0
  editor (~hundreds of files), unreachable at runtime.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaPlugin.swift`
  (444 LOC) — Capacitor `CAPPlugin` exposing `recordClip` /
  `runExport` etc. via the JS bridge. **No SwiftUI surface calls
  it**; only doc comments in `FilmtoneExportSession.swift` and
  `ExportCancelController.swift` reference it.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBridgeViewController.swift`
  (9 LOC) — `CAPBridgeViewController` subclass that registers the
  plugin. Dead at runtime since AppDelegate boots the SwiftUI
  hosting controller directly.
- `index.html` / `vite.config.ts` / `tsconfig.json` /
  `postcss.config.mjs` — Vite build harness for the React bundle.
- `capacitor.config.ts` — Capacitor app config for the JS bridge.
- `ios/App/Podfile` + `Pods/` — CocoaPods build of `Capacitor` /
  `CapacitorCordova` frameworks linked into the app binary.
- `ios/App/App/public/` — Vite-built React bundle copied at archive
  time; never served to a Capacitor WebView since AppDelegate skips
  the WebView path.

This lane removes the dead surface in stages so each step is
independently verifiable on simulator + device.

## Stage plan

| Stage | Scope | Risk |
|---|---|---|
| **A. Swift bridge surface** | Delete `FilmtoneBridgeViewController.swift` + `FilmtoneMediaPlugin.swift`. Update doc-only `FilmtoneMediaPlugin` references in `FilmtoneExportSession.swift` / `ExportCancelController.swift`. Drop pbxproj 4-section entries. | Low — runtime-dead surface only. |
| **B. TS / React tree** | Delete `src/`, `index.html`, `vite.config.ts`, `tsconfig.json`, `postcss.config.mjs`, `capacitor.config.ts`. Drop bun build scripts (`dev` / `build` / `preview` / `cap:*`) + React/Capacitor deps from `package.json`. Drop `bun run build` step from `apps/capacitor-film-lab-ios/CLAUDE.md` §3 commit gate. | Low — no Swift dependencies. |
| **C. Public bundle** | Delete `ios/App/App/public/` (Vite-built React bundle). Drop `cap:sync:ios` references from CLAUDE.md / docs. | Low — never reached at runtime. |
| **D. CocoaPods purge** | Drop `Capacitor` / `CapacitorCordova` pods from `ios/App/Podfile`. Re-run `pod install` (or remove `Pods/` + Podfile entirely). Update Xcode project to drop framework references and `[CP] Embed Pods Frameworks` build phase. | Medium — Xcode project surgery; risk of breaking build phases. Owner gate before merging to main. |
| **E. Tests / docs cleanup** | Audit `apps/capacitor-film-lab-ios/Tests/` — keep Swift tests, drop TS-only fixtures. Rewrite `apps/capacitor-film-lab-ios/CLAUDE.md` §1 (drop Capacitor row), §3 (drop bun build), §5 (drop plugin surface), §9 (drop Capacitor antipatterns). | Low. |

Stages A + B + C land autonomously per owner authorization
(2026-05-09). Stage D requires explicit owner gate before merge
because pod / Xcode project changes affect the release archive
pipeline (`fastlane archive` / `bundle install`).

## Done conditions

- `import Capacitor` and `CAPPlugin` references reach 0 hits across
  the iOS app.
- `apps/capacitor-film-lab-ios/src/` does not exist.
- `apps/capacitor-film-lab-ios/package.json` no longer declares
  `@capacitor/core` / `react` / `react-dom` / `vite`.
- `xcodebuild -workspace … -scheme App` PASSes on simulator + device
  after each stage, signed device build PASSes after Stage A & B.
- Stage D leaves the app binary smaller (Capacitor framework is
  ~few MB) and the build no longer needs `bundle install` / `pod install`
  to embed Capacitor.

## Out of scope

- Renaming the app directory (`apps/capacitor-film-lab-ios/` →
  `apps/film-lab-ios/`). Large refactor that affects CI, docs,
  worktree paths, and submodule consumption — owner gate required.
- Renaming the Xcode project file / `.xcworkspace`.
- Changing the Bundle ID `com.chibatakumi.film.lab.ios`.
- Any change to the v2-capture-gyroflow lane (M13 / M14 / M15 work
  is independent and lives in the
  `worktree-feature+ios-m9-recording-export-completion` branch).

## Lane owner

Autonomous Claude Code session in worktree
`.claude/worktrees/feature-ios-react-capacitor-purge` on branch
`worktree-feature-ios-react-capacitor-purge`. Owner picks up at
PR / merge time.

---

## Completion log

- 2026-05-09: **Lane PASS** — Stages A → E all landed in this worktree
  branch. Owner pre-merge verification (especially the fastlane
  archive lane against the trimmed Podfile) deferred to the release
  chat per the user's stated split. `grep import Capacitor|CAPPlugin`
  returns 0 across `apps/capacitor-film-lab-ios/` (excluding
  `node_modules/`); .ipa no longer embeds Capacitor.framework.
  Directory rename (`capacitor-film-lab-ios/` → `film-lab-ios/`)
  remains out of scope per the strategy.
- 2026-05-09: **Lane MERGED into main** as commit `47a1d76d`
  (`Merge branch 'worktree-feature-ios-react-capacitor-purge'`,
  `--no-ff`). Conflict resolution surfaced during the merge:
  pbxproj diverged because main had absorbed M9 / M13 / M14 / M15
  work after the purge branched, so resolution = take main's
  pbxproj and strip the 5 Capacitor file UUIDs (≈ 20 lines across
  4 pbxproj sections). Modify/delete conflicts on
  `FilmtoneMediaPlugin.swift` + `src/native/filmtoneMedia{,.web}.ts`
  resolved by keeping the deletion (purge intent stands).
  Post-merge `pod install` was required because `Pods/` is
  gitignored — the working-tree pods were still Capacitor-shaped
  until reinstall. Simulator build PASS after `pod install`.
  Worktree + branch removed. Details in
  [`archive/2026-05-09-stage-e-docs-cleanup.md`](./archive/2026-05-09-stage-e-docs-cleanup.md)
  under "Post-merge follow-up". Push to `origin/main` deferred —
  main is currently 36 commits ahead of origin and carries
  in-flight macOS Desktop work in its dirty state.
