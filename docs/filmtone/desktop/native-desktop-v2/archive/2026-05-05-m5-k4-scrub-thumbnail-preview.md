# M5-K4 Scrub Thumbnail Preview

Date opened: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-k4-scrub-thumbnails`
Branch: `feature/native-desktop-m5-k4-scrub-thumbnails`
Base commit: `0b79861f` (parent `feature/native-desktop-plan` HEAD at handoff).

## Milestone

M5 Native Editing UI (slice K4) — post-J visual handoff item #3.

## Goal

Add a hover/drag thumbnail preview above the video scrub bar so the user can
see the frame at any timestamp before committing a seek. Thumbnails default to
the **current graded edit state** so they match what the preview will show on
seek. Playback must not stutter when the thumbnail is being requested or
served.

## Tradeoff Statement (graded vs. source-only thumbnails)

Default chosen: **graded** thumbnails via `AVAssetImageGenerator` configured
with an `AVMutableVideoComposition.applyingCIFiltersWithHandler`-based
composition that runs the same `FilmtoneSourceInputTransform` +
`FilmtoneGradePipeline` as the live preview. This is feasible because:

- AVAssetImageGenerator runs on its own private dispatch queue, isolated from
  the main thread and from AVPlayer's render path.
- A dedicated thumbnail composition uses a small render canvas (240px long
  edge), so per-frame grade cost (halation pyramid, grain) is far below the
  live 1280-edge preview cost.
- Stale requests are cancelled via `cancelAllCGImageGeneration()` so rapid
  hover does not pile up GPU work.
- A bounded cache keyed by quantized seconds + edit-state signature absorbs
  retries on the same bucket.

We are NOT falling back to source-only thumbnails. If user smoke shows real
playback stutter that traces to thumbnail GPU contention, the follow-up is a
size-knob (e.g. drop from 240px to 160px), not a switch to source-only — the
product expectation is that the thumbnail represents the current Look.

## Edit Targets

```text
apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoScrubThumbnailProvider.swift  (new — AV-bound provider)
apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneScrubThumbnailMath.swift           (new — Foundation-only helpers, Verify-friendly)
apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoComposition.swift      (add small thumbnail-sized composition factory)
apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoSession.swift          (own + refresh thumbnail provider on input changes / teardown)
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift                          (refactor in-file VideoScrubBar to consume hover/drag thumbnail overlay; or extract — see Out-of-scope)
apps/filmtone-desktop-macos/Verify/main.swift                                                (new test group: quantize / cursor clamp / cache key signature)
apps/filmtone-desktop-macos/Verify/run.sh                                                    (add FilmtoneScrubThumbnailMath.swift to SOURCES)
apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj                        (register 2 new Media files)
```

## Read-only References

```text
apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoSession.swift  (current session ownership / inputs lifecycle)
apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoComposition.swift  (factory + previewLongEdge constant)
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneGlassControls.swift            (FilmtoneGlassSlider drag callback shape)
apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift                   (isScrubbing / videoPreviewSeconds / videoSession)
docs/filmtone/desktop/native-desktop-v2/strategy.md                                   (M5-J integrated baseline + Verify 65/65)
docs/filmtone/desktop/native-desktop-v2/archive/2026-05-05-native-desktop-v2-post-j-visual-handoff.md  (issue #3)
```

## Checklist

- [ ] Add `FilmtoneScrubThumbnailMath.swift` with pure helpers: `quantize(seconds:bucket:)`, `clampHoverFraction(x:width:knob:)`, `clampThumbnailCenterX(cursorX:thumbnailWidth:scrubBarMinX:scrubBarMaxX:)`, `ThumbnailCacheKey` (Hashable: quantized seconds × inputs signature).
- [ ] Add `FilmtoneVideoScrubThumbnailProvider` (`@MainActor final class`) that owns one `AVAssetImageGenerator` per asset, builds a thumbnail-sized graded `AVVideoComposition`, exposes `requestThumbnail(atSeconds:completion:)`, holds a small LRU cache, cancels in-flight on supersede, and bumps an inputs signature on `updateInputs(_:)`.
- [ ] Add `FilmtoneDesktopVideoComposition.makeThumbnailComposition(...)` that mirrors `make(...)` but with a small (240) long-edge render size; reuse the same handler so the visual stays consistent with the live preview.
- [ ] Wire the provider into `FilmtoneDesktopVideoSession`: build it from `prepare(...)`, refresh inputs whenever the live composition refreshes, tear it down with the session.
- [ ] Replace the inline `VideoScrubBar` Slider area with a wrapper that adds: hover tracking on the slider's local coordinate space, and a thumbnail overlay rendered above the scrub bar capsule whenever hover OR drag is active. Cursor follows X but is clamped so the thumbnail never escapes the scrub bar's horizontal bounds.
- [ ] Preserve existing `Space` toggle, `⌘O` open, `⌘\` sidebar toggle, `V` compare, 1×/2×/3× rate menu, drag-to-scrub auto-pause behavior.
- [ ] Register the 2 new Media files in `FilmtoneDesktop.xcodeproj/project.pbxproj` (PBXBuildFile + PBXFileReference + Media group + Sources phase).
- [ ] Add `FilmtoneScrubThumbnailMath.swift` to `Verify/run.sh` SOURCES.
- [ ] Add Verify tests: quantize bucket math, clamp helpers, cache key signature stability.

## Verification

```bash
bash apps/filmtone-desktop-macos/Verify/run.sh
bun run verify:macos
git diff --check
pkill -x Filmtone 2>/dev/null || true
open -n /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-k4-scrub-thumbnails/apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app
```

## Done Conditions

- Hovering anywhere over the scrub bar slider region shows a thumbnail at the
  hovered timestamp without making playback stutter.
- Dragging the scrub bar keeps the thumbnail visible and tracks the drag
  timestamp; auto-pause behavior on drag is preserved.
- The thumbnail's horizontal position follows the cursor but is clamped so it
  never escapes the scrub bar's window-relative bounds.
- Thumbnail content reflects the current edit state (Look / preset / strength
  / Quick / overrides / source profile), via the same composition handler as
  the live preview.
- Repeated hover at the same quantized timestamp serves from cache (no GPU
  re-render).
- Existing controls keep working: ⌘O, ⌘\, V, Space, 1×/2×/3×.
- Compare remains preview-only and unaffected by this slice.
- Verify run is green: 65 → 65+N PASS (N = new test count).
- `bun run verify:macos` succeeds (xcodebuild Debug).
- `git diff --check` is clean.

## Stop Conditions

- All Done Conditions met → archive.
- Unexpected blocker (AVAssetImageGenerator handler-based composition fails
  on macOS 26 image extraction, or the existing live AVPlayer composition
  cannot be safely shared with the generator) → stop, document, hand back.
- 3 consecutive verification failures on the same run target (Verify or
  xcodebuild) without a tractable diagnostic → stop, document, hand back.

## Out of Scope

- Issues #1, #2, #4, #5 from the post-J handoff (toolbar flicker, draggable
  compare, Look/strength grouping, opening readability). Each is a separate
  K-slice.
- `AVVideoComposition.videoComposition(with:applyingCIFiltersWithHandler:)`
  async migration (M5-I.3 candidate).
- Frame-accurate keyframe vs. nearest-keyframe seek tuning beyond the
  `requestedTimeToleranceBefore/After` defaults appropriate for thumbnails.
- Showing a timestamp label inside the thumbnail. The scrub bar already shows
  `videoPreviewSeconds`. If user smoke wants a label inside the thumbnail it
  is a follow-up; not adding chrome speculatively.
- Extracting `VideoScrubBar` from `RootWindowView.swift` into its own file.
  Only extract if the in-file growth materially trips the SwiftUI body
  type-checker. If we hit that, extract and document; otherwise keep the
  refactor surface narrow.

## Unexpected Blockers

None encountered.

## Verification Results (2026-05-05 JST)

```text
bash apps/filmtone-desktop-macos/Verify/run.sh
=> 73/73 passed, 0 failed (was 65/65; +8 new tests for FilmtoneScrubThumbnailMath
   quantize default + custom bucket + non-finite/negative clamp, clampHoverFraction
   [0,1] clamp + FilmtoneGlassSlider knob-math agreement, clampThumbnailCenterX
   inside-bar clamp + bar-center fallback, FilmtoneScrubThumbnailCacheKey
   signature-aware Hashable).

bun run verify:macos
=> ** BUILD SUCCEEDED ** (xcodebuild Debug, Swift 6 strict concurrency clean).

git diff --check
=> clean.

pkill -x Filmtone 2>/dev/null || true
open -n .../apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app
=> Debug app launched for user visual smoke (PID confirmed running).
```

## Done Status

All Done Conditions satisfied at the verification gate. Visual smoke remains
user-driven (hover/drag thumbnail UX cannot be asserted by the harness).

Implementation summary:

- New `Media/FilmtoneScrubThumbnailMath.swift` (Foundation + CoreGraphics) —
  pure helpers: `quantize(seconds:bucket:)`, `clampHoverFraction(x:width:knob:)`,
  `clampThumbnailCenterX(...)`, and the `FilmtoneScrubThumbnailCacheKey` Hashable.
- New `Media/FilmtoneVideoScrubThumbnailProvider.swift` (`@MainActor final
  class`) — owns one `AVAssetImageGenerator` per asset, builds a thumbnail-sized
  `AVMutableVideoComposition` via the same `applyingCIFiltersWithHandler` factory
  as the live preview, exposes `requestThumbnail(atSeconds:completion:)` with
  cancel-on-supersede + bounded LRU cache. `updateInputs(_:)` bumps an inputs
  signature so a render-input change auto-invalidates cache entries.
- `Media/FilmtoneDesktopVideoComposition.swift` — extracted shared
  `makeComposition(...)` private factory; new public `makeThumbnailComposition`
  + `thumbnailRenderSize` + `thumbnailLongEdge = 240`.
- `Media/FilmtoneDesktopVideoSession.swift` — lazily constructs a
  `FilmtoneVideoScrubThumbnailProvider` on first access, refreshes it in
  lockstep with the live composition rebuild, tears it down with the session.
- `UI/RootWindowView.swift` — restructured the in-file `VideoScrubBar` into
  a ZStack that owns both the glass-clipped capsule chrome and the
  unclipped thumbnail overlay. Hover via `.onContinuousHover` on the slider's
  local coordinate space; drag via the existing `state.isScrubbing` flag.
  Thumbnail X is clamped through `clampThumbnailCenterX` so it never escapes
  the scrub bar's bounds. Existing ⌘O / ⌘\ / V / Space / 1×/2×/3× kept.
- `apps/filmtone-desktop-macos/Verify/run.sh` — added
  `Media/FilmtoneScrubThumbnailMath.swift` to SOURCES.
- `apps/filmtone-desktop-macos/Verify/main.swift` — 8 new tests pinning the
  math invariants the AV-bound provider relies on.
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj` —
  registered both new Media files (PBXBuildFile + PBXFileReference + Media
  group + Sources phase).
