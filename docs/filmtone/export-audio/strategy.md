# Export Audio Restoration Strategy

Date: 2026-05-12 JST

## Goal

Restore export audio preservation on the current iOS and Native Desktop export
paths. A successful export must be proven from the completed output file, not
from writer intent.

## Done Conditions

- iOS normal video export preserves source audio when the source has audio and
  `preserveAudio` is true.
- Native Desktop normal video export preserves source audio when the source has
  audio.
- Highlight-reel export remains source-audio disabled.
- Final output validation checks the completed media file for audio tracks.
- Export setup fails loudly when required audio reader/writer attachment cannot
  happen.

## Constraints

- Gyroflow remains frozen and read-only.
- Detail Softness / Source Detail Compensation is a separate lane.
- Do not touch release/version claims, generated Swift, renderer packages, or
  portfolio submodules.
- Keep user-facing failure text direct and task-focused.

## Current Milestone

None active. Export Audio Restoration B completed on 2026-05-12 JST.

## Completion Log

- 2026-05-12 JST — Export Audio Restoration A completed: iOS audio truth is
  completed-output validated, Native Desktop normal export preserves source
  audio, and highlight exports remain source-audio disabled. Verified with
  `bun run verify:ios`, `bun run verify:macos`, Desktop `ffprobe` proof,
  `git diff --check`, and copy/context gates.
- 2026-05-12 JST — Export Audio Restoration B completed: real-device iOS
  exports now preserve audio from app-captured sources after adding microphone
  capture to the product master path, capture-master audio validation,
  deterministic export diagnostics, and feature-local audio helpers. Verified
  with owner retest export `ffprobe` + sidecar proof, `bun run verify:ios`,
  `git diff --check`, and device build/install.
