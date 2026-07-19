# Active: Film Damage Render Speed Recovery

Date opened: 2026-06-06 JST
Milestone: M3 / M5 thin fix

## Goal

Recover Desktop video export speed after the Film Damage dust visibility tuning
while preserving the accepted black debris / hairline damage read as closely as
possible.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/Verify/CoreOpticalFilterTests.swift` only if
  coverage needs a small guard adjustment.

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-06-film-damage-visibility-tuning.md`
- `/tmp/filmtone-desktop-damage-check/desktop-frames-strip.png`
- `/tmp/filmtone-export-speed-investigation/*.log`

## Checklist

- [x] Confirm render-stage baseline for no damage vs current Film Damage.
- [x] Optimize Film Damage debris without changing the product look intent.
- [x] Mirror kernel optimization between Desktop and iOS.
- [x] Verify Desktop visual probe still shows dark debris on bright material.
- [x] Verify Desktop export timing improves on the high-resolution probe.
- [x] Run focused Desktop verification.
- [x] Record verification and archive this active task.

## Verification

- Desktop export timing with `FILMTONE_EXPORT_TIMING=summary`.
- Film Damage visual probe image inspection.
- `bash apps/filmtone-desktop-macos/Verify/run.sh`
- `bun run verify:desktop`
- `bun run verify:ios` if mirrored iOS kernel compiles are touched.
- `git diff --check`

## Result

- Kept the accepted debris/hairline shape math intact: no trig quantization or
  look-coefficient shortcuts were retained.
- Added conservative broad-phase exits to `damageSpot` and `damageDebris`, so
  far pixels skip expensive orientation/curl/texture work only after the event
  identity, life, fade, center, and maximum reach are known.
- Reduced debris evaluation from the unconditional current+four-neighbor calls
  to the owning cell. Side-by-side 3840 frame inspection preserved the accepted
  black debris read; PSNR against the pre-optimization accepted export was
  average 50.43 dB on the 30-frame 3840 strong probe.
- `damageSpot` broad-phase was output-identical to the previous single-cell
  optimized export on the 3840 strong probe (`psnr=inf`) while reducing render
  time further.

## Verification Log

- 3840x2880 / 30-frame local export timing, pre-optimization accepted strong:
  `render avg=21.018ms/frame`.
- 3840x2880 / 30-frame final timing:
  - standard: `render avg=16.927ms/frame`
  - dust-only strong: `render avg=13.584ms/frame`
  - strong: `render avg=16.955ms/frame`
- Visual probes inspected:
  - `/tmp/filmtone-export-speed-investigation/strong-before-vs-after-spotbound-frame12.png`
  - `/tmp/filmtone-export-speed-investigation/after-spotbound-strong-strip.png`
  - `/tmp/filmtone-film-damage-optimized/film-damage-current-bright.png`
  - `/tmp/filmtone-film-damage-optimized/film-damage-temporal-dust-only-strong.png`
- `bun run verify:desktop` passed.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed: 165/165.
- `bun run verify:ios` passed.
- `git diff --check` passed.

## Copy / History Impact

- No copy/history impact: internal Film Damage render optimization only.
- Article Opportunity: No story.
- Change-History Opportunity: Developer note.

## Done Conditions

- High-resolution Film Damage render time is materially lower than the current
  measured 3840 strong baseline (`render avg` around 21 ms/frame on the local
  30-frame probe).
- The visual probe still reads with dark dust/debris, not white-only dust.
- Desktop and iOS kernel copies stay aligned.
- Focused verification passes.

## Stop Conditions

- Done conditions met.
- Unexpected rendering artifact is found that changes the accepted look.
- 3 consecutive verification failures on the same command.

## Out Of Scope

- New Film Damage UI controls.
- Export architecture changes outside the current CoreImage kernel path.
- Release packaging, copy, App Store metadata, or public version claims.

## Unexpected Blockers

- None yet.
