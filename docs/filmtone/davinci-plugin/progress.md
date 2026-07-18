# Filmtone DaVinci Resolve Plugin Progress

Date: 2026-07-18 JST
Coordinator-owned: yes

This is the only master progress record for the OpenFX lane. Worker chats must
not edit this file. Workstream plans are immutable after dispatch. Workers
update only their assigned record under `workstreams/progress/`; the
coordinator incorporates terminal handoffs here after review.

All dispatches follow `delegation.md`. Master states are:
`Queued -> Ready -> Dispatched -> Running -> Review -> Accepted`, with
`Paused / Blocked` as explicit side states.

## Current Product Decision

- Product surface: working name `Filmtone Finish`.
- Target: DaVinci Resolve 21, macOS Apple Silicon, OpenFX + Metal.
- Playback: real-time not required; stopped-frame adjustment must be practical.
- Modules: Film Breath, Gate Weave, Film Damage.
- Defaults: every module off; exact identity.
- Placement: after CinePrint35 by default; effect remains movable.
- CinePrint overlap: never stack Gate Weave or Dust by default.
- Source ownership: Film Breath in Filmtone; generic Film Damage / Gate Weave
  in `visual-effect-core`; Filmtone mapping in `filmtone-pack`.
- Foundation implementation: CONTRACT/HOST source scopes complete with
  verification debt; ADAPTER running.
- Tests, installation, and release: not started.

## Workstream Status

| ID | Plan | Progress | Repository | Depends on | State |
|---|---|---|---|---|---|
| `CONTRACT` | [Plan](workstreams/contract-and-product-mapping.md) | [Progress](workstreams/progress/contract-and-product-mapping.md) | visual-effect-core | planning | Review — interface frozen; verification blocked |
| `HOST` | [Plan](workstreams/ofx-host-foundation.md) | [Progress](workstreams/progress/ofx-host-foundation.md) | Filmtone | planning | Review — verification blocked |
| `ADAPTER` | [Plan](workstreams/filmtone-contract-adapter.md) | [Progress](workstreams/progress/filmtone-contract-adapter.md) | Filmtone | CONTRACT interface freeze | Running; clean-base gate passed |
| `BREATH` | [Plan](workstreams/film-breath.md) | [Progress](workstreams/progress/film-breath.md) | Filmtone | CONTRACT + ADAPTER + HOST | Blocked |
| `WEAVE` | [Plan](workstreams/gate-weave.md) | [Progress](workstreams/progress/gate-weave.md) | Filmtone | CONTRACT + ADAPTER + HOST | Blocked |
| `DAMAGE` | [Plan](workstreams/film-damage.md) | [Progress](workstreams/progress/film-damage.md) | Filmtone | CONTRACT + ADAPTER + HOST | Blocked |
| `INTEGRATION` | [Plan](workstreams/resolve-integration.md) | [Progress](workstreams/progress/resolve-integration.md) | Filmtone | BREATH + WEAVE + DAMAGE | Blocked |
| `QUALITY` | [Plan](workstreams/visual-quality.md) | [Progress](workstreams/progress/visual-quality.md) | Filmtone + Resolve | INTEGRATION + explicit authorization | Blocked |

## Parallel Launch Order

```text
CONTRACT ── ADAPTER ─┐
                     ├─ foundation freeze ─┬─ BREATH ─┐
HOST ────────────────┘                     ├─ WEAVE  ─┼─ INTEGRATION ─ QUALITY
                                           └─ DAMAGE ─┘
```

`CONTRACT` and `HOST` started together. `ADAPTER` may start after the CONTRACT
source interface is frozen even when verification debt is explicitly retained.
The three feature chats start only after the coordinator accepts all Foundation
source handoffs and records the exact contract revision, generated handoff
path, plugin interface, and clean integration base.

## Dispatch Record

| ID | Task | Worktree mode | Assigned base | State |
|---|---|---|---|---|
| CONTRACT | `019f7416-8ed4-7023-947d-8f5d0570f38c` | `/Users/chibatakumi/.codex/worktrees/7057/visual-effect-core` | `84efd1a8a5dae0edd3afb777a0428739f7c1e72b` | Review — interface frozen; verification blocked |
| HOST | `019f7416-9bd1-7e12-a95e-cfee8eda1797` | `/Users/chibatakumi/.codex/worktrees/a45d/filmtone` | `a840634ac2a630df36b10d414ec1c4e53f27a6ce` | Review — verification blocked |
| ADAPTER | `019f7438-f67e-7c11-80fc-81839b706589` | `/Users/chibatakumi/.codex/worktrees/66f1/filmtone` | `a840634ac2a630df36b10d414ec1c4e53f27a6ce` | Running; clean-base gate passed |

The current planning source is detached and dirty. Until these documents are
integrated, dispatched workers read the coordinator-provided absolute planning
path read-only and return their structured handoff in-task. They never write
to the planning worktree.

## Proposed File Ownership

The exact scaffold may refine these paths, but ownership must remain disjoint.

| Workstream | Exclusive edit area |
|---|---|
| CONTRACT | External Film Damage contract / reference / `filmtone-pack` finish mapping only; Filmtone is read-only. |
| ADAPTER | Filmtone generated/public C++ adapter and generator boundary only; external repository read-only. |
| HOST | `apps/filmtone-resolve-ofx/` host wrapper, initial Makefile, bundle resources, shared processor interfaces. |
| BREATH | `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/` only. |
| WEAVE | `apps/filmtone-resolve-ofx/Sources/Effects/GateWeave/` only. |
| DAMAGE | `apps/filmtone-resolve-ofx/Sources/Effects/FilmDamage/` only. |
| INTEGRATION | Root effect registry, OFX descriptor/parameter pages, shared pass graph, build source list, bundle manifest, optional sidecar/Lua integration. |
| QUALITY | Tuning profiles, evidence, usage guidance, performance notes, packaging decisions after behavior is accepted. |

Feature workers must not edit:

- `OFX::Plugin::getPluginIDs` or the root effect factory;
- the root Makefile/source list;
- shared Metal pipeline cache code;
- product identifiers or bundle metadata;
- `package.json`;
- Filmtone sidecar writers;
- `filmtone_connect_import_package.lua`;
- master `progress.md`.

## Existing Dirty-Tree Guard

The planning worktree was already dirty before this lane opened. In particular,
the current native Film Damage / optical sources contain owner changes and are
read-only evidence for this project:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

Do not branch implementation work from this detached dirty worktree. Initial
tasks must use clean project worktrees; they may read the absolute planning
path under the exception in `delegation.md`. Record clean base commits before
accepting work. Do not archive or rewrite
`docs/filmtone/davinci-bridge/active.md` as part of this lane; it belongs to a
separate completed Bridge task.

## Foundation Freeze Record

Partially populated. Before `BREATH`, `WEAVE`, and `DAMAGE` start, the
coordinator must complete this record:

- clean base commit;
- external Film Damage contract: version 2, revision 2.2;
- generic Gate Weave: amount, short-axis X/Y amplitude, clockwise rotation
  amplitude, cycles/second cadence, deterministic jitter, travel axis;
- deterministic render context: version 1; Resolve adapter must convert OFX
  frame-time to seconds and pass explicit frame index/fps;
- generated/public C++ handoff: frozen CONTRACT paths recorded in the CONTRACT
  progress file; ADAPTER handoff pending;
- Film Breath C++ handoff source;
- OFX plugin identifier and parameter ID list;
- render context fields for time, frame rate, seed, render scale, and bounds;
- module interface and uniform ownership;
- supported pixel format and Metal buffer assumptions;
- build command and bundle output path;
- explicit test authorization state.

## Verification State

- Research: complete.
- Planning documents: complete in this chat.
- Source implementation: CONTRACT and HOST terminal source handoffs reviewed;
  both retain explicit verification debt. ADAPTER is running.
- Builds/tests/Resolve launch: not run.
- Test files: not created or modified.
- `/Library/OFX/Plugins`: not modified.
- External repositories: read only in this chat.

## Coordinator Closeout Rules

For each accepted workstream:

1. Review its handoff and changed-file list.
2. Confirm no forbidden shared file was edited.
3. Record the integration commit/base only after the owner authorizes Git
   operations.
4. Update the state table and Foundation Freeze Record.
5. Start newly unblocked chats together.
6. Move detailed execution evidence into an archive only after the whole
   workstream is accepted.

Quality work begins only after all three modules operate through Resolve. It
does not block core feature implementation earlier than that.
