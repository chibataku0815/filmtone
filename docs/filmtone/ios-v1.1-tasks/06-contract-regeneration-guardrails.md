# T6 — Contract Regeneration Guardrails

- Priority: P1
- Target: iOS v1.1
- Related plan: `../filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`

## Problem

iOS generated Phase0 payload can drift from Desktop shared defaults. The risk is highest around hidden defaults that Desktop uses for ray-angle, depth, and Cross Filter behavior but iOS does not expose as public controls.

## Current Facts

- iOS `FilmtonePhase0Generated.swift` stores final preset values
- Desktop shared defaults live in `packages/film-lab-core/src/params.ts` and `packages/film-lab-core/src/presets.ts`
- iOS `paramKeys` are a Phase0 subset
- Hidden defaults are not automatically available to iOS renderer helpers

## Implementation

1. Add generated hidden-default payload:
   - `depthRayAngleGamma`
   - `depthRayAngleInnerThreshold`
   - cross-filter defaults for future T7
   - depth coupling defaults for future T8
2. Add regeneration script or verify step:
   - source of truth is shared core package
   - generated Swift must fail verification if stale
3. Update fixture:
   - canonical export request includes camera optics and source metadata
   - generated defaults are checked without exposing UI controls
4. Document workflow:
   - how to regenerate
   - how to verify before release

## Acceptance Criteria

- A single command verifies iOS generated payload against shared contract
- CI/local typecheck fails on stale generated payload
- Hidden defaults are available to iOS code without user-visible sliders
- Preset catalog count is verified as 10

## Files

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/verify-phase0-contract.swift`
- `apps/capacitor-film-lab-ios/scripts/fixtures/phase0-contract/`
- `packages/film-lab-core/src/params.ts`
- `packages/film-lab-core/src/presets.ts`

## Tests

- Run existing Swift contract verifier
- Add stale fixture failure case if feasible
- Add preset count assertion

## Risks

- Over-expanding iOS DTOs can imply unsupported rendering parity
- Generated code must remain readable enough for App Store review debugging

