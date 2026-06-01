# Native Desktop v2 Active Task: Film Damage Candidate A

Milestone: M3 / M4 Native Color And Optics Parity

Goal: Implement and verify Film Damage Candidate A for native Desktop and iPad,
using the visual target report to make Dust read as film-material dirt rather
than white sparkle dots, and to make Strong lean toward projector/gate damage.

Placement: This is the single current Native Desktop v2 active task. It follows
`film-damage-visual-target-report.md` and the archived visual alignment task.

Edit targets:
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneStrengthSheetData.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift`
- This active task doc
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` only on completion

Read-only references:
- `docs/filmtone/desktop/native-desktop-v2/film-damage-visual-target-report.md`
- `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-visual-probe/film-damage-current-*.png`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/packages/visual-render-core/src/features/film-damage/reference.ts`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/packages/visual-effect-core/src/features/film-damage/defaults.ts`

## Visual Target

Default:
- Subtle archival.
- Footage remains first read.
- Dust bed is mostly dark / neutral / translucent.
- White sparkle is rare and small.
- No novelty scratches.

Strong:
- Projector/gate damage.
- Edge dirt and gate wear read before full-frame random dust.
- Scratches/fibers are occasional, broken, and materially irregular.
- White sparkle remains an accent.

Out of scope:
- Distressed leader as product-default taste.
- Adding new public controls.
- Importing visual-effect-core runtime into Filmtone.
- Legacy Electron Desktop.

## Implementation Plan

1. Rebalance dust hierarchy.
   - Split internal Dust behavior into a low-contrast dirt bed and sparse
     sparkle.
   - Reduce near-white sparkle target and probability.
   - Give dirt bed larger, softer, mottled shapes so reducing white sparkle does
     not make the effect disappear.

2. Strengthen gate/projector identity.
   - Increase edge/gate dirt response before raising full-frame dot density.
   - Make gate wear more broken and darker/neutral.
   - Keep flicker subtle.

3. Improve scratches/fibers.
   - Reduce light scratch probability.
   - Add darker/neutral fibers and weaker clean white curves.
   - Keep deterministic seed/time behavior.

4. Keep Desktop/iPad parity.
   - Apply the same kernel logic to Desktop and iOS export kernel.
   - Keep existing `dustAmount` / `scratchAmount` controls and sidecar shape.

5. Generate visual evidence.
   - Use the existing Desktop probe to generate Candidate A comparison sheets.
   - Compare dark/midtone/bright plates against the current-renderer sheets.
   - Tune again before app launch if Candidate A still first-reads as white dots.

## Acceptance Criteria

Pass if:
- Default does not first-read as white dots.
- Dust-up does not mean only more bright specks.
- Strong reads more like edge/gate/projector handling than random dirt overlay.
- Mid-tone and dark plates no longer make white sparkle dominate.
- Bright plates retain visible artifacts without becoming gray mud.
- Scratches are less clean, less uniformly light, and less line-like.
- Desktop and iPad compile with matching Film Damage semantics.

Reject if:
- White dots remain the most memorable artifact.
- Candidate A is only lower-opacity, not more material.
- Strong looks like television noise or distressed leader damage.
- The effect disappears after sparkle suppression.

## Checklist

- [x] Confirm this is the only active Native Desktop v2 task.
- [x] Implement Candidate A in Desktop Film Damage kernel.
- [x] Port identical Candidate A logic to iPad/iOS export kernel.
- [x] Tune product recipe defaults only if kernel hierarchy alone is not enough.
- [x] Regenerate Candidate A comparison sheets.
- [x] Visually inspect generated dark/midtone/bright sheets.
- [x] Run Desktop runtime/kernel verification.
- [x] Run Desktop build verification.
- [x] Run iOS verification.
- [x] Launch Desktop debug app for owner review.
- [x] Record verification, copy/history impact, and archive this task.

## Verification

- Generated Candidate A sheets:
  `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-candidate-a/film-damage-current-*.png`
- Generated Candidate A2 sheets:
  `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-candidate-a2/film-damage-current-*.png`
- Generated Candidate A3 sheets:
  `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-candidate-a3/film-damage-current-*.png`

Visual inspection:
- Candidate A removed most white sparkle dominance but still read partly as
  dot-density when Dust was pushed.
- Candidate A2 pushed edge/gate identity harder, but introduced a rectangular
  dirt/block read in stress cases.
- Candidate A3 keeps the speck suppression, reduces the rectangular dirt read,
  and is the verification candidate.

Commands:
- `swiftc apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift -o /tmp/filmtone-film-damage-visual-probe && /tmp/filmtone-film-damage-visual-probe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-candidate-a3` pass.
- `apps/filmtone-desktop-macos/Verify/run.sh` pass, 161/161.
- `bun run verify:desktop` pass.
- `bun run verify:ios` pass.
- `bun run check:filmtone-context` pass.
- `git diff --check` pass after removing trailing whitespace.

Desktop app:
- Launched `apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app`
  for owner visual review.

Copy / History Impact:
- No public copy/history impact: this changes existing Film Damage rendering
  behavior only; no user-facing strings, release/version/platform claims, App
  Store copy, or implementation-history wording changed.
- Article Opportunity: Release-note only after owner visual acceptance.
- Change-History Opportunity: Developer note. Candidate A3 keeps Film Damage in
  the native host color-kernel path; sampler/transport-stage escalation remains
  a future option if owner review still reads the effect as an overlay.

## Stop Conditions

- Done conditions met and app is launched for owner visual review.
- Candidate A still reads as overlay after two targeted tuning passes; record
  the issue and propose sampler/transport-stage escalation.
- 3 consecutive verification failures on the same unresolved root cause.

## Unexpected Blockers

- None yet.
