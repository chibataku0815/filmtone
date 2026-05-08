# Active: Stage B — TS / React tree deletion

Date: 2026-05-09 JST
Branch: `worktree-feature-ios-react-capacitor-purge`
Status: **scoped — autonomous Stage B in flight 2026-05-09**

## Why this active exists

Stage A deleted the Swift Capacitor bridge surface. The TS / React
tree (`apps/capacitor-film-lab-ios/src/`, ~hundreds of files) is
runtime-dead but still consumed at build time by `bun run build`
+ `cap sync ios` to populate `apps/.../ios/App/App/public/`. That
public bundle is bundled into the app .ipa but never served because
the Capacitor WebView path was already torn out in Stage A.

Stage B removes the TS / React tree + the Vite build harness.
`apps/.../ios/App/App/public/` (the consumed Vite output) stays on
disk during Stage B so the Xcode project's existing Resources
reference doesn't break the build; Stage C deletes that public
bundle + the pbxproj reference.

## Scope

- DELETE `apps/capacitor-film-lab-ios/src/` (entire React + TS tree).
- DELETE `apps/capacitor-film-lab-ios/Tests/` if and only if
  it's TS-only (verify per-subdirectory before deletion).
- DELETE `apps/capacitor-film-lab-ios/index.html` (Vite entry).
- DELETE `apps/capacitor-film-lab-ios/vite.config.ts`.
- DELETE `apps/capacitor-film-lab-ios/tsconfig.json`.
- DELETE `apps/capacitor-film-lab-ios/postcss.config.mjs`.
- DELETE `apps/capacitor-film-lab-ios/capacitor.config.ts`.
- DELETE `apps/capacitor-film-lab-ios/dist/` (Vite output staging).
- UPDATE `apps/capacitor-film-lab-ios/package.json`:
  - Drop scripts: `dev` / `build` / `preview` / `verify:swift-contract`
    / `gen:fixtures:*` / `cap:add:ios` / `cap:sync:ios` / `ios:open`.
  - Keep scripts: `release:bundle:install` / `release:env:check` /
    `release:archive` / `release:screenshots` / `release:metadata` /
    `release:beta` / `release:appstore` / `release:submit-review`
    (fastlane only, no React dep).
  - Drop dependencies: `@capacitor/core` / `react` / `react-dom` /
    `@phosphor-icons/react` / `film-lab-core` (Swift only via Pods?
    verify) / `film-lab-ui`.
  - Drop devDependencies: `@capacitor/cli`, `vite`, `@vitejs/*`,
    `typescript`, `tsx`, `@types/*` for React / DOM.
- UPDATE `apps/capacitor-film-lab-ios/CLAUDE.md`:
  - §3 Commit gate: drop step 1 (`bun run build`).
  - §3: drop the `bun run cap:sync:ios` warning line.
  - §5: drop the "Capacitor plugin surface" + `src/native/filmtoneMedia.ts`
    bullet.
  - §2 identity row: drop the Capacitor row.

The `apps/.../ios/App/App/public/` bundle stays in place until
Stage C — Xcode project still references it as a resource directory;
removing it now would break `xcodebuild`.

## Verification

```bash
test ! -d apps/capacitor-film-lab-ios/src
test ! -e apps/capacitor-film-lab-ios/index.html
test ! -e apps/capacitor-film-lab-ios/vite.config.ts
test ! -e apps/capacitor-film-lab-ios/capacitor.config.ts
grep -c '"build":' apps/capacitor-film-lab-ios/package.json
# expect 0

xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
# expect ** BUILD SUCCEEDED **
```

## Stop conditions

- Any deleted TS file is referenced by Swift code or workspace
  fastlane lanes — investigate before continuing.
- xcodebuild fails after deletion (would mean the public/ bundle
  stale-state isn't holding) — restore the deleted files.
- `apps/capacitor-film-lab-ios/Tests/` contains Swift fixtures used
  by Swift tests — keep those, only delete TS subdirs.

## Outcome

PASS. Deleted: `apps/capacitor-film-lab-ios/src/`,
`apps/capacitor-film-lab-ios/dist/`, `index.html`, `vite.config.ts`,
`tsconfig.json`, `postcss.config.mjs`, `capacitor.config.ts`. Trimmed
`package.json` to fastlane release scripts + Swift verify scripts +
fixture-generator scripts (no `dependencies` / `devDependencies`
blocks; node_modules at this app level is no longer needed for
production paths).

`apps/capacitor-film-lab-ios/CLAUDE.md` updated: §2 identity row
notes the SwiftUI-only stack with a 2026-05-09 React/Capacitor
purge timestamp; §3 commit gate dropped the `bun run build` step
and the `cap:sync:ios` warning; §5 code map dropped the Capacitor
plugin surface bullet.

`Tests/Fixtures/` kept — Swift doc comments reference these
source-profile encoding ramps as SSOT for color-science verification
(no runtime dependency, but documentation pointer remains valid).

`apps/capacitor-film-lab-ios/ios/App/App/public/` left in place at
this stage so the Xcode project's existing Resources reference does
not break the build; Stage C deletes the public bundle + the pbxproj
reference.

Simulator build: `** BUILD SUCCEEDED **`.
