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

## 4. Per-fixture oracle (`<basename>.ffprobe.json`)

Each fixture must be accompanied by an oracle file sharing its basename, for example `iphone-hlg-1s-abcd.mov` → `iphone-hlg-1s-abcd.ffprobe.json`.

The oracle is the **declaration of what the fixture is** — not a verbatim copy of ffprobe's output. It is read by `electron/fixture-policy.integration.test.ts`, which runs real ffprobe against the fixture and then checks:

1. the live probe output is a **structural superset** of `ffprobe` (extra keys on the live side are fine; only what the oracle declares is pinned),
2. the derived `colorClass` equals `expected.colorClass`,
3. the derived `deriveDesktopHdrPreparationPolicy(...)` returns `expected.policy.strategy` + `expected.policy.reason`.

### 4.1 Required shape

```json
{
  "expected": {
    "colorClass": "hdr-hlg",
    "policy": {
      "strategy": "prepare-sdr-mezzanine",
      "reason":   "source-is-hdr-hlg"
    }
  },
  "ffprobe": {
    "streams": [
      {
        "codec_type":      "video",
        "color_transfer":  "arib-std-b67",
        "color_primaries": "bt2020",
        "color_space":     "bt2020nc",
        "pix_fmt":         "yuv420p10le"
      }
    ],
    "format": {
      "tags": {
        "com.apple.quicktime.make": "Apple"
      }
    }
  }
}
```

### 4.2 Field reference

- `expected.colorClass` — one of `sdr-bt709`, `hdr-pq`, `hdr-hlg`, `wide-gamut-unknown`, `unknown`.
- `expected.policy.strategy` — one of `none`, `prepare-sdr-mezzanine`, `defer-unknown`.
- `expected.policy.reason` — one of `source-is-sdr-bt709`, `source-is-hdr-pq`, `source-is-hdr-hlg`, `wide-gamut-transfer-unknown`, `source-color-unknown`, `ffmpeg-missing-hdr-filters`.
- `ffprobe.streams[0]` — minimal subset actually consumed by the source-metadata normalizer. Pin the fields that identify the fixture (e.g. `color_transfer`, `color_primaries`, `color_space`, `pix_fmt`, `codec_type`), but **do not** pin volatile / environment-dependent fields like `bit_rate`, `duration`, `nb_frames`, `start_time`.
- `ffprobe.format.tags` — pin only tags the fixture truly carries (e.g. manufacturer / software) and that matter to downstream logic. Optional.

### 4.3 Authoring tips

- Keep the oracle minimal and hand-editable. A fixture plus a 20-line JSON oracle is easier to review than a 200-line ffprobe dump.
- When the oracle lists a value, it becomes a hard contract. When it omits one, the live value is free.
- If your dev ffmpeg lacks `zscale` / `libplacebo`, an HDR fixture's `expected.policy` must still match whatever the current capability-aware policy returns — i.e. `strategy: "defer-unknown"` / `reason: "ffmpeg-missing-hdr-filters"`. Once ffmpeg is upgraded (see `docs/metadata-driven-export-quality-hdr-fixture-inventory-2026-04-24.md` §6), update the oracle to `prepare-sdr-mezzanine` + `source-is-hdr-pq` / `source-is-hdr-hlg`.
- The integration suite skips entirely when no fixtures are present. Empty directories keep CI green.

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
