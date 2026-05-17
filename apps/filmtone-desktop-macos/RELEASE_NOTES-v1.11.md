# Filmtone Desktop v1.11

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.11 makes the built-in Creative Pack 01 Looks source-aware, so Rec.709 and
> unknown display-referred footage get a safer transform while Log / camera
> profile sources keep the stronger creative treatment.

### Safer Stone, Urban, and Noir on Rec.709 footage

Stone, Urban, and Noir now use a Rec.709-safe branch when the source is
Rec.709, SDR BT.709, Display P3 SDR, or otherwise display-referred. The app
caps the effective LUT strength and the strongest contrast / compression pushes
before rendering, reducing clipping, harsh saturation, and unstable highlight
behavior on already-display-rendered footage.

### Camera-profile sources stay expressive

When a source is explicitly normalized from a camera or Log profile, the current
strong Look Director behavior is preserved. The change separates the source
input transform from the creative Look, matching the expected color-management
shape without replacing the full pipeline.

### Preview and export share the same policy

Preview, still export, video export, and video composition rendering now resolve
the same effective built-in Look policy. Imported user LUTs and imported grade
packages are not changed by this release.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.11 DMG.
- Sidecar output remains compatible; v1.11 does not require a schema bump.

## Known limits

- Rec.709-safe Looks are intentionally more restrained on display-referred
  footage than on normalized Log / camera-profile footage.
- Imported Grade / DRX handling remains approximate and does not claim DaVinci
  Resolve parity.

## Checksum

```text
f72e9b39e3db319e8f5a426df0889ec797a66c857e7b7512f9539a9c8b091c7f  Filmtone-1.11.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
