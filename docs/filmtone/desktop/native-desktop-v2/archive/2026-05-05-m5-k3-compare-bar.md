# Archive — M5-K3 Draggable Compare Bar

Date completed: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-k3-compare-bar`
Branch: `feature/native-desktop-m5-k3-compare-bar`
Base: `0b79861f`

## Milestone

M5-K3 — Native Editing UI follow-up. Replaced the M5-J.2 fixed 50:50 compare
MVP with a draggable before/after split bar. Compare stays preview-only.

## Goal

Ship a draggable before/after split overlay so the user can move the
comparison line horizontally across the loaded preview. The fraction is
the single source of truth, threaded through still and video preview
paths and clamped at the boundary. The drag handle stays inside the
media's aspect-fit rect (not the full window) so letterboxed /
pillarboxed sources do not invite drags into the matte.

## What Changed

### New
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtoneCompareSplitMath.swift`
  — pure-Foundation enum with `default = 0.5`, inclusive `range = 0...1`,
  and a NaN-safe `clamp(_:)`. Single source of truth shared by
  `EditorState`, `FilmtoneCompareCompose`, and the AVPlayer composition
  handler. Registered in the Xcode project (Domain group + Sources build
  phase) and in `Verify/run.sh` so the boundary behavior is pinned without
  booting CoreImage.

### State
- `EditorState.compareSplitFraction: Double = FilmtoneCompareSplitMath.default`
  — clamped via `didSet` to defend against bad bindings. Threaded through
  `currentVideoRenderInputs(_:)`.

### Render plumbing
- `FilmtoneDesktopVideoRenderInputs` carries `compareSplitFraction`.
- `FilmtoneDesktopVideoComposition` snapshots the clamped fraction at
  build time and passes it to `FilmtoneCompareCompose.makeSplit(splitAt:)`
  (replacing the hard-coded `0.5`).
- `FilmtoneDesktopVideoSession.displayAspectRatio` exposes the oriented
  display aspect for the drag-handle overlay so the handle constrains
  itself to the AVPlayer's letterboxed rect.

### Still preview + UI
- `PreviewSurface.renderFrames(...)` now returns
  `RenderedFrames(graded: NSImage, sourceForCompare: NSImage?)`. The raw
  companion is rasterized only when compare is on, so toggling V is the
  only re-grade-adjacent moment that touches CoreImage.
- New `StillCompareLayer` lays the graded NSImage on the full preview
  area, then masks the raw companion frame on top of the left half via a
  SwiftUI `.mask(alignment: .leading)` rectangle sized to
  `splitFraction × paneWidth`. Drag is a pure SwiftUI invalidation — no
  pipeline rerun per drag tick.
- New `CompareSplitOverlay` (private to `PreviewSurface.swift`) hosts the
  vertical split line + a Liquid Glass grip. The handle uses an
  `aspectFitRect(...)` helper to constrain drag-x to the media's own
  rect, not the full preview region, and pushes `NSCursor.resizeLeftRight`
  on hover so the affordance is obvious. Drag is bound to a 40 pt-wide
  invisible hit zone that spans the full media height — the visible
  line + grip are `allowsHitTesting(false)` — so the user can grab
  anywhere along the bar (top / middle / bottom), not just the 36 pt
  center grip. (P2 fix from review.)
- `PreviewRenderKey` intentionally omits `compareSplitFraction` so the
  still task does not re-fire mid-drag.
- `RootWindowView.VideoCompositionRefreshKey` adds `compareSplitFraction`
  so video sources rebuild the AVPlayer composition when the user drags
  (debounced 100 ms by `FilmtoneDesktopVideoSession.updateInputs(_:)`).

### Verify
- 5 new tests pin the clamp helper boundary (default, range, identity,
  out-of-range, non-finite). Verify run is now 70/70.

## Preserved Behavior

- `Command-O` opens media (toolbar action unchanged).
- `Command-\\` toggles the editing sidebar.
- `V` toggles compare; default fraction on first toggle is `0.5`; the
  user-set fraction persists across toggles within a session.
- `Space` toggles video playback.
- 1×/2×/3× playback rate menu unchanged.
- Loaded media preview matte stays glass-free for color judgment.
- Compare stays preview-only — `FilmtoneStillExporter`,
  `FilmtoneVideoExporter`, and `FilmtoneSidecarWriter` were not touched.
  Compare math branches only inside the still render pass and the video
  composition handler.

## Verification

```text
bash apps/filmtone-desktop-macos/Verify/run.sh
=> 70/70 passed, 0 failed (was 65; +5 FilmtoneCompareSplitMath tests)

bun run verify:macos
=> ** BUILD SUCCEEDED ** (xcodebuild Debug, FilmtoneDesktop scheme)

git diff --check
=> clean

pkill -x Filmtone 2>/dev/null || true
open -n .../apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app
=> Debug app launched. Visual smoke is the user's gate.
```

## Remaining Product Risks

- Video drag through compare composes through `updateInputs(_:)` which
  has a 100 ms debounce. During fast drag on video, the split visibly
  steps at ~10 Hz instead of true continuous tracking. Acceptable for
  v1.4 since the feedback the user sees on the AVPlayer composition is
  the same loop every other slider rides.
- Still drag is fluid because the split is now a SwiftUI mask, but the
  raw companion `sourceForCompare` is rasterized at the full graded
  canvas extent. For very large stills (e.g. 60 MP) the toggle-on render
  cost is ~doubled vs the M5-J.2 single-pass path. The toggle itself is
  rare; drag is unaffected.
- `aspectFitRect(...)` matches `.scaledToFit()` for stills and matches
  AVPlayer's default content gravity for the video view. If a future
  change to `FilmtoneDesktopPlayerView` switches gravity to fill / aspect
  fill, the handle will drift from the actual content rect — call out
  in the player view if that's ever changed.
- Compare drag fires `VideoCompositionRefreshKey` which also rebuilds on
  preset / strength / quick / overrides edits. This is intentional and
  matches the M5-I.2 plumbing; no regression observed for non-compare
  edits during this slice.

## Dirty Files Intentionally Left Untouched

The parent worktree at
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
already had:

- `M docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `?? archive/2026-05-04-native-desktop-v2-m4b-m5c4-handoff.md`
- `?? archive/2026-05-05-native-desktop-v2-planning-doc-cleanup.md`
- `?? archive/2026-05-05-native-desktop-v2-post-j-visual-handoff.md`

This slice ran in a fresh worktree branched from `0b79861f`, so none of
those files were touched. The post-J visual handoff stash backups
(`stash@{0}`–`{3}` and the
`backup/native-desktop-m5-j2-compare-pre-delete-20260505` tag) were
similarly left in place.

## Review Follow-ups

- **P2 (fixed in this slice)** — drag was bound to the 36 pt grip only;
  reviewer flagged that grabs near the top / bottom of the line went dead.
  Resolved by attaching the `DragGesture` + `.onHover` to a 40 pt-wide
  invisible hit zone spanning the full media height; visible line + grip
  are now purely visual (`allowsHitTesting(false)`).
- **P3 (deferred, not v1.4 blocking)** — still fallback renders can have
  `sourceForCompare == nil`. The overlay still appears whenever
  `compareEnabled && mediaAspectRatio != nil`, so on a fallback still the
  user sees a draggable handle with no Before reveal. Not regressing the
  M5-J.2 behavior. Fix path: gate the still overlay on
  `frames.sourceForCompare != nil`, or surface "compare unavailable"
  on the toggle.

## Out Of Scope (deferred)

- Vertical (top/bottom) compare orientation.
- Side-by-side (non-overlapping) compare layout.
- Saving / restoring compare fraction across launches.
- Touchpad two-finger swipe for compare.
- M5-K1 toolbar flicker / opening readability.
- M5-K2 Look + Strength regrouping.
- M5-K4 scrub thumbnail preview.
