# Filmtone Desktop v1.15

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.15 focuses on Desktop export behavior: Film Damage scratches sit more
> naturally in full-resolution output, normal video export defaults to FHD, and
> 4K output is now an explicit choice for 4K-capable sources.

### Film Damage export integration

Full-resolution exports now soften and break up Film Damage scratches by output
size, so vertical scratches read less like clean overlay lines in 4K output.
Bright scratches are also kept relative to the source luminance instead of being
pushed toward a fixed near-white target.

The export path now uses the SDR `RGBA8` Core Image context that matches the
current H.264/BGRA writer path. On the tested DJI 4K/60 Stone + Grain + Film
Damage clip, the same 4048-frame export improved from `127.79s` to `84.39s`.
Different files and settings can still vary.

### FHD and 4K export choice

Video export now defaults to FHD for normal Desktop use. When the source is
4K-capable, the export panel exposes a 4K option and shows a time-cost warning
when 4K is selected. The export button also names the selected path, such as
`Export FHD Video...` or `Export 4K Video...`.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.15 DMG.
- Sidecar output remains compatible; v1.15 does not require a schema bump.

## Known limits

- 4K export can still take noticeably longer than FHD, especially with heavy
  Film Damage, Grain, and optical filters.
- The current Desktop Developer ID build writes SDR H.264 output. HDR, 10-bit,
  and ProRes export are not part of this release.

## Checksum

```text
0e7fc9d31484d319759d21044d572e1d9fc48eabdcbea1b93082ac9d32e14d29  Filmtone-1.15.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
