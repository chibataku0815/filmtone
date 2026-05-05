# M5-K1 Chrome Stability + Opening Readability

Date opened: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-k1-chrome-opening`
Branch: `feature/native-desktop-m5-k1-chrome-opening`
Base commit: `0b79861f`

## Milestone

M5 Native Editing UI — post-J visual follow-up slice K1.

## Goal

Two product issues from `archive/2026-05-05-native-desktop-v2-post-j-visual-handoff.md`:

1. **Toolbar icon flicker** when the editing sidebar opens/closes via toolbar
   button or `⌘\`. Fix without changing toolbar actions, shortcuts, or the
   transparent unified-glass posture.
2. **Opening screen readability**: the current fully clear Apple Liquid Glass
   field is hard to see over arbitrary desktops. Establish enough contrast for
   icon / title / subtitle / Open button while keeping the premium glass
   direction and an app-first (not marketing-page) feel.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneGlassControls.swift`
  (only if a stable button helper is needed; default is no edit)
- `docs/filmtone/desktop/native-desktop-v2/active.md` (this file)
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` (1-3 line completion
  note on archive)

## Read-Only References

- `archive/2026-05-05-native-desktop-v2-post-j-visual-handoff.md` (in the parent
  worktree at `filmtone-native-desktop-plan/...`; copied conceptually here)
- `archive/2026-05-05-m5-i4a-clear-opening-glass-follow-up.md`
- `archive/2026-05-05-m5-i4a-opening-true-transparency.md`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift`
- `AGENTS.md` § Long-Running Task Model

## Approach

### Toolbar flicker

Likely cause: each `ToolbarItem` swaps either its `Label` title
(`"Hide Inspector" ↔ "Show Inspector"`) or its `systemImage`
(`"rectangle.split.2x1" ↔ ".fill"`) when state flips. Pair that with the
sidebar's conditional `if sidebarOpen { EditorSidebar(...) }` insertion in
the root `ZStack`, and SwiftUI re-evaluates the whole body — the toolbar
items lose stable identity and visibly redraw.

Fix without architectural changes:

- Give each `ToolbarItem` an explicit stable `id:` so identity is preserved
  across body re-evaluations.
- Stabilise the `Label` content:
  - Sidebar button: fixed title `"Inspector"` and fixed `systemImage`.
    The Hide/Show distinction moves to `.help(...)` only.
  - Compare button: fixed `Label("Compare", systemImage: "rectangle.split.2x1")`,
    state shown via `.symbolVariant(state.isCompareEnabled ? .fill : .none)`
    so the icon glyph changes without reissuing the Label string.
- Do not change shortcuts, placements, or `.buttonStyle(.glass)`.

### Opening readability

`BrandedOpeningBackdrop` keeps clear-glass posture but adds a subtle dark
neutral wash so brand/CTA text is readable over bright desktops; the
`EmptyPreviewLabel` content gets a bounded luminous field (rounded glass
plate) behind the icon / title / subtitle / Open button to anchor it.
Loaded media preview path (`NeutralFrostedPreviewMatte` + `Image(nsImage:)`)
is untouched, so the preview content layer remains glass-free.

## Checklist

- [x] Toolbar `ToolbarItem`s gain stable `id:` and stable `Label` content.
- [x] Sidebar Hide/Show distinction moved to `.help(...)` only.
- [x] Compare fill/non-fill switches via `.symbolVariant(...)` (stable Label).
- [x] `BrandedOpeningBackdrop` adds a subtle dark neutral wash for readability.
- [x] `EmptyPreviewLabel` gets a bounded luminous field behind brand/CTA.
- [x] Loaded `NeutralFrostedPreviewMatte` path untouched.
- [x] Compare path (`FilmtoneCompareCompose`, video render inputs, sidecar)
      untouched.
- [x] Shortcuts preserved: `⌘O`, `⌘\`, `V`, Space, 1×/2×/3×.
- [x] Run verification (see below).
- [x] Archive this `active.md` to `archive/2026-05-05-m5-k1-chrome-opening.md`.
- [x] 1-3 line note appended to `strategy.md` Completion Log.

## Verification

Required (run from the worktree root):

```bash
bash apps/filmtone-desktop-macos/Verify/run.sh
bun run verify:macos
git diff --check
pkill -x Filmtone 2>/dev/null || true
open -n apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app
```

Visual smoke (user):

- Toggle sidebar via toolbar `sidebar.right` button and via `⌘\`. Toolbar
  icons should not flicker / jump / re-opacity.
- Compare toggle (`V`) flips icon glyph fill cleanly without redrawing
  neighbouring icons.
- Empty state legible over a light desktop background and over a dark
  desktop background.
- After opening media, preview matte stays neutral and glass-free for
  color judgment.

Result:

- `apps/filmtone-desktop-macos/Verify/run.sh` — PASS (65/65, no UI tests
  affected; UI changes are .swift compilation only).
- `bun run verify:macos` — PASS (xcodebuild Debug clean).
- `git diff --check` — clean.
- Debug app build artifact present at
  `apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app`.
- Visual smoke: deferred to user (no regression in Verify or xcodebuild).

## Done Conditions

- Sidebar toggle via toolbar button and `⌘\` does not visibly flicker the
  Open / Compare / Export / Inspector toolbar icons.
- Empty opening screen reads with adequate contrast over arbitrary desktop
  backgrounds, while remaining premium Liquid Glass and not opaque.
- Loaded media preview material is unchanged (no glass over content layer).
- Compare remains preview-only; export/sidecar paths untouched.
- All listed shortcuts still fire as before.
- Verify run.sh, `bun run verify:macos`, and `git diff --check` all pass.

## Stop Conditions

- Done conditions met → archive and append strategy note.
- Unexpected blocker → record under `Unexpected` and stop.
- N=3 consecutive failures of either `Verify/run.sh` or `verify:macos` →
  stop and hand back; do not loop fixes blindly.

## Out Of Scope

- M5-K2 Look + Strength grouping.
- M5-K3 Draggable compare bar / split-fraction model.
- M5-K4 Scrub thumbnail preview.
- AVPlayer playback architecture, sidecar schema, export inspector.
- Localization copy changes beyond the existing strings.
- Loaded preview matte redesign.
- Toolbar restructuring (no new items, no order changes).

## Unexpected Blockers

(none — to be filled in if encountered)
