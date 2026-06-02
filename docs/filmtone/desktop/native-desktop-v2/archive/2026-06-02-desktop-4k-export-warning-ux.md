# Desktop 4K Export Warning UX

Date opened: 2026-06-02 JST
Milestone: M5 Native Editing UI

## Goal

Make the 4K export time cost visible at the moment the user selects 4K, not
only as a quiet helper sentence.

## Diagnosis

- The current FHD/4K selector changes helper text when 4K is selected.
- That is technically present, but too subtle for a high-cost export choice.
- The export button should also reflect that the selected action is 4K.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/ExportInspectorPanel.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Replace the 4K helper sentence with a visible warning callout.
- [x] Change the video export button title to include FHD/4K.
- [x] Verify Desktop build/checks.
- [x] Record results and archive this task.

## UI Copy Brief

- Primary reader: a Mac user who intentionally switches a 4K-capable source
  from FHD to 4K before export.
- Moment: immediately after selecting 4K, before pressing Export.
- Unresolved feeling: wants full detail, but needs to understand the time cost.
- Next action: either keep 4K selected knowingly, or switch back to FHD.
- Not for: public marketing, release claims, codec positioning.
- Claim class: Internal product UI.
- Source evidence: measured 4K timing from the 2026-06-02 archive.
- Reversibility buffer: say 4K can take longer, not a fixed duration.

## Verification

- `bun run verify:desktop` passed.
- `bun run check:filmtone-copy` passed.
- `bun run check:filmtone-context` passed.
- `git diff --check` passed.

## Done Conditions

- 4K selection shows a visually distinct warning about slower export.
- The export button communicates whether the video export is FHD or 4K.

## Stop Conditions

- Done conditions are met and verification is recorded.
- The same verification class fails 3 consecutive times.

## Out Of Scope

- New confirmation modal.
- Export duration estimate model.
- iOS/iPad export UI.

## Copy / History Impact

No public copy/history impact expected: this is Desktop in-app export setting
copy.

Article Opportunity: Release-note only.

Change-History Opportunity: No story.
