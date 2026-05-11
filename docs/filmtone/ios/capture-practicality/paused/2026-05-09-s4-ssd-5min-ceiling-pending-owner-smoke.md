# Active: S4 - External SSD 5-Minute Capture Ceiling

Date: 2026-05-09 JST
Status: Paused — code-complete, pending owner-device smoke

Paused reason: Coder-side S4 work (300 s external auto-stop ceiling,
30 GB preflight gate, owner-visible cap formatting in the storage
pill) is landed and verified (`xcodebuild` BUILD SUCCEEDED). Remaining
done conditions are owner-device smoke checks (real 5 min SSD take,
30 GB preflight refusal, package metadata round-trip). S5 - Recording
Preview Behavior Improvement starts in parallel because it depends
only on S1-S4 having settled, which they have code-side.

## Milestone

S4 - External SSD 5-Minute Capture Ceiling

## Goal

Let external-SSD capture run up to 5 minutes (300 s) while keeping
local internal capture short and explicit. The new ceiling should be
reflected in the auto-stop, the preflight free-space gate, the status
UI, and the package metadata so a downstream reader knows which cap
was in effect.

## Product Locks

- External storage mode uses a 300 s auto-stop ceiling.
- Internal local capture remains capped at 10 s.
- Status UI shows the resolved cap for both modes (`Internal 10s` /
  `External 5m`).
- Package metadata (`durationLimitSeconds`) records the cap the run
  observed.
- Preflight free-space gate is raised to fit one 5 min ProRes 422 HQ
  Apple Log 2 capture plus proxy / finalize headroom.
- SSD unavailable / not external / not writable / insufficient
  capacity continues to fail visibly via the existing preflight error
  path; no silent fallback to internal mode.
- Auto-stop and manual stop both preserve the existing master / proxy
  package and export pipeline behavior.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCapturePreflight.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureView.swift`

`FilmtoneProductCapture.swift` is intentionally untouched — it is the
legacy fixed-duration product-capture evidence path noted in
`strategy.md` "Known Constraints" and is not part of the V2 capture
surface this lane is changing.

## Read-Only References

- `docs/filmtone/ios/capture-practicality/strategy.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`

## Checklist

- [x] Bump `FilmtoneCaptureSession.externalDurationCapSeconds` from
  60 s to 300 s and update the doc comment so it no longer claims
  parity with `FilmtoneProductCapture.maxDurationSeconds`.
- [x] Bump `FilmtoneCapturePreflight.minimumFreeBytes` to fit one
  300 s ProRes 422 HQ Apple Log 2 master plus proxy export staging
  and finalize headroom (~30 GB).
- [x] Update `FilmtoneCaptureView.storagePillLabel` external branch
  so it shows the resolved cap (`External 5m`) instead of a static
  `External master` string.
- [x] Confirm `FilmtoneCapturePackage.durationLimitSeconds` already
  carries through to `capture-package.json` (it does — no edit
  needed; verification only).
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

1. Pick an SSD with ≥ 30 GB free; confirm preflight passes and the
   storage pill reads `External 5m`.
2. Pick an SSD with < 30 GB free; confirm preflight fails visibly
   (preflight error banner, no recording allowed).
3. Record one full 5 min take on SSD; confirm auto-stop fires at
   ~300 s and the package records `durationLimitSeconds: 300`.
4. Confirm the master is on the SSD (not internal Documents) and
   ProRes 422 HQ Apple Log 2 master quality holds across the long
   take.
5. Switch to internal mode (no SSD picked); confirm the cap remains
   10 s and the storage pill reads `Internal 10s`.
6. Confirm S1 STAB toggle, S2 lens chip readout, and S3 multi-take
   commit pill all continue to work in a 5 min SSD session.

## Done Conditions

- External-mode auto-stop fires at 300 s.
- Internal-mode auto-stop unchanged at 10 s.
- Preflight gate refuses SSDs that cannot hold one 5 min master plus
  staging.
- Status pill text reflects the resolved cap for both modes.
- Package metadata round-trips the cap (existing schema; no new
  field).
- Verification results are appended to this file.
- This file is moved to
  `archive/YYYY-MM-DD-s4-ssd-5min-ceiling.md` after the owner-device
  smoke passes; otherwise it pauses to
  `paused/<date>-s4-ssd-5min-ceiling-pending-owner-smoke.md` while
  S5 begins.
- `strategy.md` gets only a 1-3 line completion log entry.

## Stop Conditions

Stop and report if any of these fires:

- The fix requires changing the master codec, color space, fps, or
  lens contract to make the long take fit.
- ProRes 422 HQ or Apple Log 2 downgrades anywhere in the long take.
- The preflight gate change blocks SSDs the strategy intended to
  accept (e.g., 256 GB drives with > 30 GB free that previously
  passed).
- The work starts to require S5 preview render-loop changes.

## Out of Scope

- Internal 5 min recording.
- Adaptive bitrate / HEVC fallback.
- Thermal policy beyond visible failure on writer interrupt.
- Broad multi-device / multi-SSD QA.
- Per-take cap override UI.

## Verification Log

- 2026-05-09 JST — S4 implementation pass:
  - `git diff --check` clean across edited Swift surface.
  - `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` →
    `** BUILD SUCCEEDED **`.
  - `bun run verify:swift-contract` not re-run on this lane: S4 only
    touches a single static `Double` constant, the preflight gate
    `Int64`, and a SwiftUI string formatter. None of phase0 / look /
    veil / sidecar / source-profile math contracts is reached. The
    S3 pass left those green and they are unchanged here.
- Device smoke (5 min SSD take, 30 GB preflight refusal,
  `durationLimitSeconds: 300` round-trip) — pending owner-device
  run.

## Implementation Notes

- `FilmtoneCaptureSession.externalDurationCapSeconds` raised to
  300.0 s. The doc comment now states the V2 surface intentionally
  diverges from `FilmtoneProductCapture.maxDurationSeconds` (the
  legacy 60 s fixed-duration evidence path) so a future grep does
  not re-couple the two.
- `FilmtoneCapturePreflight.minimumFreeBytes` raised to 30 GiB.
  Sizing rationale: 5 min ProRes 422 HQ Apple Log 2 at 24 fps ≈
  20–22 GB, plus ≈ 1 GB proxy staging, plus a few GB of finalize /
  movie-atom headroom. 30 GB preserves the prior gate's ≈ 1.5×
  safety margin against the M10-flagged "passed → ENOSPC mid-
  recording" failure mode.
- `FilmtoneCaptureView.storagePillLabel` now formats the cap with a
  small private helper (`formatDurationCap`) that renders
  `< 60 s` as `Ns`, whole minutes as `Nm`, and mixed values as
  `NmNs`. External branch reads the same shape as internal
  (`Internal 10s` / `External 5m`) so the cockpit's storage readout
  stays consistent.
- `FilmtoneCapturePackage.durationLimitSeconds` and the
  `currentDurationLimit()` plumbing in `FilmtoneCaptureSession`
  required no edits — they already wire the resolved cap into the
  package and the auto-stop closure. The 300 s value flows through
  unchanged because the auto-stop, the package metadata, and the
  status pill all read the same `currentDurationLimit()` getter.
- `FilmtoneProductCapture.swift` left untouched per `strategy.md`
  "Known Constraints" — the legacy fixed-duration path stays at
  60 s as historical evidence and is not part of the V2 surface
  this lane addresses.
