# S6 - Capture Orientation Contract

Date: 2026-05-10 JST

## Goal

Make capture orientation an explicit product contract so rotating the iPhone
does not corrupt the live preview, chrome layout, tap-to-focus coordinates,
recorded master/proxy orientation, or export provenance.

The current hotfix commit (`12978262 Lock iOS capture surface orientation`)
is containment only: it prevents SwiftUI landscape relayout from fighting the
existing `videoRotationAngle = 90` capture pipeline. S6 is the real lane.

## Product Locks

- No leaf-only text/icon rotation. The previous attempt made cockpit labels
  vertical, clipped HUD text, and caused overlapping controls.
- Owner-smoke revision: dynamic AVFoundation / scene orientation is disabled
  in S6 because it broke the core portrait capture/preview path. Capture video
  stays portrait-pinned, while whole chrome controls rotate from
  `UIDeviceOrientation` so parameter labels remain readable when the phone is
  held sideways.
- Use `AVCaptureConnection.videoRotationAngle`; do not add new
  `videoOrientation` usage.
- Ignore transient `faceUp`, `faceDown`, and `unknown` device orientation.
  Keep the last valid capture orientation instead.
- Freeze orientation for a recording at record start. Mid-record device
  rotation must not rewrite the master orientation silently.
- If movie orientation becomes dynamic, persist requested and observed
  orientation in `capture-package.json` and export sidecar provenance.
- Preserve the strict master gates: ProRes 422 HQ, Apple Log 2, 4K24,
  selected lens, stabilization request/observation, SSD policy, proxy
  generation, editor adoption, and export path.
- Keep outer-shell work minimal. No App Store, screenshots, broad QA, or
  marketing copy in this lane.

## Non-S6 Dirty Worktree Notice

The workspace already contains unrelated staged and unstaged changes
(front-camera exploration, recording-time storage pressure, desktop release
work, Creative Pack work, and docs cleanup). S6 owns only orientation-related
capture changes and this active plan unless explicitly noted in the
implementation log.

## Implementation Plan

- [x] Commit immediate containment hotfix.
- [x] Create orientation-specific active plan and switch `strategy.md`
  Current Active to S6.
- [x] Split orientation responsibility out of `AppDelegate` / capture view
  into dedicated code.
- [x] Add a typed capture-orientation model backed by
  `AVCaptureDevice.RotationCoordinator` preview/capture angles.
- [x] Apply orientation to preview connections in one place:
  `AVCaptureVideoPreviewLayer` for fallback preview, renderer-side
  CIImage transform for graded VDO preview, and existing tap-to-focus
  conversion.
- [x] Decide whether movie output should remain portrait-pinned or adopt the
  start-of-record orientation; if dynamic, add package + sidecar truth before
  shipping the change.
- [x] Restore portrait-pinned capture after owner smoke showed dynamic
  orientation breaks vertical preview and can strand the UI after one
  landscape rotation.
- [x] Restore chrome readability on physical landscape without touching
  preview/movie rotation: rotate whole chips, HUD pills, lens chips, SSD, and
  LOOK controls instead of rotating leaf text/icons.
- [x] Owner-requested S3 take-picker revision: replace the fixed four-frame
  contact strip with a lightweight still-frame scrubber so long SSD takes can be
  inspected before choosing which take opens in the editor.
- [ ] Add a landscape chrome layout only if needed after preview/master
  orientation is correct. Do not rotate individual text leaves.
- [x] Run minimal verification after each meaningful step.
- [x] Update verification log and implementation notes as work lands.

## Verification Plan

Coder-side:

- `git diff --check` on S6-owned files.
- `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace
  -scheme App -configuration Debug -destination 'generic/platform=iOS'
  build CODE_SIGNING_ALLOWED=NO`
- `bun run verify:swift-contract` if package/sidecar wire shape changes.
- Grep for banned remnants:
  `captureChromeRotated|captureChromeAngle|FilmtoneCaptureOrientation`
  unless a deliberately named replacement is introduced.

Owner-device smoke:

1. Open capture in portrait; preview upright, controls readable.
2. Rotate the physical device left/right; preview remains upright and the
   parameter chips / HUD / lens chips / SSD / LOOK controls rotate as whole
   readable controls, not clipped vertical text.
3. Rotate back upright; chrome returns to portrait and preview is not stranded
   in landscape.
4. Tap-to-focus in portrait; reticle and focus point match the tapped subject
   area.
5. Record a short portrait clip.
6. Adopt it into the editor; proxy orientation and preview match capture.
7. Run short export; master/proxy/package/sidecar orientation truth records
   the portrait-pinned 90 degree contract.

## Implementation Notes

- 2026-05-10: S6 opened after owner confirmed the portrait-lock hotfix
  commit and asked to proceed autonomously.
- 2026-05-10: Split `FilmtoneInterfaceOrientationLock` out of
  `AppDelegate` and added `FilmtoneCaptureOrientation.swift` for typed
  AVFoundation rotation values.
- 2026-05-10: `FilmtoneCaptureSession` now installs
  `AVCaptureDevice.RotationCoordinator`, tracks preview and capture
  rotation separately, applies fallback-preview rotation to the preview-layer
  connection, freezes movie rotation at record start, and fails loudly if the
  observed movie connection angle differs at record finish.
- 2026-05-10: After checking Apple AVFoundation docs, the graded Metal
  preview no longer rotates the `AVCaptureVideoDataOutput` connection.
  `FilmtoneCaptureLivePreview` receives the typed preview angle and rotates
  the CIImage in the renderer before grade/aspect-fill.
- 2026-05-10: `capture-package.json` and export sidecar provenance now carry
  `requestedCaptureRotationDegrees` and `observedCaptureRotationDegrees`
  additively for S6 captures.
- 2026-05-10: Owner smoke found the dynamic path breaks the core vertical
  product path: portrait preview is wrong and once the device goes landscape
  it cannot recover to portrait. S6 now explicitly returns to portrait-pinned
  capture: scene mask locked to portrait, VDO/fallback/movie connections use
  the proven 90 degree baseline, Metal preview does not add an extra renderer
  rotation, and package/sidecar truth still records requested/observed 90.
- 2026-05-10: Owner then correctly rejected the first recovery because it also
  removed physical-landscape chrome feedback. Added UI-only chrome orientation:
  capture/video remains portrait-pinned, but whole control surfaces rotate from
  `UIDeviceOrientation` via a dedicated environment modifier. This avoids the
  previous failed leaf-only text/icon rotation that clipped labels and left
  card shapes unrotated.
- 2026-05-10: Owner smoke rejected that chrome revision too: rotating each
  control surface in-place still produced vertical card-in-card shapes and
  overlapping badges. Removed the per-control rotation path. The revised
  approach lays out the entire cockpit overlay against landscape dimensions
  first, then rotates the full chrome overlay as one unit while leaving preview
  and movie capture portrait-pinned.
- 2026-05-10: Responsibility follow-up after owner flagged
  `FilmtoneCaptureView.swift` size: moved the S6 overlay rotation/sizing
  responsibility into `FilmtoneCaptureChromeOverlay` in
  `FilmtoneCaptureChrome.swift`. `FilmtoneCaptureView` now only supplies
  chrome content and the current chrome orientation.
- 2026-05-10: Owner requested the take picker move beyond static thumbnails
  because 1-minute SSD takes can look indistinguishable from a single thumbnail.
  The planned revision is still-image based, not multi-`AVPlayer`: each visible
  take gets a bounded low-resolution proxy frame set, a scrub indicator, and an
  explicit Open control so inspection gestures cannot accidentally commit a
  take.
- 2026-05-10: Implemented the S3 take-picker scrubber in
  `FilmtoneCaptureView.swift`: each visible take now samples 12 low-resolution
  proxy frames with nearest-keyframe `AVAssetImageGenerator` tolerance, shows a
  larger selected still plus a compact scrub strip, and commits only through the
  row's explicit Open button.
- 2026-05-10: Owner flagged `FilmtoneCaptureView.swift` as still too large.
  Split completed-take inspection into
  `FilmtoneCaptureTakePickerOverlay.swift`, moved the fallback
  `AVCaptureVideoPreviewLayer` bridge into `FilmtoneCapturePreviewLayer.swift`,
  and moved the chrome slot layout into `FilmtoneCaptureChromeScaffold` so
  `FilmtoneCaptureView` is back to capture orchestration instead of owning
  every overlay implementation.
- 2026-05-10: Owner smoke found take-picker frames were not carrying the
  capture-time Look and were too dim to judge. Added package-specific take
  preview grade processors through `FilmtoneEditorStore`, applied them to
  scrubber samples, kept the selected still full-strength over a blurred fill,
  and pinned scrub timing to `recordedDurationSeconds` so the timeline label
  matches package truth.
- 2026-05-10: Owner smoke rejected the take-picker compactness: the scrub strip
  could visually escape the rounded Liquid Glass panel and the vertical row was
  too tall for physical-landscape height. The picker panel now clips its content
  to the glass shape, expands to available compact height, and switches rows to
  a lower horizontal layout with a shorter scrub strip when height is limited.
- 2026-05-10: Owner smoke confirmed that the compact layout issue was still not
  solved and that Look-applied inspection was too heavy to verify correctly.
  Split take preview sampling / caching / selected-still Look rendering into
  `FilmtoneCaptureTakePreviewLoader`. The picker view now owns presentation
  only; compact-height rows remove the external thumbnail strip entirely and
  place a six-sample scrub rail inside the selected preview surface.

## Verification Log

- 2026-05-09: Containment hotfix before S6 active:
  `git diff --check` clean, `xcodebuild ... generic/platform=iOS ...`
  succeeded, banned leaf-rotation symbols absent.
- 2026-05-10: S6 rotation contract implementation pass:
  `git diff --check` clean on S6-owned files;
  `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace
  -scheme App -configuration Debug -destination 'generic/platform=iOS'
  build CODE_SIGNING_ALLOWED=NO` succeeded;
  `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract`
  passed all checks including sidecar builder.
- 2026-05-10: Renderer-responsibility revision after Apple doc check:
  removed `AVCaptureVideoDataOutput` connection rotation from the graded
  preview path; `FilmtoneCaptureLivePreview` now receives
  `orientationState.previewRotation` and applies the CIImage transform before
  grading / aspect-fill. `git diff --check` clean on S6-owned files;
  pbxproj grep count is 4 for both new Swift files;
  `xcodebuild ... generic/platform=iOS ...` succeeded;
  `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract` passed.
- 2026-05-10: Device deployment pass:
  `xcodebuild ... -destination id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9
  -derivedDataPath /tmp/filmtone-s6-device-build build` succeeded for
  iPhone (7), `xcrun devicectl device install app ... App.app` succeeded,
  and `xcrun devicectl device process launch ... com.chibatakumi.film.lab.ios`
  launched the app.
- 2026-05-10: Portrait-pinned recovery pass after owner smoke rejection:
  `git diff --check` clean on S6-owned files;
  `xcodebuild ... generic/platform=iOS ... CODE_SIGNING_ALLOWED=NO`
  succeeded; `bun run --cwd apps/capacitor-film-lab-ios
  verify:swift-contract` passed; `xcodebuild ... -destination
  id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 -derivedDataPath
  /tmp/filmtone-s6-portrait-pin-device-build build` succeeded. No install or
  launch was run for this revision.
- 2026-05-10: Chrome-readable revision after owner rejected the
  portrait-only recovery: `git diff --check` clean on touched S6/sidecar
  files; conflict-marker grep clean across the iOS Swift surface;
  `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract`
  passed; `xcodebuild ... generic/platform=iOS ... CODE_SIGNING_ALLOWED=NO`
  succeeded; `xcodebuild ... -destination
  id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 -derivedDataPath
  /tmp/filmtone-s6-chrome-device-build build` succeeded. No install or launch
  was run for this revision.
- 2026-05-10: S3 take-picker scrubber revision:
  `git diff --check` clean on touched files;
  `xcodebuild ... generic/platform=iOS ... CODE_SIGNING_ALLOWED=NO` succeeded
  after removing the new Swift 6 actor-isolation warning from detached frame
  generation; `bun run --cwd apps/capacitor-film-lab-ios
  verify:swift-contract` passed.
- 2026-05-10: Capture-view responsibility split:
  `git diff --check` clean on touched files; pbxproj grep count is 4 for both
  new Swift files (`FilmtoneCaptureTakePickerOverlay.swift` and
  `FilmtoneCapturePreviewLayer.swift`); `xcodebuild ... generic/platform=iOS
  ... CODE_SIGNING_ALLOWED=NO` succeeded. No install or launch was run.
- 2026-05-10: Owner requested device install after the responsibility split:
  `xcodebuild ... -destination id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9
  -derivedDataPath /tmp/filmtone-capture-refactor-device-build build`
  succeeded, then `xcrun devicectl device install app ... App.app` installed
  bundle `com.chibatakumi.film.lab.ios`. No launch was run.
- 2026-05-10: Take-picker graded-thumbnail revision after owner smoke:
  `git diff --check` clean on touched files; pbxproj grep count is 4 for both
  split Swift files; `xcodebuild ... generic/platform=iOS ...
  CODE_SIGNING_ALLOWED=NO` succeeded; `bun run --cwd
  apps/capacitor-film-lab-ios verify:swift-contract` passed; `xcodebuild ...
  -destination id=00008150-001674883C84401C -derivedDataPath
  /tmp/filmtone-take-picker-graded-device-build build` succeeded; `xcrun
  devicectl device install app ... App.app` installed bundle
  `com.chibatakumi.film.lab.ios`. No launch was run.
- 2026-05-10: Take-picker layout correction after owner screenshot:
  `git diff --check` clean on `FilmtoneCaptureTakePickerOverlay.swift`;
  `xcodebuild ... generic/platform=iOS ... CODE_SIGNING_ALLOWED=NO` succeeded;
  `xcodebuild ... -destination id=00008150-001674883C84401C -derivedDataPath
  /tmp/filmtone-take-picker-layout-device-build build` succeeded; `xcrun
  devicectl device install app ... App.app` installed bundle
  `com.chibatakumi.film.lab.ios`. No launch was run.
- 2026-05-10: Take-picker performance + compact-layout responsibility revision:
  `git diff --check` clean on the take-picker overlay, new loader, and pbxproj;
  pbxproj grep count is 4 for `FilmtoneCaptureTakePreviewLoader.swift`;
  `xcodebuild ... generic/platform=iOS ... CODE_SIGNING_ALLOWED=NO` succeeded;
  `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract` passed;
  `xcodebuild ... -destination id=00008150-001674883C84401C -derivedDataPath
  /tmp/filmtone-take-picker-perf-layout-device-build build` succeeded; `xcrun
  devicectl device install app ... App.app` installed bundle
  `com.chibatakumi.film.lab.ios`. No launch was run.

## Current State

Dynamic AVFoundation / scene rotation is rejected by owner smoke. The current
code-side S6 revision keeps preview/movie portrait-pinned and restores
physical-landscape chrome readability by rotating whole controls from
`UIDeviceOrientation`. The S3 take picker now keeps frame sampling and lazy
selected-still Look rendering in a dedicated loader, while compact-height UI
uses an in-preview scrub rail instead of an external thumbnail strip. It is
green on Swift contract, generic iOS build, and iPhone (7) device
build/install. Owner device smoke is still required before archiving.
