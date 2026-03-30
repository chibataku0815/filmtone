# Filmtone Desktop v0.1.2

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: manual download replacement for now
- Support: `chiba@fores-tone.co.jp`

## What changed

### Color accuracy in video export

Exported MP4 videos now match the Edit tab preview much more closely.

In v0.1.1, the video decoder path used for export produced colors that were
significantly darker than what you see in the app. This has been fixed by
switching to a rendering path that matches the preview exactly.

If you exported videos with v0.1.1, re-exporting with this version will
produce more accurate results.

### Other changes

- Video export output now includes proper BT.709 color metadata for
  correct playback in QuickTime, VLC, and other players.
- Removed unused internal code paths (~1800 lines).

## Notes

- Video export requires `ffmpeg` and `ffprobe` on the machine.
- LUT files are not copied automatically from preview to export. Only numeric Params are synced.
- Donation and sharing remain off in the Desktop build.
- Smart Look AI is not included in this Desktop release.

## Checksums

Publish the output of `bun run release:checksums` after the signed + notarized DMG is finalized.
