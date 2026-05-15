# Filmtone Desktop v1.8

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.8 is a Native Desktop update after v1.7. It adds 24fps Slow Mode, brings
> Film Breath and black-floor controls into the shared native color contract,
> and extends the headless automation path used by Codex workflows.

### 24fps Slow Mode

Video export now includes an explicit 24fps Slow Mode for sources above 24fps.
When selected, Filmtone writes a slower 24fps output and records timing metadata
in the sidecar so the export choice is recoverable later.

### Film Breath

The shared color contract now includes Film Breath, a controlled temporal
modulation for native export paths. The v1.8 tuning makes strong settings
visible while keeping the default path neutral.

### Black-floor controls

The native grade path now carries `blackPoint` and `toeContrast` through the
shared TypeScript and Swift contracts. These controls give the grade pipeline a
more explicit way to anchor or shape the low end without changing the sidecar
schema version.

### Headless automation hardening

The Codex-facing automation path now uses the native automation CLI and an MCP
server with bounded path access, preview-before-run batch plans, signed plan
checks, and clearer unsupported-profile errors. This is for workflow
automation; it is not an in-app chat surface.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.8 DMG.
- Sidecar output remains compatible; v1.8 does not require a schema bump.

## Known limits

- 24fps Slow Mode is for sources above 24fps. Image exports do not carry video
  timing metadata.
- The automation path supports the current H.264-oriented batch profiles. ProRes,
  HEVC, and cloud upload requests return an unsupported-profile message in this
  release.
- Imported Grade / DRX handling remains approximate and does not claim DaVinci
  Resolve parity.

## Checksum

```text
8a7a398bff773ac6d9cd939ceea87ccc835b453a5aaff22696e7e156b5a82820  Filmtone-1.8.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
