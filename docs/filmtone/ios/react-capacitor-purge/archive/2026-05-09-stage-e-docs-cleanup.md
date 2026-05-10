# Active: Stage E — Final docs cleanup

Date: 2026-05-09 JST
Branch: `worktree-feature-ios-react-capacitor-purge`
Status: **scoped — autonomous Stage E close 2026-05-09**

## Why this active exists

After Stages A → D removed the runtime + build-time Capacitor surface,
two doc / convention surfaces still referenced Capacitor and were
inconsistent with the actual app shape:

- `apps/capacitor-film-lab-ios/CLAUDE.md` §1 Capacitor-related row,
  §2 UI stack identity, §3 commit gate (`bun run build` step,
  `cap:sync:ios` references), §5 plugin surface row.
- `apps/capacitor-film-lab-ios/ios/.gitignore` had stale Capacitor
  ignore rules (`App/App/public/`, generated capacitor.config.json
  patterns).
- `docs/filmtone/ios/react-capacitor-purge/strategy.md` Completion
  Log needed the lane PASS entry.

Stage E rewrites those surfaces so a fresh contributor reading the
guide doesn't expect a Capacitor / React stack that no longer exists.

## Scope

- `apps/capacitor-film-lab-ios/CLAUDE.md`:
  - §1: drop the Capacitor row from the operating principles.
  - §2: change UI stack identity to **Native SwiftUI
    (`FilmtoneRootView`)** with a parenthetical note that the
    Capacitor stack was purged 2026-05-09.
  - §3 commit gate: drop the `bun run build` step. Only Swift
    contract verify + pbxproj 4-section grep + xcodebuild remain.
  - §5: drop the plugin surface row.
- `apps/capacitor-film-lab-ios/ios/.gitignore`:
  - Drop the Capacitor-specific ignore rules that no longer protect
    anything (the directories they referenced are gone).
- `docs/filmtone/ios/react-capacitor-purge/strategy.md`:
  - Append Lane PASS entry under Completion Log enumerating Stages
    A → E and the verification grep.

## Verification

```bash
grep -c -i Capacitor apps/capacitor-film-lab-ios/CLAUDE.md
# expect 1 — the Stage E note explaining when the purge happened

grep -c -i Capacitor apps/capacitor-film-lab-ios/ios/.gitignore
# expect 0

grep -rln 'import Capacitor\|CAPPlugin' apps/capacitor-film-lab-ios
# expect 0 (excluding node_modules — the workspace has none anyway
# after Stage B trimmed package.json)
```

## Outcome

PASS.

- `apps/capacitor-film-lab-ios/CLAUDE.md` rewritten — UI stack now
  reads "Native SwiftUI" as the canonical truth; no Capacitor /
  React references except the dated purge note.
- `apps/capacitor-film-lab-ios/ios/.gitignore` reduced to
  `App/build` / `App/Pods` / `App/output` / `DerivedData` /
  `xcuserdata`. No Capacitor-shaped lines.
- `react-capacitor-purge/strategy.md` Completion Log records the
  lane PASS plus the deferred fastlane archive verification (per
  owner stated split — release happens in a separate chat).

`grep -rln 'import Capacitor\|CAPPlugin' apps/capacitor-film-lab-ios`
returns 0. The lane is done at the source-tree layer.

## Post-merge follow-up (added 2026-05-09 JST after main merge)

The lane was merged into `main` as commit `47a1d76d` via `--no-ff`
merge of `worktree-feature-ios-react-capacitor-purge`. Two real
items surfaced during the merge that are worth recording for the
next contributor:

1. **pbxproj merge surgery** — main had received M9 / M13 / M14 /
   M15 work after the purge branch was cut, so the pbxproj diverged
   substantially. Resolution: take main's pbxproj as the base
   (`git checkout --ours`) then strip Capacitor-only UUIDs (5 files
   × 4 sections ≈ 20 lines) so main's M13/M14/M15 entries survive.
   The 5 files:
   - `FilmtoneBridgeViewController.swift` (UUID `B10000010000000000000003`)
   - `FilmtoneMediaPlugin.swift` (UUID `B10000010000000000000005`)
   - `capacitor.config.json` (UUID `50379B222058CBB4000EE86E`)
   - `config.xml` (UUID `2FAD9762203C412B000D30F8`)
   - `public` folder (UUID `50B271D01FEDC1A000F3C39B`)
2. **`pod install` rerun required after merge** — `Pods/` is
   gitignored so the merge did not touch it; the post-merge build
   failed with `The sandbox is not in sync with the Podfile.lock.`
   Running `pod install` in `apps/capacitor-film-lab-ios/ios/App/`
   removed `Capacitor` + `CapacitorCordova` from the working tree
   and the simulator build went green.

These items don't change the lane itself — they're consequences of
the worktree branching off before the M9 / 1.7-release prep work.
Future cross-cutting purge lanes that branch off mid-flight should
expect similar resolution.

Worktree (`/.claude/worktrees/feature-ios-react-capacitor-purge`)
removed and branch (`worktree-feature-ios-react-capacitor-purge`)
deleted after the merge landed on main.
