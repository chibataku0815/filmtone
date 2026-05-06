# T5 — Camera Optics UI Label

- Priority: P1
- Target: iOS v1.1
- Related plan: `../filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`

## Problem

iOS probes camera optics but does not show them. Users cannot tell whether the app used real metadata or assumed optics.

## Current Facts

- `SourceProbeDTO.cameraOptics` includes source, focal pixel fields, FOV, lens, make, and model
- Preview meta label currently shows dimensions and duration only
- Export panel source info currently shows dimensions, duration, and codec
- Desktop has `formatCameraOpticsForProbeLabel()`

## Implementation

1. Add an iOS formatter:
   - camera make + model
   - lens model
   - `HFOV xx.xdeg`
   - source: `metadata` or `assumed`
2. Preview:
   - append short optics segment to `previewMetaLabel`
   - keep text compact enough for small screens
3. Export panel:
   - add optics row under source info
   - avoid showing empty values
4. Localization:
   - source labels for metadata / assumed
   - accessibility label

## Acceptance Criteria

- Metadata optics source displays as metadata
- Assumed optics source displays as assumed
- Missing camera/lens names do not produce awkward separators
- Label fits in compact portrait layout
- Snapshot tests cover at least assumed optics

## Files

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings`
- `apps/desktop-film-lab-batch/src/renderer/video-probe-label.ts`

## Tests

- Formatter unit tests
- Snapshot for preview meta label
- Snapshot for export source info

## Risks

- Long lens model strings can overflow
- Metadata may be sparse; source label must still be useful

