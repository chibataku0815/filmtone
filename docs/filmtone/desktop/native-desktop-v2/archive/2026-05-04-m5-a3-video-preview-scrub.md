# M5-A.3 Video Preview Scrub

Date: 2026-05-04 JST
Milestone: M5
Classification: Tier 1 (deferred from M5-A.2 interrupt; resumed)
Status: In progress
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

## Why

After M5-A.2 the still preview shows the Stone / Urban Look live, but the
video preview is pinned to the midpoint frame — the Look's effect across
the timeline (skin / highlight / shadow distribution shifts) is invisible.
Scrubbing is the smallest UI addition that lets the user see how a Look
behaves on temporally varying material. It is the highest-value next
M5 slice on the user-facing product surface.

## Scope (本質)

- Video sources gain a scrub bar that picks the previewed frame time.
- Preview reuses the existing iOS-canonical grade path with the scrubbed
  frame instead of the midpoint.
- Look + Preset + Strength controls keep working at the new scrub time.
- Single in-flight frame request; latest scrub time wins.

## Out of scope (外殻)

- AVPlayerLayer / MTKView migration (Phase 3 backlog).
- Disk / memory frame cache across scrub (separate optimization lane).
- Timeline thumbnail strip / scrubber-thumb image.
- Keyboard shortcut nudge (±1 frame). Recorded as Follow-up.
- Still preview behavior — unchanged.
- Export paths (still + video) — unchanged.
- CLI surface — unchanged (scrub is preview-only).

## Stages

- [x] S1 — Loader extension. Added
  `FilmtoneVideoFramePreviewLoader.loadFrame(from:atSeconds:)` plus a
  helper `loadDurationSeconds(from:)`. `loadMidpointFrame` is now a
  thin wrapper that probes duration then delegates to `loadFrame`.
  Tolerance fallback (zero → 0.5 s) preserved.
- [x] S2 — State. Added `videoPreviewSeconds: Double?` and
  `videoDurationSeconds: Double?` to `EditorState`. `setSource` cancels
  any in-flight duration probe, drops stale scrub state, and starts a
  new probe for video sources. The probe seeds
  `videoPreviewSeconds = duration × 0.5` so first paint matches
  pre-M5-A.3 midpoint behavior. `EditorState` is now `@MainActor` (it
  was already main-actor in practice; required to satisfy Swift 6 strict
  concurrency on the new probe Task that mutates `self`).
- [x] S3 — Preview wire-up. `PreviewSurface` accepts
  `videoPreviewSeconds: Double?` and forwards it. Pre-probe (nil) falls
  back to `loadMidpointFrame` so the first paint is identical to the
  pre-M5-A.3 path. Existing Task cancellation coalesces rapid scrub
  updates.
- [x] S4 — Scrub UI. Added `VideoScrubBar` overlay pinned bottom-center
  in `RootWindowView`. Visible only when `state.sourceKind == .video`
  and `videoDurationSeconds > 0`. Slider 0…duration with monospaced
  `M:SS.SS / M:SS.SS` labels.
- [x] S5 — Build + CLI regression. `xcodebuild ... build` →
  `BUILD SUCCEEDED` (Swift 6 strict concurrency clean). CLI still smoke
  (Stone @ 1.0 on `09-skin-light.png`) hash =
  `436bfc812627f489d7680dededb8ed6af0bc3bcb7db6d9e3d26c8ea9d5f49931`,
  identical to the M5-A.2 archive record → preview-only changes did not
  perturb any export path. Visual scrub UX smoke (drag 0→100%, Look
  consistency across timeline, no flicker on rapid drags) is deferred
  to the user — same posture as M5-A.2 archive.
- [ ] S6 — Commit. One feat commit covering loader + state + UI + wiring.

## Stage granularity

- S1 ~15 min
- S2 ~15 min
- S3 ~10 min
- S4 ~25 min
- S5 ~15 min
- S6 ~5 min

Total ≈ 85 min, single sitting.

## Invariants

- Still preview path: zero behavioural change.
- Export paths (still + video): zero behavioural change.
- iOS-canonical grade pipeline + Look cube applied per scrubbed frame —
  no shortcuts on preview accuracy.
- Latest scrub time wins; in-flight tasks cancelled (existing Task
  cancellation pattern in `PreviewSurface` preserved).
- Default scrub time on first video open = `duration × 0.5` so opening a
  video and not touching the slider matches the pre-M5-A.3 midpoint
  preview frame.
- `AVAssetImageGenerator` tolerance: zero first, fall back to 0.5 s —
  same recovery pattern as the existing midpoint loader.

## Unexpected

(filled during implementation)

## Follow-up

- Reuse a single `AVURLAsset` + `AVAssetImageGenerator` across scrub
  events instead of constructing both per frame.
- Disk-backed frame cache so backward scrub does not re-decode.
- Timeline thumbnail strip (horizontal scrubber thumb cache).
- Keyboard shortcut: ←/→ for ±1 frame nudge.
- `AVPlayerLayer` / `MTKView` migration (Phase 3).

## Result

Implementation complete and committed (3b12805 on
`feature/native-desktop-plan`):

- Loader, state, preview, scrub UI all wired through.
- `xcodebuild ... build` → `BUILD SUCCEEDED` under Swift 6 strict
  concurrency. The only structural change required to satisfy strict
  concurrency was lifting `EditorState` to `@MainActor`, which matches
  how every existing call site was already treating it.
- CLI regression: Stone @ 1.0 on `09-skin-light.png` →
  `436bfc81…d5f49931`, byte-identical to the M5-A.2 archive record.
  Preview-only changes did not perturb any export path.
- Visual scrub UX smoke deferred to user (drag 0→100%, Look consistency
  across timeline, no flicker on rapid drags). Same posture as M5-A.2
  archive.

Archived 2026-05-04 to make room for the user-requested M5-B (Apple
Liquid Glass adoption) interrupt slice.
