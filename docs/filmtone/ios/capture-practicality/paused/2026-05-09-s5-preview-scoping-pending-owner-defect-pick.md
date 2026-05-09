# Active: S5 - Recording Preview Behavior Improvement

Date: 2026-05-09 JST
Status: Paused — scoping pass code-complete, full preview-improvement
lane awaiting owner-device dominant-defect pick

Paused reason: The S5 done condition that does not need owner data
(fallback preview honesty) is landed and verified; the candidate-
problem map is documented; the actual preview-improvement
implementation cannot proceed without the owner identifying which of
the five candidate defects (judder / first-frame black / Look-switch
delay / color mismatch / recording-time performance) dominates on
their hardware. The next S5 active task is owner-side; this scoping
pass is complete from the coder side.

## Milestone

S5 - Recording Preview Behavior Improvement

## Goal

Improve the capture preview only after the capture controls (S1),
multi-take flow (S3), and SSD duration work (S4) are stable, because
this work touches the render loop and is heavier than the prior
milestones.

The strategy explicitly puts S5 last for a reason: render-loop work
expands easily into color honesty, performance, and master-path
contention. This active task is therefore a **scoping** lane, not an
implementation lane for the full preview rewrite. Two outputs:

1. The one S5 done condition that does not need owner-device data
   lands now: the fallback preview path becomes honest about whether
   the live preview is graded.
2. A short candidate-problem list is left for the owner-device pass
   so the next active task can pick the dominant defect to fix.

## Product Locks

- The MovieFileOutput master path stays untouched. ProRes 422 HQ /
  Apple Log 2 / 4K24 / cinematicEE / lens contract / per-take
  packaging are unchanged by S5.
- The preview-only VDO stays preview-only. Nothing in S5 routes the
  VDO to the writer.
- Fallback preview (raw `AVCaptureVideoPreviewLayer` because
  `canAddOutput` rejected VDO + MovieFileOutput coexistence) renders
  an explicit "Ungraded" badge so the owner knows the chip-applied
  Look is not visible in the live frame.
- The badge is not a failure banner — fallback preview is an
  intentional graceful-degrade path, not an error state.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureView.swift`

No new Swift file. The badge is small enough to render inline as a
private `@ViewBuilder` overlay on the existing `previewLayer`
composition.

## Read-Only References

- `docs/filmtone/ios/capture-practicality/strategy.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureLivePreview.swift`

## Checklist

- [x] Add an explicit "Ungraded" badge to the preview overlay when
  `session.hasLivePreview == false`, anchored at top-leading so it
  does not overlap the cockpit's close X (top-leading) or the
  HUD readout (top-trailing).
- [x] Survey the existing preview path (FilmtoneCaptureLivePreview,
  hasLivePreview gating, canAddOutput rejection conditions) and
  enumerate the candidate dominant defects.
- [x] Run focused verification and record results here.

## Candidate Dominant Preview Problems

The strategy lists five candidate dominant problems. Code-side this
lane cannot pick which one matters most without owner-device
feedback; below is a map of each candidate to its likely fix surface
so the next active can move fast once the owner confirms which one.

| Candidate | Likely fix surface | Master path risk |
|-----------|-------------------|------------------|
| Judder | `FilmtoneCaptureLivePreview` MTKView display-tick coupling, GCD queue priorities, drop-frame logic | None — preview-only |
| First-frame black | `previewFrameSink.clear()` / first-frame priming on `prepare(lens:)`, surface attach timing | None — preview-only |
| Look-switch delay | `activeGradeProcessor` rebuild on `.onChange(of: captureLookSelection)`, processor cache on `FilmtoneEditorStore` | None — preview-only |
| Color mismatch (preview vs master) | Apple Log 2 → display gamma mapping in `FilmtoneSharedGradeProcessor.applyForLivePreview`, BGRA tonemap | None — preview-only; master keeps Apple Log 2 ProRes422HQ |
| Recording-time performance | VDO sample buffer rate during `.recording`, `previewSampleQueue` priority, MTKView `preferredFramesPerSecond` under load | None — preview-only; movie connection is independent |

## Verification

Required before archive:

```bash
git diff --check
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Owner-device smoke before declaring product PASS:

1. On hardware where VDO + MovieFileOutput coexist (iPhone 17 Pro
   Max iOS 26.4), confirm no badge is shown — graded preview is the
   default path.
2. On hardware (or under thermal throttling) where the VDO is
   rejected at `prepare(lens:)`, confirm the "Ungraded" badge
   appears at top-leading without overlapping the close X or the
   storage HUD.
3. Confirm the badge is a11y-readable as "Ungraded preview" so a
   VoiceOver user gets the same signal a sighted user gets.
4. Owner identifies which candidate dominant problem matters most.
   Result feeds the next S5 active task.

## Done Conditions

- Fallback preview always renders an explicit, owner-visible
  "Ungraded" badge.
- Candidate-problem map documented in this active.
- Verification results appended.
- This file is moved to
  `archive/YYYY-MM-DD-s5-preview-scoping.md` after the smoke passes;
  otherwise it pauses to
  `paused/<date>-s5-preview-scoping-pending-owner-smoke.md` while
  the full preview-improvement lane stays open.
- `strategy.md` gets a 1-3 line entry noting that S5 entered scoping
  phase and the dominant-defect pick is owner-side.

## Stop Conditions

Stop and report if any of these fires:

- The badge change requires touching `FilmtoneCaptureLivePreview`'s
  render path or the VDO setup logic.
- The badge competes with the S3 commit pill for the same screen
  region.
- The work starts to require master-path changes.
- Three consecutive verification failures from the same root cause.

## Out of Scope

- Picking the dominant preview defect (owner-side).
- Implementing the dominant-defect fix (next S5 active task once
  owner picks).
- Waveform / false color / zebra / focus peaking tools.
- Replacing the export pipeline.
- App Store assets and public copy.

## Verification Log

- 2026-05-09 JST — S5 scoping pass:
  - `git diff --check` clean on
    `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureView.swift`.
  - `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` →
    `** BUILD SUCCEEDED **`.
  - `bun run verify:swift-contract` not re-run on this lane:
    only the SwiftUI preview overlay changed; no Phase0 / look /
    veil / sidecar / source-profile math contract surface was
    reached. The S3/S4 passes left those green and they are
    unchanged here.
- Owner-device smoke (graded-path no-badge, fallback-path badge
  visible without overlap, VoiceOver readback, dominant-defect
  pick) — pending owner-device run.

## Implementation Notes

- Added a small "Ungraded preview" badge (`captureGlassHUD` HUD
  shape), only rendered when `session.hasLivePreview == false` and
  the raw `previewLayer` fallback exists.
- Revision pass after S3 integration: moved the badge out of the raw
  preview ZStack's fixed top-leading coordinate and into the cockpit
  overlay flow directly below the top controls. This prevents overlap
  with the S3 take-commit pill, storage HUD, quality-contract line,
  and parameter chips.
- `allowsHitTesting(false)` so tap-to-focus / tap-to-meter still
  reach the underlying preview surface even if the badge frame
  grows.
- a11y label spells "Ungraded preview" (matches the visible text)
  and an accessibility identifier
  `filmtone.capture.ungradedPreviewBadge` is set so the
  owner-device smoke can assert presence/absence with a single
  XCUITest predicate when it is later automated.
- Implementation kept in `FilmtoneCaptureView` — the badge is
  small enough that extracting to a separate file would add a
  pbxproj 4-section gate cost without a god-object payoff. The
  existing private-`@ViewBuilder` overlay pattern (the dropped
  F3-R DIAG overlay used the same shape) is the right home.
- The candidate-problem map under `## Candidate Dominant Preview
  Problems` is the scoping output. None of those candidates can
  be chosen without the owner's dominant-defect signal on their
  hardware — that pick is the next S5 active task's prompt.
