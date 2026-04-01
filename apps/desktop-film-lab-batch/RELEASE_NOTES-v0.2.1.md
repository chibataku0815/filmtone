# Filmtone Desktop v0.2.1

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

### Update notification now works out of the box

The update check URL is now embedded at build time. Previous builds
required a runtime environment variable to enable update checks, which
meant the in-app update banner never appeared for DMG users. From this
version onward, Filmtone automatically checks for new versions on launch
and every 24 hours.

## Notes

- All v0.2.0 features are included (Dual LUT, redesigned export, faster
  video, etc.). See the v0.2.0 release notes for the full list.
- Video export requires `ffmpeg` and `ffprobe` on the machine.
- Smart Look AI is not included in this Desktop release.

## Checksums

Publish the output of `bun run release:checksums` after the signed
+ notarized DMG is finalized.
