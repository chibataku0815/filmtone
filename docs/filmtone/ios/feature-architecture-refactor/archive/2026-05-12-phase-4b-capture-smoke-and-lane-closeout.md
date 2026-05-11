# Archive - Phase 4B Capture Smoke + Lane Closeout

Date: 2026-05-11 JST
Closeout: 2026-05-12 JST (owner-confirmed smoke OK)
Phase: Phase 4B - capture smoke and final lane closeout
Status: **CLOSED** — feature-architecture lane completed.
Milestone: Verified the post-refactor capture pipeline at the product
surface and closed the feature-architecture lane without adding broad
QA machinery.

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

- [x] Run `bun run verify:ios`.
- [x] Run `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh`
  with this repo root if needed.
- [x] Search `apps/capacitor-film-lab-ios/RELEASE.md` and lane docs for
  stale moved Swift file paths; update only real stale references.
- [x] Owner/device smoke: record one take, adopt into editor, change
  grade, export one output. **PASS** (owner-confirmed 2026-05-12 on
  千葉工のiPhone (7) after this lane's build+install).
- [x] If smoke fails, record the exact failure and fix only the direct
  regression. **N/A** — smoke passed.
- [x] Record automated gate status and remaining known product risks.

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

No code mutation in Phase 4B. Phase 4A (commit `e187e1db`) is the
underlying split. Code remains at `feature/ios-feature-architecture @
e187e1db`; Phase 4B currently mutates only this active doc to record
automated gate results and owner-deferred smoke.

| File | Phase 4B mutation |
|---|---|
| `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureSession.swift` | unchanged (880 lines, facade) |
| `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CaptureDeviceManager.swift` | unchanged (444 lines) |
| `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/RecordingStateController.swift` | unchanged (402 lines) |
| `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CapturePackageAssembler.swift` | unchanged (365 lines) |
| `apps/capacitor-film-lab-ios/RELEASE.md` | inspected, no stale flat path, no edit |
| `docs/filmtone/ios/feature-architecture-refactor/active.md` | filled below sections only |

## Gate Results

| Gate | Result |
|---|---|
| `bun run verify:ios` | **exit 0** (generated Swift drift + `xcodebuild -quiet` BUILD + grain catalog + Swift contract + cube parser + capture transform LUT classifier + CacheStore + source-color-classifier + ray-angle optics + 6 source-profile log-format accuracy gates max \|Δ\|=0.000000, ΔE2000=0.000 / ΔE Macbeth=0.000 within 1e-3 / 2.0 / 0.5 budgets + look×veil energy merge 10 checks + sidecar builder) |
| `git diff --check` | **exit 0** (no whitespace anomaly) |
| `check-filmtone-ios-truth.sh` (FILMTONE_REPO_ROOT override) | **green** — public 1.8 (`PENDING_DEVELOPER_RELEASE` -> release 2026-05-10), local Xcode `1.7 / 6`. Refactor branch was cut before the 1.8 marketing/build bump, so local stream still reads 1.7-6; this is a documented two-axis state (life truth-script interpretation), not a regression. Owner decides whether to rebase / merge the 1.8 release commit into this branch before PR |
| `grep -nE 'ios/App/App/Filmtone[A-Z]' RELEASE.md` | empty |
| `grep -rnE 'ios/App/App/Filmtone[A-Z]' docs/filmtone/ios/feature-architecture-refactor/` | empty |
| Device build + install on iPhone 17 Pro (CoreDevice ID `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`, 千葉工のiPhone (7)) | **green** — `xcodebuild -workspace App.xcworkspace -scheme App -configuration Debug -destination id=3A2A3A66...` BUILD SUCCEEDED (note: must use workspace not raw project — App.xcconfig still references `-framework Pods_App` from pre-Capacitor-purge era, only the workspace builds the empty Pods stub). `xcrun devicectl device install app` placed `com.chibatakumi.film.lab.ios` at `/private/var/containers/Bundle/Application/8D666E80-145D-493F-8B1F-F31288260B8C/App.app/` |
| Manual owner gate: record -> grade -> export | **PASS** (owner-confirmed 2026-05-12 on 千葉工のiPhone (7) post device-install) |

## Smoke Result

Device build + install completed 2026-05-12 from this lane.
`feature/ios-feature-architecture @ e187e1db` was signed (automatic /
team `C3G77H8NM6`) and installed on `千葉工のiPhone (7)` (CoreDevice ID
`3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`, iPhone 17 Pro `iPhone18,1`,
bundle id `com.chibatakumi.film.lab.ios`, installed at
`/private/var/containers/Bundle/Application/8D666E80-145D-493F-8B1F-F31288260B8C/App.app/`).
The plan's reference UDID `D3011FE4-...` is an older snapshot UDID
form; CoreDevice IDs are what `xcrun devicectl` accepts.

Owner ran the hands-on smoke on the installed build 2026-05-12 and
confirmed **PASS** — feature-architecture lane closed. Phase 4A retains
ProRes 422 HQ + Apple Log 2 + cinematicExtendedEnhanced invariants
verified at the product surface (only real device can exercise them).

Smoke recipe that the owner executed (one cycle):

1. Boot the app on the device; verify capture cockpit appears at idle.
2. Record one short take (5-10 s) with default lens.
3. Stop -> capture package adoption auto-flips editor to that package.
4. In editor: change one grade param (any strength or look pick).
5. Trigger export; verify one master + proxy output lands and a sidecar
   JSON is written next to the master.
6. Look for non-zero EV in cockpit before record, lens swap survives at
   `.ready`, stabilization toggle responds at `.ready` (Phase 4A facade
   composite path).

Smoke result: **PASS** — owner-confirmed 2026-05-12. active.md archived
here; `strategy.md` Completion Log updated; feature-architecture lane
closed.

## Unexpected / Follow-up

1. **Branch ↔ release-state delta** — `feature/ios-feature-architecture`
   was cut before the 1.8 marketing bump. Local Xcode reads `1.7 / 6`
   while public ASC stream is `1.8 / 7` released 2026-05-10. This is not
   a refactor defect, but the owner should choose pre-PR whether to
   rebase / merge the 1.8 release commit so the resulting PR diff is
   purely refactor. (Plan §"Worktree & Branch" pre-flight option (B) path
   in practice.)
2. **`livePreviewTelemetry` ownership** — Still on `FilmtoneCaptureSession`
   facade (VDO `PreviewSampleDelegate` writes it). Could move to
   `CaptureDeviceManager` later but requires a callback hop with no
   visible product benefit; deferred (was Phase 4A Follow-up §2).
3. **Pre-existing dead rotation observer code** — Phase 4A removed
   `installRotationCoordinator` / `receivePreviewRotation` /
   `receiveCaptureRotation` / `applyLatestRotationIfUnlocked` (no
   callers in repo). No follow-up needed; recorded for trace.
4. **Lane closeout vs Plan §11-13 day estimate** — Actual elapsed:
   Phase 1A/1B + 2A/2B/2C + 3A/3B/3C + 4A + 4B closeout = lane completes
   inside the original 11-13 working-day band. Specific elapsed days are
   in each archived sub-phase doc; not re-aggregated here to avoid
   silent recount drift.
5. **Stale flat-path refs outside scope** — Frozen archive docs under
   `docs/filmtone/ios/v2-capture-gyroflow/archive/` and
   `docs/filmtone/ios/capture-practicality/paused/` mention legacy flat
   `App/FilmtoneCaptureSession.swift` paths. These are explicitly out of
   Phase 4B scope (different lanes' historical record). Do not rewrite
   archived docs.
