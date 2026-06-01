# Film Damage Ultra Fast Attack Release Morph

Date opened: 2026-06-01 JST
Milestone: M3 Native Color And Optics Parity

## Goal

Make Film Damage dust and scratches feel less mechanical by making attack and
release extremely fast, while keeping the held portion visually stable and
adding morph / blur / smear only during the non-held transition portions.

## Motion Interpretation

- Source intent: reference footage shows defects entering and leaving very
  quickly, with a small amount of blur or instability around those moments.
- Motion thesis: each defect should read as a stable material mark with a
  rapid optical arrival and departure, not as a constantly animated procedural
  object.
- Signature law: `hold` is stable; `attack` and `release` are the only moments
  allowed to morph, smear, widen, or drift.
- Negative constraints: do not make every defect swim continuously, do not add
  slow dissolves, and do not make morphing strong enough to read as liquid UI
  animation.
- Acceptance criteria: defects pop in/out faster than the previous fast-easing
  proof, but the visible held portion remains anchored.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift`

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-01-film-damage-fast-easing-blur.md`
- `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-fast-easing-proof/`

## Checklist

- [x] Add explicit attack/release transition phase helpers.
- [x] Make dust/dirt/stain attack and release extremely fast.
- [x] Make scratches/fibers attack and release extremely fast while preserving
  stable hold.
- [x] Add transition-only morphing for dust and scratches.
- [x] Keep Desktop and iOS kernels behaviorally aligned.
- [x] Generate visual probe output for timing inspection.
- [x] Run verification.
- [x] Record results and archive this task.

## Results

- Added explicit temporal age and transition-phase helpers so Film Damage can
  distinguish attack/release from hold.
- Dust, dirt, stains, scratches, and fibers now use much shorter attack/release
  windows than the previous fast-easing pass.
- Hold is more stable: continuous frame-driven drift was reduced or moved into
  transition-only paths.
- Dust/dirt/stain transitions now add short-lived center drift, shape morph,
  radius morph, contour jitter, and stronger edge softness.
- Scratch/fiber transitions now add short-lived smear, bend morph, wider soft
  line edges, and transition-only texture travel.
- Desktop and iOS kernels were kept aligned.
- Visual probe output:
  `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-ultrafast-morph-proof/`

## Known Remaining Product Risk

- The morph/blur remains a procedural approximation inside a single-sample
  `CIColorKernel`. A true film plate blur or optical smear should move to a
  sampler kernel / material plate compositor.

## Copy / History Impact

No copy/history impact: internal Film Damage timing and material behavior changed
without public copy, release, platform, export, privacy, or implementation-history
claims.

Article Opportunity: No story.

Change-History Opportunity: Developer note only if a future Film Damage material
model write-up documents the interim CIColorKernel approximation.

## Verification

- `xcrun swiftc apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift -framework AppKit -framework CoreImage -o /tmp/FilmDamageVisualProbe && /tmp/FilmDamageVisualProbe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-ultrafast-morph-proof` - passed
- `apps/filmtone-desktop-macos/Verify/run.sh` - passed, 161/161
- `bun run verify:desktop` - passed
- `bun run verify:ios` - passed
- `git diff --check` - passed before archive
- `bun run check:filmtone-context` - passed after archive

## Done Conditions

- Attack/release feel clearly faster than the previous fast-easing pass.
- Hold phases remain stable instead of continuously swimming.
- Dust and scratches show transition-only blur/smear/morph.
- Desktop and iOS verification passes.

## Stop Conditions

- Done conditions are met and verification is recorded.
- A real multi-sampler blur/plate compositor becomes required for the requested
  motion quality.
- The same verification class fails 3 consecutive times.

## Out Of Scope

- Public schema changes.
- New UI controls.
- Real texture plate assets.
- Replacing the current Film Damage pipeline with a sampler kernel.

## Unexpected

None.
