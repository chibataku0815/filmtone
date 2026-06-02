# Desktop 60fps One-Minute Export 99 Percent Stall

Date opened: 2026-06-02 JST
Milestone: M3 Native Color And Optics Parity

## Goal

Reproduce and fix the native Desktop export path stalling at 99% when exporting
about one minute of 60fps video from the currently running app scenario.

## Diagnosis

- The previous 4K/24fps 10s timing run showed render cost dominates short heavy
  exports, and writer wait / append / finish were not material in that case.
- The user now confirms a separate condition: a one-minute 60fps export reaches
  99% and appears stuck. In the current Desktop code, 99% is emitted after frame
  rendering and before or during the final writer flush, so the suspect area is
  writer finish / audio preservation / timestamp finalization / output-file
  closing under a longer 60fps workload.
- Reproduced with a generated 1080x1920 60fps ~59.67s source carrying AAC audio.
  The pre-fix heavy export failed after ~148s at 3547/3580 frames with
  `waitForReadyTimedOut`.
- The same 60fps source without audio completed in ~27.6s, isolating the failure
  to audio preservation / AVAssetWriter input coordination rather than Film
  Damage render cost or final writer flush.
- A separate audio reader alone did not fix the issue; the audio path still used
  a polling await loop against `audioInput.isReadyForMoreMediaData`.
- Matching the iOS-style `requestMediaDataWhenReady` audio pump fixed the stall:
  the final heavy 60fps/audio export completed 3580/3580 frames in 31.1s with
  video and AAC audio preserved.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoWriter.swift`
- `docs/filmtone/desktop/native-desktop-v2/film-damage-grain-quality-knowledge.md`

## Checklist

- [x] Inspect the currently running Filmtone process and recover input/output
  clues if possible.
- [x] Reproduce a 60fps roughly one-minute export with timing enabled.
- [x] Identify whether the 99% stall is writer finish, audio append, timestamp
  ordering, validation, sidecar, or UI progress state.
- [x] Add the smallest reliability fix that prevents indefinite 99% hangs.
- [x] Verify with a 60fps one-minute export.
- [x] Run native Desktop verification.
- [x] Record results and archive this task.

## Verification

- Pre-fix reproduction:
  `FILMTONE_EXPORT_TIMING=1 ... --input /tmp/filmtone-60fps-1min-audio-source.mp4`
  failed after ~147.9s with `waitForReadyTimedOut` at 3547/3580 frames.
- Audio isolation:
  `/tmp/filmtone-60fps-1min-video-only-source.mp4` completed in 27.6s.
- Fixed export:
  `/tmp/filmtone-60fps-1min-heavy-output-final.mp4` completed in 31.1s,
  3580/3580 frames, timing summary fps=116.95, finish=5.4ms.
- `ffprobe` confirmed output streams:
  H.264 video 59.666667s and AAC audio 59.666009s.
- `apps/filmtone-desktop-macos/Verify/run.sh` -> 161/161 passed.
- `bun run verify:desktop` -> build succeeded.
- `git diff --check` -> passed.

## Done Conditions

- A 60fps roughly one-minute export no longer hangs indefinitely at 99%.
- If writer finalization is legitimately slow, progress/logging reports the
  final stage and the writer has a bounded failure path instead of an endless
  wait.

## Stop Conditions

- Done conditions are met and verification is recorded.
- Same reproduction or verification class fails 3 consecutive times.
- The hang only occurs in a currently running stale app binary that predates the
  local fix, and cannot be reproduced in the rebuilt app.

## Out Of Scope

- Film Damage visual-quality tuning.
- Release, notarization, portfolio, or App Store metadata work.
- Cleanup or staging of unrelated ARRI, iPad, source-profile, or export filename
  worktree changes.

## Unexpected

- No running Filmtone process was found when inspected, so the bug was reproduced
  through the rebuilt Desktop CLI path using a generated 60fps/audio source.

## Copy / History Impact

No public copy/history impact expected: this is export reliability plumbing.

Article Opportunity: Release-note only.

Change-History Opportunity: Developer note.
