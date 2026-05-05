# M5-K4 Review Fixes — Scrub Thumbnail Preview

Slice scoped to the 4 review findings on the K4 base implementation
(archived `archive/2026-05-05-m5-k4-scrub-thumbnail-preview.md`). All
follow-up work happens in this same worktree / branch
(`feature/native-desktop-m5-k4-scrub-thumbnails`).

## Milestone

M5-K4 Scrub Thumbnail Preview — quality follow-up before integration.

## Goal

Make K4 integration-ready by closing 4 specific review findings. No new
feature surface, no shortcut/wiring changes, no compare-flow changes.

## Edit targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneScrubThumbnailMath.swift`
  — add `clampToDuration(seconds:duration:)` math helper.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoScrubThumbnailProvider.swift`
  — track in-flight cache key; coalesce same-key requests (no
  cancel/restart); clamp request seconds to `0...durationSeconds`
  before quantize.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  — consume `ScrubBarCapsuleFrameKey` for the actual measured capsule
  width; switch `thumbnailCard` to `.scaledToFit()` over a neutral
  black backing so portrait footage isn't cropped to 16:9.
- `apps/filmtone-desktop-macos/Verify/main.swift` — add tests for the
  new clamp math.

## Read-only references

- `archive/2026-05-05-m5-k4-scrub-thumbnail-preview.md` — base K4 slice.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneGlassSlider.swift`
  — knob math the hover fraction must continue to agree with.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoSession.swift`
  — durationSeconds source on the provider.

## Checklist

- [ ] Add `FilmtoneScrubThumbnailMath.clampToDuration(seconds:duration:)`
  pure helper (Foundation+CG, mirrors existing math style).
- [ ] Provider: store `inFlightKey: FilmtoneScrubThumbnailCacheKey?`;
  coalesce same-key requests (no `cancelAllCGImageGeneration`); clear
  on completion / teardown / `updateInputs`.
- [ ] Provider: clamp `seconds` against `durationSeconds` before
  quantize.
- [ ] RootWindowView: consume `ScrubBarCapsuleFrameKey` via state +
  `.onPreferenceChange`; use measured capsule frame for the bar's
  outer-bound clamp in `thumbnailOffset`. Keep slider-frame for the
  cursor-X computation (knob math unchanged).
- [ ] RootWindowView: `thumbnailCard` uses `.scaledToFit()` inside a
  bounded card with `.background(Color.black)` so portrait footage
  letterboxes inside the fixed 170×96 frame.
- [ ] Add 4 Verify tests:
  - `clampToDuration` typical/at-zero-duration/non-finite/negative.
  - In-flight key dedup behavior is provider state — covered by
    xcodebuild compile + visual smoke; not added to Foundation-only
    Verify scope (intentional limit).
- [ ] `bash apps/filmtone-desktop-macos/Verify/run.sh` → all PASS
  (target: 73 prior + new ones).
- [ ] `bun run verify:macos` → BUILD SUCCEEDED.
- [ ] `git diff --check` → clean.
- [ ] Visual smoke (user-driven): hover near right edge / final frame,
  hover slowly within one 0.25s bucket, hover on portrait footage,
  hover on a narrow window.

## Verification (commands)

```bash
bash apps/filmtone-desktop-macos/Verify/run.sh
bun run verify:macos
git diff --check
open -n apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app
```

## Done conditions

- Provider: same-bucket hover never re-cancels in-flight generation;
  duration-edge hover never produces an out-of-range request.
- UI: thumbnail card respects the measured capsule width on narrow
  windows; portrait footage is letterboxed (not cropped) inside the
  card.
- Verify suite passes; xcodebuild Debug target succeeds.
- `git diff --check` clean.

## Stop conditions (N=3)

1. Two consecutive xcodebuild errors that aren't preprocessor / typo
   fixes (deeper SwiftUI / AVFoundation contract surprise).
2. Verify suite fails twice in a row after a math change is reverted.
3. The in-flight-key dedup change reveals a third invariant (e.g.
   `latestRequestSeconds` divergence) that needs design rather than a
   localized fix.

If any stop fires: archive a `paused/` note with the failing state and
hand back to user for direction.

## Out of scope

- All non-K4 work (M5-J visual handoff items, K1/K2/K3/K5 lanes).
- Compare flow / sidecar / export wiring.
- AVMutableVideoComposition deprecated synchronous-init (M5-I.3
  candidate, unrelated to this slice).
- Thumbnail timestamp overlay / DaVinci-style cursor indicator.
- VideoScrubBar refactor into its own file.
- Tuning `thumbnailLongEdge` / cache size — only adjust if smoke shows
  a real regression.

## Unexpected blockers

None.

## Follow-up

User-driven visual smoke remains open:

- Hover near the right edge of clips with non-multiple-of-0.25 durations
  (e.g. 12.34s) to confirm the last in-range bucket renders.
- Hover slowly inside a single 0.25s bucket and confirm the thumbnail
  appears once and stays put (no re-cancel/restart flicker).
- Open a portrait iPhone clip and confirm the card letterboxes the
  frame instead of cropping into 16:9.
- Resize the window narrow enough that the capsule shrinks below the
  600pt max content cap, hover near both edges, confirm the overlay
  stays inside the visible capsule.

## Completion (2026-05-05 JST)

- Verify: 77/77 PASS (base K4 73 + 4 new clamp/end-of-asset tests).
- `bun run verify:macos`: **BUILD SUCCEEDED**.
- `git diff --check`: clean.
- Debug app launched (PID 39371) for user visual smoke.
- All 4 review findings closed:
  - **P1** in-flight key dedup: `inFlightKey` tracks the bucket
    currently being generated; same-bucket continuous hover no longer
    cancels and restarts. Cleared on completion (success/cancel),
    teardown, and `updateInputs`.
  - **P2** duration clamp: `FilmtoneScrubThumbnailMath.clampToDuration`
    runs before quantize; far-right hover lands on the last in-range
    bucket and never escapes the asset.
  - **P2** measured capsule width: `ScrubBarCapsuleFrameKey` is now
    consumed; thumbnail X clamps against the actual capsule frame
    rather than the 600pt max-content constant. Slider-frame fallback
    only on the very first paint.
  - **P3** portrait scaledToFit: thumbnail card uses
    `ZStack { Color.black; Image(...).scaledToFit() }` inside the
    fixed 170×96 frame, letterboxing portrait footage.
- Files touched:
  - `Media/FilmtoneScrubThumbnailMath.swift` (+ `clampToDuration`)
  - `Media/FilmtoneVideoScrubThumbnailProvider.swift` (in-flight key,
    duration clamp before quantize, main-actor-clear on all exit
    paths)
  - `UI/RootWindowView.swift` (consume capsule frame key, scaledToFit
    card)
  - `Verify/main.swift` (+4 tests)
  - `docs/filmtone/desktop/native-desktop-v2/active.md` (this file)
