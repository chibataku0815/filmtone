# T7 — Cross Filter Native Parity

- Priority: P2
- Target: v1.2 candidate
- Related plan: `../filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`

## Problem

Desktop has a depth-aware and ray-angle-aware Cross Filter streak pass. iOS native export currently has no Cross Filter implementation in the Phase0 Core Image path.

## Current Facts

- Desktop reference: `packages/film-lab-renderer/src/webgpu/shaders/cross-filter-streak.frag.wgsl.ts`
- iOS Phase0 generated params do not include `crossFilter*`
- No native Core Image / Metal cross-streak pass is present in `FilmtoneExportSession.swift`

## Proposed Scope

1. Add hidden/default `crossFilter*` contract values to iOS generated support through T6
2. Build minimal soft-mode cross streak implementation
3. Add ray-angle shaping after T3 helper exists
4. Add depth shaping only after T8 pipeline exists
5. Gate UI exposure separately; first implementation can be preset-driven only

## Acceptance Criteria

- Cross Filter can be enabled by preset/contract value without UI controls
- Streak count, angle, length, chromatic, threshold, and randomness are supported
- Missing depth map falls back to non-depth behavior
- Visual fixture demonstrates streak parity within accepted tolerance

## Files

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift`
- `packages/film-lab-renderer/src/webgpu/shaders/cross-filter-streak.frag.wgsl.ts`
- `packages/film-lab-core/src/params.ts`

## Tests

- Synthetic point-light fixture
- Soft mode fixture
- Edge-field wide vs tele optics fixture

## Risks

- Core Image may be awkward for multi-direction streak marching
- A Metal pass may be cleaner but increases implementation scope
- Cross Filter can be expensive on older devices

