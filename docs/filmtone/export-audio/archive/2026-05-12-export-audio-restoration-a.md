# Export Audio Restoration A

Date: 2026-05-12 JST
Milestone: Export Audio Restoration A

## Goal

Make normal video exports preserve source audio on iOS and Native Desktop, and
base reported audio truth on completed-output validation.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoIOBuilder.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoReader.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoWriter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `docs/filmtone/export-audio/`

## Read-Only References

- `docs/filmtone/2026-05-12-export-audio-detail-softness-handoff.md`
- `docs/filmtone/2026-05-11-export-audio-investigation.md`
- `docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md`
- Gyroflow/capture smoke files remain frozen/read-only.

## Checklist

- [x] Create lane docs and branch context.
- [x] Make iOS audio setup fail loudly when required audio attachment fails.
- [x] Validate iOS completed output before reporting `audioPreserved: true`.
- [x] Add Native Desktop normal-export audio reader/writer preservation.
- [x] Validate Native Desktop completed output.
- [x] Prove a Native Desktop export from a tiny video+AAC source has audio.
- [x] Run `bun run verify:ios`.
- [x] Run `bun run verify:macos`.
- [x] Run `git diff --check`.
- [x] Record copy/history impact and archive this active task.

## Verification

- `bun run verify:ios`
- `bun run verify:macos`
- `git diff --check`
- `ffmpeg` synthetic video+AAC source -> Native Desktop headless
  `--export-video` -> `ffprobe` final output audio stream check.

## Done Conditions

- Source audio + preserve-audio normal export cannot silently produce a silent
  output on iOS or Native Desktop.
- `CompletedExport.audioPreserved` reflects completed iOS output truth.
- Highlight-reel export remains source-audio disabled.
- No Gyroflow/capture smoke files are edited.

## Stop Conditions

- Three consecutive failures on the same verification step.
- A fix requires editing frozen Gyroflow/capture smoke infrastructure.
- Output validation reports missing audio after a normal export from a source
  known to contain audio.
- The change alters video color/render ordering or highlight behavior.

## Out Of Scope

- Detail Softness / Source Detail Compensation.
- Gyroflow, capture, stabilization, `.gcsv`, `Smoke/`, and
  `FILMTONE_SMOKE_LANE` work.
- Release/version/public claims.
- Portfolio implementation or submodule updates.

## Unexpected Blockers

- None yet.

## Completion Log

- iOS export now fails loudly when required audio writer/reader attachment
  cannot be added, and `CompletedExport.audioPreserved` is based on completed
  output audio-track validation.
- Native Desktop normal video export now opens an audio reader/writer path,
  appends source audio samples, and validates the completed output. Highlight
  reel export remains silent.
- Frozen Gyroflow/capture smoke surfaces were not edited.

## Verification Results

- `bun run verify:ios` — PASS. Existing AVFoundation/Core Image/Sendable
  warnings remain; export audio validation builds.
- `bun run verify:macos` — PASS (`** BUILD SUCCEEDED **`). Existing Core Image
  and AVVideoComposition deprecation warnings remain.
- Desktop direct proof — PASS. Generated `build/export-audio-proof/source-with-audio.mp4`
  with AAC audio, exported through headless `Filmtone --export-video`, and
  `ffprobe` confirmed the completed output has an AAC audio stream.
- `git diff --check` — PASS.
- `bun run check:filmtone-copy` — PASS.
- `bun run check:filmtone-context` — PASS.

## Copy / History Impact

- Copy / History Impact: release/support copy may mention restored or verified
  audio preservation only after this change is intentionally included in a
  release surface. No release/version claims were changed here.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Developer note. This records the move from the
  Native Desktop AVFoundation video-only exporter to completed-file-validated
  audio preservation, while iOS changed from intent-based to output-validated
  audio truth.
