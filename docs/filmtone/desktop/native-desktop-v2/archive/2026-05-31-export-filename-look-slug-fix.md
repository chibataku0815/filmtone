# Native Desktop v2 Active Task: Export Filename Look Slug Fix

Milestone: Native Desktop v1.14 Follow-up

Goal: Fix native Desktop export default filenames so active built-in Looks use
their Look slug instead of the underlying compatibility preset name such as
`reset`.

Edit targets:
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift`
- Focused Desktop verify tests if an existing harness covers filename
  suggestion behavior
- This active task doc

Read-only references:
- `/Users/chibatakumi/Movies/P1290493-reset.filmtone.json`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift`

Checklist:
- [x] Confirm current filename generation path and the Look identity source.
- [x] Replace preset-name filename suffixing with a Look-aware export slug.
- [x] Add or update focused Desktop verification coverage.
- [x] Run the smallest verification that proves the fix.
- [x] Record result and archive this task.

Verification:
- `git diff --check` passed.
- `apps/filmtone-desktop-macos/Verify/run.sh` compiled and the new export
  filename regression tests passed:
  - `export filename uses built-in Look slug instead of reset preset`
  - `export filename keeps preset suffix when no Look is active`
  - `export filename applies the same Look suffix to still export formats`
  - `export filename falls back to sanitized unknown Look slug`
- The same full verify run ended `155/160 passed, 5 failed` because existing
  AdvancedAdjustCatalog expectations do not yet account for the in-progress
  Film Damage group in the dirty worktree. Those failures are outside this
  filename fix.
- `bun run verify:desktop` passed (`** BUILD SUCCEEDED **`).

Result:
- Built-in Look exports now default to `P1290493-stone.mp4` /
  `P1290493-noir.png` instead of `P1290493-reset.*`.
- Preset-only exports still default to the preset suffix, e.g.
  `P1290493-reset.mp4`.
- No sidecar identity behavior was changed.

Copy / History Impact:
- No copy/history impact: this changes only the default local save-panel
  filename suggestion.
- Article Opportunity: No story.
- Change-History Opportunity: No story.

Done conditions:
- Stone / Urban / Noir exports default to Look-based filenames instead of
  `reset`.
- Preset-only exports keep preset-based filenames.
- Existing sidecar identity behavior remains unchanged.

Stop conditions:
- Done conditions met.
- Filename generation is tightly coupled to unrelated dirty worktree changes and
  cannot be changed without reverting user work.
- 3 consecutive verification failures on the same unresolved root cause.

Out of scope:
- Public release packaging/upload.
- Renaming already exported files.
- Legacy Electron Desktop.

Unexpected blockers:
- Full Desktop verify is currently red from unrelated in-progress Film Damage
  catalog expectation drift; the filename-specific tests and Xcode app build
  are green.
