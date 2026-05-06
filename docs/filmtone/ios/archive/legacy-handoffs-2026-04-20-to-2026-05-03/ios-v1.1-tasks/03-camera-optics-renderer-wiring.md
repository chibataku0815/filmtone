# T3 — Camera Optics Renderer Wiring

- Priority: P1
- Target: iOS v1.1
- Related plan: `../filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`

## Problem

iOS already probes `CameraOpticsDTO`, but native render/export does not use it. Desktop uses camera optics to resolve ray-angle behavior, so edge-field optical response can differ between platforms.

## Current Facts

- `SourceProbeService.swift` creates `CameraOpticsDTO`
- `Phase0ExportRequestDTO.sourceProbe` carries that DTO into export
- `FilmtoneExportSession.swift` Core Image kernels do not read `cameraOptics`
- Desktop reference math lives in `packages/film-lab-renderer/src/webgpu/rayAngleOptics.ts`

## Implementation

1. Add Swift ray-angle helper:
   - validate `fovXDeg / fovYDeg`
   - fallback to `fxPx / fyPx`
   - fallback to 65 deg equivalent when optics are missing
   - output `tanHalfFovX / tanHalfFovY / source`
2. Add field mask helper:
   - equivalent to Desktop `rayAngleMaskValue`
   - use default `depthRayAngleGamma = 1.4`
   - use default `depthRayAngleInnerThreshold = 0.1`
3. Wire into existing Core Image stages:
   - vignette field response
   - edge softness / radial RGB shift response
   - optional glow family response if low-risk
4. Keep UI params unchanged:
   - no new visible controls
   - hidden defaults come from T6 contract guardrails

## Acceptance Criteria

- Metadata HFOV and assumed HFOV produce different ray-angle masks
- Missing optics falls back deterministically
- Existing SDR sample output changes only within expected edge-field tolerance
- Camera optics source appears in debug/sidecar

## Files

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift`
- `packages/film-lab-renderer/src/webgpu/rayAngleOptics.ts`

## Tests

- Pure Swift math tests for 35mm-ish, wide, tele, and missing optics
- Snapshot comparison for assumed vs metadata optics
- Contract fixture with `cameraOptics.source = metadata`

## Risks

- Desktop shader and iOS Core Image kernels are not identical renderers
- Applying field mask too broadly can shift established iOS look
- Need to distinguish optics source visibility from actual render use

