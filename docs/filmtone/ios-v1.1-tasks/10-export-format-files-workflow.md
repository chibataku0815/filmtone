# T10 — Export Format and Files Workflow

- Priority: P3
- Target: design backlog
- Related plan: `../filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`

## Problem

iOS output is currently H.264/MP4 fixed. Even still-image sources are exported as short MP4 videos. That may be acceptable for v1.0/v1.1, but it limits archive and Desktop round-trip workflows.

## Current Facts

- `FilmtonePhase0Generated.outputProfile.container = "mp4"`
- `FilmtoneExportSession.makeWriter()` creates `.mp4`
- `exportStillImage()` renders a 3 second video
- Preview JPEGs are temporary preview artifacts, not final still exports
- Desktop image batch supports JPEG/PNG, while Desktop video UI currently names output `-graded.mp4`

## Proposed Scope

1. Separate media export type from source kind:
   - image source to PNG/JPEG still
   - image source to 3 second MP4
   - video source to MP4
2. Add Files-first flow for round-trip:
   - media + sidecar
   - optional zip package if share targets handle multiple files poorly
3. Keep Photos save simple:
   - save only selected media output
4. Defer MOV/ProRes until codec strategy is explicit

## Acceptance Criteria

- User can export a still image as PNG or JPEG
- Sidecar is available for Files/AirDrop workflow
- Photos save behavior remains predictable
- Export result records media kind and container

## Files

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/ShareSheetService.swift`
- `apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts`

## Tests

- Still image PNG/JPEG export
- Video MP4 export remains unchanged
- Share media + sidecar package
- Photos save for image and video outputs

## Risks

- More choices can complicate the mobile UI
- MOV/ProRes expectations can expand scope quickly
- Some share targets handle multiple files inconsistently

