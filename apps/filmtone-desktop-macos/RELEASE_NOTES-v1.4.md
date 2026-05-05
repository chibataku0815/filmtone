# Filmtone Desktop v1.4

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.4 is the native macOS cutover release. It replaces the legacy Electron
> Desktop line for macOS 26 users and aligns Desktop with the iOS Filmtone
> product model.

### Native Mac app

Filmtone Desktop is now a native SwiftUI/AppKit Mac app. The app keeps the same
Desktop Bundle ID, so it can replace the existing Electron Desktop install, but
the editing surface, media preview, and export flow are rebuilt for macOS.

Control surfaces use the macOS 26 Liquid Glass direction while loaded media
preview stays glass-free for color judgment.

### iOS-aligned editing flow

The native app follows the iOS product model more closely:

- built-in Filmtone Looks and Look strength
- still image and video preview
- still image and video export
- source profile / camera conversion handling
- before/after compare with a draggable split
- video playback, rate controls, scrubbing, and thumbnail preview
- compatible sidecar output for exported media

### Better first-run and review confidence

The opening screen, toolbar, sidebar, compare tool, Look controls, and video
scrub bar have been polished for the native desktop workflow. Hovering or
dragging on the video scrub bar can show a graded thumbnail preview for faster
review without moving the seek bar.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- This release is a replacement Desktop app, not a separate parallel product.
- Existing users should install the new `Filmtone.app` from the v1.4 DMG.

## Known limits

These are accepted follow-ups for this cutover:

- Source profile auto-selection needs broader real-media coverage beyond the
  verified Apple Log / Apple Log 2 path.
- Backlight Veil is available, but difficult backlit footage should be watched
  for iOS/Desktop visual tuning.
- iOS-style advanced recipe chips (`None` / `Default` / `Strong`) are visible,
  but longer-session Desktop QA should confirm the model is understandable.

## Checksum

```text
40d2b2fd745c648849d310856e2bcd5d0db0afd948b3842fd83800f68e705cb8  Filmtone-1.4.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/chibatakumi-portfolio/issues`
