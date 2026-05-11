# Filmtone Export Audio Investigation

Date: 2026-05-11 JST

Scope: investigation only. No product code was changed.

## User-Observed Symptom

The current exported media from both iOS and Desktop has no audible audio track.
Treat this as product truth for this investigation: the important question is
whether the final exported file contains an audio stream, not whether the code
appears to intend to preserve one.

## Summary

- Native Desktop export is currently video-only by construction. The public
  Native Desktop path uses `AVAssetWriter` with only a video input and no audio
  reader/writer/mux step.
- iOS has an intended audio preservation path, but the current implementation
  does not prove that an audio stream actually lands in the output. It has
  silent skip paths around audio input/output attachment and no post-export
  audio-track validation.
- Old Electron Desktop has an ffmpeg audio-copy path. That does not protect the
  current Native Desktop app, which is the current Desktop implementation path.
- Save to Photos and share on iOS pass the already-rendered file through. They
  do not appear to intentionally strip audio; if the app output file is silent,
  those routes will preserve that failure.

## Native Desktop Findings

Current app: `apps/filmtone-desktop-macos/`.

The Native Desktop video exporter renders frames through
`FilmtoneVideoExporter.export(...)` and writes them with `FilmtoneVideoWriter`.
The writer owns:

- `AVAssetWriter`
- one `AVAssetWriterInput(mediaType: .video)`
- one `AVAssetWriterInputPixelBufferAdaptor`

There is no audio input on the writer:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoWriter.swift`
- lines inspected: writer properties around 30-32, video input setup around
  72-79, finish around 120-136

The exporter constructs only `FilmtoneVideoReader` and `FilmtoneVideoWriter`,
then appends rendered video frames:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- lines inspected: normal export around 213-336

`FilmtoneVideoReader` is also video-only:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoReader.swift`
- lines inspected: one `AVAssetReaderTrackOutput` created for the probed video
  track around 37-64

The preview player is not evidence for export audio. Preview uses AVPlayer and
explicitly sets `isMuted = false`, so preview can play audio while export is
still silent:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoSession.swift`

Conclusion: Native Desktop exported files without audio are expected from the
current implementation. This is a missing export feature, not a downstream save
or playback issue.

## iOS Findings

Current app: `apps/capacitor-film-lab-ios/`.

The shared default output profile says audio should be preserved:

- `packages/film-lab-core/src/phase0-schema.ts`
- `PHASE0_OUTPUT_PROFILE.preserveAudio: true`

The Swift generated profile also carries `preserveAudio: true`:

- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift`

The iOS export session has an audio path:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- audio track selection: around 789-790
- audio writer/reader pipeline setup: around 792-820
- audio sample append loop: around 1128-1159
- `audioPreserved` returned as `audioInput != nil`: around 1178-1183
- AAC writer settings: around 1436-1458

However, the implementation currently has weak truth checks:

1. If `writer.canAdd(audioInput)` is false, the code simply does not add the
   audio input, but it still keeps non-nil `audioInput` / `audioOutput`.
2. If `reader.canAdd(audioOutput)` is false, the code simply does not add the
   audio output, but it still keeps non-nil `audioInput` / `audioOutput`.
3. `audioPreserved` is computed from `audioInput != nil`, not from the completed
   output asset having an audio track.
4. There is no post-export validation step that opens `outputURL` and checks
   for an audio track before reporting success.

Because the user-observed output is silent, the iOS code should be treated as
"intended audio preservation, unverified and currently failing in practice"
until a real output file proves otherwise.

## iOS Save / Share Findings

Photos save uses the generated file URL directly:

- `apps/capacitor-film-lab-ios/ios/App/App/PhotoLibraryService.swift`
- video route uses `PHAssetChangeRequest.creationRequestForAssetFromVideo`

Share uses the generated file URL directly:

- `apps/capacitor-film-lab-ios/ios/App/App/ShareSheetService.swift`
- `UIActivityViewController` receives the file URL as an item

No code path found here intentionally strips audio. If Photos or Share output is
silent, first suspect the rendered export file itself.

## Old Electron Desktop Contrast

The old Electron Desktop path has explicit ffmpeg audio mapping/copy:

- `apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.ts`
- when `hasAudio` is true, args include second input, `-map 1:a:0`, and
  `-c:a copy`

Tests assert this path:

- `apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.test.ts`

This confirms audio preservation existed in the Electron path, but it does not
apply to the current Native Desktop app.

## Verification Gap

There is no current verification gate that proves exported mp4/mov files contain
audio tracks.

The missing proof should be explicit:

```bash
ffprobe -v error -select_streams a \
  -show_entries stream=index,codec_type,codec_name,channels,sample_rate,duration \
  -of json /path/to/export.mp4
```

Equivalent AVFoundation validation should also be acceptable in Swift tests:

- open `AVURLAsset(url: outputURL)`
- load audio tracks
- assert `audioTracks.count > 0` when the source had audio and the export mode
  is expected to preserve it

## Recommended Next Investigation / Fix Order

1. Capture one iOS source file with known audio and its exported output, then
   inspect both with `ffprobe` or AVFoundation. Record whether the source has
   audio and whether the app output has any audio stream.
2. Add an iOS post-export validation probe before reporting `audioPreserved:
   true`. This should make the current failure visible instead of silently
   reporting success.
3. In iOS export setup, make audio preservation fail-fast when source audio is
   present and `preserveAudio` is true but the audio writer input or reader
   output cannot be attached.
4. Add Native Desktop audio support by porting the iOS audio reader/writer path
   into the Native Desktop exporter/writer, then validate the completed output
   asset.
5. Add verification fixtures/gates for both platforms that assert final output
   audio track presence.

## Copy / History Impact

No copy/history impact from this investigation document alone.

If a product fix lands, public support/release copy that claims audio is
preserved should be checked against the new verification result before shipping.

Article Opportunity: Release-note only, if the eventual fix ships in a user
visible update.

Change-History Opportunity: Developer note, because the difference between old
Electron ffmpeg audio copy and current Native Desktop AVFoundation video-only
export is implementation-history relevant.
