# Film Damage v3 Plate-Material Proof

Date opened: 2026-06-01 JST
Milestone: M3 Native Color And Optics Parity

## Goal

Replace the current procedural-only Film Damage feel with a first native
plate/material proof that avoids one-frame mechanical popping, left-edge
concentration, pure-white speckle noise, and near-invisible scratches.

This task is a product-quality proof, not a public schema bump.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift`
- `apps/filmtone-desktop-macos/Verify/CoreOpticalFilterTests.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneStrengthSheetData.swift`

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/film-damage-visual-target-report.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-01-film-damage-temporal-humanization.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-01-film-damage-visual-target-alignment.md`
- `visual-effect-core/docs/proposals/film-damage-v3-plate-material-contract.md`

## Checklist

- [x] Inspect the current Desktop and iOS Film Damage kernels and visual probe.
- [x] Add a plate/material-style temporal model: roll envelopes, persistent events, fade, drift, and non-frame-stepped changes.
- [x] Add more organic damage morphology: clustered dust, broken scratches, hair/fiber-like lines, gate/stain texture.
- [x] Improve material response so white damage is visible but not pure-white procedural speckle.
- [x] Keep existing UI controls and sidecar/schema surfaces unchanged.
- [x] Port the same core behavior to iOS export/preview kernel surface where applicable.
- [x] Run focused visual/contract verification.
- [x] Record verification and archive this task.

## Verification

- `apps/filmtone-desktop-macos/Verify/run.sh`
- `bun run verify:desktop`
- `bun run verify:ios`
- `git diff --check`
- `bun run check:filmtone-context`

## Done Conditions

- Strong mode shows visible scratches before maxing the override slider.
- Damage does not concentrate at the left edge or create a moire-like stripe.
- Dust and scratches do not appear as rigid one-frame mechanical flashes.
- White dust is present, but softened, material-colored, and balanced with dark defects.
- Existing Desktop and iOS verification passes.

## Stop Conditions

- Done conditions are met and verification is recorded.
- Unexpected architecture or asset packaging work is required beyond this proof.
- The same verification class fails 3 consecutive times.

## Out Of Scope

- Bundling third-party film damage assets.
- Public schema bump.
- New visible UI controls or copy changes.
- Release packaging, signing, notarization, or App Store metadata.

## Unexpected

None.

## Result

Implemented the first Film Damage v3 plate-material proof without changing
public schema or adding new visible controls.

- Desktop and iOS now use fractional frame time, longer roll-period envelopes,
  smoother fade curves, per-event drift, and persistent scratch/fiber events.
- Dust uses larger organic cells, drifted soft particles, material-colored
  bright defects, darker print dirt, stain texture, and lower edge bias.
- Scratches use doubled deterministic scratch fields, edge-to-interior
  redistribution, broken plate-like vertical segments, scuff width variation,
  and persistent fade instead of one-frame lane pops.
- Default/Strong recipe values were raised to make scratches visible before max
  override while preserving the existing two-slider UI.
- Visual probe output:
  `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-visual-probe-v3-proof/`

## Verification Run

- `apps/filmtone-desktop-macos/Verify/run.sh` -> 161/161 passed
- `bun run verify:desktop` -> passed
- `bun run verify:ios` -> passed
- `xcrun swiftc apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift -framework AppKit -framework CoreImage -o /tmp/FilmDamageVisualProbe && /tmp/FilmDamageVisualProbe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-visual-probe-v3-proof` -> generated contact sheets
- `git diff --check` -> passed
- `bun run check:filmtone-context` -> passed

## Copy / History Impact

No public copy impact: UI labels, release claims, and App Store/public wording
were not changed.

Article Opportunity: Developer note after visual acceptance, because this is an
implementation-quality shift from procedural-only film damage toward a
plate/material model.

Change-History Opportunity: Yes. This records why the procedural-only approach
was insufficient and why future Film Damage work should move toward real bundled
or generated material plates.
