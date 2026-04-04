# Filmtone Desktop v0.4.3

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

### Faster video export for heavy sources

4K HEVC sources now export up to 4× faster. A 58-second clip that previously
took over 3 minutes finishes in under 45 seconds.

Heavy codec sources — HEVC, VP9, AV1, and ProRes — are automatically optimized
before grading begins. H.264 sources skip this step and continue to export at
full speed.

A progress bar appears during the optimization step so you can see that the
export is working, not stalled.

## Lineage

- Builds on v0.4.2 Pro panel vocabulary and video transport.
- Internal: life#109 visually lossless mezzanine.

## Checksums

After the signed + notarized DMG is finalized, publish the output of
`bun run release:checksums`.
