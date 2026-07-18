# Filmtone DaVinci Resolve Plugin Delegation

Date: 2026-07-18 JST
Coordinator-owned: yes

This file is the execution contract for every dedicated Codex task in the
Filmtone Finish OpenFX lane. Product direction remains in `strategy.md`; live
state remains in `progress.md`; bounded scope remains in `workstreams/`.

## One Task, One Boundary

Every worker has exactly:

- one repository;
- one clean dedicated worktree;
- one immutable workstream plan;
- one dedicated progress record;
- one exclusive edit area;
- one returned handoff.

Cross-repository implementation is never assigned to one worker. Generic
contract work stays in `visual-effect-core`; the generated/public Filmtone
adapter is a separate Filmtone workstream.

Only the coordinator may:

- edit master `progress.md`;
- edit any immutable workstream plan after dispatch;
- change a workstream to `Ready` or `Accepted`;
- populate the Foundation Freeze Record;
- declare the next wave unblocked;
- integrate shared registration, build, or manifest files outside the
  integration workstream.

## State Machine

```text
Queued -> Ready -> Dispatched -> Running -> Review -> Accepted
             ^          |          |          |
             |          +----------+----------+
             |                  Paused / Blocked
             +-------------------------+
```

- `Queued`: dependencies or authorization are missing.
- `Ready`: coordinator has frozen the repository, base, scope, and prompt.
- `Dispatched`: a dedicated task exists but has not returned useful work yet.
- `Running`: the worker passed its start gate and is executing its loop.
- `Review`: the worker reached a terminal handoff; coordinator review remains.
- `Accepted`: handoff and ownership are accepted into the integration base.
- `Paused`: work is intentionally stopped without invalidating its result.
- `Blocked`: an external decision, dependency, conflict, or authorization is
  required. The coordinator returns it to `Ready` after resolution.

Workers report state; only the coordinator changes master state.

## Worker Loop

Repeat until a terminal condition:

1. Confirm repository, clean worktree, base, dependencies, and exclusive scope.
2. Select the smallest unfinished item that directly advances the plan's
   acceptance criteria.
3. Implement only that item.
4. Inspect status and diff read-only; reject accidental out-of-scope changes.
5. Record state, decisions, interfaces, files, limitations, and verification
   state in the dedicated workstream progress record and worker handoff.
6. Evaluate stop conditions, then continue or return the handoff.

Do not replace implementation progress with broad audits, cleanup, release
shell, issue hygiene, or speculative abstraction.

## Common Prohibitions

Unless the owner explicitly authorizes them in that worker task:

- do not run builds, tests, test-like verification, or Resolve;
- do not create or edit test files;
- do not install an OFX bundle;
- do not stage, commit, merge, rebase, push, or release;
- do not edit master `progress.md`;
- do not edit another worker's exclusive area;
- do not mutate the detached dirty planning worktree;
- do not silently add a lower-quality renderer or claim unsupported parity.

Implementation completion and verification completion are separate states. A
worker may reach `Review — verification blocked` when the code scope is done
but proof requires an action that is not authorized.

## Common Stop Conditions

Return a handoff immediately when any condition is true:

- the workstream Done conditions are reached;
- the worktree is dirty before worker changes or the base is not the assigned
  base;
- a dependency or public contract differs from the accepted handoff;
- an existing owner change overlaps the exclusive area;
- progress requires editing another workstream or a coordinator-owned file;
- a material product/architecture decision cannot be discovered locally;
- the same authorized operation fails three consecutive times;
- completion proof now requires an unauthorized build, test, Resolve launch,
  install, or Git write.

## Handoff Schema

Every terminal response uses this compact schema:

```text
Terminal state:
Repository / worktree / base:
Changed files:
Public interfaces or artifacts:
Decisions fixed:
Remaining work:
Blocker:
Verification performed:
Verification not performed:
Stop reason:
```

The coordinator reviews the returned diff and writes the authoritative result
into master `progress.md`. The worker progress record remains the detailed
execution evidence.

## Planning-Source Exception

The initial planning documents currently exist only in the coordinator's
detached dirty worktree. A worker launched from a clean worktree must treat the
coordinator-provided absolute planning paths as read-only input and return its
handoff in the task. It must not write back into that worktree.

This exception ends after the planning documents are integrated into an
owner-approved clean base. From that point, each worker updates only its own
dedicated progress record in its own worktree. Plans remain immutable unless
the coordinator explicitly changes scope.

## Launch Waves

1. Dispatch `CONTRACT` in `visual-effect-core` and `HOST` in Filmtone together.
2. After the `CONTRACT` source interface is statically accepted and frozen,
   dispatch `ADAPTER` in Filmtone; retain any explicit verification debt.
3. After `CONTRACT`, `ADAPTER`, and `HOST` are accepted, the coordinator freezes
   Foundation and dispatches `BREATH`, `WEAVE`, and `DAMAGE` together.
4. Dispatch `INTEGRATION` alone after all three feature modules are accepted.
5. Dispatch `QUALITY` only with explicit build/test/Resolve authorization.

## New Task Prompt Template

```text
Filmtone Finish OpenFXの <ID> workstreamを担当してください。

最初に対象repositoryのAGENTS.mdを読み、次に指定されたstrategy.md、
master progress.md、delegation.md、担当workstream plan、担当progress recordを
読んでください。計画元が別worktreeの絶対パスの場合はread-onlyで参照し、
書き戻さないでください。

開始ゲート:
- 対象repositoryと専用worktreeが正しい
- git status --shortがworker開始前に空
- HEAD/baseが委任時の指定と一致
- dependency handoff、exclusive edit area、担当progress recordが明確

delegation.mdのWorker Loopを、DoneまたはStop Conditionsまで自律的に
繰り返してください。質問は、ローカル資料と安全なread-only調査で解けず、
回答が実装を変える場合だけに限定してください。

禁止: tests/test files/build/Resolve/install、stage/commit/merge/rebase/push、
master progress.md・workstream plan編集、他worker領域の編集、範囲外cleanup。

終了時はdelegation.mdのHandoff Schemaだけを簡潔に返してください。
```
