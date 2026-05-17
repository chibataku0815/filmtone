# Filmtone Desktop v1.12

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.12 refines the built-in Stone, Urban, and Noir Looks for Rec.709 and other
> display-referred sources, keeping the optical character while reducing the
> color breakage that can happen when a strong creative LUT is applied directly
> to already-rendered footage.

### Rec.709-safe Look color variants

Stone, Urban, and Noir now ship with dedicated Rec.709-safe LUT variants. On
Rec.709, SDR BT.709, Display P3 SDR, or unknown display-referred sources, the
Desktop renderer uses the safer variant instead of only lowering the full Look
intensity.

The goal is to keep the glow, softness, and optical finish available while
pulling back the hue and saturation moves that can clip, posterize, or push
skin and highlights into unstable color.

### Full Looks stay available for normalized sources

Log and camera-profile sources continue to use the full Creative Pack 01 Look
path. Imported user LUTs and imported grade packages are not changed by this
release.

### Preview and export use the same decision

Preview, still export, video export, and video composition rendering resolve the
same source-aware Built-in Look variant, so a Rec.709-safe preview matches the
export path.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.12 DMG.
- Sidecar output remains compatible; v1.12 does not require a schema bump.

## Known limits

- Rec.709-safe Looks are intentionally more restrained in color than the full
  normalized-source Looks.
- Imported Grade / DRX handling remains approximate and does not claim DaVinci
  Resolve parity.

## Checksum

```text
bafaed774a08f2679f44cdb21ebcbfe3b8339592b0534f4822fe81f9877c00b7  Filmtone-1.12.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
