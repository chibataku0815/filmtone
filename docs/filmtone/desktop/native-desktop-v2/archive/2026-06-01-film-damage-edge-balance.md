# Native Desktop v2 Active Task: Film Damage Edge Balance

Milestone: M3 / M4 Native Color And Optics Parity

Goal: Fix the current Film Damage tuning so artifacts do not visibly anchor to
the left edge, and restore a small amount of non-dominant light sparkle where it
is physically plausible.

Placement: This is the single current Native Desktop v2 active task. It follows
`archive/2026-06-01-film-damage-v21-host-bridge.md` after owner visual review.

Edit targets:
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- This active task doc
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` only on completion

Read-only references:
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-01-film-damage-v21-host-bridge.md`
- `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-v21-host-bridge-c/film-damage-current-*.png`
- Kodak processed film handling notes on scratches and abrasions
- AV Artifact Atlas `Sparkle`
- Dehancer Film Damage article on light/dark artifact ratio

## Scope

Implement now:
- Remove hard left-edge anchoring from scratch lane placement.
- Balance gate wear and edge soil noise so one side does not dominate due to
  raw x-coordinate noise.
- Add symmetric dirt/stain neighbor sampling where large spots can cross cell
  boundaries.
- Restore rare, guarded off-white sparkle as a minority artifact.
- Keep Desktop and iPad kernel semantics matched.

Defer:
- New public Film Damage controls.
- Multi-pass/sampler source-coordinate gate weave.
- Defocus source sampling.
- Dedicated debug mask export UI.

## Acceptance Criteria

Pass if:
- Left-edge artifact clusters are reduced in generated comparison sheets.
- Edge wear can still appear near film gates but does not repeatedly read as a
  left-side bug.
- White/light artifacts are visible only as rare small accents, never as the
  first read.
- Dark dirt, stains, gate wear, and broken scratches remain the dominant
  character.
- Desktop and iPad kernels compile with matching semantics.

Reject if:
- The result returns to white sparkle dominance.
- Scratches become too invisible under scratch-only strong.
- Edge wear becomes completely uniform or sterile.
- Single-kernel limitations prevent improvement after 2 targeted tuning passes.

## Checklist

- [x] Create focused edge-balance task.
- [x] Apply Desktop kernel tuning.
- [x] Port matching tuning to iPad/iOS export kernel.
- [x] Regenerate visual comparison sheets.
- [x] Visually inspect edge balance and light sparkle.
- [x] Run targeted Desktop/kernel verification.
- [x] Run Desktop build verification.
- [x] Run iOS verification.
- [x] Run context/diff checks.
- [x] Launch Desktop debug app for owner review.
- [x] Record verification, copy/history impact, and archive this task.

## Verification

- `swiftc apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift -o /tmp/filmtone-film-damage-visual-probe && /tmp/filmtone-film-damage-visual-probe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-edge-balance-c` passed with existing Core Image deprecation warnings.
- Visual sheet C: left-edge-only accumulation is reduced; gate/edge wear remains present but less side-dominant; white/light artifacts are still minority off-white accents rather than the first read.
- `apps/filmtone-desktop-macos/Verify/run.sh` passed, 161/161.
- `bun run verify:ios` passed with existing Core Image / AVFoundation deprecation warnings.
- `bun run verify:desktop` passed with existing Core Image / AVFoundation deprecation warnings.
- `git diff --check` passed.
- `bun run check:filmtone-context` passed.
- Desktop debug app launched from `apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app`; process observed as PID 5134.

## Product Notes

- White/light artifacts should not be the dominant read. Kodak's film handling
  notes and Dehancer's Film Damage model both support dark and light artifacts
  depending on whether damage/dust is on positive, negative, base, or emulsion
  material. AV Artifact Atlas also describes `sparkle` as small white spots from
  dust or dirt on negative/internegative material. The Filmtone target is
  therefore rare off-white sparkle plus mostly dark/warm dirt.
- Left-only concentration was treated as implementation bias, not film
  character. Gate and edge artifacts can be edge-biased, but the renderer should
  not repeatedly anchor them to the left side.

## Copy / History Impact

- No copy/history impact: this changes native Film Damage rendering behavior
  only, with no public copy, release claim, App Store metadata, or
  implementation history wording changed.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Developer note. This records the correction from
  left-origin artifact placement to edge-balanced native Film Damage behavior.

## Known Remaining Product Risks

- Real footage owner review is still needed; contact sheets cannot prove every
  scene/luma condition.
- True gate weave and defocus still require the deferred sampler/multi-pass
  phase.

## Stop Conditions

- Done conditions met and app is launched for owner visual review.
- 2 targeted tuning passes still cannot improve edge balance without
  multi-pass/sampler support.
- 3 consecutive verification failures on the same unresolved root cause.

## Unexpected Blockers

- None yet.
