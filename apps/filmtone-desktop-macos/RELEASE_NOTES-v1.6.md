# Filmtone Desktop v1.6

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `26.0+`
- Architecture: Universal (`arm64` + `x86_64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.6 is a focused Native Desktop bug-fix release after v1.5. It restores full
> right-rail control reachability with video sources loaded and includes small
> UI simplifications approved for this release.

### Right rail reaches the window bottom

The right inspector rail now extends to a 24pt window-bottom inset for every
source kind. When the inspector is open over a video source, the floating scrub
bar reserves a right gutter equal to the inspector footprint, so the scrub
capsule sits beside the rail instead of underneath it.

### Right rail lower-half hit dead zone fixed

The inspector no longer uses the macOS 26 `GlassEffectContainer` wrapper around
the inspector ScrollView. That wrapper's NSView-backed morphing surface claimed
hits in the lower window y-band even when SwiftUI z-ordering placed the
inspector above the scrub layer. Per-panel Apple Liquid Glass styling remains
in place, and the full rail accepts hover, click, drag, and scroll from top to
bottom.

### Opening and backdrop simplification

The empty opening state now shows the Filmtone mark, title, and instruction
copy without the central `素材を開く` CTA. Open material from the toolbar `Open`
button or `Command-O`.

Loaded media now uses a media-derived blurred and dimmed backdrop behind the
aspect-fit preview, so Apple Liquid Glass chrome samples a coherent continuation
of the foreground frame instead of a flat black matte.

### Quick adjust intensity row

The Backlight Veil Intensity slider now appears only when a density chip is
selected. With `None` selected, the panel shows only the chips instead of a
disabled-looking slider.

## Compatibility

- Requires macOS 26 or later.
- Desktop v1.0.4 remains the frozen legacy Electron build for pre-macOS-26
  users.
- Existing Native Desktop users should replace the app from the v1.6 DMG.
- Sidecar output remains compatible; v1.6 does not require a schema bump.

## Known limits

- The compact empty-state CTA click target is intentionally not restored in
  v1.6; opening is through the toolbar or `Command-O`.
- Broader real-media Source Auto / Conversion LUT population testing remains a
  follow-up beyond the accepted Apple Log / Apple Log 2 path.

## Checksum

```text
5437abbc2aa7a01ee0d1d5a8f9a23945d5d3cabbae60916ca2a19eaafad0fa94  Filmtone-1.6.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
