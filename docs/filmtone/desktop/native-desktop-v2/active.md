# Active Task: M5-A.1 Visual Smoke

> Reference-only mirror in this checkout. The current Native Desktop v2
> `active.md` lives in
> `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/docs/filmtone/desktop/native-desktop-v2/active.md`.
> Do not archive, pause, restore, or implement from this copy.

Date opened: 2026-05-04 JST
Milestone: M5 (Native Editing UI), slice A.1 — manual acceptance gate
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

## Goal

Confirm by direct observation that the Look Strength Slider (M5-A.1, archived
2026-05-04) behaves as designed in the running native macOS app. This is the
only checklist item from `archive/2026-05-04-m5-a1-look-strength-slider.md`
that was not closed automatically — it is a user-driven manual gate.

## Pre-conditions

- The app already builds: `xcodebuild ... -scheme FilmtoneDesktop` → BUILD
  SUCCEEDED (verified 2026-05-04).
- A test still image is available, e.g.
  `apps/desktop-film-lab-batch/test/golden/source-images/09-skin-light.png`.

## Procedure

1. Open `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj` in Xcode.
2. Run the `FilmtoneDesktop` scheme on the local Mac (▶).
3. ⌘O → choose `09-skin-light.png` (or any still).
4. In the right-hand control group:
   - Confirm the Look Picker shows: Reset / iPhone / Soft Blue / Amber Glow.
   - Confirm a "Strength" row appears below the picker with a slider and a
     `100%` readout by default.
5. Pick **Reset**. Confirm the Strength slider visibly disables and dims (~50%
   opacity), since the slider has no effect on the bareline pivot.
6. Pick **iPhone**. Confirm the slider re-enables at 100%.
7. Drag the Strength slider slowly from 100% → 0%. Confirm the preview
   continuously interpolates: at 100% it matches the iPhone look; at 0% it
   matches the bareline (resetParams pivot, NOT the "Reset" preset tone).
8. Drag back to ~50%. Confirm an intermediate look (subtle iPhone tint).
9. Switch to **Soft Blue** at strength 100%, then 0% — verify the same
   pivot-to-target sweep behaviour is preset-agnostic.
10. (Optional) ⌘E export at strength 0.3, open the resulting `.filmtone.json`
    and confirm `batchLookChoice.strength == 0.3` and `gradeParams` reflects
    interpolated values (not the full target preset).

## Acceptance Gates

- Slider appears, is bound, and updates the preview live (no commit / no
  shutter feel).
- 100% looks identical to pre-M5-A.1 behaviour for a given preset.
- 0% on a non-Reset preset looks like the bareline (more neutral than the
  "Reset" preset, since the pivot is `resetParams`, not `paramsByName["reset"]`).
- Slider disables on the "Reset" preset.
- No crash, hang, or visible flicker during slider drag.

## Edit Targets

(none — this is a verification active, not an implementation active)

## Out of Scope

- Performance characterisation of slider drag at 4K (separate lane).
- Changing the disable-on-Reset behaviour.
- Any code edits — if a defect is found, append it to **Unexpected** and the
  next active will fix it.

## Operating Notes

- This active is closed by the user reporting either "all gates pass" (→
  archive + brief note in strategy.md) or specific defects (→ a fix active is
  created next).
- INV-7: no auto-commit; the M5-A.1 implementation commit is still pending
  user-manual commit and may be combined with any visual-smoke fix into a
  single bundled commit (`feedback_dont_overengineer_dirty_state_split`).

## Checklist

- [ ] App launches from Xcode without errors
- [ ] Look Picker shows 4 entries
- [ ] Strength row visible with `100%` default readout
- [ ] Strength slider disables on "Reset" preset
- [ ] iPhone @ 100% matches pre-M5-A.1 behaviour
- [ ] iPhone @ 0% looks neutral (bareline, not "Reset" preset)
- [ ] iPhone @ ~50% shows continuous interpolation
- [ ] Soft Blue / Amber Glow show same sweep behaviour
- [ ] (Optional) Sidecar at strength 0.3 round-trips correctly
- [ ] No crash / hang / flicker during drag

## Unexpected

(none yet — append observed defects here; if non-empty at close, file a fix active)

## Result

(left blank for the user to fill in: "all gates pass" / specific defects)
