# M5-I Integration: Product Parity Recovery

## Milestone

M5 Native Editing UI / Product Parity Recovery

## Goal

Integrate the completed M5-I work and the parent worktree's relevant dirty
state into a clean branch, while keeping product UI, release-cutover docs, and
agent-rule updates separated by commit.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/`
- `apps/filmtone-desktop-macos/Verify/`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/`
- `docs/filmtone/desktop/release-cutover/`
- `scripts/release-*.mjs`
- `AGENTS.md`

## Read-only References

- Worktree `../filmtone-native-desktop-m5-i1-localization`
- Worktree `../filmtone-native-desktop-m5-i2-avplayer-preview`
- Worktree `../filmtone-native-desktop-m5-i4-control-polish`
- Worktree `../filmtone-native-desktop-m5-i4a-preview-background`
- Parent worktree `../filmtone-native-desktop-plan` dirty UI pass

## Checklist

- [x] Apply I1 localization/copy parity patch only.
- [x] Cherry-pick I2 AVPlayer preview route commit only.
- [x] Apply I4a preview/background patch after AVPlayer and resolve conflicts.
- [x] Choose one control-polish implementation and avoid duplicate control systems.
- [x] Integrate parent release-cutover / AGENTS dirty state in a separate commit.
- [ ] Run `git diff --check`.
- [ ] Run `apps/filmtone-desktop-macos/Verify/run.sh`.
- [ ] Run `bun run verify:macos`.
- [ ] Archive this active task and append a short strategy note.

## Done Conditions

- Integration branch contains M5-I product changes plus explicitly separated
  parent dirty release/agent updates.
- No unrelated iOS Backlight or stale handoff commits are pulled in.
- macOS Debug build succeeds.
- Verify harness passes.
- Remaining manual smoke risks are explicitly listed.

## Stop Conditions

- Three consecutive verification failures for the same root cause.
- A patch requires pulling unrelated non-M5-I commits.
- Two control-polish implementations cannot be reconciled without redesign.

## Out of Scope

- Push.
- Portfolio submodule bump.
- iOS Backlight implementation.
- Portfolio/public push.
