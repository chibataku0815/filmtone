# Filmtone Native Desktop Transition Plan

Date: 2026-05-03 JST

Worktree:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`

Branch: `feature/native-desktop-plan`

This file is the canonical index. Keep it short. Detailed plan material lives in:

```text
docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/
```

## Current State

- **Phase 0 (Contract & Skeleton): COMPLETE.** All 8 acceptance gate checks
  pass. macOS native app launches on macOS 26.4.1 with Xcode 26.4.1.
- **Phase 1a (Open + Preview precondition): COMPLETE.** Decision A adopted:
  `SharedGenerated/FilmtonePhase0Generated.swift` is compile-linked through
  macOS-local Phase0 type stubs, `NSOpenPanel` / `⌘O` opens still images, and
  `PreviewSurface` renders a no-grade preview through `NSImageView`.
- **Next: Phase 1b.** Preset selection -> grade application -> still export ->
  sidecar JSON -> Electron baseline-B PSNR parity. Phase 1c is the video slice.

## Read Order

1. [01-current-state-and-decision.md](native-desktop-transition-plan-2026-05-03-jst/01-current-state-and-decision.md)
   - status, purpose, product decision, current platform facts
2. [02-target-architecture-and-contracts.md](native-desktop-transition-plan-2026-05-03-jst/02-target-architecture-and-contracts.md)
   - app shell, media/render core, performance render spine, data contract
3. [03-migration-and-concurrent-lanes.md](native-desktop-transition-plan-2026-05-03-jst/03-migration-and-concurrent-lanes.md)
   - parallel migration strategy and Desktop Look Unification dependency
4. [04-phase-plan.md](native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md)
   - Phase 0-5 deliverables, gates, verification, first implementation order
5. [05-future-lanes.md](native-desktop-transition-plan-2026-05-03-jst/05-future-lanes.md)
   - Continuity Export on Mac and Resolve / Pro NLE integration
6. [06-quality-gates-risks.md](native-desktop-transition-plan-2026-05-03-jst/06-quality-gates-risks.md)
   - quality gates, open questions, risks, definition of done

## Core Rule

Native Desktop v2 is a parallel product lane. Electron Desktop remains the
shipping rail until the native app beats it on preview/export quality.

Do not let documentation, release shell, CloudKit/Handoff, Resolve, OFX, DCTL,
or public copy work delay the next product proof:

```text
Phase 1b: preset -> grade -> still export -> sidecar -> PSNR parity
```

## Canonical Handoffs

- Phase 0 completion:
  [filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md](filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md)
- Phase 1a completion / Phase 1b entry:
  [filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md](filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md)
- Phase 0 internal design plan:
  `~/.claude/plans/luminous-sparking-eclipse.md`

## Update Policy

- Keep this index under roughly 100 lines.
- Put detailed changes into the numbered files.
- If a new implementation handoff supersedes the current phase, update
  `Current State` and `Canonical Handoffs` here.
- Keep links relative so this file works inside the worktree and in GitHub.
