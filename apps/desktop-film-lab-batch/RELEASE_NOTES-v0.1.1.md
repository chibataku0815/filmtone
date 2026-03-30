# Filmtone Desktop v0.1.1

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: manual download replacement for now
- Support: `chiba@fores-tone.co.jp`

## Notes

- This patch release aligns the public DMG filename with **Filmtone** (`filmtone-<version>-arm64.dmg`).
- Packaged Desktop builds now resolve `ffmpeg` / `ffprobe` more reliably on macOS GUI launches, including common Homebrew paths.
- Version differences and checksums for this build are defined by this release note entry.
- LUT files are **not** copied automatically from preview to batch export. Only numeric `Params` are synced. Final confirmation should happen on the exported file.
- Donation and sharing stay off in the Desktop build.
- Smart Look AI is **not** included in this Desktop release.
- Video export requires `ffmpeg` and `ffprobe` to be installed on the machine.

## Checksums

Publish the output of `bun run release:checksums` after the signed + notarized DMG is finalized.
