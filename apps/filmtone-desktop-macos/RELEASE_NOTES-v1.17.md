# Filmtone Desktop v1.17

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.17 introduces Deep Glow as a consistent optical finish and expands
> Highlight export controls for longer or separate clips.

### Deep Glow

The former Backlight Veil control is now presented as Deep Glow with Subtle,
Balanced, and Strong choices. Deep Glow uses a normalized multi-band falloff
and a separate strength response so highlight spread and intensity remain
independent controls.

Existing projects and sidecars remain compatible. The previous optical profile
ids are retained internally and are no longer shown as the feature name.

### Highlight export

Highlight clips can now use 1, 3, 5, or 10-second windows. Export can combine
the selected moments into one reel or write each moment as a separate clip.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.17 DMG.
- Sidecar output remains compatible; v1.17 does not require a schema bump.

## Known limits

- Heavy Film Damage, Grain, and optical filters cost more at 4K than at FHD.
- The current Desktop Developer ID build writes SDR H.264 output. HDR, 10-bit,
  and ProRes export are not part of this release.

## Checksum

```text
27a5a2670c5173a9e71964347ebacb2a0eabdabcecb8f0a177fc18ec68ebc6e8  Filmtone-1.17.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
