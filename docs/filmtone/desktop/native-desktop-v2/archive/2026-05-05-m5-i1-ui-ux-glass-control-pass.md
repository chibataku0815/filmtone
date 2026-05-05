# M5-I.1 UI/UX Glass Control Pass

Date opened: 2026-05-05 JST
Milestone: M5 Native Editing UI

## Goal

Raise the Native Desktop v2 control quality for select boxes, buttons, and hover
cursor behavior while preserving the product rule that Apple Liquid Glass applies
to control chrome only, not the preview content layer.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/`
- Xcode project source membership only if a new Swift UI helper file requires it.

## Read-Only References

- User-provided Liquid Glass reference images for button hierarchy quality.
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- Existing M5-B / M5-F / M5-H comments in the Native Desktop UI files.

## Checklist

- [x] Add reusable glass control helpers for primary / secondary / tertiary controls.
- [x] Add enabled-only pointing-hand cursor behavior for custom controls.
- [x] Replace default-looking Source and Look menu pickers with full-width glass menu controls.
- [x] Bring Export format and Export action controls into the new hierarchy.
- [x] Apply consistent lower-hierarchy posture to inline library, adjust, reveal/share, cancel, and scrub controls.
- [x] Keep preview content layer free of glass changes.
- [x] Run `bun run verify:macos`.
- [x] Run `git diff --check`.

## Verification

- `bun run verify:macos` PASS. First run caught a SwiftUI `frame` API mismatch
  in the new helper; fixed, then reran successfully.
- `git diff --check` PASS.

## Done Conditions

- Source, Look, and Export Format controls no longer read as default system select boxes.
- Export/Open-class actions read as higher hierarchy than reset/reveal/share/delete actions.
- Enabled clickable controls show the pointing-hand cursor on hover; disabled controls do not imply clickability.
- Existing state, export, sidecar, color, playback, and release behavior remains unchanged.
- `bun run verify:macos` and `git diff --check` pass, or any failure is recorded with a clear blocker.

## Stop Conditions

- Done conditions met.
- Unexpected overlap with unrelated dirty worktree changes blocks safe implementation.
- Three consecutive `bun run verify:macos` failures caused by this UI change.

## Out Of Scope

- Color pipeline, sidecar schema, export mechanics, playback pipeline, LUT wiring, release cutover, signing, notarization, and portfolio updates.

## Unexpected Blockers

- None yet.
