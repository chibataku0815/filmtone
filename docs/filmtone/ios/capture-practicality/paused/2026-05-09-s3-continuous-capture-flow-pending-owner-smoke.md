# Active: S3 - Continuous Capture Flow

Date: 2026-05-09 JST
Status: Paused — code-complete, pending owner-device smoke

Paused reason: All coder-side S3 work (auto-rearm session, captured-
takes accumulator, persistent commit pill, and visual take chooser for
multi-take sessions) is landed and verified (`xcodebuild` BUILD
SUCCEEDED, `verify:swift-contract` green, pbxproj 4-section count = 4
for the new file). The remaining done conditions are owner-device
smoke checks (3+ takes in one session, contact-strip-backed chosen
take opens in editor, earlier takes survive on disk). S4 - External
SSD 5-Minute Capture Ceiling proceeds in parallel because it depends
only on S3's session lifecycle, which is now in place code-side.

## Milestone

S3 - Continuous Capture Flow

## Goal

Support a real shooting session where the owner records multiple takes
without being forced into the editor after every clip. The strategy's
open question favors implicit "keep shooting" with explicit "open
editor" — that is the chosen direction.

## Product Locks

- Recording completion no longer auto-routes to the editor. The
  session re-arms for the next take immediately.
- After 3+ takes the owner can open the editor with a chosen take via
  an explicit, persistent commit pill in the cockpit. One take opens
  directly; multiple takes present a clear Liquid Glass overlay with
  four proxy frames per take, not a card-in-card system sheet.
- Earlier takes are not lost: each `capture-package.json` lands on
  disk and the relaunch reconnect path can rediscover it.
- "All takes live" means all packages persist on disk. The editor is
  still a single-source surface, so batch/all-import is not claimed
  by S3.
- The cockpit shows the take count — owner always knows how many
  clips this session has captured.
- Editor adoption still routes through the existing
  `onCompleted(_:)` → `adoptCaptureResult(_:)` path; sidecar
  provenance, master/proxy URLs, and Phase0 / Look math contracts are
  untouched.
- Mid-record state never loses takes — the commit pill is disabled
  while recording / stopping; close X is also disabled while recording.

## Edit Targets (this lane)

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureView.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureCockpitTopBar.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureTopStatusBar.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCapturePostRecordChoice.swift` (new)
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  (4-section registration of the new file)

## Read-Only References

- `docs/filmtone/ios/capture-practicality/strategy.md`
- `docs/filmtone/ios/capture-practicality/paused/2026-05-09-s1-stabilization-toggle-pending-owner-smoke.md`
- `docs/filmtone/ios/capture-practicality/paused/2026-05-09-s2-active-lens-visibility-pending-owner-smoke.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`

## Checklist

- [x] Add `FilmtoneCaptureSession.rearm()` so a `.completed` session
  can return to `.ready` without tearing down the AVCaptureSession
  graph.
- [x] Track captured packages in `FilmtoneCaptureView` and append on
  every `.completed` transition without invoking
  `session.teardown()` / `onCompleted(pkg)` automatically.
- [x] Auto-rearm immediately on `.completed` so the cockpit never
  paints a frozen post-record screen.
- [x] Surface the take count and the explicit open-editor affordance
  via a new `FilmtoneCapturePostRecordChoice` Liquid Glass pill
  rendered between the close X and the HUD readout.
- [x] Wire the commit pill to call `session.teardown()` +
  `releaseExternalFolderScope()` + `onCompleted(selectedPkg)`,
  matching the prior auto-route's terminal behavior.
- [x] Owner-smoke revision: when multiple takes exist, present an
  explicit take chooser so take 2 can be committed even after take 3
  exists.
- [x] Owner-smoke revision: make that chooser visual by generating
  lazy thumbnails from each take's proxy, with take number, latest
  badge, duration, lens, and Look metadata.
- [x] Owner-smoke revision: replace the heavy `NavigationStack` /
  `List(.insetGrouped)` sheet with an in-capture clear Liquid Glass
  overlay, and replace single thumbnails with a four-frame contact
  strip so 1-minute SSD takes can be compared by motion/context.
- [x] Owner-smoke revision: move LOOK out of the crowded top parameter
  row into the bottom-right capture control; the top row stays five
  chips (ISO / SHUTTER / EV / WB / STAB).
- [x] Disable the commit pill while recording / stopping and during
  the in-flight teardown so a stop-into-commit double-tap cannot
  race the proxy export's `.completed` transition.
- [x] Register the new Swift file in `project.pbxproj` 4 sections
  (PBXBuildFile / PBXFileReference / PBXSourcesBuildPhase / PBXGroup);
  grep count = 4.
- [x] Run focused verification and record results here.

## Verification

Required before archive:

```bash
git diff --check
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
cd apps/capacitor-film-lab-ios && bun run verify:swift-contract
```

Owner-device smoke before declaring product PASS:

1. Record three short takes back-to-back without ever leaving the
   capture surface; confirm the cockpit returns to live preview after
   every `stop`.
2. Confirm the commit pill increments to "Editor · 3 takes" and is
   tappable when not recording.
3. Tap the pill; confirm a clear Liquid Glass chooser appears over
   the capture preview with four proxy frames for each take. Pick take
   2 by its contact strip and confirm the editor opens take 2, not the
   latest take, and that `capture-package.json` records the correct
   master / proxy linkage for that clip.
4. Inspect `~/Documents/captures/` (internal mode) or the SSD
   destination (external mode) and confirm earlier-take packages exist
   intact on disk.
5. Re-enter capture, record one more take, dismiss with the close X
   without committing; confirm no take is lost on disk and the editor
   was not changed.
6. Confirm S1 STAB toggle and S2 lens chip / contract line agreement
   still hold during a 3-take session.
7. Confirm the top parameter row stays to five chips and SHUTTER no
   longer wraps; LOOK opens from the bottom-right control and is
   disabled while recording.

## Done Conditions

- Capture surface supports multi-take recording without auto-routing
  to the editor.
- Take count is owner-visible at all times after the first record.
- The selected take is the one that opens in the editor when
  committed; latest is only the default owner choice, not a hidden
  rule.
- Editor adoption still uses the existing `adoptCaptureResult(_:)`
  path.
- Master / proxy persistence and export provenance remain intact for
  every clip, not just the committed one.
- Verification results are appended to this file.
- This file is moved to
  `archive/YYYY-MM-DD-s3-continuous-capture-flow.md` after the
  owner-device smoke passes; otherwise it pauses to
  `paused/<date>-s3-continuous-capture-flow-pending-owner-smoke.md`
  while S4 begins.
- `strategy.md` gets only a 1-3 line completion log entry.

## Stop Conditions

Stop and report if any of these fires:

- The fix requires changing the AVCaptureMovieFileOutput connection
  contract or rewiring the proxy-export pipeline.
- A stop-into-commit double-tap can race the proxy export's
  `.completed` transition.
- Earlier takes get silently overwritten because the captureId or
  package directory generation is reused across takes.
- The work starts to require S4 SSD duration changes or S5 preview
  render-loop changes.

## Out of Scope

- Full clip browser / timeline.
- Batch editing, all-import into the editor, or per-take Look
  reassignment.
- Auto-export.
- Rewriting the editor adoption pipeline.
- Owner-side disposal of unwanted takes (`capture-package.json` files
  are reachable via relaunch reconnect; a delete-take UI is its own
  product surface).

## Verification Log

- 2026-05-09 JST — S3 implementation pass:
  - `git diff --check` clean across edited Swift surface +
    `project.pbxproj`.
  - `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` →
    `** BUILD SUCCEEDED **`.
  - `bun run verify:swift-contract` (run from
    `apps/capacitor-film-lab-ios/`) → all sub-tests pass (phase0
    contract, source-profile math 6 profiles, look × veil energy
    merge 10/10, sidecar builder).
  - pbxproj `grep -c 'FilmtoneCapturePostRecordChoice'` = 4
    (PBXBuildFile + PBXFileReference + PBXGroup + PBXSourcesBuildPhase).
- Device smoke (3-take session / chosen take opens editor / earlier
  takes survive on disk / close X without commit does not lose
  takes) — pending owner-device run.
- 2026-05-09 JST — Owner-smoke revision:
  - LOOK moved from the top parameter row to the bottom-right capture
    control, opposite the SSD control. Top row is now ISO / SHUTTER /
    EV / WB / STAB only.
  - Multi-take commit now opens a take chooser when more than one take
    exists; one-take sessions still commit directly.
  - `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` →
    `** BUILD SUCCEEDED **`.
  - `bun run verify:swift-contract` → all sub-tests pass.
  - Owner-device smoke (take 2 selection, all packages retained,
    bottom-right LOOK placement/no top-row wrap) pending.
- 2026-05-09 JST — Visual take-picker revision:
  - Multi-take chooser now renders proxy-backed thumbnails plus take
    number, Latest badge, duration, lens, and Look metadata so the
    owner can identify the actual image before committing.
  - `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` →
    `** BUILD SUCCEEDED **`.
  - Owner-device smoke (thumbnail loads for each take and chosen
    thumbnail opens the matching editor clip) pending.
- 2026-05-09 JST — Visual take-picker revision 2:
  - Replaced the heavy system `NavigationStack` / grouped-list sheet
    with a single clear Liquid Glass overlay inside
    `FilmtoneCaptureView`, keeping the capture preview visible behind
    the chooser and avoiding card-in-card structure.
  - Each take now renders a four-frame proxy contact strip sampled
    across the clip, so longer SSD takes are not judged from one
    still frame.
  - `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` →
    `** BUILD SUCCEEDED **`.

## Implementation Notes

- `FilmtoneCaptureSession.rearm()` clears only per-run scratch state
  (`masterURL` / `proxyURL` / `packageDirURL` /
  `recordedDurationSnapshot` / `pendingFailure` /
  `recordingDelegate`) and transitions `state` from `.completed` to
  `.ready`. Owner choices (exposure mode, ISO, shutter, EV, WB lock,
  stabilization, lens) are intentionally preserved across takes —
  re-arm is "next take continues from here," not "session reset."
- `FilmtoneCaptureView` holds `capturedPackages: [FilmtoneCapturePackage]`
  and `commitInFlight: Bool`. `.onChange(of: session.state)`
  `.completed(pkg)` appends and calls `session.rearm()` instead of
  the prior auto teardown + `onCompleted(pkg)` pair.
- `commitTakes()` is the explicit terminal action. One take commits
  directly; multiple takes present `FilmtoneCaptureTakePickerOverlay`,
  a clear Liquid Glass overlay with one four-frame proxy contact
  strip per take. `commitTake(at:)` tears down the session, releases
  the security-scoped folder bookmark (when external mode is in use),
  and calls `onCompleted(selectedPackage)`.
- `FilmtoneCapturePostRecordChoice` is a pure SwiftUI view: take
  count + isDisabled + onCommit closure. Lives in its own file so
  the orchestrator does not also own the take-readout chrome. The
  pill's opacity drops to 0 when `takeCount == 0` so the cockpit
  geometry stays stable from the first record onward — no layout
  jump when the first `.completed` fires.
- The pill is layered between the close X (top-leading) and the
  HUD readout (top-trailing). Close X handles full dismiss
  (takes orphan to disk, recoverable via `capture-package.json`);
  the pill is the explicit "commit a take to editor" action.
- LOOK is no longer a top parameter chip. `FilmtoneCaptureBottomDeck`
  owns the bottom-right LOOK button, while the SSD picker remains
  bottom-left; an external clear action now rides as a small overlay
  on the SSD control so the right side stays reserved for LOOK.
- The new file is registered in 4 `project.pbxproj` sections per
  the CLAUDE.md commit gate (PBXBuildFile / PBXFileReference /
  PBXSourcesBuildPhase / PBXGroup, grep count = 4).
- The S1 STAB toggle and S2 lens-prefix contract line are
  unchanged — both surfaces continue to render correctly because
  rearm() preserves the live AVCaptureSession's connection
  configuration (stabilization mode, format, color space).
