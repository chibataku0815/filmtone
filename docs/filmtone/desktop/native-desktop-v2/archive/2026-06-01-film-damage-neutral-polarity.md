# Film Damage Neutral Dust Polarity

Date opened: 2026-06-01 JST
Milestone: M3 Native Color And Optics Parity

## Goal

Remove the incorrect brown / tea-colored Film Damage artifacts seen in preview.
Dust, dirt, stains, scratches, and gate wear should read as black, gray, or
off-white material damage, not as warm colored translucent UI-like patches.

## Visual Diagnosis

- The screenshot shows brown square-ish patches over the image.
- That is not acceptable for the current Film Damage control because it reads as
  color grading contamination rather than physical dust/scratch damage.
- The likely source is warm-biased `dirtTarget`, `stainTarget`, `gateTarget`,
  `edgeSoilTarget`, `sparkleTarget`, and `scratchLightTarget` values.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift`

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-01-film-damage-ultrafast-morph.md`
- `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-ultrafast-morph-proof/`

## Checklist

- [x] Neutralize dirt/gate/stain color targets.
- [x] Keep sparse white dust off-white, not yellow/brown.
- [x] Keep scratch light polarity neutral/off-white.
- [x] Keep Desktop and iOS kernels aligned.
- [x] Generate visual probe output.
- [x] Run verification.
- [x] Record results and archive this task.

## Results

- Gate wear and edge soil no longer use warm brown multipliers; they now push
  toward neutral luma.
- Dirt and stain targets no longer inherit warm source color as strongly. Dirt
  now targets neutral grayscale, and stain opacity was reduced so large marks do
  not read as tea-colored translucent patches.
- Sparse light dust and light scratches now use neutral/off-white targets
  instead of yellow/beige targets.
- Fiber and dark scratch targets were neutralized away from brown.
- Desktop and iOS kernels were kept aligned.
- Visual probe output:
  `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-neutral-polarity-proof/`

## Known Remaining Product Risk

- Real footage with strong warm wood/skin tones can still show source color
  through any low-opacity overlay. The warm defect color source has been removed;
  further removal would require either lower opacity or opaque neutral plate
  assets.

## Copy / History Impact

No copy/history impact: internal Film Damage color composition changed without
public copy, release, platform, export, privacy, or implementation-history
claims.

Article Opportunity: No story.

Change-History Opportunity: Developer note only if a future Film Damage material
model write-up explains the move from warm procedural stains to neutral material
polarity.

## Verification

- `xcrun swiftc apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift -framework AppKit -framework CoreImage -o /tmp/FilmDamageVisualProbe && /tmp/FilmDamageVisualProbe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-neutral-polarity-proof` - passed
- `apps/filmtone-desktop-macos/Verify/run.sh` - passed, 161/161
- `bun run verify:desktop` - passed
- `bun run verify:ios` - passed
- `git diff --check` - passed before archive
- `bun run check:filmtone-context` - passed after archive

## Done Conditions

- Large Film Damage marks no longer read as brown.
- Dark defects are neutral black/gray.
- Light defects are neutral/off-white.
- Desktop and iOS verification passes.

## Stop Conditions

- Done conditions are met and verification is recorded.
- Same verification class fails 3 consecutive times.

## Out Of Scope

- Public schema changes.
- New UI controls.
- Real film plate assets.
- Replacing the kernel architecture.

## Unexpected

None.
