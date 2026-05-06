# Filmtone Motion 180 Baseline / Industry Standard Handoff

Created: 2026-04-29 JST  
Primary repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`  
Entry context repo: `/Volumes/SamsungPortableSSDX5001/documents/life`  
Target area: Filmtone Desktop renderer, WebGL/WebGPU preview/export parity, iOS export parity, Motion UI copy

## Purpose

This document hands off the full context for the Filmtone Motion 180 degree baseline fix and the follow-up decision that should be made in the next chat.

The short version:

- The already-implemented 180 degree no-op baseline is product-correct for normal iPhone/cinema footage.
- The current `720 degree = 6 active frames` mapping is not a good industry-standard shutter simulation.
- The next pass should keep the 180 degree baseline behavior but revise the active-frame mapping so `shutterAngle` behaves like target shutter exposure, while long expressive trails remain the responsibility of `trailIntensity`.

## Routing / Startup Notes For The Next Chat

If the next chat starts from the `life` repo, follow `/Volumes/SamsungPortableSSDX5001/documents/life/AGENTS.md` and open:

- `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/film-lab-current-index.md`
- this handoff document
- the active implementation files listed below

Do not begin with broad file discovery. The implementation repo is:

```bash
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
```

If release/latest-version status becomes relevant, run the truth scripts from `life` before making release claims. This handoff is about rendering behavior, not release status.

## Original Product Problem

Filmtone Motion previously treated `shutterAngle = 180` as an additional temporal blend over neighboring frames. That is wrong for normal source footage.

The product assumption is:

- Normal iPhone/cinema footage already contains roughly 180 degree shutter motion blur.
- Filmtone Motion is an additive post process.
- Filmtone does not deblur high-shutter footage.
- Therefore, `shutterAngle = 180` should mean "normal-source baseline / no added blur", not "add another 180 degree blur pass".

Without this correction, normal 180 degree footage receives double blur and visible ghosting.

## User's Initial Implementation Requirements

The requested fix was:

- Interpret `shutterAngle` as target shutter feel relative to normal 180 degree source material.
- Keep schema, DTO, saved project shape, export request shape, and project version unchanged.
- Make `shutterAngle <= 180` a motion-stage no-op for preview, desktop export, and iOS export.
- Reset temporal history/ring state when motion is inactive.
- Only apply temporal blending for `shutterAngle > 180`.
- Use one shared TypeScript helper for WebGL/WebGPU math.
- Mirror the same math in Swift for iOS export.
- Preserve legacy `motionBlurAmount` only as a fallback when `shutterAngle` is missing.
- Update presets:
  - Standard/default: `shutterAngle = 360`, `trailIntensity = 0`
  - Strong: `shutterAngle = 720`, `trailIntensity = 0.35`
- Update UI copy:
  - `180 degree = normal-source baseline / no added blur`
  - `>180 degree = slow-shutter extension`
  - `trailIntensity = beyond-shutter-window trail only`

## Implementation Already Landed

The Filmtone Motion baseline work is already present on `main`.

Observed commit containing the Motion changes:

```text
0ec50f3637385dcdd49d4b7da5a39d461fb7f0ac
feat(filmtone-ios): add LUT amount sliders
AuthorDate: 2026-04-29 15:43:00 +0900
```

Important: the commit subject mentions LUT amount sliders, but the commit also contains the Motion 180 baseline work. Do not assume the subject fully describes the commit.

Files touched by that commit for this Motion work include:

- `packages/film-lab-renderer/src/motionBlurMath.ts`
- `packages/film-lab-renderer/src/motionBlurMath.test.ts`
- `packages/film-lab-renderer/src/webgl/WebGLBackend.ts`
- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts`
- `packages/film-lab-renderer/src/webgpu/RingBuffer.ts`
- `packages/film-lab-renderer/src/Viewport.ts`
- `apps/desktop-film-lab-batch/src/renderer/effective-export-grade.ts`
- `apps/desktop-film-lab-batch/src/renderer/effective-export-grade.test.ts`
- `apps/desktop-film-lab-batch/messages/en.json`
- `apps/desktop-film-lab-batch/messages/ja.json`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMotionBlurMath.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/test-motion-blur-math.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/verify-phase0-contract.swift`
- `apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh`

## Current Implemented Math

Current TypeScript helper:

```ts
export const MOTION_BLUR_BASELINE_SHUTTER_ANGLE = 180;
export const MOTION_BLUR_MAX_SHUTTER_ANGLE = 720;
export const MOTION_BLUR_DEFAULT_RING_SLOTS = 8;

export function additionalMotionShutterAngle(shutterAngle: number): number {
  return clampMotionShutterAngle(shutterAngle) - MOTION_BLUR_BASELINE_SHUTTER_ANGLE;
}

export function isShutterMotionActive(shutterAngle: number): boolean {
  return additionalMotionShutterAngle(shutterAngle) > 0;
}

export function activeMotionBlurFramesForShutter(
  shutterAngle: number,
  ringSlots: number = MOTION_BLUR_DEFAULT_RING_SLOTS,
): number {
  const additionalAngle = additionalMotionShutterAngle(shutterAngle);
  if (additionalAngle <= 0) return 1;
  const slots = Math.max(1, Math.round(ringSlots));
  const raw = Math.round((additionalAngle / 360) * (slots / 2));
  return Math.max(2, Math.min(slots, raw));
}
```

With the default 8 ring slots, this currently gives:

- `0 degree`: inactive, 1 frame passthrough
- `180 degree`: inactive, 1 frame passthrough
- `360 degree`: active, 2 frames, triangle weights `[2/3, 1/3]`
- `720 degree`: active, 6 frames, flattened box weights `[1/6 x 6]`

The same formula exists in Swift:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMotionBlurMath.swift`

## Verified Behavior Already Achieved

The following checks were run after the first implementation and passed:

```bash
bun test packages/film-lab-renderer/src/motionBlurMath.test.ts
bun test packages/film-lab-core/src
bun test apps/desktop-film-lab-batch/src/renderer/effective-export-grade.test.ts
bun run build:core
bun run build:renderer
bun run generate:filmtone-ios-swift
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

The Xcode build succeeded. Existing warnings were observed around app extension `CFBundleVersion` mismatch and CocoaPods script output configuration; those were not introduced by the Motion work.

## Git / Worktree State Observed During This Handoff

At the time this document was created, the implementation repo was on `main`.

Recent log observed:

```text
d7b9b275 fix(filmtone-ios): guard mezzanine routing for p3 sources
946a3b19 fix(journal): include translation namespace expansion missing from wave 1 commit
b8353730 feat(journal): wave 1 - registry, articles, motion-studies hub
1e80d317 fix(web): align liquid-glass front canvas with css box on scrolled pages
0ec50f36 feat(filmtone-ios): add LUT amount sliders
90de10b7 fix(filmtone-ios): stabilize LUT clear state
```

Unrelated dirty worktree entries observed before adding this handoff:

```text
 M apps/web/src/features/hero/components/HomeHero.tsx
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-lut-intensity-slider-handoff-2026-04-29-jst.md
```

Do not revert these unless explicitly asked. They are unrelated to the next Motion correction.

Earlier feature worktrees were checked:

- `.worktrees/filmtone-ios-code-residual` on `feature/filmtone-ios-code-residual`
- `.worktrees/logo-lockup-home-20260428` on `feature/logo-lockup-home-20260428`

Both were no-op relative to `main` at that time: no ahead commits and no meaningful diff to merge.

## Industry Standard Research Summary

The user explicitly asked to research the industry-standard solution before deciding whether the current approach is really good.

Sources checked:

- RED Support: "Shutter Angles and Creative Control"  
  https://support.red.com/hc/en-us/articles/360019775493-Shutter-Angles-and-Creative-Control
- Foundry Nuke Kronos MotionBlur controls  
  https://learn.foundry.com/nuke/current/content/comp_environment/kronos_motionblur/adjusting_motionblur_controls.html
- Foundry Nuke render motion blur parameters  
  https://learn.foundry.com/nuke/content/comp_environment/prmanrender/adjusting_motion_blur.html
- Blender Cycles Motion Blur manual  
  https://docs.blender.org/manual/en/latest/render/cycles/render_settings/motion_blur.html
- Blender EEVEE Motion Blur manual  
  https://docs.blender.org/manual/en/latest/render/eevee/render_settings/motion_blur.html
- SideFX Houdini Mantra motion blur  
  https://www.sidefx.com/docs/houdini/render/blur.html
- Adobe After Effects Pixel Motion Blur tutorial  
  https://www.adobe.com/africa/learn/after-effects/web/aftereffects-pixel-motion-blur-cc
- Research paper: "Video shutter angle estimation using optical flow and linear blur"  
  https://arxiv.org/abs/2303.10247

Key findings:

1. Industry tools treat shutter angle as exposure duration relative to the frame interval.
   - `180 degree = 0.5 frame exposure`
   - `360 degree = 1.0 frame exposure`
   - `720 degree = 2.0 frame exposure`, if allowed as a stylized/digital extension

2. Render/compositing tools separate shutter duration from sample count.
   - Nuke exposes Shutter Time and Shutter Samples separately.
   - Blender exposes Shutter and Steps/Samples style controls separately.
   - Houdini separates shutter time, shutter offset, and motion samples.

3. Post-processing motion blur for already-shot footage is usually used to rescue or stylize under-blurred/high-shutter footage.
   - Adobe's Pixel Motion Blur example frames the effect as adding motion blur to already-shot or already-rendered material, especially footage shot with too-fast shutter.
   - This supports Filmtone's decision not to blindly add 180 degree blur on normal footage.

4. Optical flow / motion vectors are the industry path for higher-quality post blur on existing footage.
   - AE Pixel Motion Blur uses optical-flow-like intermediate points.
   - Nuke Kronos MotionBlur uses motion estimation vectors.
   - Academic shutter-angle estimation also models the relationship between exposure fraction, optical flow, and linear blur.

## Assessment Of The Current Implementation

### What Is Correct

Keep these decisions:

- `shutterAngle <= 180` should be motion-stage no-op for normal-source footage.
- When inactive, preview/export/iOS should reset temporal history and return the spatial grade result directly.
- `trailIntensity` should not apply when `shutterAngle <= 180`.
- `motionBlurAmount` should remain only a legacy fallback when `shutterAngle` is missing.
- WebGL, WebGPU, and Swift should use the same frame-count and weight semantics.
- No schema, DTO, project version, or wire shape changes are needed.

### What Is Not Good Enough

The weak part is the current active-frame formula:

```ts
round((additionalAngle / 360) * (ringSlots / 2))
```

This conflates three different concepts:

- shutter duration / exposure window
- temporal sample count / quality
- number of stored previous frames in a ring buffer

With 8 ring slots, this maps `720 degree` to 6 stored frames. That is not an industry-standard 720 degree shutter. It is closer to a long frame echo or trail effect.

In industry terms:

- `720 degree` means 2 frame intervals of exposure.
- Since Filmtone assumes the source already has a 180 degree / 0.5-frame exposure baked in, the additional exposure target is about `2.0 - 0.5 = 1.5 frames`.
- A ring-buffer approximation should therefore use a short window, not 6 historical frames.

## Recommended Next Approach

Keep the current external API:

- `shutterAngle: 0...720`
- `trailIntensity: 0...0.95`
- no schema or DTO changes
- no migration
- saved `shutterAngle: 180` remains valid and means no added blur

Change the internal helper semantics to exposure-frame math:

```ts
const BASELINE_SOURCE_SHUTTER_ANGLE = 180;
const MAX_TARGET_SHUTTER_ANGLE = 720;

const targetExposureFrames = clamp(shutterAngle, 0, 720) / 360;
const sourceExposureFrames = BASELINE_SOURCE_SHUTTER_ANGLE / 360; // 0.5
const additionalExposureFrames = Math.max(
  0,
  targetExposureFrames - sourceExposureFrames,
);
const motionActive = additionalExposureFrames > 0;
```

For the current ring-buffer renderer, map the additional exposure to a small history window. A pragmatic first-pass mapping:

```ts
function activeMotionBlurFramesForShutter(shutterAngle: number): number {
  const additionalExposureFrames = additionalMotionExposureFrames(shutterAngle);
  if (additionalExposureFrames <= 0) return 1;
  return clamp(1 + Math.ceil(additionalExposureFrames), 2, 3);
}
```

Expected behavior with this mapping:

- `0 degree`: inactive, current frame only
- `180 degree`: inactive, current frame only
- `360 degree`: active, 2 frames
- `540 degree`: active, 2 frames or 3 frames depending on final taste decision
- `720 degree`: active, 3 frames

Recommended concrete choice:

- `360 degree = 2 active frames`, triangle weights `[2/3, 1/3]`
- `720 degree = 3 active frames`, flat/box-ish weights `[1/3, 1/3, 1/3]`
- keep weight flatness based on target `shutterAngle`, unless visual smoke shows a harsher transition

This is not a perfect physical shutter simulation, but it is more honest:

- `shutterAngle` controls the shutter-window extension.
- `trailIntensity` controls stylized beyond-window afterimage.
- ring-buffer frame count is only an approximation of exposure duration.

## Why Not Keep 720 = 6 Frames?

Keeping `720 = 6 frames` is acceptable only if the product intentionally wants "Slow Shutter / Trails" as an expressive effect, not a camera-shutter-angle simulation.

The user asked for product quality over conservative advice. Product-quality implication:

- If the UI says "target shutter feel", `720 = 6 frames` is misleading and too echo-like.
- If the UI says "creative trails", 6 frames can be valid, but then `trailIntensity` loses its clean meaning.
- The cleaner model is: shutter window stays physically plausible; `trailIntensity` adds the obvious expressive tail.

## Future High-Quality Path

The best long-term implementation is not larger ring blending. It is optical-flow or motion-vector sampling:

- estimate or obtain motion vectors
- generate intermediate temporal samples inside the target shutter window
- integrate those samples with a shutter curve
- use sample count as a quality/performance setting, not as the effect amount

This aligns with AE Pixel Motion Blur, Nuke Kronos MotionBlur, and common render-engine motion blur designs.

This is likely too large for the immediate next fix. The next pass should first correct the current ring-buffer approximation.

## Suggested Implementation Steps For The Next Chat

1. Open these files:

```text
packages/film-lab-renderer/src/motionBlurMath.ts
packages/film-lab-renderer/src/motionBlurMath.test.ts
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMotionBlurMath.swift
apps/capacitor-film-lab-ios/scripts/swift/test-motion-blur-math.swift
apps/capacitor-film-lab-ios/scripts/swift/verify-phase0-contract.swift
apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh
```

2. Change TS and Swift helper math together.

3. Update tests:

- `0` inactive, current-only
- `180` inactive, current-only
- `360` active, 2 frames, triangle weights
- `720` active, recommended 3 frames, flattened weights
- `trailIntensity` still ignored when `shutterAngle <= 180`

4. Check WebGL/WebGPU/iOS call sites for assumptions that expect `720 = 6`.

5. Keep UI copy conceptually unchanged:

- 180 degree baseline / no added blur
- above 180 degree slow-shutter extension
- trail intensity is beyond-window afterimage

6. Run focused checks:

```bash
bun test packages/film-lab-renderer/src/motionBlurMath.test.ts
bun test packages/film-lab-core/src
bun test apps/desktop-film-lab-batch/src/renderer/effective-export-grade.test.ts
bun run build:core
bun run build:renderer
bun run generate:filmtone-ios-swift
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
```

7. If focused checks pass and no unrelated failures appear, run iOS simulator build smoke:

```bash
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

## Non-Goals

Do not do these in the next pass unless explicitly requested:

- schema migration
- DTO/wire-shape change
- project version bump
- broad release QA
- snapshot refresh
- release notes
- unrelated iOS LUT work
- unrelated web hero work
- broad docs architecture cleanup

## Exact Handoff Prompt For The Next Chat

Use this prompt verbatim in the next chat for maximum continuity:

```text
We are working in:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

Please read this handoff first:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-motion-180-baseline-industry-handoff-2026-04-29-jst.md

Task:
Implement the follow-up correction for Filmtone Motion shutter-angle math based on the industry-standard research in that handoff.

Keep:
- `shutterAngle <= 180` is motion-stage no-op.
- inactive motion resets temporal history/ring and returns the spatial grade result.
- schema, DTO, saved project shape, export request shape, project version, and wire shape unchanged.
- `motionBlurAmount` remains legacy fallback only when `shutterAngle` is missing.
- WebGL, WebGPU, and iOS export remain behaviorally aligned.
- Motion presets remain Standard/default `shutterAngle=360, trailIntensity=0` and Strong `shutterAngle=720, trailIntensity=0.35`, unless tests/smoke reveal a clear product-quality reason to adjust.

Change:
- Do not keep the current `720 degree = 6 active frames` mapping.
- Rework the helper to treat shutter angle as target exposure duration relative to an assumed 180 degree source baseline:
  - `targetExposureFrames = clamp(shutterAngle, 0, 720) / 360`
  - `sourceExposureFrames = 180 / 360`
  - `additionalExposureFrames = max(0, targetExposureFrames - sourceExposureFrames)`
  - active only when `additionalExposureFrames > 0`
- For the current ring-buffer approximation, use a short physical-ish history window:
  - `0` and `180`: inactive/current-only
  - `360`: 2 active frames with triangle weights `[2/3, 1/3]`
  - `720`: recommended 3 active frames with flattened/box-ish weights `[1/3, 1/3, 1/3]`
- Keep long expressive afterimages under `trailIntensity`, not under `shutterAngle`.

Files to inspect first:
- `packages/film-lab-renderer/src/motionBlurMath.ts`
- `packages/film-lab-renderer/src/motionBlurMath.test.ts`
- `packages/film-lab-renderer/src/webgl/WebGLBackend.ts`
- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts`
- `packages/film-lab-renderer/src/webgpu/RingBuffer.ts`
- `packages/film-lab-renderer/src/Viewport.ts`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMotionBlurMath.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/test-motion-blur-math.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/verify-phase0-contract.swift`

Important repo state:
- The first Motion 180 baseline implementation already landed on `main` in commit `0ec50f3637385dcdd49d4b7da5a39d461fb7f0ac`, whose subject is `feat(filmtone-ios): add LUT amount sliders`.
- That commit subject is misleading; it also contains the Motion helper, WebGL/WebGPU/iOS export changes, and tests.
- There may be unrelated dirty files. Do not revert unrelated user/worktree changes.

Verification to run:
- `bun test packages/film-lab-renderer/src/motionBlurMath.test.ts`
- `bun test packages/film-lab-core/src`
- `bun test apps/desktop-film-lab-batch/src/renderer/effective-export-grade.test.ts`
- `bun run build:core`
- `bun run build:renderer`
- `bun run generate:filmtone-ios-swift`
- `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract`
- If focused checks pass, run iOS simulator build smoke:
  `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -destination 'generic/platform=iOS Simulator' build`

Use sequential thinking for the implementation decision. The product-quality priority is:
1. Avoid double-blur at 180 degree.
2. Make `shutterAngle` honestly represent target shutter-window extension.
3. Keep long trails as `trailIntensity`.
4. Maintain desktop/iOS parity and existing project compatibility.
```
