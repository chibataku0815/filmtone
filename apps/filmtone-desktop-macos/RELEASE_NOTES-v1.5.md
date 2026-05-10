# Filmtone Desktop v1.5

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.5 is a Native Desktop refinement release after the v1.4 replacement
> cutover. It focuses on portrait-video editing, optical-filter correctness,
> Look strength response, and release-readiness hardening.

### Portrait video editing

Portrait sources now keep the media as the primary surface. The inspector uses
the same right-rail model as landscape editing, but portrait sessions open with
the inspector hidden and slide it in from the right with `Command-\`.

The video scrub bar is split into transport and marker rows so playback,
scrubbing, bookmark, Highlight Marker, previous/next marker, and speed controls
remain usable in narrow portrait windows.

### Backlight Veil and Look strength

Backlight Veil now carries a continuous intensity cursor in addition to the
density chips. The setting is threaded through still preview, video preview,
still export, video export, scrub thumbnails, and sidecar output without a
schema bump.

The macOS grade path now includes the Backlight Veil optical scatter composite,
so the effect is visible instead of only changing intermediate bloom /
halation / diffusion parameters.

Look Strength now drives Creative LUT alpha blending continuously, making the
slider response match the intended Look strength behavior.

### Highlight Reel foundation

Highlight markers can be turned into source-relative one-second clip segments
using the shared Swift core contract. Native Desktop, iOS, and DaVinci use the
same centered, clamped, overlap-merged segment model.

### Release readiness

The Mac App Store release lane now has sandbox entitlements, export options,
localized metadata, fastlane automation, and readiness checks. The public
Desktop download rail remains the signed and notarized Developer ID DMG.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.5 DMG.
- Sidecar output remains compatible; v1.5 does not require a schema bump.

## Known limits

- Broader real-media Source Auto / Conversion LUT population testing remains a
  follow-up beyond the accepted Apple Log / Apple Log 2 path.
- Backlight Veil should continue to be watched against difficult backlit
  footage for iOS/Desktop visual tuning.
- Mac App Store public submission still requires screenshots and App Privacy
  answers before review submission.

## Checksum

```text
3d233125df33d8efe73f291f3122ade5babd28411cd4a9d3a6e3901a5a50257e  Filmtone-1.5.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/chibatakumi-portfolio/issues`
