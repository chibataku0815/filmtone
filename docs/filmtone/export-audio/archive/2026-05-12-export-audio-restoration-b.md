# Export Audio Restoration B

Date: 2026-05-12 JST
Milestone: Export Audio Restoration B

## Goal

Fix the iOS real-device path where normal exports still appear to lose audio.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSidecarBuilder.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoIOBuilder.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoAudioPump.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoCompletionCoordinator.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSidecarWriter.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportAudioDiagnostics.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCapturePackage.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCapturePackagePersistence.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CapturePackageAssembler.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CaptureAudioSupport.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Info.plist`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `docs/filmtone/export-audio/`

## Read-Only References

- `docs/filmtone/export-audio/archive/2026-05-12-export-audio-restoration-a.md`
- Frozen: Gyroflow.

## Checklist

- [x] Make iOS audio preservation read audio from the original source, not the
  routed mezzanine video asset.
- [x] Keep highlight-reel source audio disabled.
- [x] Make completed-output validation compare against original source audio.
- [x] Rebuild and install on the connected iPhone for real-device retest.
- [x] Run focused verification and update this lane doc.
- [x] Add deterministic iOS audio diagnostics instead of guessing.
- [x] Add Debug-only editor source audio visibility.
- [x] Surface completed-output audio diagnostics in exported sidecar JSON.
- [x] Decide whether product scope should unfreeze capture audio recording.
- [x] Add microphone-backed audio to the product capture master path.
- [x] Validate completed capture masters contain an audio track.
- [x] Verify owner-provided success export has an AAC audio stream and
  completed-output sidecar audio truth.
- [x] Refactor audio validation, diagnostics, and capture audio setup into
  feature-local Internal helpers.

## Verification

- `bun run verify:ios`
- `git diff --check`
- Device Debug build/install for `com.chibatakumi.film.lab.ios`

## Done Conditions

- A source with audio cannot silently export without an output audio track on
  iOS normal export, including mezzanine-routed sources.
- Filmtone product capture masters contain an audio track when capture succeeds.
- Real-device build installs successfully.
- No frozen Gyroflow files are edited.

## Stop Conditions

- Three consecutive failures on the same verification step.
- The fix requires editing frozen Gyroflow infrastructure.
- Real-device install is blocked by signing/device trust after a successful
  local build.

## Out Of Scope

- Detail Softness / Source Detail Compensation.
- Gyroflow work.
- Release/version/public claims.
- Portfolio implementation or submodule updates.

## Unexpected Blockers

- Real-device testing showed export audio still absent after Restoration A.
- First verification after adding editor diagnostics failed from a local helper
  name collision in `FilmtoneEditorStore`; fixed before rebuild/install.
- Owner-provided reproduced export
  `filmtone-export-a190ea13-9266-4964-b9d9-cb884d4f2a06.mp4` contains no
  audio stream by `ffprobe`. The matching device diagnostic reports
  `sourceAudioTrackCount: 0`, `outputAudioTrackCount: 0`, and
  `audioSamplesAppended: 0`. Its sidecar identifies the input as the app
  capture `master.mov`, and `FilmtoneCaptureWriter.swift` currently documents
  `No audio track (strategy.md: M1-M4 produce silent video)`. This means the
  reproduced failure is capture-source audio absence, not an export writer drop.
- Owner clarified that only Gyroflow is frozen; product capture audio is now
  in scope for this export-audio lane.

## Progress Log

- Updated iOS export so video may still read from routed mezzanine, but audio
  preservation reads from the original source asset through a dedicated audio
  reader. Completed-output audio validation also checks the original source
  asset, so a video-only mezzanine can no longer make audio loss look valid.
- Tightened mezzanine audio setup so writer/reader audio attachment failures
  fail loudly instead of producing a silent cached intermediate.
- Installed the rebuilt Debug app on `千葉工のiPhone (7)` for owner retest.
- Added Debug-only audio diagnostics:
  `Documents/FilmtoneAudioDiagnostics/latest-export-audio.json` records source,
  effective-video, and output audio track counts plus appended audio sample
  count; the export panel shows the same summary as `Audio debug`.
- Added Debug-only editor preview metadata `audio N` so the owner can see
  whether the imported video itself is being read as audio-bearing before
  export starts. The same fact is logged as `[FilmtoneAudioDebug]`.
- Added `output.audioPreserved` and `audioDiagnostics` to the iOS export
  sidecar so downloaded export packages carry source/effective/output audio
  track counts without needing device-log access.
- Added microphone permission and a microphone device input to the product
  capture session, then made capture assembly fail if the completed `master.mov`
  has no audio track.
- Persisted the completed capture master's audio track count in the capture
  package snapshot so future diagnostics can distinguish capture-source absence
  from export-time audio loss.
- Added `NSMicrophoneUsageDescription` for the new capture audio permission.
- Owner retest export
  `filmtone-export-1094b76b-5010-4ec1-8b57-aa9c8d1a1451.mp4` contains a
  video stream and AAC audio stream by `ffprobe`; its sidecar reports
  `sourceAudioTrackCount: 1`, `outputAudioTrackCount: 1`, and
  `audioPreserved: true`.
- Refactored feature architecture: `ExportAudioDiagnostics` now owns
  completed-output audio validation, sample-count tracking, device debug JSON,
  and sidecar diagnostic conversion; `CaptureAudioSupport` now owns microphone
  permission, microphone graph attachment, audio connection validation, and
  master audio-track validation.

## Verification Results

- `bun run verify:ios` — PASS.
- Device build — PASS (`xcodebuild ... -destination 'generic/platform=iOS'`).
- Device install — PASS (`com.chibatakumi.film.lab.ios` installed on
  `千葉工のiPhone (7)`).
- `bun run verify:ios` after diagnostics — PASS.
- Device build/install after diagnostics — PASS.
- First `bun run verify:ios` after editor audio visibility — FAIL
  (`FilmtoneEditorStore` helper/property name collision).
- `bun run verify:ios` after editor audio visibility fix — PASS.
- `git diff --check` after editor audio visibility fix — PASS.
- Device build/install after editor audio visibility fix — PASS
  (`com.chibatakumi.film.lab.ios` installed on `千葉工のiPhone (7)`,
  installationURL
  `file:///private/var/containers/Bundle/Application/BABB8E47-7F13-4D3E-9CA7-AD3C2B722019/App.app/`).
- Owner repro file inspection — PASS for diagnosis: local `ffprobe` confirmed
  one video stream and zero audio streams.
- Device diagnostic pull — PASS:
  `build/export-audio-device-debug/latest-export-audio.json` confirmed
  `sourceAudioTrackCount: 0`.
- `bun run verify:ios` after sidecar audio diagnostics — PASS.
- `git diff --check` after sidecar audio diagnostics — PASS.
- Device build/install after sidecar audio diagnostics — PASS
  (`com.chibatakumi.film.lab.ios`, installationURL
  `file:///private/var/containers/Bundle/Application/23CE12F6-1454-4F6E-93C5-80646C351060/App.app/`).
- `bun run verify:ios` after capture master audio validation — PASS.
- `bun run check:filmtone-copy` after microphone usage copy — PASS.
- `git diff --check` after capture master audio validation — PASS.
- Device build after capture master audio validation — PASS
  (`xcodebuild ... -destination 'generic/platform=iOS'`).
- Device install after capture master audio validation — PASS
  (`com.chibatakumi.film.lab.ios`, installationURL
  `file:///private/var/containers/Bundle/Application/C32A50F9-70C4-415C-9E74-1BC8BBB80BE5/App.app/`).
- Owner success export inspection — PASS: `ffprobe` confirmed AAC audio and
  sidecar audio diagnostics reported source/output audio count 1.
- `bun run verify:ios` after feature-architecture refactor — PASS.
- `git diff --check` after feature-architecture refactor — PASS.
- Device build/install after feature-architecture refactor — PASS
  (`com.chibatakumi.film.lab.ios`, installationURL
  `file:///private/var/containers/Bundle/Application/C99222D3-6EB6-45A1-BFC2-4091B50D2A11/App.app/`).

## Copy / History Impact

- Copy impact: Added only the iOS microphone permission string required for
  capture audio. No release/version/public claims changed.
- Refactor impact: no additional user-facing copy or release/version claims.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Developer note; the real-device failure was
  traced to capture masters without audio, not only export-writer behavior.
