# Native Desktop v2 Active Task

Date opened: 2026-05-16 JST

## Milestone

M5 Native Editing UI

## Goal

Investigate why the Desktop Quick sliders do not visibly change the preview,
then replace the Quick panel with the real Adjust parameters in the same
editing surface if that is the lowest-risk product fix.

## Edit Targets

- `apps/filmtone-desktop-macos/UI/`
- Adjacent Desktop preview/store/color wiring only if the Quick no-op requires it.

## Read-Only References

- `apps/filmtone-desktop-macos/README.md`
- `docs/filmtone/desktop/README.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Trace Quick slider state, grade payload, and preview renderer wiring.
- [x] Identify why the screenshot Quick sliders appear visually no-op.
- [x] Decide whether Quick should be removed in favor of Adjust controls.
- [x] Implement the scoped UI/wiring fix.
- [x] Verify with the smallest meaningful Desktop checks.
- [x] Record copy/history impact and archive this active task.

## Verification

- `bun run verify:desktop` — passed 2026-05-16 JST.
- `git diff --check` — passed 2026-05-16 JST.
- `bun run check:filmtone-copy` — passed 2026-05-16 JST.
- `bun run check:filmtone-context` — passed 2026-05-16 JST.

## Done Conditions

- Quick no-op cause is documented.
- The visible editor surface exposes controls that are bound to real preview
  parameters.
- Desktop verification passes, or any failure is recorded with a concrete
  blocker.

## Stop Conditions

- Done conditions met.
- Unexpected scope expansion outside Desktop native editing UI.
- 3 consecutive verification failures on the same command.

## Out Of Scope

- Legacy Electron Desktop changes.
- iOS implementation changes.
- Release/version metadata changes.
- Preset/color recipe retuning beyond what is needed to fix the UI binding.

## Unexpected Blockers

- None yet.

## Notes

- Quick state is included in `EditorState.currentGradeRecipe`, still
  `PreviewRenderKey`, and video `VideoCompositionRefreshKey`; the live preview
  can react to Quick changes.
- The screenshot's `27 advanced` badge is the root symptom: built-in Look
  selection applies `lookSlug` and also copies the built-in Look patch into
  live user `paramOverrides`. Since `paramOverrides` are applied after Quick,
  the affected Quick keys are overwritten by the duplicated Advanced patch.
- Product decision: remove the visible Quick axis panel and put direct Adjust
  controls in that rail position, while preserving Backlight Veil in the same
  panel.

## Copy / History Impact

- Copy / History Impact: public Desktop wording that still promises visible
  Quick controls should be reviewed before the next release note or public
  page update. This task changes the in-app Desktop editing surface from
  Quick axes to direct Adjust parameters.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Developer note.
