# Active — M5-M.3 Portrait inspector right-rail slide-in + 2-row scrub bar

Date opened: 2026-05-06 JST
Milestone: `M5-M.3 Portrait inspector right-rail slide-in`
Branch: `fix/native-desktop-look-veil-energy-max-merge`
Predecessor: `archive/2026-05-06-m5-m-portrait-with-recovery-rounds.md` (M5-M
landed + earlier failed visual rounds: black-matte/rail/widening, then
media-derived blurred backdrop, then bottom-sheet slide-up).

## Goal

Final portrait inspector posture after the bottom-sheet slide-up was
rejected on visual smoke. The right-rail surface is now the single
canonical inspector for both orientations — visibility is what differs:

1. Loaded source backdrop = solid `Color.black` (iOS canonical recipe).
   Unchanged from the prior round.
2. Inspector = `EditorSidebar` (320pt right rail) for both portrait and
   landscape. Portrait defaults closed via
   `@AppStorage("editorPortraitInspectorOpen")` and slides in from the
   trailing edge on ⌘\\; landscape keeps `editorSidebarOpen` (default
   true). The same `EditorPanelStack` content (Source / Look / Quick /
   Export) is shared.
3. Scrub bar split to 2 rows (transport + markers) so a narrow portrait
   window doesn't squeeze the slider, bookmark and jump-prev/next chips,
   and speed menu into one cramped row.
4. Inspector's bottom edge clears the floating scrub bar (via
   `sidebarBottomPadding`) so the user can scrub while the inspector is
   summoned — the rail is shorter, not the scrub bar narrower.

Out of scope: iOS / iOS sidecar / iOS Profile.version, color & export
pipeline, schema bump, packaging / notarization / portfolio submodule
bump, Verify harness contract test for the slide-in (visual smoke is the
gate), Look / Quick / Export panel internals, optical filter families.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift`
  - Drop `EditorBottomSheet`. Keep `EditorSidebar` + `EditorPanelStack`
    + `EditorSidebarPanelGlass`. Update header to describe the shared
    right-rail posture across both orientations.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  - Rename `bottomSheetOpen` → `portraitInspectorOpen`; @AppStorage key
    `editorBottomSheetOpen` → `editorPortraitInspectorOpen`.
  - Replace bottom-sheet `GeometryReader` branch in `editorOverlayLayout`
    with a single `if inspectorVisible { EditorSidebar(...) }` mount,
    `.transition(.move(edge: .trailing).combined(with: .opacity))`.
  - Drop the second portrait branch entirely. Both orientations now use
    the same right-rail mount, padded with `sidebarBottomPadding`.
  - Bump `sidebarBottomPadding` for video so the rail's bottom edge
    clears the 2-row scrub bar capsule + bottom inset:
    portrait video = 116, landscape video = 156, non-video = 24.
  - Animate both `sidebarOpen` and `portraitInspectorOpen` with the same
    spring so the slide-in feels equivalent regardless of orientation.
  - Refactor `VideoScrubBar.capsule` from a single HStack to
    `VStack(spacing: 8)` of two HStacks:
      * `transportRow`: play | currentTime | sliderArea | totalTime | speed
      * `markersRow`: bookmark+ | (HighlightMarkerMenu) | prev | next | Spacer
    Reduce vertical padding from 16 → 12 so the 2-row capsule doesn't
    grow too tall.

## Done conditions

- [x] `EditorSidebar.swift` no longer declares `EditorBottomSheet`. Header
  comment describes the shared right-rail posture.
- [x] `RootWindowView.swift` renames the storage key and variable;
  `editorOverlayLayout` mounts a single `EditorSidebar` for both portrait
  and landscape; transition is `.move(edge: .trailing)`.
- [x] `sidebarBottomPadding` clears the 2-row scrub bar for both portrait
  and landscape video.
- [x] `VideoScrubBar.capsule` is a VStack of `transportRow` + `markersRow`.
- [x] `git diff --check` clean.
- [x] `bash apps/filmtone-desktop-macos/Verify/run.sh` → 121/121 passed.
- [x] `bun run verify:macos` → BUILD SUCCEEDED.
- [ ] User visual smoke (Debug app):
  - portrait clip — media fills window, no left/right black bars,
    inspector default-closed, ⌘\\ slides the rail in from the right,
    dismiss → media unobstructed
  - landscape clip — right rail behavior unchanged, ⌘\\ still toggles
  - both orientations — scrub bar visible and operable while inspector is
    open (rail's bottom edge sits above scrub bar)
  - scrub bar — 2 rows, transport row drives playback, markers row
    handles bookmark add / jump-prev / jump-next without crowding
  - still — both portrait + landscape inspector behavior matches video
  - empty launch — branded plate + Liquid Glass field, compact
  - Backlight Veil chip + cursor still drive visible preview change
- [ ] Archive this `active.md` to `archive/` and append a 1–3 line note
  to `strategy.md` after visual smoke passes.

## Verification

```bash
git diff --check
bash apps/filmtone-desktop-macos/Verify/run.sh
bun run verify:macos
```

Then open the Debug app
(`apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app`)
and run the smoke list above.

## Stop conditions

- Done when the visual smoke is acceptable.
- Stop on an unexpected blocker that would force out-of-scope changes.
- Stop after 3 consecutive verification failures on the same step.

## References

- iOS canonical portrait recipe (read-only):
  - `apps/capacitor-film-lab-ios/src/features/editor/MobilePhase0Editor.tsx`
  - `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePreviewView.swift`
  - `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePreviewPlayerView.swift`
- Memory: `feedback_no_black_matte_for_glass_exposure` (2026-05-06) — locks
  the "no black matte / no continuous rail / no widening for sidebar"
  ceiling. Window aspect stays locked to source aspect; the only
  background visible is solid `Color.black` (iOS canonical letterbox).
- `feedback_check_legacy_ui_conventions_before_new_ui` — ⌘\\ shortcut
  preserved; landscape default-open behavior preserved; portrait
  default-closed mirrors the iOS pattern of summoning the inspector on
  demand from a non-overlap posture.
