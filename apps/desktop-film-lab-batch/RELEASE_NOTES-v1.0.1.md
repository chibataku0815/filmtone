# Filmtone Desktop v1.0.1

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.0.1 tightens the first WebGPU preview release, restores more trust between
> what you see and what you export, and makes the write-out surface feel more
> finished on real footage.

### Highlights hold together more naturally while you preview

Preview now feels steadier on bright footage. Highlights keep their shape more
naturally, finish tools hold together more cleanly, and it is easier to judge
the final mood on screen before you export.

This release also completes the first WebGPU preview pass for the remaining
Hard Mode and Light Shafts work that was still in flight for v1.0.0.

### Cross Filter is easier to judge live

Cross Filter now behaves more reliably while you preview. You can tune the
brightness that triggers the streaks, how much they split into color, and how
closely the highlights can sit before the effect feels too dense.

This update also restores the intended streak direction and reduces the
unwanted temporal echo that could make the effect feel unstable on moving
footage.

### Preview and export are closer again

Color trust between preview and export has been tightened for normal working
ranges, so it is easier to make finishing decisions on screen with confidence.
Compare split behavior has also been restored.

This is a trust improvement, not a full claim of perfect parity in every edge
case.

### Export settings can now travel with your file

Desktop exports can now write a metadata sidecar (`.filmtone-session.json`)
next to the output file. That makes it possible to reopen the same finishing
setup later, inspect what was used, and continue from the same starting point.

### The write-out surface is cleaner and easier to read

The write-out tab has been reworked into a more consistent glass surface, with
clearer controls on bright footage and less of the heavy dark-card feeling from
earlier builds. Buttons, fields, preset tiles, and dividers now sit closer to
the rest of the product's material language, so the export flow feels more
finished and less patchworked.

## Known limits

- Video export continues to use the current WebGL2 export path in this release.
- Some older WebGL-era preview tools still remain outside the current WebGPU
  preview path and will return in later releases.
- Cross Filter preset round-trip save/load is still future work.
- Smart Look AI is not part of this Desktop release.

## Compatibility

- macOS 11+ arm64.
- Signed and notarized Apple Silicon DMG.

## Checksums

```text
eb3f573b4f5d1e646f95f24688197aa2c560914c9c67827fe5a2c8f03b4163ad  filmtone-1.0.1-arm64.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/chibatakumi-portfolio/issues`
