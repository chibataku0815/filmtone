# Active — M5-J1/J2 v2 Integration Intake

Date: 2026-05-05 JST
Milestone: M5 Native Editing UI
Worktree: `filmtone-native-desktop-m5-j-integration`
Branch: `feature/native-desktop-m5-j-integration`

## Goal

Integrate the correctly rebased M5-J1 sidebar shell and M5-J2 compare worker
branches into the M5-J integration branch after M5-J3 v2.

## Scope

- Merge `feature/native-desktop-m5-j1-sidebar-shell-v2`.
- Merge `feature/native-desktop-m5-j2-compare-v2`.
- Resolve only integration conflicts caused by parallel work:
  - pbxproj UUID collision (`A3C/B3B`) between `EditorSidebar.swift` and
    `FilmtoneCompareCompose.swift`.
  - `RootWindowView.swift` additions from sidebar + compare.
  - `strategy.md` completion log ordering.
- Verify the integrated branch.

## Checklist

- [x] Confirm worker branches are clean and archived.
- [x] Merge M5-J1 v2.
- [x] Merge M5-J2 v2.
- [x] Resolve pbxproj / RootWindowView / strategy conflicts with both features retained.
- [ ] Run `apps/filmtone-desktop-macos/Verify/run.sh`.
- [ ] Run `bun run verify:macos`.
- [ ] Run `git diff --check`.
- [ ] Archive this active file.

## Done Conditions

- M5-J integration branch contains J1 commit `3f67a79c` and J2 commit `f9037a44`.
- Editor sidebar toggle (`⌘\`) and compare toggle (`V`) coexist.
- `EditorSidebar.swift` and `FilmtoneCompareCompose.swift` are both registered in the Xcode project with distinct UUIDs.
- Verification passes on the integration worktree.

## Out Of Scope

- Reworking worker implementations beyond conflict resolution.
- Visual smoke; user will run the app after integration.
