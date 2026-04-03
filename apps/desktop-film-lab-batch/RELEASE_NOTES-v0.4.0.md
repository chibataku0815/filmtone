# Filmtone Desktop v0.4.0

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

### Film process controls (Web and Desktop)

New grading controls for a film-style process path: compression amount, compression
range, print contrast, and cyan / magenta / yellow trim. Values line up between the
browser demo preview and Desktop export so what you grade is what you ship.

### Quick and Pro layout

Quick mode keeps the shortest path (film stock, preset intensity, LUT, source exposure).
Pro mode surfaces Process, artifacts, source trim, and LUT in a clearer order. Source
trim starts collapsed so the panel stays scannable.

### Film Stock picker and categories

Preset surfaces use category grouping so stocks like Velvia 50 sit in sensible
buckets and are easier to find next to cinematic and reset options.

### Stable panels and safer extremes

On Desktop, switching tabs no longer tears down the control panel in a way that
reset process settings during photo preview. Compression range is capped in the UI
and eased in the shader so very high values are less likely to show harsh artifacts.

### Share links and export compatibility

Shared URLs and import/export paths keep older links working while carrying the new
process parameters when present.

## Scope notes for this release

- Smart Look AI and Remotion-related flows remain unchanged in this version.
- A dedicated “film developer” style step is not included; it may be revisited in a
  future release.

## Lineage

- Includes v0.3.1 browser video export beta, Desktop reliability fixes, and all prior
  Desktop and Web demo improvements.

## Checksums

After the signed + notarized DMG is finalized, publish the output of
`bun run release:checksums`.

**Build note:** If `dist:mac:release` cannot complete notarization (missing Apple API key
or app-specific password in the environment), use `dist:mac:unsigned` for internal QA
only. Replace the public Blob artifact with a notarized DMG before announcing a
production release.
