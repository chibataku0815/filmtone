# Film Damage Grain Integration Performance Fix

Date opened: 2026-06-01 JST
Milestone: M3 Native Color And Optics Parity

## Goal

Fix the export-speed regression caused by the Film Damage / Grain integration
pass while preserving the visible improvement that made damage and grain feel
less detached.

## Diagnosis

- The previous quality pass added smooth `damageValueNoise` re-grain and edge
  raggedness after Film Damage composition.
- That code runs per pixel in the final damage kernel, which is too expensive
  for video export, especially at high dust/scratch values.
- The fix should keep the integration concept but use a guarded and cheaper
  texture approximation.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `docs/filmtone/desktop/native-desktop-v2/film-damage-grain-quality-knowledge.md`

## Checklist

- [x] Add a material-mask fast path so clean pixels skip re-grain work.
- [x] Replace smooth re-grain value-noise calls with cheaper hash/cell texture.
- [x] Keep Desktop and iOS kernels aligned.
- [x] Preserve neutral damage integration behavior.
- [x] Run verification.
- [x] Record results and archive this task.

## Verification

- `xcrun swiftc apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift -framework AppKit -framework CoreImage -o /tmp/FilmDamageVisualProbe && /tmp/FilmDamageVisualProbe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-grain-integration-performance-proof`
- `apps/filmtone-desktop-macos/Verify/run.sh`
- `bun run verify:desktop`
- `bun run verify:ios`
- `git diff --check`
- `bun run check:filmtone-context`

Results:

- Visual probe generated the performance-proof sheets; final local run was
  `real 1.45`, `user 0.62`, `sys 0.17`.
- `apps/filmtone-desktop-macos/Verify/run.sh` passed: `161/161 passed`.
- `bun run verify:desktop` passed.
- `bun run verify:ios` passed.
- `git diff --check` passed.
- `bun run check:filmtone-context` passed.

## Done Conditions

- The expensive re-grain work no longer runs for clean pixels.
- The damage integration still adds neutral micro texture where damage exists.
- Desktop and iOS verification passes.

## Stop Conditions

- Done conditions are met and verification is recorded.
- Same verification class fails 3 consecutive times.

## Out Of Scope

- Full export pipeline profiling.
- Real plate/material assets.
- New UI controls or schema changes.

## Result

- Desktop and iOS/iPad kernels now skip the damage-integration tail for clean
  pixels.
- Smooth value-noise re-grain was replaced by cheap quantized cell hashes in
  damaged regions.
- Grain now computes one frame-material pattern per output frame instead of
  blending two grain patterns.
- Neutral material integration remains visible in the visual probe.

## Copy / History Impact

No copy/history impact: this is an internal optical-kernel performance fix and
does not change release, platform, privacy, account/cloud, codec/export support,
or public implementation-history claims.

Article Opportunity: Release-note only if grouped into the Film Damage quality
update.

Change-History Opportunity: Developer note; this captures why final-pass damage
integration must stay cheap in export kernels.

## Known Remaining Product Risks

- Full real-video export timing was not benchmarked; the fix removes the known
  expensive per-pixel work but does not prove end-to-end export throughput on
  user footage.
- The larger Film Damage quality ceiling still depends on real plate/material
  assets rather than procedural masks alone.

## Unexpected

- The previous quality pass made export kernels materially heavier by adding
  smooth re-grain value noise after Film Damage composition. The fix keeps the
  integration behavior but avoids full-frame multi-sample noise work.
