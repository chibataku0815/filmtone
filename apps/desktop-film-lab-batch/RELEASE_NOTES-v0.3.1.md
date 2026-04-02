# Filmtone Desktop v0.3.1

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

### Browser graded video export beta

Filmtone now includes a beta browser path for short graded video export.
This makes it easier to try video output without leaving the web experience,
while Desktop remains the more reliable production route.

### Better browser reliability and Safari guidance

The browser export flow is more defensive about encoder constraints and now
surfaces clearer guidance when Safari is not a good fit. When needed, users are
pointed toward Chrome, Edge, or Filmtone Desktop instead of hitting a vague
failure path.

### Finder / Quick Look thumbnails are no longer black

Filmtone now drops the first raw frame before MP4 encoding, which avoids the
black-first-frame behavior that made graded exports look broken in Finder and
Quick Look even when playback itself was fine.

### Better video file pickup for MOV-style inputs

Some video files arrive without a reliable MIME type. Filmtone now falls back
to likely video extensions more gracefully, making drag and drop more reliable
for `.mov` and related files.

## Beta notes

- Browser graded video export is still **beta**.
- Safari has stricter browser limitations than Chrome or Edge for this path.
- For the most dependable export workflow, Filmtone Desktop remains the primary
  route.

## Lineage

- Includes all v0.3.0 improvements to Desktop export flow, preset search, and
  Edit / Export visual alignment.

## Checksums

After the signed + notarized DMG is finalized, publish the output of
`bun run release:checksums`.
