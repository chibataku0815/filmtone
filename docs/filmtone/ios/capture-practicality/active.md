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
2. Rotate to landscape left before recording; preview upright for framing,
   controls not overlapping.
3. Rotate to landscape right before recording; same checks.
4. Tap-to-focus in each orientation; reticle and focus point match the tapped
   subject area.
5. Record a short landscape-left clip and a short landscape-right clip.
6. Adopt each into the editor; proxy orientation and preview match capture.
7. Run short export; master/proxy/package/sidecar orientation truth matches
   the selected S6 contract.

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

## Current State

Coder-side S6 core is green and installed/launched on iPhone (7). Remaining
risk is visual/behavioral and needs owner-device smoke: preview uprightness in
landscape left/right, cockpit layout density after real scene rotation,
tap-to-focus coordinate correctness, and editor/export orientation truth for
short landscape clips.
