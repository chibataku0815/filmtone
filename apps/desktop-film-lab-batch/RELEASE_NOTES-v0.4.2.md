# Filmtone Desktop v0.4.2

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

### Video preview transport (Web and Desktop)

Play / pause, timeline scrub, elapsed time, and **Space** to toggle playback (with safe
behavior alongside Compare mode and export/busy locks).

### Pro panel vocabulary (Web and Desktop)

Several Pro labels were renamed for quicker reading—especially the old **Artifacts** and
**Source Trim** blocks, plus **RGB Shift** (now **Color fringing** in English).

Japanese updates include clearer words for **Bloom** and **Halation**, and friendlier
names for the source/exposure section.

### Hover hints on section headers

Collapsible and toggle headers (film texture, bloom, halation, source adjustments) show
a short native tooltip on hover so the category’s purpose is obvious without opening docs.

### Bloom threshold tooltip

The Bloom **Threshold** slider now includes an inline tooltip explaining which brightness
levels drive the glow.

## Lineage

- Builds on v0.4.1 Tone block labels and v0.4.0 film process controls.

## Checksums

After the signed + notarized DMG is finalized, publish the output of
`bun run release:checksums`.
