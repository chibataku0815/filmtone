# Active — M5-K4 review fix #2: quantize-within-duration

Date: 2026-05-05
Worktree: `filmtone-native-desktop-m5-k4-scrub-thumbnails`
Milestone: M5-K4 (Scrub Thumbnail Preview) — follow-up to 2026-05-05 review fixes archive.

## Context

Reviewer found that the prior P2 fix (`clampToDuration` then `quantize`) still
lets bucket rounding push the request past `duration`. Concrete repro:

- duration = 12.38s, far-right hover
- `clampToDuration(12.38, 12.38)` → 12.38
- `quantize(12.38)` → 12.50 (round-half-to-even pushes 49.52 → 50)
- 12.50 > 12.38 → AVAssetImageGenerator silently rejects the request,
  right edge of scrub bar produces no thumbnail.

The added Verify test used 12.34s, which rounds *down* to 12.25 and so
never exercised the round-up overshoot.

## Goal

`quantize` cannot return a value > `duration`. When the rounded bucket
overshoots, fall back to the last bucket ≤ duration.

## Edit targets (this slice only)

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneScrubThumbnailMath.swift`
  — add `quantizeWithinDuration(seconds:duration:bucket:)`.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoScrubThumbnailProvider.swift`
  — replace the `clampToDuration` + `quantize` chain at the request entry
  point with a single `quantizeWithinDuration` call.
- `apps/filmtone-desktop-macos/Verify/main.swift` — add tests covering the
  round-up overshoot (12.38s, 12.88s) and a sanity test that exact-on-bucket
  durations still resolve to that bucket.

## Out of scope

- Anything beyond this single semantic fix. P1/P2-width/P3 are landed.
- No timestamp overlay, no thumbnail size tuning, no AVMutableVideoComposition
  warning cleanup.

## Verification

- `bash apps/filmtone-desktop-macos/Verify/run.sh` → expect 80/80 (was 77).
- `bun run verify:macos` → BUILD SUCCEEDED.
- `git diff --check` → clean.

## Done conditions

- New helper covered by tests for: round-up overshoot (12.38, 12.88),
  exact-bucket boundary (12.50), zero/non-finite duration, unchanged
  mid-range pass-through.
- Provider call site uses `quantizeWithinDuration` directly.
- Strategy completion log gets a 1–3 line entry on top of the prior
  review-fixes entry.

## Stop conditions (N=3)

- Verify regresses (any prior test fails): stop, do not push.
- xcodebuild fails for any reason other than the known SwiftPM index-only
  diagnostic noise: stop.
- Helper signature drifts beyond the math layer (would require touching
  ScrubBar UI logic): stop, escalate.
