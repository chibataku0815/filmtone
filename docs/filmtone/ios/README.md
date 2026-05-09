# Filmtone iOS Docs

This directory is the current entry point for Filmtone iOS documentation.
Historical handoffs are archived below so release state and implementation
entry points stay visible.

## Current Truth

Before stating public App Store state, local Xcode candidate state, or release
scope, run:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Report public App Store state and local implementation state separately.

## Current Implementation Entry

- App guide: `apps/capacitor-film-lab-ios/CLAUDE.md` (UI stack is now
  Native SwiftUI; the React + Capacitor stack was purged 2026-05-09)
- App source: `apps/capacitor-film-lab-ios/`
- App Store metadata: `apps/capacitor-film-lab-ios/fastlane/metadata/`
- Screenshot notes: `apps/capacitor-film-lab-ios/fastlane/screenshots/README.md`
- Native Swift surfaces: open the exact Swift target named by the task.

## Lane Index

Each lane keeps a `strategy.md` (long-running goal + log) and, when
work is in flight, an `active.md` (≤ 30-min sub-tasks). Closed lanes
keep `strategy.md` as the canonical record; their per-task notes
move to `<lane>/archive/`.

| Lane | Status | Strategy | Notes |
|---|---|---|---|
| Capture Practicality | **Coder-side S1-S5 advanced — owner smoke pending** | [`capture-practicality/strategy.md`](./capture-practicality/strategy.md) | S1 stabilization, S2 lens visibility, S3 continuous capture, S4 SSD 5-minute cap, and S5 preview scoping are paused under `capture-practicality/paused/` until owner-device smoke / dominant-defect pick. |
| V2 Capture / Gyroflow | **Closed at M14 + M15 PASS (2026-05-09)** | [`v2-capture-gyroflow/strategy.md`](./v2-capture-gyroflow/strategy.md) | No `active.md` — lane awaits owner pick of next sub-lane (Filmtone-optimized motion library, broad device matrix). M9–M15 archives in [`v2-capture-gyroflow/archive/`](./v2-capture-gyroflow/archive/) |
| React / Capacitor purge | **Closed + merged into main as `47a1d76d` (2026-05-09)** | [`react-capacitor-purge/strategy.md`](./react-capacitor-purge/strategy.md) | Stages A → E archived. Worktree + branch removed post-merge. |
| Meta Before/After DaVinci shell | Asset directory, not a lane | [`meta-before-after-davinci-shell/README.md`](./meta-before-after-davinci-shell/README.md) | Placeholder Resolve project + Lua helpers for ad production. Not active product work. |

## Idea Notes

- [`ideas/2026-05-07-multicam-apple-log-new-app-feasibility-handoff.md`](./ideas/2026-05-07-multicam-apple-log-new-app-feasibility-handoff.md)
  is a separate new-app feasibility handoff for MultiCam Apple Log capture.

## Copy And Metadata Gates

- Run `bun run check:filmtone-copy` after App Store metadata, public web copy,
  or release-note copy changes.
- App Store metadata currently targets `ja`, `en-US`, and `en-GB`. Screenshot
  sets currently target `ja` and `en-US`.
- Do not infer public App Store state from metadata files. Use the truth script
  above, then report public state and local candidate state separately.

## Archive

- [`archive/legacy-handoffs-2026-04-20-to-2026-05-03/`](./archive/legacy-handoffs-2026-04-20-to-2026-05-03/) keeps old iOS release, parity,
  Filmtone Connect, LUT, Liquid Glass, performance handoffs, and v1.1 task
  specs as evidence.
- Treat archived release-state notes as historical only. Do not use them as
  current release truth without the truth script and live source checks.
- Per-lane archives (`<lane>/archive/`) record sub-task PASS/REJECT logs
  for that lane only. The lane's `strategy.md` Completion Log is the
  index into them.
