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
- [x] Run `git diff --check`.
- [x] Run `apps/filmtone-desktop-macos/Verify/run.sh`.
- [x] Run `bun run verify:macos`.
- [x] Archive this active task and append a short strategy note.

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

## Verification

- `git diff --check` clean.
- `apps/filmtone-desktop-macos/Verify/run.sh`: 65/65 passed.
- `bun run verify:macos`: Debug build succeeded after restoring the I4a
  `WindowAccessor` / `RootSafeAreaTopInsetKey` helpers lost during the parent
  UI conflict resolution.

## Remaining Manual Smoke Risks

- Compare bar / before-after wipe is not implemented in this integration.
- AVPlayer preview path builds and should remove timer-driven stutter, but real
  footage smoothness still needs user visual smoke on representative clips.
- Final release artifact regeneration / notarization is intentionally later,
  after product-scope visual smoke freezes.
