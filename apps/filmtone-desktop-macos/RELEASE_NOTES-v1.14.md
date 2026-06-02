# Filmtone Desktop v1.14

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.14 adds ARRI LogC3 as a built-in Source Profile, so LogC3 / ARRI Wide
> Gamut 3 footage can be normalized inside Filmtone before applying the
> creative Look and export pipeline.

### ARRI LogC3 Source Profile

The Source menu now includes `ARRI LogC3` alongside Apple Log, DJI D-Log,
Canon Log, V-Log, S-Log3, and Rec.709 profiles. It is a manual Source Profile:
pick it when the source was recorded as ARRI LogC3 / ARRI Wide Gamut 3, such as
compatible LUMIX S1II footage.

Filmtone decodes LogC3 with ARRI EI 800 parameters, converts linear ARRI Wide
Gamut 3 to Rec.709, then applies Filmtone's shared SDR shoulder before the
normal grade path. This keeps the conversion in the same Source Profile system
as V-Log, S-Log3, and Canon Log 3.

### Preview and export parity

Preview, still export, video export, and video composition rendering resolve
the same ARRI LogC3 input transform. Sidecar output records the new source
profile id and curve without requiring a schema bump.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.14 DMG.
- Sidecar output remains compatible; v1.14 does not require a schema bump.

## Known limits

- ARRI LogC3 is manual. Filmtone does not auto-detect it from source metadata
  unless the file exposes a reliable signal.
- This release does not bundle or emulate ARRI Classic 709 / K1S1 display
  looks; it normalizes the source into Filmtone's Rec.709 SDR pipeline.

## Checksum

```text
025e61cfe8947b9086e2e90b8449d377960db6f7fec594bbf6220852cac20340  Filmtone-1.14.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
