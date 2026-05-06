# Filmtone iOS Meta Before/After DaVinci Shell

This directory contains a small, non-final DaVinci Resolve starter shell for
Filmtone iOS Meta/Facebook/Instagram Before/After ad production.

It is intentionally placeholder-only:

- `layout_background_9x16.png` / `_15s.mp4`: 1080 x 1920 vertical safe-zone and
  placeholder layout.
- `before_horizontal_placeholder.png` / `_15s.mp4`: 1920 x 1080 Before media
  placeholder.
- `after_horizontal_placeholder.png` / `_15s.mp4`: 1920 x 1080 After media
  placeholder.
- `create_meta_before_after_shell.lua`: Resolve scripting helper that creates a
  30 fps, 1080 x 1920, 15-second timeline and imports the placeholder assets.
- `fix_current_shell_layout.lua`: optional helper for correcting an already
  open shell timeline to the current Before-top / After-bottom layout.

The user supplies the final footage and copy. Do not treat these placeholder
labels as public ad copy.

## Resolve Script

Run with DaVinci Resolve open:

```bash
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  docs/filmtone/ios/meta-before-after-davinci-shell/create_meta_before_after_shell.lua \
  docs/filmtone/ios/meta-before-after-davinci-shell
```

Expected result:

- Project: `Filmtone Meta BeforeAfter 2026-05` if no project is open.
- Timeline: `META_9x16_15s_STACKED_BEFORE_AFTER_v001` or the next available
  versioned name.
- Bins: `01_before`, `02_after`, `03_ui_or_screen_recording`, `04_audio`,
  `05_graphics_logo`, `06_timelines`, `07_exports`.
- Markers at frame 0, 60, and 360 for setup, reveal, and CTA replacement.

If an older generated timeline has the Before/After placeholders vertically
swapped, run:

```bash
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  docs/filmtone/ios/meta-before-after-davinci-shell/fix_current_shell_layout.lua
```
