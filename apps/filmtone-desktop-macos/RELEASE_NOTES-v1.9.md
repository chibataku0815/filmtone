# Filmtone Desktop v1.9

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.9 focuses the right editing rail on the real Adjust controls. It also fixes
> a built-in Look override path that could make the old Quick sliders appear to
> move without changing the rendered result.

### Adjust in the right rail

The former Quick section now shows the same parameter groups used by Adjust.
You can open tone, color, film, bloom, source, video, mask, and finish controls
directly from the rail without opening the separate advanced popover first.

### Built-in Look parameter ownership

Applying a bundled Look no longer copies the catalog patch into live user
overrides. The Look supplies its base grade, and user-facing parameter edits own
their values after that, so slider changes are not hidden behind duplicated
built-in overrides.

### Backlight Veil stays visible

Backlight Veil remains available in the rail beside the detailed Adjust
parameters. This keeps the common light-haze correction close to the preview
while still leaving the full parameter groups visible.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.9 DMG.
- Sidecar output remains compatible; v1.9 does not require a schema bump.

## Known limits

- The rail now exposes detailed Adjust groups, so it is denser than the former
  Quick area.
- Imported Grade / DRX handling remains approximate and does not claim DaVinci
  Resolve parity.

## Checksum

```text
d3efb71b4d30e21f2935df4c35e616ca4286c9999b46d222b579b3fb56a8bf08  Filmtone-1.9.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
