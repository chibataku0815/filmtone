# T1 — HDR Source Visibility + Policy Notice

- Priority: P0
- Target: iOS v1.1
- Related plan: `../filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`

## Problem

iOS export already has Core Image HDR→SDR handling through `toneMapHDRtoSDR`, but the app does not expose that fact. Source probe has no color classification, UI has no HDR policy notice, and exported artifacts have no HDR policy record.

This is a transparency gap, not a total processing gap.

## Current Facts

- iOS video/image import can call `.toneMapHDRtoSDR`
- `SourceProbeService.swift` does not expose transfer / primaries / color space
- `SourceProbeDTO` has no `colorClass` or `hdrPreparationPolicy`
- Desktop derives `SourceColorClass` and `HdrPreparationPolicy`, then shows notice only for relevant policy reasons

## Implementation

1. Add iOS DTOs:
   - `SourceColorMetadataDTO`
   - `SourceColorClassDTO`
   - `HdrPreparationPolicyDTO`
   - `SourceVideoMetadataDTO`
2. Extend `SourceProbeService.swift`:
   - read `CMFormatDescriptionGetExtensions`
   - inspect color primaries, transfer function, YCbCr matrix / color space where available
   - classify `sdr-bt709`, `hdr-pq`, `hdr-hlg`, `wide-gamut-unknown`, `unknown`
3. Add iOS policy derivation:
   - SDR: `strategy = none`
   - HDR PQ/HLG: `strategy = core-image-tone-map-sdr`, `requiresFixtureValidation = true`
   - wide-gamut unknown: `strategy = defer-visible-warning`
4. Add SwiftUI notice:
   - non-blocking
   - no ffmpeg install CTA
   - text says iOS exports SDR and HDR dynamic range may be compressed
5. Include policy in sidecar through T2.

## Acceptance Criteria

- SDR BT.709 fixture shows no warning
- HLG fixture shows HDR notice
- PQ fixture shows HDR notice
- Wide-gamut unknown fixture shows caution notice
- `SourceProbeDTO` serializes with source color metadata
- Existing clients without new fields remain decodable

## Files

- `apps/capacitor-film-lab-ios/ios/App/App/SourceProbeService.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings`

## Tests

- Add probe fixtures for SDR, HLG, PQ, and wide-gamut unknown
- Add a snapshot state for HDR notice
- Verify no warning for standard SDR sample

## Risks

- AVFoundation color attachment names differ across codecs and OS versions
- Core Image tone-map output may not match Desktop future HDR mezzanine output
- Policy wording must avoid claiming lossless HDR handling

