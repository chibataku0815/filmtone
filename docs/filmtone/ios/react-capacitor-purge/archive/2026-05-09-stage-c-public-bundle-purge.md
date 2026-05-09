# Active: Stage C — Public bundle + Capacitor config deletion

Date: 2026-05-09 JST
Branch: `worktree-feature-ios-react-capacitor-purge`
Status: **scoped — autonomous Stage C in flight 2026-05-09**

## Why this active exists

Stage A removed the Swift bridge surface; Stage B removed the React /
Vite tree + Capacitor config TS. The runtime-dead `public/` directory
(Vite-built React bundle copied at archive time) and the
`capacitor.config.json` + `config.xml` runtime configs are still
bundled into the .ipa as Resources. Stage C deletes them from disk
and from the Xcode project so the .ipa stops carrying ~5 MB of dead
web bundle.

## Inventory (verified via grep this session)

In `App.xcodeproj/project.pbxproj`:
- `public/` directory — `PBXFileReference 50B271D0`, `PBXBuildFile
  50B271D1` (Resources), 1 PBXGroup ref, 1 PBXResourcesBuildPhase ref.
- `capacitor.config.json` — `PBXFileReference 50379B22`, `PBXBuildFile
  50379B23` (Resources), 1 PBXGroup ref, 1 PBXResourcesBuildPhase ref.
- `config.xml` — `PBXFileReference 2FAD9762`, `PBXBuildFile
  2FAD9763` (Resources), 1 PBXGroup ref, 1 PBXResourcesBuildPhase ref.

All three were temporarily recreated during Stage A setup so the
build could pass; Stage C deletes them for real now that no runtime
path needs them.

## Scope

- DELETE `apps/capacitor-film-lab-ios/ios/App/App/public/` (entire
  Vite-built React bundle).
- DELETE `apps/capacitor-film-lab-ios/ios/App/App/capacitor.config.json`.
- DELETE `apps/capacitor-film-lab-ios/ios/App/App/config.xml`.
- Drop pbxproj entries (4 sections each × 3 files = 12 lines):
  - `PBXBuildFile` for each Resource entry.
  - `PBXFileReference` for each path.
  - `PBXGroup` membership entry.
  - `PBXResourcesBuildPhase` entry.

## Verification

```bash
test ! -d apps/capacitor-film-lab-ios/ios/App/App/public
test ! -e apps/capacitor-film-lab-ios/ios/App/App/capacitor.config.json
test ! -e apps/capacitor-film-lab-ios/ios/App/App/config.xml
grep -c 'public\b\|capacitor.config.json\|config.xml' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
# expect 0

xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
# expect ** BUILD SUCCEEDED **
```

## Stop conditions

- Build error after pbxproj edits — investigate which removed entry
  was live.
- Any non-Resources reference to `public` in the pbxproj —
  unrelated to the React bundle (e.g., a build setting). Investigate
  before deleting.

## Outcome

PASS. Deleted from disk: `apps/.../ios/App/App/public/`,
`apps/.../ios/App/App/capacitor.config.json`,
`apps/.../ios/App/App/config.xml`. Removed all 12 pbxproj
entries (4 sections × 3 files): PBXBuildFile + PBXFileReference +
PBXGroup membership + PBXResourcesBuildPhase. After Stage C,
`grep public|capacitor.config.json|config.xml` against pbxproj
returns 0 hits.

The .ipa binary no longer carries the ~5 MB Vite-built React bundle
or the runtime Capacitor configs. The Capacitor + CapacitorCordova
frameworks are still linked via Pods (Stage D removes that).

Simulator build: `** BUILD SUCCEEDED **`.
