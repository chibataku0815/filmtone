# Desktop Scratch Export Integration And 60fps Speed

Date opened: 2026-06-02 JST
Milestone: M3 Native Color And Optics Parity

## Goal

Fix the native Desktop export path where Film Damage scratches render much
crisper and less integrated than preview, and reduce the observed one-minute
60fps export time beyond the current roughly 2m10s user result without lowering
visual quality silently.

## Diagnosis

- User-provided export screenshot shows thin vertical scratches reading as hard
  clean lines, especially around high-contrast image regions. The user reports
  preview looks more integrated than export.
- User-provided sidecar:
  `/Users/chibatakumi/Movies/DJI_20260531161741_0017_D-stone.filmtone.json`.
- The previous 60fps/audio stall fix removed writer-input blocking; remaining
  speed complaints are likely render/kernel cost unless timing proves otherwise.
- Real-source timing confirmed render/kernel cost is the bottleneck. The
  user-provided DJI 4K/60 clip exported 4048 frames in 127.79s before this pass;
  after the SDR export-context change it exported in 84.39s with render at
  64.28s / 77.5% of elapsed time. Writer wait, append, audio, and finish were
  negligible.
- A writer-pool IOSurface/Metal-compatibility experiment was rejected: it helped
  a 10s sample slightly but worsened the full 67.57s export to 92.26s.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoComposition.swift`
- `apps/filmtone-desktop-macos/Verify/CoreOpticalFilterTests.swift`
- `docs/filmtone/desktop/native-desktop-v2/film-damage-grain-quality-knowledge.md`

## Read-Only References

- `/Users/chibatakumi/Movies/DJI_20260531161741_0017_D-stone.filmtone.json`
- `/Users/chibatakumi/Library/Application Support/CleanShot/media/media_a7zdSGWQC8/CleanShot 2026-06-02 at 09.48.34@2x.png`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`

## Checklist

- [x] Inspect the supplied sidecar and recover source/output settings.
- [x] Measure a representative 60fps export with timing enabled.
- [x] Compare preview and export scratch code paths for scale/sampling/order
  differences.
- [x] Fix scratch integration so export no longer produces hard clean vertical
  lines while preserving visible scratches.
- [x] Reduce measured render cost where the fix exposes avoidable work.
- [x] Verify with real-source export and native Desktop tests.
- [x] Record results and archive this task.

## Verification

- `FILMTONE_EXPORT_TIMING=1` Desktop CLI export on
  `/Volumes/SamsungPortableSSDX5001/video/20260531/osmopocket4/DJI_20260531161741_0017_D.MP4`
  with the sidecar's Stone + Grain + Film Damage parameters: `4048` frames,
  `67.57s` output, `84.39s` wall time, timing summary `elapsed=82929.7ms`,
  `fps=48.81`, `render=64280.9ms`.
- `ffprobe` on `/tmp/filmtone-dji-0017-stone-heavy-profile-final.mp4`:
  3840x2160 H.264 video, AAC audio, duration `67.566667`.
- Frame checks:
  `/tmp/filmtone-dji-0017-final-frame-5s.png` and
  `/tmp/filmtone-dji-0017-final-frame-10s.png`.
- `apps/filmtone-desktop-macos/Verify/run.sh` passed: `161/161`.
- `bun run verify:desktop` passed.
- `bun run check:filmtone-context` passed.
- `git diff --check` passed.

## Done Conditions

- Exported scratches are visibly less hard-edged and better embedded than the
  user screenshot, without disappearing.
- Preview/export scratch treatment uses the same material assumptions or has a
  documented scale reason for any intentional difference.
- A 60fps roughly one-minute export improves from the reported 2m10s path, or
  timing proves a non-kernel bottleneck that is bounded and reported.

## Stop Conditions

- Done conditions are met and verification is recorded.
- The same verification class fails 3 consecutive times.
- The supplied source needed to reproduce the issue is unavailable and a
  generated equivalent cannot reproduce either the hard scratch or timing issue.

## Out Of Scope

- Full Film Damage v3 plate/material asset system.
- Release, notarization, portfolio, or App Store metadata work.
- iOS/iPad parity implementation unless Desktop fix proves a shared kernel
  contract issue.

## Unexpected

- None yet.

## Copy / History Impact

No public copy/history impact expected: this is export visual fidelity and
performance plumbing.

Article Opportunity: Release-note only.

Change-History Opportunity: Developer note.
