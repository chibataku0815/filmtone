# Filmtone Desktop v0.4.1

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

### Clearer Pro “Tone” labels (Web and Desktop)

Pro mode section **Process** is now **Tone** (Japanese: **階調**). Slider names and
tooltips were rewritten so they read like grading controls—not generic technical jargon.

| Before (UI string) | After (UI string) |
|--------------------|-------------------|
| Process | Tone |
| Compression | Highlight softness |
| Comp Range | Tone span |
| Print Contrast | Print snap |

Japanese UI: **プロセス → 階調**, **コンプレッション → ハイライトの柔らかさ**,
**レンジ → 階調の広がり**, **プリントコントラスト → 仕上げのコントラスト**.

Hover a slider label (or the row) for a short explanation, including that “compression”
here is **not** file compression, and that print snap is separate from the main
contrast controls.

### Slider label tooltips

All Film Lab sliders show a localized “tap label to reset” hint together with any
control-specific tooltip.

## Lineage

- Builds on v0.4.0 film process controls, Quick/Pro layout, and export parity.

## Checksums

After the signed + notarized DMG is finalized, publish the output of
`bun run release:checksums`.
