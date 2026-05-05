# M5-I.2 AVPlayer Preview Route (iOS-canonical port)

Date opened: 2026-05-05 JST
Branch: `feature/native-desktop-m5-i2-avplayer-preview`
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-i2-avplayer-preview/`
Milestone: M5 Native Editing UI — playback hardening (promoted from
M5-D.2.1 v1.5 lane to current blocker after user reported playback
remains choppy on the M5-D.2 timer-driven MVP).

## Goal

Replace the timer-driven `videoPreviewSeconds` ticker + per-tick
`AVURLAsset` + `AVAssetImageGenerator` random-seek path with the
iOS-canonical preview architecture: a single `AVPlayer` driving an
`AVPlayerItem` whose `videoComposition` runs Filmtone's grade pipeline
through `AVMutableVideoComposition.applyingCIFiltersWithHandler`.

Acceptance after landing: video preview runs smoothly enough for user
visual smoke on normal 1080p / 4K iPhone footage; 1×/2×/3× rate works;
audio plays when the source carries it; scrub seeks the player rather
than triggering random-seek frame extraction during playback; still
preview and export paths do not regress.

## Why this slice (本質)

The M5-D.2 spike (`archive/2026-05-05-m5-d2-avplayer-playback-spike.md`)
identified seven root causes of stutter (C1–C7). C1/C2/C4 in
particular — per-tick `AVURLAsset.loadTracks` + per-tick
`AVAssetImageGenerator.image(at:)` random-seek + full-resolution grade
pipeline including 6-mip halation pyramid — make 24fps playback
infeasible on real-world footage. Audio is also entirely missing
because the timer path never instantiates an AVPlayer.

The Primary Route (this slice) solves all seven simultaneously by
adopting the iOS preview pipeline shape: AVFoundation's private dispatch
queue calls back into our grade once per composed frame, on a render
size capped at 1280 long-edge, with sequential decode, native rate
control, and audio routed through the player.

## Architectural choice (本質優先)

**Selected: AVPlayer + AVMutableVideoComposition primary route**, per
spike §"推奨案 (Primary)". Alternative routes (Alt B AVAssetReader+MTKView,
Alt C raw decode + graded-on-pause, Alt D two-tier pipeline) are rejected
in the spike for documented reasons.

Implementation principles:

- Reuse the existing Desktop `FilmtoneGradePipeline.apply` from inside
  the composition handler. Do **not** re-port grade math from iOS.
- Reuse `FilmtoneSourceInputTransform.apply` for source-profile
  normalization on the per-frame `request.sourceImage` before grade.
- Reuse `FilmtoneCIContext.shared` as the render context passed to
  `request.finish(with:context:)`.
- Cap `composition.renderSize` at 1280 long-edge to match iOS preview
  cost envelope (4K → 1.0Mpx for the grade pipeline).
- Run the composition handler on AVFoundation's private dispatch queue
  (no @MainActor). The handler reads a `Sendable` snapshot of params
  captured at composition build time so each rebuild is closed over a
  fixed snapshot (avoids data races on EditorState).
- Refresh the composition (rebuild + reassign + re-seek with
  `seekingWaitsForVideoCompositionRendering = true`) on preset /
  strength / look / quick / overrides / sourceProfile changes. Debounce
  rapid slider drags at 100ms.

## Edit Targets

New files:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoSession.swift`
  — `@MainActor` class. Owns a single `AVPlayer`, a graded
  `AVPlayerItem`, the periodic time observer (drives
  `EditorState.videoPreviewSeconds`), and the composition refresh +
  rate / seek / play / pause API. Holds an immutable
  `RenderInputs` snapshot type for handing into the composition.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoComposition.swift`
  — Pure factory. Takes `(asset, videoTrack, renderInputs)` and
  returns an `AVMutableVideoComposition` whose handler runs source
  transform + grade pipeline. Renders into 1280 long-edge size derived
  from track's `naturalSize` × `preferredTransform` (handles vertical
  iPhone footage).
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneDesktopPlayerView.swift`
  — `NSViewRepresentable` wrapping `AVPlayerView`. `controlsStyle =
  .none` (custom Liquid Glass scrub bar drives playback);
  `videoGravity = .resizeAspect` (preserves source aspect, lets
  `Color.black` backdrop in `PreviewSurface` provide the letterbox).

Modified files:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
  — Drop `playbackTask` + the timer-based `startPlayback` /
  `stopPlayback` body. Add `videoSession: FilmtoneDesktopVideoSession?`
  + `playbackRate: Double = 1.0`. New `togglePlayback()` /
  `seek(toSeconds:)` / `setPlaybackRate(_:)` delegate to the session.
  `setSource(_:)` tears down the previous session and creates a new one
  for video sources. Composition refresh is fired from a unified
  `refreshVideoCompositionIfNeeded()` whenever preset / strength / look
  / quick / overrides / sourceProfile change.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
  — Add a `.video` branch that renders `FilmtoneDesktopPlayerView`
  when the session has a player. Keep the still branch unchanged
  (`Image(nsImage:)` + identity gating). Probe `colorClass` is still
  written to `state.probedSourceColorClass` after the session probe so
  the source-cap gate continues to fire.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  — `VideoScrubBar` now drives `state.videoSession?.player.seek(to:)`
  on slider edit, `state.togglePlayback()` for play/pause, and gains a
  1×/2×/3× `Menu` button. `onChange(of:)` hooks fire
  `state.refreshVideoCompositionIfNeeded()` for params/look/profile so
  the graded composition re-renders when the user edits.
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
  — Register the 3 new files. Build IDs: A37
  (FilmtoneDesktopVideoSession), A38 (FilmtoneDesktopVideoComposition),
  A39 (FilmtoneDesktopPlayerView). File refs: B36 / B37 / B38. Media
  group adds B36 + B37; UI group adds B38; Sources phase adds A37 +
  A38 + A39.

## Read-only References

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoFramePreview.swift`
  — Legacy `AVAssetImageGenerator` loader stays for still preview's
  `loadFrame(from:atSeconds:)` / `loadDurationSeconds(from:)`. Not
  removed — `loadDurationSeconds` is also called from
  `EditorState.startVideoDurationProbe` (stable contract).
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneSourceProber.swift`
  — `probeVideo` is reused to populate `colorClass` / `cameraOptics`
  for the source-cap gate. The session gets its own probe call so the
  composition handler can capture optics once at build time rather than
  re-probing per frame.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
  — Reused inside the composition handler. No grade math edits.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSourceInputTransform.swift`
  — Reused for the per-frame source profile transform.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCIContext.shared`
  — Passed as `request.finish(with:context:)` argument.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
  +228..+410 — iOS canonical lifecycle pattern (reference only).
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
  +3787..+3827 — iOS canonical
  `applyingCIFiltersWithHandler` shape (reference only).

## Checklist

- [x] active.md created (this file)
- [x] FilmtoneDesktopVideoSession.swift added (player ownership, periodic
  time observer, composition refresh, play/pause/seek/rate API)
- [x] FilmtoneDesktopVideoComposition.swift added (factory builds
  AVMutableVideoComposition with applyingCIFiltersWithHandler running
  FilmtoneSourceInputTransform + FilmtoneGradePipeline at 1280-long-edge)
- [x] FilmtoneDesktopPlayerView.swift added (NSViewRepresentable wrapper
  for AVPlayerView, controlsStyle .none, videoGravity .resizeAspect)
- [x] EditorState.swift rewired (playbackTask removed; videoSession +
  playbackRate added; togglePlayback / seek / setPlaybackRate delegate;
  refreshVideoCompositionIfNeeded for param changes; setSource teardown)
- [x] PreviewSurface.swift branched (.video → player view when session
  active; .still unchanged)
- [x] RootWindowView.swift VideoScrubBar wired (player-bound
  play/pause/seek; 1×/2×/3× rate menu; onChange refresh hooks)
- [x] pbxproj updated (3 new file refs + 3 build files + group/sources
  phase entries)
- [x] `bun run verify:macos` passes (xcodebuild Debug succeeds)
- [x] `apps/filmtone-desktop-macos/Verify/run.sh` passes (existing 56/56
  — no Verify additions in this slice)
- [x] git diff --check clean (no whitespace damage)
- [x] active.md archived (this file moved on completion) and 1-3 line
  completion entry appended to strategy.md

## Verification

- `bun run verify:macos` → `** BUILD SUCCEEDED **` (Swift 6 strict
  concurrency clean). Two pre-existing-style deprecation **warnings**
  on the macOS 26.0 deprecation of the synchronous
  `AVMutableVideoComposition(asset:applyingCIFiltersWithHandler:)`
  initializer — see Follow-up below.
- `apps/filmtone-desktop-macos/Verify/run.sh` → 56/56 passed. No new
  Verify cases were added in this slice (composition handler runs on
  AVFoundation's private dispatch queue and would need a fixture video
  asset to PNG-hash; out of scope per active.md).
- `git diff --check` → clean.

## Manual Smoke (user-driven)

Launch the freshly built app (Filmtone.app under `apps/filmtone-desktop-macos/build/Build/Products/Debug/`)
and verify on a real video:

1. Open a normal H.264/HEVC video (1080p or 4K iPhone footage).
2. Hit Space (or the Play button on the scrub bar). Expected: smooth
   real-time graded playback, with audio if the source carries it.
3. Drag the scrub bar mid-playback. Expected: thumb follows finger
   without jitter, playback pauses, release leaves it paused at the new
   time. Press Space to resume from there.
4. Open the rate menu (right of the scrub bar) and pick 2× or 3×.
   Expected: playback continues at the higher rate, audio pitched
   accordingly (AVPlayer default behavior).
5. Edit a Look / Strength / Quick / Override / Source Profile while
   playback is running. Expected: graded composition updates within
   ~100ms (debounce window) and the next composed frame reflects the
   change. Time should not jump.
6. Switch to a still image. Expected: still preview path is unchanged
   from before this slice (Image(nsImage:) render).
7. Open a vertical iPhone clip. Expected: source aspect ratio
   preserved; Color.black backdrop forms the letterbox; preview is not
   stretched or cropped.

## Unexpected / Follow-up

- **macOS 26.0 deprecation warnings** on `AVMutableVideoComposition`
  and its `init(asset:applyingCIFiltersWithHandler:)`. The new
  `class func videoComposition(with:applyingCIFiltersWithHandler:)
  async throws -> AVVideoComposition` is the canonical replacement,
  but it is async and would require turning the composition factory
  + `updateInputs` path async-throwing as well. Punted to a follow-up
  slice (M5-I.3 candidate: "Async AVVideoComposition migration")
  rather than expanded into this one — the deprecated synchronous
  init still functions on macOS 26 and is not slated for removal.
- **Compare mode** (graded ↔ original `AVPlayerItem` swap) and
  **renderSize knob** (1280 / 1024 / 720) remain explicitly out of
  scope. Hooks are additive — `FilmtoneDesktopVideoSession` already
  centralizes player + composition refresh, so a second
  `originalItem` field + a public `setRenderSize(_:)` are clean to
  layer in later.
- **Verify coverage** for the composition handler resolve path would
  require a fixture video; deferred per scope.
- **Post-smoke framing correction**: user visual smoke confirmed
  playback worked but the full source was not framed correctly. Root
  cause was the composition handler returning source-extent frames into
  the 1280-capped `composition.renderSize` canvas. Fixed by mirroring
  iOS live preview: normalize `request.sourceImage` to zero origin,
  scale into `renderSize`, crop to `CGRect(origin: .zero, size:
  renderSize)`, then run source transform + grade. `preferredTransform`
  is not applied again because AVVideoComposition already provides
  presentation-oriented frames.


## Done conditions

- Native macOS app builds + launches with the new playback architecture
  in place (xcodebuild Debug succeeds).
- A `.mov` / `.mp4` opens, the preview shows the graded video, and
  Play/Pause progresses time at real-time without ticker drift. (Visual
  smoke on real footage is user-driven; structural fix is verifiable
  from code.)
- 1×/2×/3× rate menu changes `player.rate`.
- Slider drag during playback seeks the player and pauses; release
  resumes only via explicit Play.
- Audio plays from the source if present (default mute disabled).
- Source aspect ratio preserved; letterbox is `Color.black` from the
  surrounding `PreviewSurface` background, not the player's chrome.
- Still preview and export paths unchanged in behavior.
- Timer-driven path is removed from EditorState (no fallback): the
  AVPlayer route is the sole video preview path. Justification: the
  spike documented that the timer path is structurally unsuitable for
  playback; keeping it as fallback adds dead code surface and dual
  invariants for no product benefit.

## Out of scope

- Compare mode toggle (graded ↔ original `AVPlayerItem` swap). Spike
  §"設計" references it; left as a separate slice. Hooks here use a
  single graded item so adding compare later is additive (introduce
  `originalItem` + `replaceCurrentItem` + currentTime carry-over).
- Verify/run.sh additions. Composition handler grade resolve is
  deterministic, but PNG-hash parity tests for AVFoundation render
  paths require fixture video assets we do not have in repo.
- Frame-by-frame stepping shortcuts.
- Loop on EOF.
- Removing `FilmtoneVideoFramePreview.swift` legacy loader. Used for
  the duration probe and may yet serve still-from-video extraction.
- `composition.renderSize` exposing a UI quality knob (1280 / 1024 /
  720). Land hard-coded 1280 first; surface knob if visual smoke
  reveals further perf gap.
- Look unification rename / vocabulary work.
