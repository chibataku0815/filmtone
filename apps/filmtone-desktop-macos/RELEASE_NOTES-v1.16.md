# Filmtone Desktop v1.16

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.16 focuses on Film Damage: dark dust, debris, and hairline marks are easier
> to read on bright footage, and the high-resolution render path avoids damage
> work outside its visible bounds.

### Film Damage texture

Film Damage now mixes in more dark debris and fine hairline marks instead of
letting white dust dominate the effect. The result is closer to scanned-film
surface damage on bright skies, water, and other pale footage while keeping the
accepted grade, grain, and framing behavior intact.

### Film Damage render speed

The render path now skips out-of-reach damage pixels earlier and avoids
unconditional neighbour checks for debris detail. On the local 3840-pixel
30-frame Film Damage probe, the strong preset path improved from `21.018ms` per
frame to `16.955ms` per frame. Different files, machines, and settings can vary.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.16 DMG.
- Sidecar output remains compatible; v1.16 does not require a schema bump.

## Known limits

- Heavy Film Damage, Grain, and optical filters still cost more at 4K than at
  FHD.
- The current Desktop Developer ID build writes SDR H.264 output. HDR, 10-bit,
  and ProRes export are not part of this release.

## Checksum

```text
9df8b1d51350fe40d7338aa8f3527f815b1097301db878886dc2d5d2e91dc1d9  Filmtone-1.16.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
