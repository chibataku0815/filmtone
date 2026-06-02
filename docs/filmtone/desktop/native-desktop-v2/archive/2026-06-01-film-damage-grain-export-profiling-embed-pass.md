# Film Damage / Grain Export Profiling And Embed Pass

Date opened: 2026-06-01 JST
Milestone: M3 Native Color And Optics Parity

## Goal

Find the remaining real-export bottleneck in the native Desktop export path and
make Film Damage / Grain sit more inside the image instead of reading like a
clean overlay.

## Diagnosis

- CLI real-material export is now much faster, but the user still sees only a
  modest speed improvement in the app experience.
- The next performance question is no longer only shader cost. The export loop
  needs stage timing for decode/filter/render/append/finish so slow UI exports
  can be attributed instead of guessed.
- Film Damage / Grain can still float when defect opacity and grain response do
  not respect local luma, detail, blur, and damaged-region material response.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoWriter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `docs/filmtone/desktop/native-desktop-v2/film-damage-grain-quality-knowledge.md`

## Checklist

- [x] Add opt-in export timing that separates frame read, filter construction,
  render, append/backpressure, and final writer finish.
- [x] Reproduce a real-material export with timing enabled and record the
  dominant stage.
- [x] Inspect current Film Damage / Grain blend order and identify why defects
  can float over source detail.
- [x] Add one constrained material-response improvement that keeps defects
  neutral while binding opacity/polarity to source luma/detail.
- [x] Keep Desktop and iOS/iPad optical kernels aligned where the visual blend
  changes.
- [x] Run focused real-material export verification.
- [x] Run native Desktop verification.
- [x] Record results and archive this task.

## Verification

- Timed Desktop CLI export on a local real source with Grain + Film Damage
  enabled.
- `apps/filmtone-desktop-macos/Verify/run.sh`
- `bun run verify:desktop`
- `swift -frontend -parse apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `git diff --check`

## Verification Results

- `swift -frontend -parse apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`:
  passed.
- `swift -frontend -parse apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`:
  passed.
- `swift -frontend -parse apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`:
  passed.
- `bun run verify:desktop`: passed; Debug app rebuilt.
- Timed 4K/24fps 10s DJI real-material export with Grain + Film Damage stress
  overrides:
  `FILMTONE_EXPORT_TIMING=1 Filmtone --export-video --input /tmp/filmtone-real-dji-10s.mp4 --output /tmp/filmtone-real-dji-10s-embed-timed.mp4 --no-sidecar --param grainIntensity=0.064 --param grainSize=0.62 --param grainRadialMix=0.95 --param dustAmount=0.52 --param scratchAmount=0.56`
  -> `ok 3840x2160 frames=240`, `real 6.04`.
- Export timing summary for that run:
  `render=4356.7ms / 78.3%`, `read=500.8ms / 9.0%`,
  `filter_graph=445.9ms / 8.0%`, `writer_wait=0.4ms`,
  `append=7.6ms`, `finish=17.6ms`.
- Extracted and visually inspected:
  `/tmp/filmtone-real-dji-10s-embed-timed-5s.png` and
  `/tmp/filmtone-real-dji-10s-input-5s.png`.
- `apps/filmtone-desktop-macos/Verify/run.sh`: 161/161 passed.
- `bun run verify:ios`: passed with existing deprecation warnings.
- `bun run check:filmtone-context`: passed.
- `git diff --check`: passed.

## Done Conditions

- Export timing identifies whether the remaining perceived slowness is filter,
  render, append/backpressure, or finish time.
- Film Damage / Grain uses local source response enough to reduce clean overlay
  float without reintroducing brown color drift.
- Desktop and iOS/iPad kernels remain source-aligned for the changed optical
  behavior.

## Stop Conditions

- Done conditions are met and verification is recorded.
- The same verification class fails 3 consecutive times.
- Timing shows the remaining bottleneck is outside the app-controlled export
  loop.

## Out Of Scope

- Real plate/material asset ingestion.
- New user-facing quality/performance mode.
- Release, notarization, portfolio, or App Store metadata work.
- Cleanup or staging of unrelated ARRI, iPad, source-profile, or export filename
  worktree changes.

## Unexpected

- The timed 4K stress export showed the remaining cost is dominated by
  CoreImage render, not `AVAssetWriter` backpressure or final finish. This
  points the next large speed jump toward fewer render passes, a Metal path,
  or an explicit export-quality mode rather than additional writer tuning.

## Copy / History Impact

No public copy/history impact expected unless the change becomes a user-facing
quality/performance claim.

Article Opportunity: Developer note.

Change-History Opportunity: Developer note.
