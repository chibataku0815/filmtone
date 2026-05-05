# M5-I Integration: Product Parity Recovery

## Milestone

M5 Native Editing UI / Product Parity Recovery

## Goal

Integrate the completed M5-I work into a clean branch without pulling unrelated
release-cutover, iOS, or agent-rule commits.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/`
- `apps/filmtone-desktop-macos/Verify/`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/`

## Read-only References

- Worktree `../filmtone-native-desktop-m5-i1-localization`
- Worktree `../filmtone-native-desktop-m5-i2-avplayer-preview`
- Worktree `../filmtone-native-desktop-m5-i4-control-polish`
- Worktree `../filmtone-native-desktop-m5-i4a-preview-background`
- Parent worktree `../filmtone-native-desktop-plan` dirty UI pass

## Checklist

- [x] Apply I1 localization/copy parity patch only.
- [ ] Cherry-pick I2 AVPlayer preview route commit only.
- [ ] Apply I4a preview/background patch after AVPlayer and resolve conflicts.
- [ ] Choose one control-polish implementation and avoid duplicate control systems.
- [ ] Run `git diff --check`.
- [ ] Run `apps/filmtone-desktop-macos/Verify/run.sh`.
- [ ] Run `bun run verify:macos`.
- [ ] Archive this active task and append a short strategy note.

## Done Conditions

- Integration branch contains only M5-I relevant changes.
- No unrelated release-cutover, iOS Backlight, or task-rule commits are pulled in.
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
- Release-cutover scripts/docs.
- iOS Backlight implementation.
- Public release version changes.
