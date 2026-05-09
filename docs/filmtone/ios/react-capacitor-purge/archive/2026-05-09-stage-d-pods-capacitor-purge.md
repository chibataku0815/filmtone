# Active: Stage D — CocoaPods Capacitor purge

Date: 2026-05-09 JST
Branch: `worktree-feature-ios-react-capacitor-purge`
Status: **scoped — autonomous Stage D in flight 2026-05-09**

## Why this active exists

After Stage A removed the Swift bridge, Stage B removed the React /
Vite tree, and Stage C removed the public/ + Capacitor configs, the
last Capacitor surface is the linked `Capacitor.framework` /
`CapacitorCordova.framework` pulled in via CocoaPods. Stage D
removes those pods so the .ipa stops carrying the Capacitor binary.

`fastlane/Fastfile`, `fastlane/Snapfile`, and
`scripts/generate-help-comparison-assets.sh` hard-reference
`App.xcworkspace`, so the workspace stays in place; only the Podfile
contents change (Capacitor pods removed) and `pod install` cleans
the integration layer.

## Scope

- Strip `Podfile` to a minimal CocoaPods setup with no third-party
  pods declared. Drop the `require_relative '...pods_helpers'` shim,
  the `capacitor_pods` def, the `capacitor_pods` call inside
  `target 'App' do`, and the `post_install assertDeploymentTarget`
  hook (Capacitor-specific helper).
- Run `pod install` so the integration regenerates with 0 pods.
  CocoaPods removes the framework links, the `[CP] Embed Pods
  Frameworks` build phase, and the per-config xcconfig includes
  for Capacitor / CapacitorCordova.
- Verify: simulator + signed device builds PASS.

## Verification

```bash
grep -c 'Capacitor' apps/capacitor-film-lab-ios/ios/App/Podfile
# expect 1 — the comment header explaining the purge

grep -c 'Capacitor' apps/capacitor-film-lab-ios/ios/App/Podfile.lock
# expect 0

xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS' \
  -configuration Debug build
```

## Stop conditions

- `pod install` errors during integration update.
- Build error referencing `Capacitor.framework` /
  `CapacitorCordova.framework` — Stage A should have removed all
  Swift `import Capacitor` already.
- fastlane `archive` lane breakage (deferred to owner verification
  before merge).

## Outcome

PASS. Podfile rewritten to a minimal CocoaPods setup with no
third-party pods. `pod install` removed the Capacitor +
CapacitorCordova integration: framework links dropped, `[CP] Embed
Pods Frameworks` script phase dropped, per-config xcconfig
references updated to point at the now-empty Pods-App.{debug,release}.xcconfig.

`Podfile.lock`: 0 dependencies, 0 specs.
`grep Capacitor Podfile.lock` returns 0.

Simulator build: `** BUILD SUCCEEDED **`.
Device build: `** BUILD SUCCEEDED **` (signed).

The .ipa binary no longer embeds Capacitor.framework or
CapacitorCordova.framework. The Pods.xcodeproj target is now empty
but kept in the workspace so future third-party iOS deps can land
via either CocoaPods or SwiftPM without reorganizing the workspace.
