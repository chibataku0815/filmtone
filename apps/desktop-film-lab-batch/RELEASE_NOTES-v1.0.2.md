# Filmtone Desktop v1.0.2

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.0.2 is a release-hardening update for Desktop video export. It focuses on
> making ffmpeg failures easier to recover from, preventing stale export
> sessions from writing into the wrong process, and keeping preview/export
> behavior aligned with the current WebGPU finishing pass.

### Video export handles broken ffmpeg pipes more cleanly

Video export now keeps a dedicated controller around ffmpeg stdin writes. If
ffmpeg closes the pipe early, Desktop captures asynchronous `EPIPE` failures
and surfaces the export failure through the normal write or finish path instead
of leaving the renderer waiting on a stale drain.

This is especially relevant when ffmpeg rejects an input, exits early, or closes
stdin during a retry path.

### Export sessions are now isolated

Desktop now gives each video export its own session id across start, frame
write, finish, and abort IPC calls. Stale messages from an older export are
rejected instead of being allowed to affect the active export.

Starting a new video export also disposes any previous export session first, so
cancel, retry, and restart flows have less chance to leave zombie state behind.

### Preview and export trust stays aligned

This release keeps the current WebGPU preview/export contract aligned while the
Desktop app continues to use the existing video export path. The AI depth,
offscreen render, and low-end grain refinements that landed after v1.0.1 are
included in the Desktop build so exported stills and the preview surface stay
closer to the current finishing model.

## Known limits

- Video export continues to use the current WebGL2 export path in this release.
- Video export still requires `ffmpeg` and `ffprobe` on `PATH`.
- Some older WebGL-era preview tools still remain outside the current WebGPU
  preview path and will return in later releases.
- Cross Filter preset round-trip save/load is still future work.
- Smart Look AI is not part of this Desktop release.

## Compatibility

- macOS 11+ arm64.
- Signed and notarized Apple Silicon DMG.

## Checksums

Pending final signed DMG.

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/chibatakumi-portfolio/issues`
