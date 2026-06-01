# Film Damage Grain Integration Pass

Date opened: 2026-06-01 JST
Milestone: M3 Native Color And Optics Parity

## Goal

Reduce the cases where Film Damage and Film Grain look detached from the source
image by making damage marks inherit material grain, local luminance response,
and less-clean mask edges.

## Diagnosis

- Current Film Damage is applied after grain and print, so it can read as a
  clean mask on top of the image.
- Grain has exposure gates, but damage does not receive a re-grain / scan
  integration pass after it is composited.
- A full plate/material asset system is out of scope for this slice; the first
  product-quality improvement should stay inside the native kernels.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift`

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-01-film-damage-monochrome-physical.md`
- `docs/filmtone/desktop/native-desktop-v2/film-damage-visual-target-report.md`

## Checklist

- [x] Add total-damage material mask accounting.
- [x] Re-grain only the damaged regions so marks do not look cleanly pasted on.
- [x] Add local luma/source-retention response without reintroducing brown tint.
- [x] Keep Desktop and iOS kernels aligned.
- [x] Update visual probe output for combined grain/damage review.
- [x] Run verification.
- [x] Record results and archive this task.

## Verification

- `xcrun swiftc apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift -framework AppKit -framework CoreImage -o /tmp/FilmDamageVisualProbe && /tmp/FilmDamageVisualProbe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-grain-integration-proof`
  - Passed; wrote damage-only, grain+damage, and temporal proof images under
    `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-grain-integration-proof/`.
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

- Grain now uses a 24 fps frame-material clock with only a small sub-frame
  transition blend, reducing the slow "floating / swimming overlay" read.
- Film Damage now tracks per-layer blend weights into a material mask and adds
  neutral micro re-grain only where damage actually exists.
- White damage receives a small neutral soil pass, while damaged regions get
  luma-based tone return and neutral lock so they sit inside the image without
  reintroducing warm brown tint.
- The visual probe now includes a `grain+damage` midtone sheet and grain+damage
  temporal sheets, so future quality reviews can inspect the combined behavior.

No copy/history impact: this is an internal native render-quality change with no
public copy, release claim, version claim, or implementation-history claim.

Article Opportunity: Release-note only.
Change-History Opportunity: Developer note, because this records the shift from
clean post-damage masks toward material-integrated grain/damage compositing.

Knowledge note:
`docs/filmtone/desktop/native-desktop-v2/film-damage-grain-quality-knowledge.md`

## Done Conditions

- Damage marks remain visible but no longer read as perfectly clean overlays.
- The combined grain/damage probe shows damage edges and interiors carrying
  neutral micro texture.
- Desktop and iOS verification passes.

## Stop Conditions

- Done conditions are met and verification is recorded.
- Same verification class fails 3 consecutive times.

## Out Of Scope

- New public schema or UI controls.
- Real film plate assets.
- Reordering the full render pipeline.
- Motion-vector-aware scene tracking.

## Unexpected

None yet.
