# Native Desktop v2 Active Task: Film Damage Temporal Humanization

Milestone: M3 / M4 Native Color And Optics Parity

Goal: Make Film Damage readable at Strong without making Max look like
frame-by-frame procedural graphics.

Placement: This is the single current Native Desktop v2 active task. It follows
`archive/2026-06-01-film-damage-visibility-balance.md` after owner review.

Edit targets:
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneStrengthSheetData.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift` only if
  visual proof needs an added case
- This active task doc
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` only on completion

Read-only references:
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-01-film-damage-visibility-balance.md`
- Owner feedback: Strong is still hard to see; Max is visible but mechanically
  displayed one frame at a time.

## Scope

Implement now:
- Lift internal dust/scratch response so Strong is visibly inspectable.
- Raise the Film Damage Strong recipe only if the current chip remains below
  the visible threshold after renderer tuning.
- Hold dust/scratch temporal evaluation over multiple frames to avoid
  frame-by-frame digital popping.
- Make Max scratches less mechanical by reducing lane regularity and blocky
  broken-column shapes.
- Keep Desktop and iPad kernel semantics matched.

Defer:
- New UI controls.
- Texture-atlas dust/scratch plates.
- Multi-pass/sampler implementation.

## Acceptance Criteria

Pass if:
- Strong is visibly inspectable on synthetic sheets and real footage.
- Max remains intense but no longer reads as one-frame procedural graphics.
- Scratch-only output has irregular thin/medium marks rather than repeated
  blocky vertical strips.
- Desktop and iPad kernels compile with matching semantics.

Reject if:
- Strong remains barely visible.
- Max still looks like frame-by-frame generated graphics.
- The result returns to smooth, synthetic fade animation.

## Checklist

- [x] Create focused temporal-humanization task.
- [x] Apply Desktop response/temporal/scratch naturalization.
- [x] Port matching tuning to iPad/iOS export kernel.
- [x] Regenerate visual comparison sheets.
- [x] Visually inspect Strong and Max behavior.
- [x] Run targeted Desktop/kernel verification.
- [x] Run Desktop/iOS verification as needed.
- [x] Run context/diff checks.
- [x] Launch Desktop debug app for owner review.
- [x] Record verification, copy/history impact, and archive this task.

## Verification

- `swiftc apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift -o /tmp/filmtone-film-damage-visual-probe && /tmp/filmtone-film-damage-visual-probe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-temporal-humanization-d`
- Visual inspection: `film-damage-current-midtone.png`, `film-damage-current-bright.png`, `film-damage-temporal-strong.png`, `film-damage-temporal-dust-only-strong.png`, and `film-damage-temporal-scratch-only-strong.png`.
- `apps/filmtone-desktop-macos/Verify/run.sh` - 161/161 pass.
- `bun run verify:desktop` - pass.
- `bun run verify:ios` - pass.
- `git diff --check` - pass.
- `bun run check:filmtone-context` - pass.
- Launched Desktop debug app for owner review: PID `39325`.

## Product Notes

- Strong now lands at `dustAmount=0.46` and `scratchAmount=0.42` on Desktop and iPad/iOS, replacing the too-subtle `0.34/0.28` recipe.
- The internal Film Damage response curve lifts midrange dust/scratch while preserving Max as the full stress state.
- Dust/scratch defects now evaluate on a held defect frame rather than raw frame time, reducing one-frame procedural popping.
- Scratches use denser but thinner lanes, rougher scuff edges, and less blocky gap breakup so Max reads less like generated vertical strips.
- White dust is restored as sparse off-white sparkle guarded by luma, while dark dust and stains remain the dominant damage read.

## Copy / History Impact

No copy/history impact: this changes renderer behavior and recipe values only;
no public copy, release claim, or implementation-history wording changes.

Article Opportunity: Release-note only.

Change-History Opportunity: Developer note.

## Known Remaining Product Risks

- If owner review still reads the single-kernel result as mechanical, the next
  quality tier should be texture-plate or multi-pass/sampler film damage rather
  than more scalar tuning.

## Stop Conditions

- Done conditions met and app is launched for owner visual review.
- The single color-kernel path still reads as procedural at Max; stop and
  propose texture plate or multi-pass/sampler damage as the next quality tier.
- 3 consecutive verification failures on the same unresolved root cause.

## Unexpected Blockers

- None yet.
