# Filmtone Desktop v1.0.3

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.0.3 is a Desktop export-quality release. It improves HDR source handling,
> bundles the video tools needed for normal exports, preserves more source
> metadata, and brings preview/export behavior closer for real video finishing.

### HDR video handling is more practical

Filmtone now detects HDR PQ / HLG and wide-gamut sources during import and
export. When the source needs HDR-to-SDR preparation, Desktop can use the
bundled video toolchain instead of asking users to install developer tools.

The in-app HDR message has also been rewritten for normal users. It explains
the practical risk in brightness or color only when needed, without exposing
`ffmpeg`, `zscale`, `libplacebo`, Homebrew commands, or fixture notes.

### Export carries better source context

Export sidecars now preserve more of the source context:

- camera and lens optics where available
- source display rotation
- source frame-rate trust
- source color metadata and color class
- HDR preparation policy
- effective preset and grade values

This makes exported files easier to inspect, reproduce, and round-trip.

### Preview and export stay closer

Video export now starts from the visible preview grade when it can, instead of
depending only on the batch grade state. Export also keeps trusted source FPS,
uses a shared render geometry contract, and writes full-range BT.709 video so
mist, bloom, halation, and highlight rolloff are less likely to shift at the
final encode step.

WebCodecs export remains enabled for supported H.264 sources, with a diagnostic
fallback available for HTML video decoding.

### The default look is calmer

New sessions and old grade imports without preset identity now fall back to
`Neutral / Clean Base` with the shared soft-finish baseline. This gives new
clips a quieter starting point while keeping film-stock and look presets
available in the usual order.

### Optical effects have stronger contracts

The hidden depth and ray-angle controls used by Mist, Glow, Halation, Bloom,
and Cross Filter now share defaults through the core schema. Cross Filter,
camera optics, and ray-angle rendering have additional guardrails and tests so
desktop export, shared grade JSON, and the iOS contract do not drift apart.

## Known limits

- Video export is still capped to FHD output and does not upscale sources.
- Preview/export parity is improved, but this release does not claim
  byte-for-byte equality for every codec, player, and display pipeline.
- Smart Look AI is not part of this Desktop release.
- Cross Filter preset round-trip save/load remains future work.

## Compatibility

- macOS 11+ arm64.
- Signed and notarized Apple Silicon DMG.

## Checksums

```text
4c8009e7f97ff7f7b76385d59dad53b148b5bf9c150980af647fd65470af202d  filmtone-1.0.3-arm64.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/chibatakumi-portfolio/issues`
