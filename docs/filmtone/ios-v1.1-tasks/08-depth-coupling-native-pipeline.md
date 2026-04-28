# T8 — Depth Coupling Native Pipeline

- Priority: P2
- Target: v1.2 candidate
- Related plan: `../filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`

## Problem

Desktop uses depth and ray-angle prefilters for bloom, halation, and diffusion. iOS has glow family stages, but they are uniform across the frame and do not consume depth.

## Current Facts

- Desktop shaders:
  - `bloom-depth-prefilter.frag.wgsl.ts`
  - `halation-depth-prefilter.frag.wgsl.ts`
  - `diffusion-depth-prefilter.frag.wgsl.ts`
- iOS Core Image stages exist for bloom / halation / diffusion
- iOS has no depth texture lifecycle or depth map import path in Phase0 native export

## Proposed Scope

1. Define depth input contract:
   - source format
   - resolution
   - alignment with source image/video
   - missing-depth fallback
2. Add native depth loading:
   - still source first
   - video sequence only after still path is stable
3. Apply depth prefilter to glow family:
   - bloom
   - halation
   - diffusion
4. Reuse T3 ray-angle helper for field response
5. Keep UI hidden until fixtures prove quality

## Acceptance Criteria

- Missing depth preserves current iOS output
- Still image with depth map changes glow contribution by depth plane
- Sidecar records whether depth was used
- Performance remains acceptable on target devices

## Files

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`
- `packages/film-lab-renderer/src/webgpu/shaders/bloom-depth-prefilter.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/halation-depth-prefilter.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/diffusion-depth-prefilter.frag.wgsl.ts`

## Tests

- Synthetic foreground/background depth fixture
- Glow plane isolation fixture
- Missing-depth parity fixture

## Risks

- Depth alignment with transformed portrait video is easy to get wrong
- Video depth sequences can become large quickly
- Performance may require Metal rather than pure Core Image

