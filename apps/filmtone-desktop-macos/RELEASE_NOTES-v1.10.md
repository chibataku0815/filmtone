# Filmtone Desktop v1.10

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.10 is a focused follow-up to v1.9. It keeps the right rail on real Adjust
> parameters, but restores the original collapsed default for parameter groups.

### Adjust groups start collapsed again

The right rail now opens with each Adjust group collapsed. This matches the
earlier Advanced Adjust behavior and keeps the rail compact until you choose a
group to edit.

### Manual expansion is unchanged

Each group can still be opened from the rail, and the same parameter sliders,
recipe chips, and reset controls remain available once a group is expanded.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.10 DMG.
- Sidecar output remains compatible; v1.10 does not require a schema bump.

## Known limits

- The right rail exposes detailed Adjust groups, so it remains denser than the
  old Quick section after you expand groups.
- Imported Grade / DRX handling remains approximate and does not claim DaVinci
  Resolve parity.

## Checksum

```text
009d82ed75e80458b4e027c1981031965337fec5dd32365f1bfd1e8aa7314f5a  Filmtone-1.10.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
