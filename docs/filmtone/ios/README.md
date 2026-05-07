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

- App guide: `apps/capacitor-film-lab-ios/CLAUDE.md`
- App source: `apps/capacitor-film-lab-ios/`
- App Store metadata: `apps/capacitor-film-lab-ios/fastlane/metadata/`
- Screenshot notes: `apps/capacitor-film-lab-ios/fastlane/screenshots/README.md`
- Native bridge / Swift surfaces: open the exact Swift or TypeScript target
  named by the task.

## Current Product Plans

- [`v2-capture-gyroflow/strategy.md`](./v2-capture-gyroflow/strategy.md)
  is the current strategy for the owner-first V2 capture / Gyroflow lane.
- [`v2-capture-gyroflow/active.md`](./v2-capture-gyroflow/active.md)
  is the only current active task for that lane.

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
