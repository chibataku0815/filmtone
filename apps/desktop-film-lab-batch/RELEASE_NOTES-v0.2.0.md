# Filmtone Desktop v0.2.0

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

### Dual LUT — Input Transform + Creative LUT

You can now apply two LUT files simultaneously. Slot 1 is for input
transforms (e.g. Log-to-Rec709 camera LUTs), and Slot 2 is for creative
looks. Both have independent intensity controls.

### LUT sync to export

LUT files set in the Edit tab now carry through to batch and video export.
A 3-state sync button shows whether your edit-tab grade matches the export
settings: synced, out-of-sync, or partially synced.

### Redesigned export panel

Export has moved from a multi-step wizard to an inline accordion panel.
The canvas stays visible while you configure output settings. The panel
uses a frosted glass UI that integrates with the macOS titlebar.

### Faster video export

WebCodecs is re-enabled with proper color space handling and PBO readback.
The video decoder now requests hardware acceleration first, with a 3-step
fallback (prefer-hardware -> hardware -> software) for broad compatibility.

### Update notifications

When a newer version is available, a banner appears in the app with a link
to the download page. No background downloads or auto-installs — you control
when to update.

## Other changes

- Internal restructuring into 4 packages (film-lab-core, film-lab-renderer,
  film-lab-ui, film-lab-smart-look) for cleaner code separation.
- Web demo canvas sizing fix.
- Download complete page with install guide on the website.
- Landing page visuals and OGP images refreshed for Product Hunt.
- Roadmap and Release Notes pages added to the website.

## Notes

- Video export requires `ffmpeg` and `ffprobe` on the machine.
- Smart Look AI is not included in this Desktop release.

## Checksums

Publish the output of `bun run release:checksums` after the signed
+ notarized DMG is finalized.
