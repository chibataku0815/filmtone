# Film Damage Monochrome Physical Defects

Date opened: 2026-06-01 JST
Milestone: M3 Native Color And Optics Parity

## Goal

Fix Film Damage polarity so visible defects read as physical black / dark gray /
white / off-white material marks, not brown translucent color stains.

## Diagnosis

- Previous neutralization was not enough because defects still blended at low
  opacity over warm source footage, so source chroma remained visible.
- White defects were still too frequent, while black/dark defects were not
  dominant enough.
- Stain-style light branches should be removed for this quality pass.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift`

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-01-film-damage-neutral-polarity.md`
- User screenshot: `CleanShot 2026-06-01 at 18.29.59@2x.png`

## Checklist

- [x] Make black/dark dust the dominant dust polarity.
- [x] Make white dust sparse and neutral/off-white.
- [x] Remove light/warm stain branches.
- [x] Make dirt/stain/gate defects overwrite source chroma more strongly.
- [x] Make dark scratches/fibers dominant and neutral.
- [x] Keep Desktop and iOS kernels aligned.
- [x] Generate visual probe output.
- [x] Run verification.
- [x] Record results and archive this task.

## Verification

- `xcrun swiftc apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift -framework AppKit -framework CoreImage -o /tmp/FilmDamageVisualProbe && /tmp/FilmDamageVisualProbe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-monochrome-physical-proof`
  - Passed; wrote visual proof images under
    `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-monochrome-physical-proof/`.
- `apps/filmtone-desktop-macos/Verify/run.sh`
  - Passed: 161/161.
- `bun run verify:desktop`
  - Passed.
- `bun run verify:ios`
  - Passed with existing Core Image / AVFoundation deprecation warnings.
- `git diff --check`
  - Passed after archive move.
- `bun run check:filmtone-context`
  - Passed after archive move.

## Results

- Desktop and iOS Film Damage now use neutral luma targets for gate wear, edge
  soil, dirt, stains, dust, scratches, and fibers instead of warm or source-
  chroma-preserving brown targets.
- Dark dust is now the dominant polarity; white/off-white dust is sparse and
  explicitly neutral.
- Dark scratches and fibers are dominant, with light scratches reserved as rare
  neutral/off-white events.
- The visual probe shows dark/black physical defects clearly again without the
  previous brown translucent stain read.

No copy/history impact: behavior changed inside the native Film Damage kernel,
but no public copy, release claim, version claim, or implementation-history claim
changed.

Article Opportunity: Release-note only.
Change-History Opportunity: Developer note, because this records why warm
procedural defect targets were removed in favor of monochrome physical masks.

## Done Conditions

- Brown/tea-colored defect marks are removed from the kernel targets.
- Dark defects are visibly present.
- White defects are sparse and neutral/off-white.
- Desktop and iOS verification passes.

## Stop Conditions

- Done conditions are met and verification is recorded.
- Same verification class fails 3 consecutive times.

## Out Of Scope

- Public schema changes.
- New UI controls.
- Real film plate assets.
- Replacing Film Damage with a sampler/plate compositor.

## Unexpected

None yet.
