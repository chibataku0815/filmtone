# Active - Phase 4B Capture Smoke + Lane Closeout

Date: 2026-05-11 JST
Phase: Phase 4B - capture smoke and final lane closeout
Milestone: Verify the post-refactor capture pipeline at the product
surface and close the feature-architecture lane without adding broad QA
machinery.

## Owner Directive

- This is not another refactor bundle unless smoke exposes a real
  blocker.
- Keep outer-shell work minimal: one capture smoke path, existing truth
  scripts, `verify:ios`, and targeted file-path cleanup only.
- Do not create XCTest, formal QA matrices, PSNR fixtures, or broad
  manual test docs here.

## Goal

Validate the end-to-end product path most likely to catch a bad
CaptureSession split:

1. Build remains green after Phase 4A.
2. iOS release truth output remains unchanged in meaning.
3. One real-device smoke completes:
   record -> adopt capture package -> grade change -> export.
4. Any stale docs / release references to moved Swift file paths are
   updated if present.

## Scope

Allowed:

- `docs/filmtone/ios/feature-architecture-refactor/active.md`
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
- `apps/capacitor-film-lab-ios/RELEASE.md` only if it references old
  flat Swift paths.
- Tiny code fix only if smoke exposes a direct Phase 4A regression.

Out of scope:

- Additional architecture extraction.
- SwiftUI view body refactor.
- New tests / QA matrix.
- Portfolio submodule updates.
- Push / PR unless owner asks.

## Checklist

- [ ] Run `bun run verify:ios`.
- [ ] Run `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh`
  with this repo root if needed.
- [ ] Search `apps/capacitor-film-lab-ios/RELEASE.md` and lane docs for
  stale moved Swift file paths; update only real stale references.
- [ ] Owner/device smoke: record one take, adopt into editor, change
  grade, export one output.
- [ ] If smoke fails, record the exact failure and fix only the direct
  regression.
- [ ] Record final lane status and remaining known product risks.

## Verification Gates

Minimum:

- `bun run verify:ios`
- `git diff --check`
- iOS truth script output reviewed for unchanged release meaning

Manual owner gate:

- iPhone 17 Pro Max iOS 26.2:
  record -> grade -> export completes once.

## Done Conditions

- Existing automated gates are green.
- Real-device smoke result is recorded, or explicitly deferred by owner.
- No stale release-path references remain in `RELEASE.md` if any were
  present.
- Strategy completion log records lane closeout status and any remaining
  risks.

## Stop Conditions

- Done conditions are met.
- Real-device smoke exposes a capture correctness bug. Fix the direct
  bug and rerun the smoke once; if it fails again, stop and record the
  blocker.
- `verify:ios` fails 3 consecutive times for the same issue.

## Line / File Deltas

Pending.

## Gate Results

Pending.

## Smoke Result

Pending.

## Unexpected / Follow-up

Pending.
