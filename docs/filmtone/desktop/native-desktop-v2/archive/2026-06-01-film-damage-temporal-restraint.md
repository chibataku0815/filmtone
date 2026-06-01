# Native Desktop v2 Active Task: Film Damage Temporal Restraint

Milestone: M3 / M4 Native Color And Optics Parity

Goal: Correct the Film Damage edge-balance overshoot by reducing white sparkle
again and removing temporal behavior that reads like a procedural simulation.

Placement: This is the single current Native Desktop v2 active task. It follows
`archive/2026-06-01-film-damage-edge-balance.md` after owner visual review.

Edit targets:
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift`
- This active task doc
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` only on completion

Read-only references:
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-01-film-damage-edge-balance.md`
- `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-edge-balance-c/film-damage-current-*.png`

## Scope

Implement now:
- Reduce light/off-white sparkle ratio and strength.
- Stop dust specks from smoothly fading in/out.
- Stop scratches/fibers from continuously wiggling over time.
- Reduce crawling in gate/edge/dirt masks by freezing or quantizing temporal
  noise.
- Keep Desktop and iPad kernel semantics matched.

Defer:
- New UI controls.
- Multi-pass/sampler gate weave and defocus.
- Texture-atlas based real dust plates.

## Acceptance Criteria

Pass if:
- White artifacts are rare again and do not dominate real footage.
- Dust and scratches appear as physical frame defects, not animated particles.
- Existing gate/dirt/scratch character remains visible.
- Desktop and iPad kernels compile with matching semantics.

Reject if:
- White specks dominate again.
- Temporal transitions still feel like smooth simulation.
- The result becomes so static/subtle that Film Damage is not inspectable under
  Strong.

## Checklist

- [x] Create focused temporal-restraint task.
- [x] Apply Desktop temporal/sparkle tuning.
- [x] Port matching tuning to iPad/iOS export kernel.
- [x] Regenerate visual comparison sheets.
- [x] Visually inspect white ratio and temporal-restraint risk.
- [x] Run targeted Desktop/kernel verification.
- [x] Run Desktop/iOS verification as needed.
- [x] Run context/diff checks.
- [x] Launch Desktop debug app for owner review.
- [x] Record verification, copy/history impact, and archive this task.

## Verification

- `swiftc apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift -o /tmp/filmtone-film-damage-visual-probe && /tmp/filmtone-film-damage-visual-probe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-temporal-restraint-c` - pass, with existing Core Image kernel deprecation warnings.
- `apps/filmtone-desktop-macos/Verify/run.sh` - pass, 161/161.
- `bun run verify:desktop` - pass, with existing Core Image kernel deprecation warnings.
- `bun run verify:ios` - pass, with existing Core Image / AVFoundation deprecation warnings.
- `git diff --check` - pass.
- `bun run check:filmtone-context` - pass.

## Product Notes

- White sparkle was reduced again and its polarity is now stable per dust cell
  instead of changing with the frame clock.
- Dust specks now pop/hold instead of smoothly fading in and out.
- Scratch/fiber geometry and light/dark polarity no longer wiggle or change
  continuously over time.
- Gate/edge/dirt noise is frozen or quantized so it does not crawl every frame.

## Copy / History Impact

No copy/history impact: this changes rendering behavior only and does not alter
public copy, release claims, App Store wording, or implementation-history
wording.

Article Opportunity: Release-note only.

Change-History Opportunity: Developer note.

## Known Remaining Product Risks

- This is still a single Core Image color-kernel approximation. If the owner
  still reads it as procedural after this pass, the next quality ceiling is
  texture-plate or sampler/multi-pass damage, not more scalar tuning.
- Visual sheets are synthetic plates; owner review on real footage remains the
  decisive quality check.

## Stop Conditions

- Done conditions met and app is launched for owner visual review.
- The single color-kernel path still reads as procedural after this tuning pass;
  stop and propose sampler/multi-pass or texture plate work.
- 3 consecutive verification failures on the same unresolved root cause.

## Unexpected Blockers

- None yet.
