# T4 — Source Video Metadata, FPS Trust, and Rotation QA

- Priority: P1
- Target: iOS v1.1
- Related plan: `../filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`

## Problem

iOS has enough AVFoundation access to expose source display, color, and timing metadata, but current DTOs only carry basic width/height/duration/codec/framerate. Rotation is applied in render/export but not represented as metadata, and FPS trust is not modeled.

## Current Facts

- `SourceProbeService.swift` applies `preferredTransform` to report display dimensions
- `FilmtoneExportSession.coreImageVideoTransform()` handles export orientation
- `AVAssetImageGenerator.appliesPreferredTrackTransform = true` handles poster preview orientation
- `estimatedVideoFrameRate()` uses request framerate or track nominal framerate
- No `display`, `color`, or `timing` nested metadata exists on iOS

## Implementation

1. Add `SourceVideoMetadataDTO`:
   - `display.rawWidth`
   - `display.rawHeight`
   - `display.displayWidth`
   - `display.displayHeight`
   - `display.rotationDeg`
   - `display.source`
   - `color`
   - `colorClass`
   - `hdrPreparationPolicy`
   - `timing`
2. Rotation metadata:
   - derive 0/90/180/270 when transform is recognizable
   - mark source as `preferred-transform`
   - keep unknown/null for non-standard transforms
3. FPS trust:
   - start with nominal vs estimated sample-duration trust
   - expose `sourceFrameRateTrusted` and `trustReason`
   - do not change frame iteration behavior until trust is verified
4. Sidecar:
   - include metadata in T2 payload

## Acceptance Criteria

- Portrait source records raw landscape dimensions and portrait display dimensions
- Existing portrait export remains correctly oriented
- Standard 30 fps clip is trusted
- VFR or ambiguous clip is untrusted with reason
- Metadata is included in sidecar

## Files

- `apps/capacitor-film-lab-ios/ios/App/App/SourceProbeService.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts`

## Tests

- Probe fixture for portrait video transform
- Probe fixture for SDR BT.709 color metadata
- Probe fixture for VFR or ambiguous FPS
- Export smoke test for portrait orientation

## Risks

- Exact sample timing inspection can be expensive for long clips
- Some iPhone clips may expose color attachments only at pixel-buffer decode time
- Rotation metadata and actual transform handling must not diverge

