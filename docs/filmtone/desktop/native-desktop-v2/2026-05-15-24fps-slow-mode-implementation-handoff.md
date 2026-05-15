# 24fps Slow Mode Implementation Handoff

Date: 2026-05-15 JST  
Repository: `/Users/chibatakumi/.codex/worktrees/2304/filmtone`  
Branch state: detached `HEAD` (`git status` reports `## HEAD (no branch)`)  
Current active lane: `docs/filmtone/desktop/native-desktop-v2/active.md`

## Purpose

This document is a full handoff for the interrupted 24fps slow-mode
implementation. It should let a new chat continue without reconstructing the
conversation.

The user first asked how Filmtone should handle loaded material that is not
24fps. The product decision was to start with explicit slow conforming, not
automatic frame-rate conversion: when a user opts in on footage above 24fps,
Filmtone should lay each source frame onto a 24fps timeline, producing slow
motion. Same-speed 24fps conversion, interpolation, optical flow, frame
blending, audio stretching, and pitch correction remain out of scope.

## Product Decision

Add a user-selected video timing mode for eligible video sources:

- `normal`: default, existing behavior.
- `slow24`: explicit 24fps slow conform.

Eligibility:

- Source must be a video.
- Source fps must be finite and greater than `24.01`.
- Unknown fps, invalid fps, `24`, and `23.976` are not eligible.

Slow-mode math:

- Target fps: `24`.
- Slow factor / playback multiplier: `24 / sourceFps`.
- Example: `60fps -> 0.4`; one source second displays as about `2.5` seconds.
- Example: `30fps -> 0.8`; one source second displays as about `1.25` seconds.
- Display-to-source mapping: `sourceTime = displayTime * slowFactor`.
- Source-to-display mapping: `displayTime = sourceTime / slowFactor`.
- Output duration: `sourceDuration / slowFactor`, or `sourceFrameCount / 24`
  when the export loop knows the decoded source-frame count.

Audio policy:

- Slow mode exports without audio.
- `audioPreserved` should be false.
- No audio stretch or pitch correction in this task.

UI copy:

- Japanese labels: `通常`, `24fpsスロー`
- Japanese helper: `素材の各フレームを24fpsで並べます。音声は含めません。`
- English labels: `Normal`, `24 fps Slow`
- English helper: `Uses each source frame at 24 fps. Audio is not included.`

Highlight export:

- Out of scope.
- Existing Highlight behavior must remain normal timing even if the editor has
  slow mode selected.

## Lane Setup Done

The repo instructions required current work to run through Native Desktop v2
`active.md`.

Completed setup:

- Read required target docs for Native Desktop v2.
- Ran `git status --short --branch`.
- The previous Twilight bundled-look `active.md` was paused and moved to:
  `docs/filmtone/desktop/native-desktop-v2/paused/2026-05-15-twilight-bundled-look-paused.md`
- Created a new active lane:
  `docs/filmtone/desktop/native-desktop-v2/active.md`
- The active lane is currently for `24fps Slow Mode (iOS + macOS)`.
- 2026-05-15 user direction: Twilight does not need to be restored after this
  interrupt completes. Finish the slow-mode lane, archive its active log, and
  leave Twilight paused unless the user explicitly asks to resume it.

Do not route this work to the legacy Electron app. Normal Desktop work means:

```text
apps/filmtone-desktop-macos/
```

## Current Git State

Tracked modified files at handoff time:

```text
apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift
apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneFullscreenLutEditor.swift
apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtonePreviewView.swift
apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorExportCoordinator.swift
apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorPreviewOrchestrator.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportPanel.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSidecarBuilder.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportConnectPackageAssembler.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoFramePump.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoIOBuilder.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoTimeline.swift
apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaRuntime.swift
apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaTypes.swift
apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtonePhase0Math.swift
apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneExportSnapshot.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarTypes.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoSession.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/ExportInspectorPanel.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift
apps/filmtone-desktop-macos/Verify/run.sh
docs/filmtone/desktop/native-desktop-v2/active.md
packages/film-lab-smart-look/dist/index.d.ts
```

Untracked files at handoff time:

```text
docs/filmtone/desktop/native-desktop-v2/paused/2026-05-15-twilight-bundled-look-paused.md
packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneVideoTiming.swift
packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/FilmtoneVideoTimingTests.swift
```

Note: `packages/film-lab-smart-look/dist/index.d.ts` changed during dependency
/ build work, not as an intentional slow-mode edit. Its diff adds
`shadowLatitude` and `vision3500t` to generated declarations. Do not blindly
revert it; inspect whether source/dist drift existed before this task or
whether a build step regenerated a tracked dist file.

## Shared Swift Core Changes

New file:

```text
packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneVideoTiming.swift
```

Added:

- `FilmtoneVideoTimingMode`
  - `.normal`
  - `.slow24`
- `FilmtoneVideoTimingPolicy`
  - `slowTargetFPS = 24.0`
  - `slowEligibilityThresholdFPS = 24.01`
  - requested/resolved mode
  - fps validation
  - eligibility
  - speed multiplier
  - source/display time mapping
  - output duration helper
- `FilmtoneVideoTimingMetadataDTO`
  - `videoTimingMode`
  - `sourceFps`
  - `targetFps`
  - `speedMultiplier`
  - `sourceDurationSec`
  - `outputDurationSec`
  - `audioPolicy`

New tests:

```text
packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/FilmtoneVideoTimingTests.swift
```

Covered:

- `60fps -> speedMultiplier 0.4`, one source second becomes about `2.5s`.
- `30fps -> speedMultiplier 0.8`.
- `24fps`, `23.976fps`, and unknown fps fall back to normal.
- Slow-mode metadata uses silent audio policy.

Important review point:

- `FilmtoneVideoTimingPolicy.targetFPS` currently returns rounded source fps in
  normal mode and `24` in slow mode.
- That may be acceptable for macOS normal export, which historically appears to
  use source fps, but it is not acceptable for iOS Phase0 normal sidecar/output
  profile, which expects the existing `Phase0OutputProfileDTO.fps` value.
- The immediate failing iOS contract is caused by using this policy-derived
  normal fps in iOS sidecar output.

## iOS Changes

### Request / Result DTOs

File:

```text
apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaTypes.swift
```

Changes:

- Added `videoTimingMode: FilmtoneVideoTimingMode? = nil` to
  `Phase0ExportRequestDTO`.
- Added helper properties:
  - `sourceVideoFPS`
  - `videoTimingPolicy`
  - `effectiveOutputFPS`
  - `effectivePreserveAudio`
- Added result fields:
  - `videoTimingMode`
  - `audioPolicy`

Known issue:

- `effectiveOutputFPS` currently returns `videoTimingPolicy.targetFPS`.
- For iOS normal mode, this can become rounded source fps, which breaks the
  existing sidecar contract expecting `request.output.fps`.
- Next fix should likely change it to:

```swift
var effectiveOutputFPS: Int {
    videoTimingPolicy.isSlow24 ? videoTimingPolicy.targetFPS : output.fps
}
```

Mirror the same fix in:

```text
apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift
```

### Request Builder

File:

```text
apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtonePhase0Math.swift
```

Changes:

- `buildExportRequest(...)` now accepts:

```swift
videoTimingMode: FilmtoneVideoTimingMode = .normal
```

- The value is passed into `Phase0ExportRequestDTO`.

Contract support was also updated in:

```text
apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift
```

It now mirrors `videoTimingMode` and the helper properties so standalone
contract tests can typecheck.

### Store / Eligibility / UI State

File:

```text
apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift
```

Changes:

- Added `@Published var videoTimingMode: FilmtoneVideoTimingMode = .normal`.
- Added:
  - `sourceVideoFPS`
  - `videoTimingPolicy`
  - `resolvedVideoTimingMode`
  - `canUseSlow24VideoTiming`
- Source replacement or ineligible source resets `videoTimingMode` to
  `.normal`.
- `setVideoTimingMode(_:)` validates eligibility, updates preview policy, and
  invalidates export package state.

### Export Panel UI

File:

```text
apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportPanel.swift
```

Changes:

- Imports `FilmLabSwiftCore`.
- Shows `通常` / `24fpsスロー` or `Normal` / `24 fps Slow` only when the
  selected source is eligible.
- Displays the required helper copy.
- Finished export metrics show slow timing as `24fpsスロー・音声なし` or
  `24 fps Slow · no audio`.

### Preview

Files:

```text
apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorPreviewOrchestrator.swift
apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtonePreviewView.swift
apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneFullscreenLutEditor.swift
```

Changes:

- Preview keeps AVPlayer internal time in source time.
- Display duration/current time are mapped through timing policy.
- Slow playback rate is `baseRate * slowFactor`.
- Fullscreen custom scrub seeks from display time back to source time.
- Fullscreen marker positions display source markers on the slow display
  timeline.
- Inline AVPlayer controls are hidden in slow mode because native controls would
  expose raw source duration/time.
- Video composition frame duration uses `1/24` in slow mode.

Review risk:

- Marker behavior was adjusted to map source marker times into display time for
  slow preview. This should be visually checked on footage with existing
  markers.

### iOS Export

Files:

```text
apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorExportCoordinator.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoTimeline.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoFramePump.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoIOBuilder.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportConnectPackageAssembler.swift
apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaRuntime.swift
```

Changes:

- Normal export receives `store.resolvedVideoTimingMode`.
- Highlight export does not pass the selected timing mode, so it remains normal.
- Slow `ExportVideoTimeline` estimates output frame count from source duration
  and source fps; output duration becomes frame count / 24.
- Slow `ExportVideoFramePump` is source-sample driven:
  - Read each decoded source frame once.
  - Render using original source presentation time.
  - Append output frame at `frameIndex / 24`.
- Audio writer path is disabled in slow mode through `effectivePreserveAudio`.
- Result DTO preserves timing fields when benchmark records are attached.
- Connect package DCTL output fps uses `effectiveOutputFPS`.

Review risk:

- iOS `effectiveOutputFPS` must not change normal Phase0 output semantics.
  Fix the helper before rerunning verification.

### iOS Sidecar

File:

```text
apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSidecarBuilder.swift
```

Changes:

- Added timing fields into `SidecarOutput`:
  - `videoTimingMode`
  - `sourceFps`
  - `targetFps`
  - `speedMultiplier`
  - `sourceDurationSec`
  - `outputDurationSec`
  - `audioPolicy`
- `preserveAudio` now uses `request.effectivePreserveAudio`.
- `fps` currently uses `request.effectiveOutputFPS`.

Known issue:

- The existing sidecar contract test fails because normal-mode `output.fps` is
  now policy/source-derived instead of the existing `request.output.fps`.
- Fix `effectiveOutputFPS` as described above.

Design consistency point:

- iOS currently places timing metadata inside the `output` block.
- macOS currently writes a separate top-level `videoTiming` dictionary.
- Both are additive, but a follow-up should decide whether cross-platform
  sidecar shape should be unified before this ships.

## macOS Desktop Changes

### State / UI / Preview

Files:

```text
apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoSession.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/ExportInspectorPanel.swift
```

Changes:

- Added `videoTimingMode` to editor state.
- Added eligibility/resolved-policy helpers.
- Source replacement resets mode to normal.
- `setVideoTimingMode(_:)` validates eligibility and applies policy to the
  video session.
- Video session stores base playback rate separately from timing multiplier.
- Effective playback rate is `selectedRate * slowFactor`.
- Existing `1x/2x/3x` controls remain base rates.
- Slow composition frame duration uses 24fps.
- Scrub bar and preview duration display mapped display time.
- Seek maps display seconds back to source seconds.
- Markers remain stored as source time and are displayed on the mapped timeline.
- Export inspector shows the same English timing selector and helper copy.

### macOS Export / Sidecar

Files:

```text
apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarTypes.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneExportSnapshot.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift
```

Changes:

- `FilmtoneVideoExportRequest` includes `videoTimingMode` defaulting to
  `.normal`.
- Normal video export request passes `state.resolvedVideoTimingMode`.
- Highlight result stays `.normal`.
- Slow export:
  - Uses source-sample-driven output.
  - Renders with original source PTS.
  - Replaces output PTS with `frameIndex / 24`.
  - Disables audio preservation.
  - Skips slow-mode audio validation.
- Result snapshot includes timing mode and output frame rate.
- Sidecar writer accepts optional timing metadata and writes a top-level
  `videoTiming` dictionary.

Desktop-specific note:

- Existing Desktop normal export appears to preserve/source-drive normal fps.
  The implementation keeps normal frame-rate handling separate from slow-mode
  24fps. Do not blindly force all Desktop normal exports to 24fps unless the
  owner explicitly changes that product decision.

### macOS Verify Harness

File:

```text
apps/filmtone-desktop-macos/Verify/run.sh
```

Change:

- Added the new Swift core object:

```text
FilmtoneVideoTiming.swift.o
```

to `PKG_OBJECTS`, because the Desktop verify harness links package objects
manually.

## Verification Already Run

Passed:

```bash
swift test
```

Run in:

```text
packages/film-lab-swift-core
```

Result:

- Passed.
- 76 tests, 0 failures.

Passed:

```bash
bun run build:core
```

Note:

- First attempt failed because dependencies were missing (`tsup: command not
  found`).
- Ran `bun install`.
- Re-ran `bun run build:core`; it passed.

Passed:

```bash
bun run verify:desktop
```

Note:

- First attempt failed because `FilmtoneDesktopVideoSession` referenced
  `self.compositionFrameRate` before all stored properties were initialized.
- Fixed by using `nominalFrameRate` for the initial composition and applying
  the slow policy after session setup.
- Re-ran `bun run verify:desktop`; Xcode build succeeded with exit code 0.

Passed:

```bash
bun run check:filmtone-copy
bun run check:filmtone-context
git diff --check
```

Context check output included:

```text
Filmtone context sync: high-risk changes have copy/history context.
Impact markers found:
  - docs/filmtone/desktop/native-desktop-v2/active.md
```

iOS verification status:

```bash
bun run verify:ios
```

First failure:

- Missing CocoaPods xcconfig:
  `Pods/Target Support Files/Pods-App/Pods-App.debug.xcconfig`.
- Ran `pod install` in:
  `apps/capacitor-film-lab-ios/ios/App`
- `pod install` completed; Podfile has no dependencies.

Second failure:

- `FilmtoneExportPanel.swift` could not find `FilmtoneVideoTimingMode`.
- Fixed by adding `import FilmLabSwiftCore`.

Third/current failure:

- iOS app build and many contract tests progressed.
- Failure is in sidecar builder contract:

```text
Swift/ErrorType.swift:254: Fatal error: Error raised at top level:
main.SidecarCheckError(message: "output.fps mismatch")
./scripts/verify-phase0-contract.sh: line 248: ... Trace/BPT trap: 5
error: script "verify:swift-contract" exited with code 133
error: script "verify:ios" exited with code 133
```

Root cause:

- Existing sidecar fixture expects `parsed.output.fps == 24`.
- The slow-mode change made iOS normal-mode sidecar fps use
  `request.effectiveOutputFPS`.
- `request.effectiveOutputFPS` currently delegates to
  `videoTimingPolicy.targetFPS`, which resolves to rounded source fps in normal
  mode.
- This violates the plan requirement: existing `Phase0OutputProfileDTO` 24fps
  definition must not change.

## Immediate Next Fix

Start with this small fix:

1. In `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaTypes.swift`,
   change `Phase0ExportRequestDTO.effectiveOutputFPS` to use `output.fps` for
   normal mode and `24` for slow mode.
2. Mirror the same change in
   `apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift`.
3. Re-run:

```bash
bun run verify:ios
```

Suggested code:

```swift
var effectiveOutputFPS: Int {
    videoTimingPolicy.isSlow24 ? videoTimingPolicy.targetFPS : output.fps
}
```

After that, review whether `FilmtoneVideoTimingMetadataDTO.make(...)` should
also accept an `effectiveTargetFPS` override for iOS sidecar metadata. The
contract failure only proves `output.fps` broke; it does not yet prove the
metadata shape is product-final.

## Verification Still Needed

After fixing the sidecar fps issue:

```bash
bun run verify:ios
bun run verify:desktop
bun run check:filmtone-copy
bun run check:filmtone-context
git diff --check
```

Recommended extra checks if time permits:

```bash
swift test
```

from:

```text
packages/film-lab-swift-core
```

Manual QA still needed before shipping:

- iOS slow-mode preview on 60fps footage:
  - selector appears only when eligible;
  - displayed duration expands;
  - playback is slow;
  - seek/scrub lands on correct visual moments;
  - native inline controls are not exposed in slow mode.
- iOS slow-mode export:
  - output has no audio;
  - output fps is 24;
  - decoded source frames are not dropped by the slow path;
  - sidecar/result metadata records slow mode.
- macOS slow-mode preview:
  - selector appears only when eligible;
  - `1x/2x/3x` base rates are multiplied by slow factor;
  - scrub/current/duration display mapped time.
- macOS slow-mode export:
  - output PTS is `frameIndex / 24`;
  - render time stays original source PTS;
  - audio is not preserved;
  - sidecar timing metadata exists.
- Highlight export remains unchanged.

## Stop / Caution Points

Do not:

- Edit `apps/desktop-film-lab-batch/`; this is not legacy Electron work.
- Change `Phase0OutputProfileDTO`'s existing 24fps profile as part of this task.
- Add automatic slow conversion; the mode must remain explicit.
- Add same-speed 24fps conversion, frame interpolation, optical flow, frame
  blending, audio stretch, or pitch correction.
- Change Highlight export timing.
- Revert user or generated changes blindly, especially tracked `dist/` files.
- Commit, stage, push, or bump portfolio submodules unless explicitly asked.

Be careful with:

- The difference between iOS output profile fps and macOS normal export fps.
- Sidecar compatibility: all timing additions must be additive.
- Cross-platform sidecar shape: iOS currently adds fields to `output`, macOS
  adds top-level `videoTiming`.
- Marker time semantics: markers are stored in source time but displayed on the
  mapped slow timeline.
- Preview UI: AVPlayer native controls show source-time duration; custom
  controls need display-time mapping.

## Copy / History Impact

Copy / History Impact:

- Adds user-facing timing copy in iOS and macOS export UI.
- Adds additive timing metadata to export results/sidecars.
- Does not require public App Store or release-version copy in this task.

Article Opportunity:

- Release-note only.

Change-History Opportunity:

- Developer note. This is a meaningful implementation-path change because
  Filmtone now has an explicit source-frame conform mode instead of only normal
  timing export.

## Best Continuation Prompt

Use this prompt in the next chat:

```text
You are continuing work in /Users/chibatakumi/.codex/worktrees/2304/filmtone.
Follow AGENTS.md exactly. This is Filmtone Native Desktop v2 work, not legacy
Electron. Start by running git status --short --branch, then read
docs/filmtone/desktop/native-desktop-v2/active.md and
docs/filmtone/desktop/native-desktop-v2/2026-05-15-24fps-slow-mode-implementation-handoff.md.

The current task is implementing explicit 24fps Slow mode for iOS and macOS.
Most code is already written. Do not restart from scratch. Continue from the
current dirty worktree.

Product rules:
- Default timing is normal.
- Slow mode is only user-selected and only eligible for video sources with a
  finite fps greater than 24.01.
- Slow mode lays every decoded source frame onto a 24fps output timeline.
- Slow factor is 24 / sourceFps.
- Preview keeps internal AVPlayer/source time but maps UI current/duration/seek
  to display time.
- Slow export renders using original source PTS but writes output PTS as
  frameIndex / 24.
- Slow export has no audio.
- Highlight export must remain unchanged.
- Do not change Phase0OutputProfileDTO's existing 24fps definition.

Immediate blocker:
bun run verify:ios currently fails in the sidecar builder contract with
"output.fps mismatch". Root cause: iOS Phase0ExportRequestDTO.effectiveOutputFPS
now returns videoTimingPolicy.targetFPS, which becomes rounded source fps in
normal mode. Existing iOS normal sidecar output must keep request.output.fps.

First fix:
In apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaTypes.swift and
apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift, change
effectiveOutputFPS to:

var effectiveOutputFPS: Int {
    videoTimingPolicy.isSlow24 ? videoTimingPolicy.targetFPS : output.fps
}

Then rerun bun run verify:ios. If it passes, rerun bun run verify:desktop,
bun run check:filmtone-copy, bun run check:filmtone-context, and git diff
--check. Also inspect the generated packages/film-lab-smart-look/dist/index.d.ts
diff before deciding whether it belongs in this change.

After verification, update active.md with results. If Done Conditions are met,
archive active.md under docs/filmtone/desktop/native-desktop-v2/archive/ and
append only a short 1-3 line completion note to strategy.md. Do not restore the
paused Twilight active task unless the user explicitly asks for it.
```
