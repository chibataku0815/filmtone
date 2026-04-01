# Filmtone Desktop v0.3.0

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed (Desktop workflow refinement)

### Clearer Export structure (photo vs video)

Top-level tabs, overlay panel, and toolbar adjustments make it easier to
choose image batch vs single video export without guessing.

### Fewer “wrong source” mistakes on export

The preview you are grading is bridged into export as the default input
where appropriate, so it is harder to export an unintended source file.

### Visual language aligned across Edit and Export

Chrome, spacing, and disclosure patterns are brought in line between
edit mode and export — less context switch, fewer surprises.

### Searchable preset picker

Find presets quickly by typing instead of scanning long lists.

### Video preview pauses while export is busy

During export work, the preview video pauses automatically so the UI
state matches what the pipeline is doing.

### Web demo preview tuning

The browser Filmtone demo got preview sizing and media presentation tweaks
for a cleaner view closer to Desktop.

## What is intentionally not in this release

- **Portrait / non-16:9 export caps** — still on the roadmap; vertical
  1080p sources may still scale down more than users expect until the
  long-edge-oriented export cap ships.
- **Interactive playback controls** (play / pause / scrub UI) — preview
  still loops automatically without a timeline control surface.
- **Smart Look AI** is not the headline of this Desktop build.
- **WebGPU / export-first migration** and related open infrastructure themes
  remain future work.

## Lineage

- Includes all v0.2.0 features (Dual LUT, inline export panel, WebCodecs
  path, package split, etc.).
- Includes the v0.2.1 change: update-check URL embedded at build time so
  the in-app update banner works for DMG installs.

## Checksums

After the signed + notarized DMG is finalized, publish the output of
`bun run release:checksums`.
