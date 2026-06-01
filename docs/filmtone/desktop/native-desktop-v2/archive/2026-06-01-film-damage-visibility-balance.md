# Native Desktop v2 Active Task: Film Damage Visibility Balance

Milestone: M3 / M4 Native Color And Optics Parity

Goal: Correct the owner-reviewed Film Damage balance after temporal restraint:
remove left-edge moire-like gate artifacts, restore sparse white dust visibility,
and make scratches readable at high scratch strength.

Placement: This is the single current Native Desktop v2 active task. It follows
`archive/2026-06-01-film-damage-temporal-restraint.md` after owner screenshot
review.

Edit targets:
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift` only if
  visual proof needs an added case
- This active task doc
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` only on completion

Read-only references:
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-01-film-damage-temporal-restraint.md`
- `/Users/chibatakumi/Library/Application Support/CleanShot/media/media_fNvu1PHwgc/CleanShot 2026-06-01 at 15.41.11@2x.png`
- `/Users/chibatakumi/Library/Application Support/CleanShot/media/media_ah4jGasrsh/CleanShot 2026-06-01 at 15.41.03@2x.png`

## Scope

Implement now:
- Reduce or remove fine left-edge gate/edge wear structure that reads as moire
  against real footage.
- Restore white/off-white dust as a sparse visible accent without returning to
  white dominance.
- Strengthen scratch-only output so `Scratches = 1.0` is visibly inspectable.
- Keep Desktop and iPad kernel semantics matched.

Defer:
- New UI controls.
- Texture-atlas dust/scratch plates.
- Multi-pass/sampler damage implementation.

## Acceptance Criteria

Pass if:
- Left-edge damage no longer creates a repeating moire-like strip.
- Dust-only high strength shows sparse white/off-white dust but not a snowfield.
- Scratch-only high strength shows readable vertical scratch/fiber marks on real
  bright footage and synthetic plates.
- Desktop and iPad kernels compile with matching semantics.

Reject if:
- The edge fix removes all gate/dirt character.
- White dust again dominates the image.
- Scratches remain invisible at high strength.

## Checklist

- [x] Create focused visibility-balance task.
- [x] Apply Desktop gate/sparkle/scratch tuning.
- [x] Port matching tuning to iPad/iOS export kernel.
- [x] Regenerate visual comparison sheets.
- [x] Visually inspect edge, white-dust, and scratch-only balance.
- [x] Run targeted Desktop/kernel verification.
- [x] Run Desktop/iOS verification as needed.
- [x] Run context/diff checks.
- [x] Launch Desktop debug app for owner review.
- [x] Record verification, copy/history impact, and archive this task.

## Verification

- `swiftc apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift -o /tmp/filmtone-film-damage-visual-probe && /tmp/filmtone-film-damage-visual-probe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-visibility-balance-d` - pass, with existing Core Image kernel deprecation warnings.
- `apps/filmtone-desktop-macos/Verify/run.sh` - pass, 161/161.
- `bun run verify:desktop` - pass, with existing Core Image kernel deprecation warnings.
- `bun run verify:ios` - pass, with existing Core Image / AVFoundation deprecation warnings.
- `git diff --check` - pass.
- `bun run check:filmtone-context` - pass.

## Product Notes

- Left-edge gate/edge wear now uses lower-frequency, lower-contrast masks to
  avoid a repeating moire-like strip against real footage.
- White dust remains sparse but its visible off-white target and opacity were
  restored from the over-suppressed temporal-restraint pass.
- Scratch-only high strength now has much higher lane presence, longer broken
  segments, stronger final contrast, and fewer fully erased gaps.

## Copy / History Impact

No copy/history impact: this changes rendering behavior only and does not alter
public copy, release claims, App Store wording, or implementation-history
wording.

Article Opportunity: Release-note only.

Change-History Opportunity: Developer note.

## Known Remaining Product Risks

- The left-edge issue is highly source-dependent because the real footage has a
  dense greenhouse mesh pattern. If it still reads as moire after this lower
  frequency pass, the next practical fix is to remove single-kernel edge wear or
  replace it with sampler/texture plate damage.
- White dust is intentionally restored by intensity more than density. If owner
  review still reads it as weak, the next adjustment should add a separate sparse
  white-pinhole layer rather than pushing all dust specks toward white.

## Stop Conditions

- Done conditions met and app is launched for owner visual review.
- The single color-kernel path cannot remove the edge moire while preserving
  visible film damage; stop and propose sampler/multi-pass or texture plate work.
- 3 consecutive verification failures on the same unresolved root cause.

## Unexpected Blockers

- None yet.
