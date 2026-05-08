# Active: Interrupt — Capture Availability Gate

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m16-capture-availability-gate`
Status: completed

## Goal

Disable Filmtone's native recording entry points on devices that do not
runtime-report the current capture contract:

- 3840x2160
- 24 fps
- Apple Log 2 (`AVCaptureColorSpace.rawValue == 4`)
- `cinematicExtendedEnhanced`

The recording pipeline remains Apple Log 2 first. Unsupported devices should
not see an enabled "Record" entry that only fails after presentation.

## Edit Targets

- `FilmtoneCaptureLensCatalog.swift`
- `FilmtoneRootView.swift`
- `FilmtoneEmptyView.swift`
- `FilmtoneFullscreenLutEditor.swift`
- `FilmtoneStrings.swift`

## Out of Scope

- Capture-session fallback to Apple Log / HDR / SDR.
- Any writer, package, proxy, export, sidecar, or React/Capacitor change.
- Broad device QA.

## Checklist

- [x] Add a runtime availability helper based on the existing lens contract scan.
- [x] Disable empty-view and editor record entry points when unsupported.
- [x] Show a concise unsupported-device explanation.
- [x] Run the smallest Swift build verification.

## Verification

```bash
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

## Outcome

PASS. Added a `FilmtoneCaptureAvailability` gate backed by the existing
`FilmtoneCaptureLensCatalog.availableRearLenses()` contract scan. Empty-view
and fullscreen-editor record entry points now disable when the current device
does not expose an Apple Log 2 / 4K24 / cinematicEE capture path, with a short
unsupported-device explanation. `presentCaptureSurfaceIfSupported()` also
guards the full-screen cover presentation path so UI and behavior agree.

Verification:

- `git diff --check` clean.
- `xcodebuild ... generic/platform=iOS Simulator ... CODE_SIGNING_ALLOWED=NO`
  finished with `** BUILD SUCCEEDED **`.

Environment note: the isolated worktree initially lacked ignored Capacitor /
CocoaPods generated files. `Pods`, `node_modules`, `public`, `config.xml`, and
`capacitor.config.json` were restored locally for build verification only; none
of those generated files are tracked in this diff.
