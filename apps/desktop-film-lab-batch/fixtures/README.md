# Filmtone Desktop Test Fixtures

Last updated: 2026-04-24
Status: **skeleton — video files not yet provided**

## 1. Purpose

Integration-grade video fixtures for Filmtone Desktop export policy tests.
First use case is verifying the HDR preparation policy (`apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts`) against real PQ / HLG / SDR BT.709 sources without committing large or privacy-sensitive footage.

Synthetic ffprobe JSON tests still live next to the source modules. This tree is for cases that need a real container / real stream metadata.

## 2. Layout

```
fixtures/
  video/
    hdr/
      iphone-hlg-1s-<hash>.mov       # iPhone HDR Video trim (HLG, bt2020, arib-std-b67)
      generic-pq-1s-<hash>.mp4       # HDR10 / PQ trim (smpte2084, bt2020nc)
    sdr/
      s1ii-bt709-1s-<hash>.mp4       # SDR BT.709 regression
  README.md                           # this file
```

## 3. Fixture requirements

- **Length**: 1–2 seconds. Just enough for ffprobe to report stream fields.
- **Size**: < 5 MB each. Avoid git-lfs for now.
- **Content**: static / landscape / non-identifiable. No people, no GPS-identifying landmarks, no audio with speech.
- **Rotation**: prefer sources without Display Matrix rotation (separate fixtures later if needed).

## 4. Per-fixture metadata

Each fixture must be accompanied by an expected ffprobe snippet, committed next to the file as `<fixture-basename>.ffprobe.json`. Example:

```json
{
  "streams": [
    {
      "codec_type": "video",
      "codec_name": "hevc",
      "width": 1920,
      "height": 1080,
      "color_space": "bt2020nc",
      "color_transfer": "arib-std-b67",
      "color_primaries": "bt2020",
      "avg_frame_rate": "30/1",
      "r_frame_rate": "30/1"
    }
  ],
  "format": { "duration": "1.033" }
}
```

Keep the JSON minimal — only the fields touched by the metadata normalizer.

## 5. Capture recipes

### iPhone HLG

1. Settings → Camera → Formats → Video Capture → High Efficiency + HDR Video **ON**.
2. Record 2 seconds of a static scene (a wall, sky).
3. Transfer via AirDrop (keeps HLG metadata) or `ImageCapture.app`.
4. Trim with `ffmpeg -ss 0 -i input.mov -t 1.0 -c copy -map_metadata 0 iphone-hlg-1s-<hash>.mov`.
5. Verify: `ffprobe -show_streams iphone-hlg-1s-<hash>.mov | grep -E 'color_transfer|color_primaries'` should report `arib-std-b67` and `bt2020`.

### HDR10 / PQ

- iPhone ProRes LOG (iPhone 15 Pro / 16 Pro) or any camera with native HDR10 PQ.
- Panasonic S1II does **not** produce PQ natively (V-Log is log SDR).
- Verify: `color_transfer=smpte2084`, `color_primaries=bt2020`.

### SDR BT.709 regression

- Any existing BT.709 `.mp4` clip will do — trim 1 second of a static scene.
- Verify: `color_primaries=bt709`, `color_transfer=bt709` (or unspecified, which still classifies as `sdr-bt709`).

## 6. Privacy / licensing

- Only commit fixtures **you recorded yourself** or that are unambiguously public-domain.
- Do not commit third-party HDR demo files (e.g. 4K Media samples) — reference them by URL in the capture recipe instead.
- Strip GPS / location tags before commit: `exiftool -GPS*:all= fixture.mov`.
