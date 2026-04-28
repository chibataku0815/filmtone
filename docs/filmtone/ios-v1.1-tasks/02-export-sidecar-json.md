# T2 — Export Sidecar JSON

- Priority: P0
- Target: iOS v1.1
- Related plan: `../filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`

## Problem

iOS exports only the media file. Desktop exports a metadata sidecar that preserves the grade, preset, source metadata, camera optics, HDR policy, and app version. Without an iOS sidecar, iPhone edits cannot round-trip cleanly into Desktop.

## Current Facts

- `FilmtoneExportSession.run()` returns the media output URI only
- `PhotoLibraryService.saveToPhotos()` saves media as a Photos asset
- `shareOutput()` currently shares a single file
- Arbitrary JSON cannot be assumed to live adjacent to a Photos asset

## Implementation

1. Define iOS sidecar payload:
   - schema name and version
   - app/platform version
   - source URI / filename / kind
   - source probe
   - source video metadata from T1/T4
   - camera optics
   - preset name/version
   - quick state
   - resolved params
   - LUT metadata without embedding huge LUT payload unless explicitly needed
   - output profile and result metrics
2. Add sidecar writer:
   - write JSON beside temporary export output in app container
   - return `sidecarUri` in `Phase0ExportResultDTO`
3. Update share flow:
   - share media + sidecar together
   - keep Save to Photos as media-only
4. Add Desktop compatibility path:
   - if exact Desktop schema is not possible, keep `schema = filmtone-ios-export-session-v1`
   - include enough fields for Desktop import fallback to reconstruct grade

## Acceptance Criteria

- Every successful export writes a JSON sidecar
- `Phase0ExportResultDTO` includes `sidecarUri`
- Share sheet includes both media and JSON
- Save to Photos still saves the media file only
- Desktop can parse the sidecar or clearly report unsupported optional fields
- Sidecar includes HDR policy when source is HDR

## Files

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/ShareSheetService.swift`
- `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts`

## Tests

- Unit test sidecar JSON encoding
- Contract fixture for minimal sidecar
- Share flow smoke test with two activity items
- Regression test that Photos save ignores sidecar and still succeeds

## Risks

- Sharing two files may behave differently across AirDrop, Files, and third-party targets
- LUT payload size can make sidecars too large if embedded naively
- Desktop import may need a separate parser if schema diverges

