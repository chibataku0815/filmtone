# Filmtone Native Desktop Transition Plan

Date: 2026-05-03 JST

Worktree:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`

Branch: `feature/native-desktop-plan`

## Canonical Planning Source

This dated transition plan is no longer the current planning source of truth.
Use the 2-layer planning model below:

```text
docs/filmtone/desktop/native-desktop-v2/
├── strategy.md
├── active.md
└── archive/
```

Read order for current work:

1. [native-desktop-v2/strategy.md](native-desktop-v2/strategy.md)
2. [native-desktop-v2/active.md](native-desktop-v2/active.md)

The old split plan files and handoffs remain historical references only.

## Why This Changed

The previous plan/handoff structure became too large and mixed strategy,
tactics, implementation notes, and history. Native Desktop v2 now uses:

- `strategy.md` for goals, milestones, Done conditions, constraints, and open
  questions.
- `active.md` for exactly one current subtask with file scope, steps,
  verification, Done conditions, and out-of-scope items.
- `archive/YYYY-MM-DD-{slug}.md` for completed active tasks.

Implementation must not start without an `active.md`.

## Current Operational State

At the time this index was migrated:

- M1 Native Contract And Skeleton: complete.
- M2 Still And Video Vertical Slice: complete.
- M3 Native Color And Optics Parity: in progress.
- The current active checkpoint is the C5b/C5d work already present in the
  worktree.
- Baseline-C population remains quality-shell work unless formal parity proof is
  requested.
- SPM consolidation remains deferred.
- Look Unification has not landed on main, so the native lane continues the
  current Case B sidecar posture until that changes.

For the live state, trust `native-desktop-v2/strategy.md` and
`native-desktop-v2/active.md` over this file.

## Historical References

The previous detailed plan lives in:

```text
docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/
```

Selected handoffs are still useful for archaeology, but not as current truth:

- `filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md`
- `filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md`
- `filmtone-native-desktop-phase1c-completion-handoff-2026-05-03-jst.md`
- `filmtone-native-desktop-phase2-master-handoff-2026-05-03-jst.md`
- `filmtone-native-desktop-phase2-c5a-master-handoff-2026-05-03-jst.md`
- `filmtone-native-desktop-phase2-c5b-a2-master-handoff-2026-05-04-jst.md`
- `filmtone-native-desktop-phase2-c5c-master-handoff-2026-05-04-jst.md`

Do not add new long-form handoffs unless the user explicitly asks for one.
