# Active: Rec.709-Safe Built-in Look Color Variants

Date opened: 2026-05-17 JST

## Milestone

M2 follow-up: Rec.709-safe Creative Pack 01 color variants.

## Goal

Keep Stone / Urban / Noir optical and glow character visible on Rec.709 or
unknown display-referred sources while preventing color breakage from the
creative LUT itself.

## Edit Targets

- `packages/film-lab-core/src/creative-pack-01*.ts`
- `scripts/build-creative-luts.ts`
- `apps/capacitor-film-lab-ios/ios/App/App/Look/`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/`
- Creative LUT resource files and their manifest pins

## Read-Only References

- ACES Input / Look Transform and Reference Gamut Compression docs
- OpenColorIO Look process-space docs
- ARRI Look File / LogC look-family docs

## Checklist

- [x] Add Rec.709-safe cube variant generation for Stone / Urban / Noir.
- [x] Pin variant hashes in the Creative Pack 01 manifest.
- [x] Route iOS Rec.709 / unknown display sources to safe variants.
- [x] Preserve full variants for Log / explicit Source Profile sources.
- [x] Mirror the same source-aware policy in native Desktop.
- [x] Verify core, iOS, Desktop, and whitespace gates.

## Verification

- `bun run build:core` — passed.
- `bun test packages/film-lab-core/src/creative-pack-01.test.ts` — passed.
- `bun run verify:ios` — passed.
- `bun run verify:desktop` — passed.
- `apps/filmtone-desktop-macos/Verify/run.sh` — passed, 154/154.
- `bun run scripts/build-creative-luts.ts --verify` — passed.
- `bun run check:filmtone-context` — passed.
- `bun run check:filmtone-copy` — passed.
- `git diff --check` — passed.

## Completion Notes

- Added Rec.709-safe generated cube variants for Stone / Urban / Noir and pinned
  them in the Creative Pack 01 manifest.
- iOS source-aware application now selects the safe cube for Rec.709 / unknown
  display sources and keeps the full cube for Log / explicit Source Profiles.
- Desktop now ships the same full + safe Pack 01 cube generation as iOS/Core and
  applies the safe variant at preview/export/source-policy resolution.
- Optical / glow runtime parameters remain active; the color breakage mitigation
  is in the creative cube selection rather than a blanket optical reduction.

## Copy / History Impact

No public copy change in this task. Existing iOS release notes already cover the
Rec.709-safe Look work and passed the copy harness.

Article Opportunity: Release-note only.
Change-History Opportunity: Developer note if the color pipeline article is
expanded later.

## Known Remaining Product Risks

- No owner-provided real Rec.709 high-key / saturated / low-sat fixture was
  available in this run, so visual QA remains the next release gate.

## Done Conditions

- Rec.709 / unknown display sources use safe color cubes for Built-in Creative
  Pack 01.
- Log / explicit camera profile sources keep the current full color cubes.
- Optical / glow runtime patch remains visible and is not globally removed to
  solve color breakage.
- Tests cover Rec.709 safe selection and Log passthrough.

## Stop Conditions

- Done conditions are met.
- Unexpected schema/resource issue makes source-aware selection unsafe.
- Two consecutive verification failures with the same root cause.

## Out Of Scope

- App Review submission.
- User-imported creative LUT behavior.
- Public copy beyond release-state notes already in progress.
- Broad visual QA matrix beyond focused smoke unless owner provides clips.

## Unexpected

- None yet.
