# Active - Film Damage Visibility Tuning

Date opened: 2026-06-06 JST
Date completed: 2026-06-06 JST
Milestone: `M3 Native Color And Optics Parity` / `M4 Shared Contract Consolidation`

## Goal

Tune Filmtone film damage so dust and scratches read like real scan debris:
mixed dark dirt, fine line scratches, faint translucent stains, and sparse white
specks that vary by frame. The current product issue is that dust is mostly
visible only as white dots, which misses the supplied visual references.

Keep preview/export deterministic and preserve existing saved parameter shape,
sidecar compatibility, release rails, and portfolio state.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/Verify/CoreOpticalFilterTests.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`

## Read-Only References

- `/Users/chibatakumi/Pictures/写真ライブラリ.photoslibrary/resources/derivatives/6/62EA34BB-3511-4E4B-BAD5-A33C65CA33F0_1_102_o.jpeg`
- `/Users/chibatakumi/Pictures/写真ライブラリ.photoslibrary/resources/derivatives/E/E1B701B5-A82A-43EC-87D7-0A8073442E33_1_102_o.jpeg`
- `/Users/chibatakumi/Pictures/写真ライブラリ.photoslibrary/resources/derivatives/7/7F0523EB-0FAC-4926-A975-5A55CCD4EB54_1_102_o.jpeg`
- `/Users/chibatakumi/Pictures/写真ライブラリ.photoslibrary/resources/derivatives/8/8DE5543E-A6C7-45DC-B5AC-E3AE532505D5_1_102_o.jpeg`
- Supplied chat screenshots showing sparse dark dirt and hairline scratches
  over a pale sky / lake frame.

## Checklist

- [x] Locate the current film damage implementation paths for Native Desktop,
  iOS, preview, export, and any shared contract tests.
- [x] Compare current behavior to the reference requirement and identify why
  white dust dominates.
- [x] Tune the damage model to add sparse dark dirt, hairline scratches, faint
  stains, and frame-varying placement without changing saved parameter shape.
- [x] Keep native preview/export behavior deterministic and aligned across
  affected native rails where the implementation is duplicated.
- [x] Add or update focused verification for the film damage kernel contract.
- [x] Run the smallest verification that proves the changed surface.
- [x] Record verification, copy/history impact, article opportunity, and any
  remaining product risk before archiving this task.

## Verification

2026-06-06 JST:

- `xcrun swiftc apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift -framework AppKit -framework CoreImage -o /tmp/FilmDamageVisualProbe && /tmp/FilmDamageVisualProbe /tmp/filmtone-film-damage-after-c` passed with existing CIKL deprecation warnings.
- Visual inspection of `/tmp/filmtone-film-damage-after-c/film-damage-current-bright.png`,
  `/tmp/filmtone-film-damage-after-c/film-damage-current-midtone.png`, and
  `/tmp/filmtone-film-damage-after-c/film-damage-temporal-dust-only-strong.png`
  confirmed black debris/flecks appear in Dust and white sparkle no longer owns
  the read.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed (`165/165`).
- `bun run verify:ios` passed.
- `bun run verify:desktop` passed.
- `git diff --check` passed.

`bun run check:filmtone-context` was not run because no public copy,
release/version claim, App Store state, or implementation-history source was
changed.

## Done Conditions

- Film damage can produce visible dark dirt and fine dark scratches on bright
  content, not only white dust.
- White dust remains present but no longer dominates the effect.
- Faint translucent stains or smudges appear sparsely enough to match the
  supplied reference character without turning into a texture overlay.
- Preview/export remain deterministic for identical input parameters and frame
  times.
- No schema, sidecar, generated Swift, release metadata, portfolio submodule,
  or legacy Electron change is introduced.
- Required verification passes or any failure is documented with a concrete
  reason and next action.

## Stop Conditions

- Done conditions are met.
- The fix requires a saved-parameter, sidecar, or public copy change outside
  this active scope.
- The same verification class fails 3 consecutive times after targeted fixes.
- Existing user changes overlap the film damage surface in a way that makes the
  intended ownership unclear.

## Out Of Scope

- Legacy Electron/WebGL/WebGPU implementation changes.
- New user-facing controls, labels, presets, or public copy.
- Release packaging, version bumps, App Store/TestFlight state, DMG upload, or
  update metadata publication.
- Portfolio submodule bump, staging, commit, or push.

## Unexpected

- None yet.

## Copy / History Impact

No copy/history impact: this only changes the internal native optical kernel
rendering and a focused verification guard. No user-facing labels, public copy,
release metadata, App Store state, sidecar schema, or implementation-history
claim changed.

Article Opportunity: Release-note only. The change is user-visible as improved
Film Damage character, but it is a small tuning pass rather than a standalone
story.

Change-History Opportunity: Developer note. Future implementation-history
writing can mention the shift from white sparkle dominance toward material
dark debris, but no context source needs an immediate update.

## Completion Log

Added a Dust-owned dark debris layer for short fibers/flecks, increased the
dark dirt/stain bed, reduced white sparkle probability/strength, and mirrored
the native kernel changes across Desktop and iOS. Added a Desktop verification
guard proving Dust creates dark debris on bright material and is not
white-sparkle dominated.

Known remaining product risk: final taste still needs owner review in the live
editor/export against real footage, because verification used supplied
reference screenshots and synthetic contact sheets rather than the original
video source.
