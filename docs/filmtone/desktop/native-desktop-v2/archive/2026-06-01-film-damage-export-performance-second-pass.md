# Film Damage Export Performance Second Pass

Date opened: 2026-06-01 JST
Milestone: M3 Native Color And Optics Parity

## Goal

Make the Film Damage / Grain speed recovery visible in real exports, not only in
the small visual probe, while preserving the quality improvements from the
recent Film Damage passes.

## Diagnosis

- The previous performance fix reduced the new integration tail, but user
  feedback says export speed changed only slightly.
- The likely remaining cost is the full Film Damage kernel: it computes many
  dust, stain, gate, scratch, fiber, and temporal primitives per pixel even when
  only one slider family is active.
- The next fix should reduce full-frame work by gating unused families and
  replacing expensive smooth procedural texture where a cheaper material hash is
  visually sufficient.
- The 99% export stall was also a Desktop export-context issue: video export was
  using the shared preview `CIContext`, while the iOS export path disables
  intermediate caching. Long 4K exports with Grain + Film Damage can accumulate
  too much transient CoreImage/encoder pressure near the final writer flush.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/App/FilmtoneDesktopApp.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCIContext.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoWriter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMediaWriter.swift`
- `docs/filmtone/desktop/native-desktop-v2/film-damage-grain-quality-knowledge.md`

## Checklist

- [x] Inspect the Film Damage kernel for remaining always-on expensive work.
- [x] Add uniform family gating so dust-only and scratch-only exports avoid
  unrelated layer work.
- [x] Replace remaining high-cost smooth noise where it is not visually
  necessary.
- [x] Stop the video writer from failing long 4K exports after a 15-second
  encoder backpressure wait.
- [x] Move Desktop video export to an export-only no-intermediate-cache
  `CIContext`.
- [x] Show `Writing output...` during final writer flush instead of leaving the
  UI at the last rendered-frame label.
- [x] Add a max-speed kernel pass: reject non-present Film Damage events before
  fade, contour, and material-shape work.
- [x] Replace non-critical smooth procedural texture in Film Damage and Grain
  with quantized cell hashes.
- [x] Add headless Desktop `--param key=value` export overrides so real-source
  Grain / Film Damage stress exports can be reproduced outside the UI.
- [x] Keep Desktop and iOS/iPad kernels aligned.
- [x] Compare visual probe timing and output.
- [x] Run real-source Desktop export tests.
- [x] Run verification.
- [x] Record results and archive this task.

## Verification

- `xcrun swiftc apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift -framework AppKit -framework CoreImage -o /tmp/FilmDamageVisualProbe && /tmp/FilmDamageVisualProbe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-export-performance-second-pass`
- `apps/filmtone-desktop-macos/Verify/run.sh`
- `bun run verify:desktop`
- `bun run verify:ios`
- `git diff --check`
- `bun run check:filmtone-context`

## Verification Results

- `xcrun swiftc ... FilmDamageVisualProbe ...` generated updated probe images
  under `artifacts/film-damage-export-performance-second-pass-after-export-fix/`.
- Max-speed visual probe generated updated sheets under
  `artifacts/film-damage-export-performance-second-pass-max-speed/`;
  elapsed time was `real 1.29`.
- `swift -frontend -parse apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`:
  passed.
- `apps/filmtone-desktop-macos/Verify/run.sh`: 161/161 passed.
- `bun run verify:desktop`: passed; Debug app rebuilt.
- Headless Desktop export smoke:
  `Filmtone --export-video --input apps/desktop-film-lab-batch/fixtures/video/sdr/synthetic-bt709-1s-20260424.mp4 --output /tmp/filmtone-export-smoke.mp4 --no-sidecar`
  -> `ok 320x180 frames=24`, `real 0.56`.
- Real-source 1080p/24fps export with Grain Push + Film Damage Strong
  overrides:
  `/Users/chibatakumi/Movies/P1290493-reset.mp4`
  -> `ok 1920x1080 frames=264`, `real 3.66`.
- Real-source 4K/24fps DJI 10s clip baseline:
  `/tmp/filmtone-real-dji-10s.mp4`
  -> `ok 3840x2160 frames=240`, `real 3.02`.
- Real-source 4K/24fps DJI 10s clip with Grain Push + Film Damage Strong
  overrides:
  `/tmp/filmtone-real-dji-10s.mp4`
  -> `ok 3840x2160 frames=240`, `real 5.05`.
- Real-source full 4K/24fps DJI export with Grain Push + Film Damage Strong
  overrides:
  `/Users/chibatakumi/Movies/DJI_20260514155502_0073_D-reset.mp4`
  -> `ok 3840x2160 frames=3070`, `real 60.30`; output duration
  `127.916667`.
- `bun run verify:ios`: passed with existing deprecation warnings.
- `git diff --check`: passed.
- `bun run check:filmtone-context`: passed.

## Done Conditions

- Film Damage avoids unrelated dust/scratch family work when those sliders are
  effectively inactive.
- Visual probe output still shows integrated neutral damage and readable
  scratches/dust.
- Desktop and iOS/iPad verification passes.

## Stop Conditions

- Done conditions are met and verification is recorded.
- Same verification class fails 3 consecutive times.

## Out Of Scope

- Full profiler instrumentation of the AVFoundation export loop.
- New user-facing performance or quality mode.
- Real plate/material assets.

## Unexpected

- User hit `FilmtoneVideoWriterError error 6` during a Desktop slow-24 video
  export. That maps to the native Desktop writer's 15-second
  `waitForReadyTimedOut` guard, not a Film Damage shader compile failure. The
  writer now checks failed/cancelled/completed status while waiting, uses a
  longer offline wait budget, and surfaces localized error messages instead of
  raw enum numbers.
- User then hit a practical 99% export stall with Grain 3 + Film Damage 2 on a
  long slow-24 video. Desktop now uses an export-only `CIContext` with
  `.cacheIntermediates: false` and `RGBAh`, waits for writer readiness before
  rendering the next frame, and switches progress copy to `Writing output...`
  before `finishWriting`.
- User asked for maximum possible speed improvement after the first speed pass
  was still only modest. The additional pass now avoids fade/shape/noise work
  for absent damage cells, avoids repeated temporal helper work inside
  `damageSpot` and `damageScratch`, and cuts high-frequency Grain / Film Damage
  texture from smooth value-noise to direct cell hashes where the material does
  not need interpolation.
- User then asked for actual-material testing. The repo fixtures only contain
  synthetic videos, so the Desktop CLI now accepts repeatable headless
  `--param key=value` overrides and was tested against local real footage,
  including a full 4K/24fps 127.9s DJI source.

## Copy / History Impact

No public copy/history impact: this is export reliability/performance plumbing
and optical-kernel optimization, not a product claim change.

Article Opportunity: Release-note only.

Change-History Opportunity: Developer note.

## Known Remaining Product Risks

- A true large speed jump likely requires a larger architecture pass: Metal
  Film Damage kernels, real plate/material assets, or an explicit export-quality
  mode. This slice avoids silently lowering export resolution.
- The latest pass changes procedural texture character: it keeps visible
  damage/grain but trades some smooth interpolation for cell-material hashes.
  User confirmed the result was substantially better before the task was
  archived.
