# Filmtone Desktop v1.7

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.7 is a Native Desktop quality release after v1.6. It restores audio in
> normal video exports and adds Texture Softness, a new control for easing hard
> digital fine detail without turning the image into a simple blur.

### Normal video export preserves audio

Video exports now read the source audio track, write AAC audio into the output
MP4, and validate the completed output file before reporting success.

This applies to normal video export from sources that contain audio.
Highlight-reel export remains source-audio disabled because those clips are
rebuilt from selected timeline segments.

### Texture Softness

The Advanced Optics group now includes `Texture softness`. It is separate from
`Lens softness`: Lens softness is for lens/periphery character, while Texture
softness reduces hard digital fine detail and local acutance across the frame.

The render pass uses an amplitude-gated bilateral detail layer rather than a
plain blur. It is placed before edge optics, glow, grain, creative LUT, and
print processing so generated grain stays crisp and glow stages are not fed by
over-sharpened edges.

### Source-aware detail compensation

Native Desktop preview, still export, and video export now apply a conservative
runtime-only source detail bias when source metadata suggests heavily sharpened
consumer footage. The bias is not saved into Looks, so a saved Look remains
portable across different source material.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.7 DMG.
- Sidecar output remains compatible; v1.7 does not require a schema bump.

## Known limits

- Texture Softness is intentionally conservative. Strong values are designed to
  reduce digital bite while preserving readable edges, but final judgment still
  depends on the source material.
- Source-aware detail compensation uses available metadata heuristics; it is
  not a certified camera manufacturer transform.
- Highlight-reel export remains source-audio disabled in this release.

## Checksum

```text
cb23f1f0b1f37c17f4eaf547975a88bc48d6ae28b720256950ffcf821ede2045  Filmtone-1.7.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
