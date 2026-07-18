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
- Foundation implementation: CONTRACT, HOST, and ADAPTER source handoffs are
  accepted into one clean integration branch; verification debt is retained.
- Feature wave: BREATH, WEAVE, and DAMAGE source handoffs are accepted and
  integrated; verification debt is retained.
- Integration wave: source accepted and integrated. One Filter now owns the
  generated parameter surface and the deterministic Breath -> Weave -> Damage
  pass graph; its build, Metal, bundle, and Resolve Color-host path are proved.
- QUALITY build, bundle, recoverable installation, Resolve discovery, actual
  Color-page instantiation, default identity, per-module output, combined
  output, and same-frame determinism: passed on Resolve 21.0.2.4 / Apple M4 Max.
- Current task: **closed by owner with partial acceptance**. Film Damage passes
  the current internal cycle; Film Breath and Gate Weave remain below the owner
  quality bar and move to future independent iterations. Packaging and release
  remain not started.
- Fresh-chat quality prompts are prepared for independent detailed work:
  [Film Breath](workstreams/film-breath-quality-chat-prompt.md),
  [Gate Weave](workstreams/gate-weave-quality-chat-prompt.md), and
  [Film Damage](workstreams/film-damage-quality-chat-prompt.md). Each freezes
  its own source/progress scope and requires research before implementation.
- Film Breath quality correction is [statically accepted and working-tree
  integrated](workstreams/progress/film-breath-quality.md): temperature/tint
  now use positive per-channel gains instead of additive RGB offsets. The
  revised combined bundle builds, installs, and is enumerated by Resolve;
  product acceptance now waits only for the owner visual verdict.
- Film Damage detailed quality correction is [statically accepted and
  working-tree integrated](workstreams/progress/film-damage-quality.md): all
  five material families were rebuilt around richer procedural and temporal
  behavior. Coordinator follow-up removed hidden Scratch/Fiber length
  multipliers so the frozen recipe remains authoritative. The revised combined
  bundle builds, installs, and is enumerated by Resolve; family-isolated and
  combined owner viewing remain.
- Gate Weave quality correction is [source-integrated through the canonical
  owner](workstreams/progress/gate-weave-quality.md): Film Damage contract
  revision 2.3 now owns the bounded correlated multi-band drift/scatter model,
  and Filmtone consumes its regenerated handoff with an exact motion envelope.
  The revised combined bundle builds, installs, and is enumerated by Resolve;
  its owner motion/crop/softness verdict remains.
- Current-cycle disposition: **closed, not Internal Core Baseline Complete**.
  All three research-backed corrections build and install, but only Film Damage
  received owner pass. Breath/Weave detail capture and tuning become later
  feature-specific work. This is not a packaging, distribution, parity, or
  public-release claim.

## Workstream Status

| ID | Plan | Progress | Repository | Depends on | State |
|---|---|---|---|---|---|
| `CONTRACT` | [Plan](workstreams/contract-and-product-mapping.md) | [Progress](workstreams/progress/contract-and-product-mapping.md) | visual-effect-core | planning | Accepted — source integrated; verification debt retained |
| `HOST` | [Plan](workstreams/ofx-host-foundation.md) | [Progress](workstreams/progress/ofx-host-foundation.md) | Filmtone | planning | Accepted — source integrated; verification debt retained |
| `ADAPTER` | [Plan](workstreams/filmtone-contract-adapter.md) | [Progress](workstreams/progress/filmtone-contract-adapter.md) | Filmtone | CONTRACT interface freeze | Accepted — source integrated; verification debt retained |
| `BREATH` | [Plan](workstreams/film-breath.md) | [Progress](workstreams/progress/film-breath.md) | Filmtone | CONTRACT + ADAPTER + HOST | Accepted — source integrated; verification debt retained |
| `WEAVE` | [Plan](workstreams/gate-weave.md) | [Progress](workstreams/progress/gate-weave.md) | Filmtone | CONTRACT + ADAPTER + HOST | Accepted — source integrated; verification debt retained |
| `DAMAGE` | [Plan](workstreams/film-damage.md) | [Progress](workstreams/progress/film-damage.md) | Filmtone | CONTRACT + ADAPTER + HOST | Accepted — source integrated; verification debt retained |
| `INTEGRATION` | [Plan](workstreams/resolve-integration.md) | [Progress](workstreams/progress/resolve-integration.md) | Filmtone | BREATH + WEAVE + DAMAGE | Accepted — source integrated and actual Resolve host path proved |
| `QUALITY` | [Plan](workstreams/visual-quality.md) | [Progress](workstreams/progress/visual-quality.md) | Filmtone + Resolve | INTEGRATION + explicit authorization | Closed with partial acceptance — Damage pass; Breath/Weave below pass and deferred |

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
| CONTRACT | `019f7416-8ed4-7023-947d-8f5d0570f38c` | `/Users/chibatakumi/.codex/worktrees/7057/visual-effect-core` | `84efd1a8a5dae0edd3afb777a0428739f7c1e72b` | Accepted as `6e7969a8a1ecff8519b7ef3dd0c6a0f24af1b61f` |
| HOST | `019f7416-9bd1-7e12-a95e-cfee8eda1797` | `/Users/chibatakumi/.codex/worktrees/a45d/filmtone` | `a840634ac2a630df36b10d414ec1c4e53f27a6ce` | Accepted as `325488e2ab86e5c25459949702ea880a888ac12d` |
| ADAPTER | `019f7438-f67e-7c11-80fc-81839b706589` | `/Users/chibatakumi/.codex/worktrees/66f1/filmtone` | `a840634ac2a630df36b10d414ec1c4e53f27a6ce` | Accepted as `7e33462357a2532d16713c813fdd65ea04d70ebd` |
| BREATH | `019f746f-c80c-7b90-963d-f6cd3b05ef95` | `/Users/chibatakumi/.codex/worktrees/e9c57c76-3e12-4d11-b2d7-7dbb1c661cbc/filmtone` | `6130aae610de9f8c535f4e72d2078f2f1aabed66` | Accepted as `a678b9153a5505e62b084ad337a461553da107f3` |
| WEAVE | `019f7470-153f-7aa3-9797-77d4aa980bc6` | `/Users/chibatakumi/.codex/worktrees/3fb973be-7602-4dd3-bf4c-c0acd3049ea3/filmtone` | `6130aae610de9f8c535f4e72d2078f2f1aabed66` | Accepted as `5aa5180a465cff1330b5f208a9aff24ed0c6e4fc` |
| DAMAGE | `019f7470-635b-7770-a419-fe02051fbe74` | `/Users/chibatakumi/.codex/worktrees/751b9f41-bc21-4e13-b82d-1c94af7b9d62/filmtone` | `6130aae610de9f8c535f4e72d2078f2f1aabed66` | Accepted as `3ddc56cb95aeb093712a56d301358ff796f3d1f7` |
| INTEGRATION | `019f74a1-81dc-7572-bf8c-3dea21472755` | `/Users/chibatakumi/.codex/worktrees/97f1/filmtone` | `eb860dfeea7a4d45fa159839ad5454a371afbab9` | Accepted as `57434fc1187df8a8175d74b69c18e63c94ee5a52`; integrated as `915012a` |
| QUALITY | `019f74bc-834b-7ce0-9a22-0297ab4a84cc` | `/Users/chibatakumi/.codex/worktrees/1433/filmtone` | `f16aa4a6bdeaff740f59a60c5029af40c491e905` | Running — Resolve host gate passed; visual tuning continues |

## Foundation Integration Record

- Planning commit: `a9410a6040164f29d02827cfce84b7fff04d2145`.
- External CONTRACT commit: `6e7969a8a1ecff8519b7ef3dd0c6a0f24af1b61f`.
- HOST source commit: `325488e2ab86e5c25459949702ea880a888ac12d`.
- ADAPTER source commit: `7e33462357a2532d16713c813fdd65ea04d70ebd`.
- Combined Filmtone source commit: `fcb3e85` on
  `feature/davinci-ofx-foundation`.
- Clean coordinator worktree:
  `/Users/chibatakumi/.codex/worktrees/filmtone-davinci-foundation`.
- Feature dispatch base: `6130aae610de9f8c535f4e72d2078f2f1aabed66`.
- Stable starting ref: `feature/davinci-ofx-foundation-freeze`.
- A delayed API response created duplicate BREATH task
  `019f746f-c751-7fa0-9877-ebacea5f0a79` in worktree
  `/Users/chibatakumi/.codex/worktrees/79175aaf-cffc-4749-a9f2-7623c1d0f640/filmtone`.
  It remained clean when detected and received an immediate superseded/stop
  instruction; it is not part of the feature wave.

## Feature Integration Record

- BREATH source commit: `a678b9153a5505e62b084ad337a461553da107f3`;
  coordinator integration commit: `11411fb`.
- WEAVE source commit: `5aa5180a465cff1330b5f208a9aff24ed0c6e4fc`;
  coordinator integration commit: `c89d722`.
- DAMAGE source commit: `3ddc56cb95aeb093712a56d301358ff796f3d1f7`;
  coordinator integration commit: `b214b76`.
- Combined feature source commit:
  `b214b765b333848131b52578325096bb7a4566f4`.
- Feature progress records were reviewed and incorporated individually; the
  coordinator master record remained coordinator-owned.
- INTEGRATION dispatch base:
  `eb860dfeea7a4d45fa159839ad5454a371afbab9`.
- Stable starting ref: `feature/davinci-ofx-integration-base`.
- INTEGRATION task: `019f74a1-81dc-7572-bf8c-3dea21472755`; clean detached
  worktree: `/Users/chibatakumi/.codex/worktrees/97f1/filmtone`.

## Resolve Integration Record

- INTEGRATION source commit:
  `57434fc1187df8a8175d74b69c18e63c94ee5a52` on
  `feature/davinci-ofx-integration`; coordinator integration commit:
  `915012a`.
- One registered Filter keeps plugin ID
  `com.chibatakumi.filmtone.finish`, the generated 17-entry base parameter
  surface, and exactly three local Film Breath response controls.
- Pass order is fixed as Film Breath -> Gate Weave -> Film Damage. Configured
  identity does not require valid host fps; configured-active temporal work
  still rejects missing rates and uses no fallback clock.
- A lone active Gate Weave uses no intermediate when Host buffers differ. If
  they alias, Integration renders to one distinct output-bounds temporary and
  copies the requested window back on the same Metal queue.
- Static source review found no remaining acceptance blocker. Retained QUALITY
  debt: broader fps/random-access/format coverage, real-image visual tuning,
  CinePrint35 coexistence, owner acceptance, and optional Makefile header-
  dependency hardening.

## Resolve Host Verification Record

- Resolve `21.0.2.4` loaded `com.chibatakumi.filmtone.finish`; the disposable
  project `Filmtone Finish QUALITY 2026-07-18` contains the dedicated timeline
  `Filmtone Finish QUALITY Host 24fps FHD` and no owner project was touched.
- The Color page instantiated one `OFX: Filmtone Finish` tool on a real ProRes
  media clip and exposed the generated Film Breath, Gate Weave, Film Damage,
  and Variation controls.
- Resolve 16-bit PNG exports at frame `86412` proved exact default identity:
  node disabled and node enabled decoded to the same raw-frame MD5
  `2691d0207dd971aff6209202cca93c0a` with zero differing pixels.
- Film Breath, Gate Weave, and Film Damage Dust each changed host output when
  enabled alone. The combined render changed output and two repeated exports
  decoded to the identical raw-frame MD5
  `e8ce94223a5e2ab2b4cdadbe1715f958`, with zero differing pixels.
- Every Resolve render job completed. No Filmtone-specific render, Metal, or
  OFX error was recorded during the host matrix.
- Untracked evidence remains under
  `apps/filmtone-resolve-ofx/build/quality-evidence/resolve-host/`; it is not
  release packaging or tracked test infrastructure.

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

Do not branch implementation work from the detached dirty owner worktree. The
planning exception has ended; feature tasks use the clean Foundation branch
and in-repository planning documents. Do not archive or rewrite
`docs/filmtone/davinci-bridge/active.md` as part of this lane; it belongs to a
separate completed Bridge task.

## Foundation Freeze Record

Foundation Freeze is complete. Feature dispatch base:
`6130aae610de9f8c535f4e72d2078f2f1aabed66`.

- Integrated Filmtone source commit: `fcb3e85`.
- External owner commit: `6e7969a8a1ecff8519b7ef3dd0c6a0f24af1b61f`.
- Film Damage contract: version 2, revision 2.2.
- Quality supersession: the current working-tree contract, generated handoff,
  and Gate Weave resolver consume revision 2.3. Revision 2.2 above remains the
  historical Foundation Freeze value.
- Generic Gate Weave: amount, short-axis X/Y amplitude, clockwise rotation
  amplitude, cycles/second cadence, deterministic jitter, and travel axis.
- Deterministic render context: version 1. Resolve conversion is
  `hostTimeSeconds = ofxTimeFrames / resolvedFrameRate`, with explicit frame
  index/fps and no generic 24 fps fallback.
- Stable generated include:
  `Sources/Generated/Contracts/filmtone_finish_contracts.hpp`.
- Film Breath authority: `packages/film-lab-core/src/film-breath.ts`; generated
  handoff: `Sources/Generated/Contracts/filmtone_film_breath.hpp`.
- Plugin identifier: `com.chibatakumi.filmtone.finish`.
- Parameter IDs/defaults/ranges: the 17-entry
  `kFilmtoneFinishParameterDefinitions` array in
  `forestone_filmtone_finish_mapping.hpp`.
- Host context: time, source/timeline frame rates, optional explicit seed,
  render scale, render window, source bounds, and output bounds.
- Module boundary: `host::ModuleProcessor`; Film Breath offsets and Film
  Damage/Gate Weave uniforms remain generated-contract values, while each
  feature owns only its local processor and Metal resources.
- Buffer contract: Metal-only float RGBA with explicit buffer, row bytes, and
  bounds; alpha and extended-range RGB must be preserved.
- Build command: `make -C apps/filmtone-resolve-ofx`.
- Expected bundle: `apps/filmtone-resolve-ofx/build/FilmtoneFinish.ofx.bundle`.
- Tests, builds, Resolve launch, installation, and test-file work: not
  authorized in this feature wave.

## Verification State

- Research: complete.
- Planning documents: integrated into the clean Foundation branch.
- Source implementation: CONTRACT, HOST, and ADAPTER handoffs reviewed and
  integrated; explicit build/test/Resolve verification debt remains.
- Feature source implementation: BREATH, WEAVE, and DAMAGE accepted and
  integrated from isolated commits.
- Integration source implementation: accepted and integrated after static
  correction review for invalid-fps configured identity and single-Gate
  aliased Host buffers.
- Authorized arm64 build, bundle inspection, embedded Metal compilation,
  recoverable evaluation install, Resolve launch/discovery, actual Color-page
  instantiation, module-isolation exports, combined export, default identity,
  and same-frame repeat: passed.
- Still open: real-image visual acceptance, fps/random-access/cache/project-
  reopen matrix, UHD/proxy/portrait/non-square formats, supplied-host alpha,
  Damage-family balance/tiling/sparkle, Film Breath mean/periodicity, and
  CinePrint35 coexistence.
- Test files: not created or modified.
- `/Library/OFX/Plugins`: not modified.
- External CONTRACT source was committed locally as the recorded owner commit;
  feature workers treat the external repository as read-only.

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
