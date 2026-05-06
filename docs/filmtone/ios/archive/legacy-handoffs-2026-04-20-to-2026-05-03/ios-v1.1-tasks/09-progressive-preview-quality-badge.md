# T9 — Progressive Preview Quality Badge

- Priority: P3
- Target: design backlog
- Related plan: `../filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`

## Problem

Desktop tells users whether they are looking at thumbnail/proxy/mezzanine quality. iOS has a mezzanine foundation, but preview/export currently prioritize original capture and do not expose a quality state.

## Current Facts

- `AssetPickerService` kicks off background mezzanine generation
- `MezzanineService` can create and cache mezzanine files
- `FilmtoneExportSession.resolvedVideoSourceURL()` intentionally returns original source
- Preview UI has loading state but no quality badge

## Proposed Scope

1. Decide whether iOS preview should ever display mezzanine/proxy instead of original
2. Add quality states only if preview can switch quality levels
3. Display compact badge:
   - Original
   - Preparing
   - Proxy
   - Full
4. Keep export behavior explicit:
   - original capture export
   - mezzanine reuse only if user chooses a speed lane later

## Acceptance Criteria

- Badge reflects actual displayed media, not background cache status
- Export button state is not blocked by unrelated background generation
- Existing standard preview remains unchanged when no progressive path is active

## Files

- `apps/capacitor-film-lab-ios/ios/App/App/MezzanineService.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePreviewView.swift`
- `apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts`
- `apps/desktop-film-lab-batch/src/renderer/QualityBadge.tsx`

## Tests

- Preview state transitions
- Background mezzanine does not incorrectly show lower-quality badge
- Snapshot for badge compact layout

## Risks

- Showing a badge for background work can mislead users
- Reusing mezzanine can introduce preview/export mismatch

