# M5-K4 Integration

Date: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

## Scope

Integrated the completed M5-K4 scrub thumbnail preview output from:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-k4-scrub-thumbnails
```

This integration lands on top of the parent K1/K2/K3 integration diff.

## What Changed

- Added graded hover/drag thumbnails above the video scrub bar.
- Added `FilmtoneScrubThumbnailMath` for Verify-covered quantize / clamp math.
- Added `FilmtoneVideoScrubThumbnailProvider` for AVAssetImageGenerator-backed,
  cached, graded thumbnails.
- Added thumbnail-sized video composition support beside the live preview
  composition.
- Wired `FilmtoneDesktopVideoSession` to lazily own and refresh the thumbnail
  provider with current render inputs.
- Updated `RootWindowView.VideoScrubBar` to measure slider/capsule geometry,
  show a clamped overlay, preserve drag-to-pause, and keep portrait thumbnails
  letterboxed.
- Registered the new Media files in the Xcode project with IDs that do not
  collide with K3's `FilmtoneCompareSplitMath.swift`.
- Added K4 scrub thumbnail math tests to the Verify harness.

## Integration Notes

- K4 `project.pbxproj` patch could not apply directly because K3 had already
  claimed the next `FT...A3E/B3D` IDs for `FilmtoneCompareSplitMath.swift`.
  The parent integration keeps K3 IDs and registers K4 files as `A3F/A40` and
  `B3E/B3F`.
- Existing parent dirty docs and the unrelated untracked `active.md` were left
  untouched.

## Follow-up Visual Fix

- After visual smoke, hover thumbnails only appeared briefly during click/drag.
  `VideoScrubBar` had attached continuous hover tracking to a measuring
  `Color.clear` background behind the slider, which did not reliably become the
  AppKit hit-test surface.
- A second hover pass showed the slider shaking because SwiftUI hover tracking
  and the slider's own hover enlargement churned together. Hover tracking now
  uses an AppKit `NSTrackingArea` layer that does not take hit testing, and the
  video scrub slider keeps its knob size stable on hover.
- A final hover pass showed the whole scrub bar moving upward because the
  thumbnail was a `ZStack` sibling and participated in layout. The thumbnail is
  now an overlay on the capsule, so it renders above the bar without changing
  the bar's measured height.

## Verification

- `bash apps/filmtone-desktop-macos/Verify/run.sh`:
  86/86 passed, 0 failed.
- `bun run verify:macos`: xcodebuild Debug build succeeded.
- `git diff --check`: clean.
- Debug app launch smoke:
  `pkill -x Filmtone 2>/dev/null || true` then
  `open -n apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app`
  exited successfully.
- Follow-up visual fix verification:
  `bash apps/filmtone-desktop-macos/Verify/run.sh` stayed 86/86;
  `bun run verify:macos` succeeded; `git diff --check` stayed clean; the Debug
  app was relaunched for another visual smoke pass.

## Remaining Product Risks

- Visual smoke is user-gated: confirm thumbnail hover/drag over start, middle,
  right edge, portrait clips, and narrow windows.
- The thumbnail provider uses a separate graded AVAssetImageGenerator path; if
  user footage shows GPU contention during playback, tune thumbnail long edge or
  cache policy before changing to source-only thumbnails.
