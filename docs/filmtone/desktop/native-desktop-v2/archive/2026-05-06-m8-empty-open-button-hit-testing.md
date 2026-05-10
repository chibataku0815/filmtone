# M8 Empty Open Button Hit Testing

Milestone: M5 Native Editing UI follow-up
Date opened: 2026-05-06 JST

## Goal

Make the empty-state `素材を開く` button reliably clickable in the launched
Native Desktop app.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift` only if
  the root overlay stack is involved

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m8-opening-open-panel-foreground.md`

## Checklist

- [x] Confirm the empty-state background/button layering.
- [x] Confirmed the CTA receives clicks; the failure is invisible modal
  presentation after the click, not background hit-test interception.
- [x] Preserve the toolbar Open path and switch to app-modal picker
  presentation.
- [x] Run Native Desktop verification and whitespace check.
- [x] Launch the current Debug build for visual confirmation.
- [x] Confirm via accessibility click that `素材を開く` opens the macOS Open
  panel in front of Filmtone.
- [x] Archive this task and append a compact strategy note.

## Verification

- `bash apps/filmtone-desktop-macos/Verify/run.sh` -> 121/121 passed.
- `bun run verify:macos` -> BUILD SUCCEEDED.
- `git diff --check` -> clean.
- Computer Use clicked the empty-state `素材を開く` button; the Open panel became
  the frontmost Filmtone window.

## Done Conditions

- The empty-state CTA receives clicks.
- Toolbar Open remains functional.
- Verification passes.

## Stop Conditions

- Done conditions met.
- Hit testing requires deeper AppKit window restructuring beyond the empty
  surface.
- 3 consecutive verification failures.

## Out Of Scope

- Empty-state redesign.
- Media import type changes.
- Release packaging or metadata updates.

## Unexpected Blockers

None yet.
