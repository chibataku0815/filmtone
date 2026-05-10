# Active — M8 Inspector Bottom Hit Testing

Date opened: 2026-05-06 JST
Milestone: `M8 Inspector Bottom Hit Testing`

## Goal

Fix the Native Desktop right inspector so visible bottom controls are actually
clickable at their current scroll position. The reported case is the Quick
panel's Backlight Veil / Intensity / Adjust area: it is visible at the bottom of
the inspector, but cannot be pressed until the user scrolls it farther upward.

Visible controls must be hit-testable. If a control cannot be acted on, the UI
must make that disabled / unavailable state clear.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
- `apps/filmtone-desktop-macos/Verify/main.swift` if a small geometry/hit-test
  contract can prove the fix.
- this `active.md`

## Read-only References

- User screenshot: bottom of the right rail shows Backlight Veil controls inside
  a red box; controls are visible but do not respond until scrolled upward.
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m5-m3-right-rail-slide-in-two-row-scrub.md`

## Checklist

- [x] Inspect the inspector / scrub overlay geometry and identify what steals or
  blocks bottom hit testing.
- [x] Make visible Quick panel controls hit-testable without requiring extra
  scroll offset.
- [x] Preserve the 2-row scrub bar and portrait right-rail behavior.
- [x] Use clear disabled styling only for genuinely unavailable commands.
- [x] Run focused verification and update this task.
- [x] Archive this task and append a short completion note to `strategy.md`.

## Verification

2026-05-06 JST:

- Root cause: the bottom scrub overlay used a full-window `VStack` /
  `Spacer` layout, mounted after the right inspector in the `ZStack`. Its
  transparent bottom/right-side layout area could receive hit testing above the
  visible inspector controls, so Backlight Veil controls looked active but did
  not respond until scrolled above that band.
- Fix: right inspector now has explicit `zIndex(2)`, scrub overlay has
  `zIndex(1)`, and scrub overlay layout scopes hit testing to the visible
  `VideoScrubBar` capsule by marking transparent vertical/horizontal spacers
  and bottom padding as non-hit-testing.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` -> 121/121 passed.
- `bun run verify:macos` -> BUILD SUCCEEDED.
- `git diff --check` -> clean.

## Done Conditions

- Backlight Veil chips, Intensity slider, and Adjust button can be pressed while
  visible at the lower edge of the right inspector.
- Invisible overlays do not intercept the right inspector's bottom controls.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passes.
- `bun run verify:macos` passes.
- `git diff --check` passes.

## Stop Conditions

- Done conditions are met.
- Stop on an unexpected blocker that requires a broader inspector redesign,
  release/version work, or unrelated iOS changes.
- Stop after 3 consecutive verification failures on the same step.

## Out Of Scope

- Mac App Store / DMG release work.
- Portfolio submodule bump, staging, commit, push, or deployment.
- New controls or new color/optics behavior.
- Unrelated iOS changes already present in the worktree.

## Unexpected / Blockers

None yet.
