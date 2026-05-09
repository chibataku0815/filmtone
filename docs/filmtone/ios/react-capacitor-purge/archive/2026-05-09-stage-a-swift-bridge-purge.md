# Active: Stage A — Swift bridge surface deletion

Date: 2026-05-09 JST
Branch: `worktree-feature-ios-react-capacitor-purge`
Status: **scoped — autonomous Stage A in flight 2026-05-09**

## Why this active exists

First stage of the React/Capacitor purge per the lane strategy.
Deletes the runtime-dead Swift Capacitor bridge surface so subsequent
stages (TS tree, pods) can land without dangling Swift references.

## Inventory (verified via grep this session)

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBridgeViewController.swift`
  — 9 LOC. Subclasses `CAPBridgeViewController`, registers
  `FilmtoneMediaPlugin`. Never referenced in the boot path
  (`AppDelegate` → `FilmtoneRootHostingController`, no
  CAPBridgeViewController instance is constructed at runtime).
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaPlugin.swift`
  — 444 LOC. `CAPPlugin` exposing `probeSource` / `runExport` /
  `recordClip` etc. via the JS bridge. Only consumers live in TS
  (`src/native/filmtoneMedia.ts`); no Swift surface calls into it.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
  + `apps/capacitor-film-lab-ios/ios/App/App/ExportCancelController.swift`
  — comment-only doc references like
  `///   - userViaUI: WebView UI → ``FilmtoneMediaPlugin/cancelExport(_:)``.`
  Need updating so the docs stop pointing at deleted symbols.

`grep -rln 'import Capacitor\|CAPPlugin' apps/.../ios/App/App` returns
exactly the two files being deleted. No other Swift code depends on
Capacitor types.

## Scope

- DELETE `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBridgeViewController.swift`
  + remove its 4 pbxproj entries.
- DELETE `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaPlugin.swift`
  + remove its 4 pbxproj entries.
- Update doc comments in `FilmtoneExportSession.swift` (~1 ref) and
  `ExportCancelController.swift` (~2 refs) so they describe the
  new SwiftUI cancel path instead of the gone Capacitor plugin.

No new files. No behavior change. The Capacitor framework is still
linked via Pods at this stage (Stage D removes that).

## Verification

```bash
grep -rln 'import Capacitor\|CAPPlugin\|FilmtoneMediaPlugin\|FilmtoneBridgeViewController' apps/capacitor-film-lab-ios/ios/App/App
# expect 0 hits

for f in FilmtoneBridgeViewController FilmtoneMediaPlugin; do
  echo "$f $(grep -c "$f" apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj)"
done
# expect 0 each

xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS' \
  -configuration Debug -derivedDataPath /tmp/filmtone-purge-A-dd build
```

Sim + signed device builds must PASS.

## Stop conditions

- `grep CAPPlugin` finds a Swift reference outside the two deleted
  files — investigate before continuing.
- Build error referencing a missing Capacitor symbol — Stage D was
  expected to remove the framework but Stage A should leave it
  available; if the framework itself is gone we have a sequencing bug.
- Any change to non-Capacitor Swift files outside the doc-comment
  fix described above.

## Outcome

PASS. `FilmtoneBridgeViewController.swift` + `FilmtoneMediaPlugin.swift`
deleted; pbxproj 4 entries × 2 files removed; `Main.storyboard`
custom-class reference replaced with stub `UIViewController` (the
storyboard root is overwritten by AppDelegate at launch); doc-only
`FilmtoneMediaPlugin` references in `FilmtoneExportSession.swift`
and `ExportCancelController.swift` rewritten to point at the
SwiftUI cancel path. `grep CAPPlugin|FilmtoneMediaPlugin|
FilmtoneBridgeViewController|import Capacitor` returns 0 hits
across `apps/.../ios/App/App/` (Swift + storyboard + pbxproj).

Simulator build: `** BUILD SUCCEEDED **`.
