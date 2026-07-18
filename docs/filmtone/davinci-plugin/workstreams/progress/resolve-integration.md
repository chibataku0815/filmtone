# Progress: Resolve Integration

Plan: [Resolve Integration](../resolve-integration.md)
Owner: `INTEGRATION` worker; master state is coordinator-owned
Last synced: 2026-07-18 JST

## State

`Review — identity and single-Gate alias corrections complete; compiled and Resolve verification not authorized`

## Assignment

- Repository: Filmtone
- Worktree: `/Users/chibatakumi/.codex/worktrees/97f1/filmtone`
- Exact base: `eb860dfeea7a4d45fa159839ad5454a371afbab9`
- Starting ref: `feature/davinci-ofx-integration-base`
- Combined feature source: `b214b765b333848131b52578325096bb7a4566f4`
- External contract: `6e7969a8a1ecff8519b7ef3dd0c6a0f24af1b61f`
- Frozen contracts: Film Damage 2 / 2.2, deterministic context 1,
  Filmtone Finish mapping 1, Film Breath 1
- Runs alone; blocks `QUALITY`

## Current Loop

Source integration, both coordinator-requested precondition corrections, and
repeated read-only scope/interface inspection are complete. Configured identity
now bypasses frame-rate resolution without weakening active temporal fps
requirements. A single active Gate Weave now routes an aliased Host invocation
through one distinct output-bounds temporary and copies the rendered window
back exactly. The next proof requires an unauthorized arm64 bundle build,
Metal compilation, and Resolve execution.

## Checklist

- [x] Accept the exact clean integration base and shared-file ownership.
- [x] Register one Filmtone Finish Filter and stable generated parameter IDs.
- [x] Register only the three accepted Film Breath local response controls.
- [x] Connect Film Breath -> Gate Weave -> Film Damage pass order.
- [x] Preserve independent bypass and exact all-off identity behavior.
- [x] Preserve configured identity when both host frame rates are invalid,
  without allowing configured-active temporal work or inventing a fallback.
- [x] Preserve single active Gate Weave when Host source/output alias by using
  one Integration-owned distinct warp target and exact windowed copy-back.
- [x] Connect actual OFX time, resolved fps, Variation/seed, render scale,
  render window, and source/output bounds.
- [x] Allocate intermediates only for active multi-pass combinations.
- [x] Add compact Basic module groups and closed Advanced groups.
- [x] Record manual CinePrint35 placement and overlap guidance without an
  automatic insertion claim.
- [x] Wire accepted feature and Integration sources into the Makefile.
- [x] Complete final read-only changed-file and invariant inspection.
- [x] Return terminal handoff for coordinator review.

## Changed Files

- `apps/filmtone-resolve-ofx/Sources/Host/FilmtoneFinishPlugin.cpp`
- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishParameters.h`
- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishParameters.cpp`
- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishRenderGraph.h`
- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishRenderGraph.mm`
- `apps/filmtone-resolve-ofx/Makefile`
- `docs/filmtone/davinci-plugin/workstreams/progress/resolve-integration.md`

No Generated, feature-algorithm, Resource, native-app, Bridge, sidecar, Lua,
package, strategy, plan, master-progress, test, release, or external-repository
file changed.

## Public Interfaces And Artifacts

- `describeFilmtoneFinishParameters` registers persistent OFX descriptors from
  frozen generated metadata and accepted Film Breath local metadata.
- `FilmtoneFinishParameterSet` fetches instance handles once and evaluates a
  bounded `EvaluatedFilmtoneFinishParameters` snapshot at actual OFX time.
- `resolveFrameRates` prefers valid timeline fps for material time and falls
  back between the actual source/timeline host rates without a 24 fps default.
- `isFilmtoneFinishIdentity` asks all accepted processors for identity using
  one seeded Host context.
- `isFilmtoneFinishConfiguredIdentity` asks the accepted processors to prove
  identity without a valid temporal context, covering all-off and
  configured-zero states before Host fps resolution.
- `encodeFilmtoneFinishMetal` owns active-pass selection, fixed pass order,
  intermediate allocation, and delegation through `host::ModuleProcessor` and
  `host::MetalPipelineCache`.
- The registered product remains one bundle, one Filter factory, and plugin ID
  `com.chibatakumi.filmtone.finish`.

## Parameter Ownership

- Base ownership remains the exact 17-entry
  `forestone::filmtone::kFilmtoneFinishParameterDefinitions` array. Registration
  reads its IDs, kinds, defaults, hard ranges, and display ranges directly.
- Instance mapping fills the accepted
  `forestone::filmtone::FilmtoneFinishParametersV1` fields and then calls
  `mapFilmtoneFinish`; Integration introduces no second mapping contract.
- Film Breath adds only Exposure Response, Tonal Response, and Color Response
  from `kFilmBreathParameterDescriptors`. Adjustable Film Breath cadence is
  not registered.
- Basic surface: Variation plus Enabled / Amount inside Film Breath, Gate
  Weave, and Film Damage groups.
- Closed Advanced surface: the three Film Breath response attenuators; five
  frozen Gate Weave controls; five Film Damage family amounts.
- Every value parameter is persistent and evaluates on change. Variation is
  the explicit deterministic seed; feature-owned stream salts retain module
  decorrelation, so unrelated parameter changes do not replace random streams.
- Generated defaults keep every module off. Gate Weave and Dust therefore do
  not stack with CinePrint35 by default.

## Pass Graph And Buffer Policy

Fixed order:

```text
host source
  -> Film Breath (when active)
  -> Gate Weave (when active)
  -> Film Damage (when active)
  -> host output
```

- Processor identity checks build the active list in that order. Inactive
  processors schedule no module command buffer.
- Zero active modules return OFX source identity through `isIdentity`; if the
  Host still calls render, the defensive identity blit copies exact float RGBA
  and still schedules no module pass. This configuration-only path does not
  require valid source or timeline fps.
- One active module normally renders source directly to output with no
  intermediate. If the only active module is Gate Weave and Host source/output
  alias, Integration allocates one output-bounds temporary, renders the
  accepted warp into it, then uses the exact Metal identity blit to copy only
  the requested window back to Host output.
- Two active modules allocate one intermediate; three allocate two. Each
  active processor receives distinct input/output buffers, and the final pass
  always writes the Host output.
- Intermediates are tightly packed, private Metal float-RGBA buffers with full
  stage-appropriate bounds. A buffer read by Gate Weave uses source bounds; a
  buffer written by Gate Weave uses output bounds.
- When Gate Weave follows another active pass, the graph requires the Host's
  advertised non-tiled full-bounds render so its four-by-four sampling cannot
  read uninitialized intermediate pixels.
- Accepted processors commit on the same Metal command queue, preserving
  submission order. Default retained command-buffer references keep temporary
  buffers alive after Integration releases its ownership.
- The graph adds no RGB clamp or alpha operation; extended-range float RGB and
  alpha behavior remains in the accepted processors.

## Deterministic Context

- `args.time` is passed unchanged as OFX frame-time.
- Timeline fps is used when valid; source fps fills a missing timeline rate,
  and timeline fps fills a missing source rate. No material 24 fps fallback was
  added.
- If both host rates are invalid, only configuration-proven identity may return
  or copy source. Any configured-active temporal module still fails Host fps
  resolution before module scheduling.
- Variation is installed as the explicit seed and reduced only at accepted
  32-bit generated/module boundaries.
- Exact render scale, render window, source bounds, and output bounds enter the
  shared Host context for every processor.
- Film Damage receives the frozen generated Resolve context with canonical
  full-frame bounds; Gate Weave derives the same canonical representation from
  the shared Host context.

## Decisions Fixed

- Metal remains the only execution path; no CPU, OpenCL, CUDA, or reduced-
  quality fallback was added.
- The factory and Host render action delegate product responsibility to
  `Sources/Integration/`; no accepted feature or Generated interface widened.
- The effect description tells a Resolve colorist to add Filmtone Finish
  manually after CinePrint35 by default, notes that it remains movable, and
  tells CinePrint users to keep one Gate Weave and one Dust treatment enabled.
  It does not claim or attempt automatic OFX node insertion.
- UI copy brief: primary reader is a Resolve colorist adding a finishing node;
  the moment is manual placement around CinePrint35; the desired action is to
  enable one restrained module and avoid overlapping Gate Weave/Dust; this is
  not copy for input transforms, film stocks, automatic insertion, or release
  availability. Claim class is Internal; evidence is the accepted strategy,
  generated contracts, and feature handoffs. “By default” and “remains
  movable” preserve the correction buffer.

## Verification

- Performed: exact clean/base start gate before edits; complete required plan,
  handoff, copy-harness, HOST, Generated, and feature-interface reads; read-only
  comparison with installed Resolve SDK parameter/sample interfaces; repeated
  `git status --short --untracked-files=all`, changed-source reads, diff reads,
  source-list inspection, and targeted symbol/invariant searches.
- Read-only inspection result: changed files remain inside the authorized Host,
  Integration, Makefile, and INTEGRATION-progress scope; one Filter/plugin ID,
  generated/local parameter ownership, Breath -> Weave -> Damage list order,
  identity blit, explicit seed, stage bounds, and accepted build-source entries
  are present. The correction trace confirms parameter evaluation precedes fps
  gating, configured identity bypasses the gate, and configured-active work
  retains the missing-rate rejection. It also confirms the single-Gate alias
  branch detects buffer identity, supplies distinct source/output to the
  accepted processor, preserves output bounds/row layout, and enqueues copy-
  back on the same queue after the warp; the normal non-alias single pass still
  allocates no intermediate.
- Not performed: tests or test files; build, compiler/syntax/type/lint checks,
  Metal library compilation, plist lint, ABI/layout checks, identity pixel
  comparison, deterministic scrub/cache/export proof, render-scale comparison,
  wide-gamut/alpha measurement, bundle inspection, Resolve launch/render,
  installation, performance measurement, visual acceptance, or Git stage /
  commit / merge / rebase / push.

## Blockers And Remaining Work

- No source/contract blocker was found.
- Coordinator source review remains.
- An explicitly authorized later wave must build the arm64 bundle, inspect its
  architecture/exports/layout, compile embedded Metal, install or load it in
  Resolve, and prove per-module/combo identity, deterministic random access,
  bounds, extended-range RGB, alpha, and CinePrint coexistence.
- QUALITY still owns visual tuning, interaction timing, performance evidence,
  and owner acceptance.

## Copy / History Impact

- No public copy/history impact: this registers an internal source surface but
  does not make availability, distribution, compatibility, or parity claims
  true.
- Article Opportunity: **Full article remains deferred** until visual
  acceptance and distribution are true.
- Change-History Opportunity: **No new direction**; implementation follows the
  already recorded OpenFX ownership and product-boundary decision.

## Handoff

Terminal state: `Review — identity and single-Gate alias corrections complete; compiled and Resolve verification not authorized`

Repository / worktree / base: Filmtone / `/Users/chibatakumi/.codex/worktrees/97f1/filmtone` / `eb860dfeea7a4d45fa159839ad5454a371afbab9` (`feature/davinci-ofx-integration-base`)

Changed files: Host factory/effect, four new `Sources/Integration/` files, root OFX Makefile, and this assigned INTEGRATION progress record; no frozen feature/Generated or coordinator-owned master file changed

Public interfaces or artifacts: `describeFilmtoneFinishParameters`, `FilmtoneFinishParameterSet`, `EvaluatedFilmtoneFinishParameters`, `resolveFrameRates`, `isFilmtoneFinishConfiguredIdentity`, `isFilmtoneFinishIdentity`, `encodeFilmtoneFinishMetal`, one registered `com.chibatakumi.filmtone.finish` Filter, and Makefile source wiring for all accepted modules

Decisions fixed: generated 17-entry base ownership plus exactly three local Film Breath responses; configured identity needs no valid fps, while configured-active temporal work still rejects both rates missing; no fallback clock; actual OFX time and resolved host fps; Variation as explicit seed; fixed Breath -> Weave -> Damage order; zero intermediates for normal zero/one-pass work, one temporary plus exact copy-back for a single aliased Gate Weave, one intermediate for two active passes, and two for three; full-bounds safety before a downstream Gate Weave; exact all-off identity; Metal only; manual post-CinePrint35 guidance with Gate Weave/Dust overlap off by default; no automatic insertion or sidecar/release shell

Remaining work: coordinator source review, then separately authorized arm64 build/Metal/bundle/Resolve/visual/performance verification and QUALITY acceptance

Blocker: no source blocker; completion proof is blocked only by the explicit prohibition on build, compiler, test, Metal, Resolve, installation, and Git-write actions

Verification performed: clean exact-base start gate; required document/interface and SDK reads; repeated read-only status, diff, changed-source, source-list, and targeted ownership/order/identity/context inspection

Verification not performed: all compiled, runtime, pixel/numerical, deterministic scrub/cache/export, visual, performance, installation, test, and Git-write verification listed above

Stop reason: requested invalid-fps identity and single-Gate alias corrections are source Done; further proof requires unauthorized build/test/compiler/Metal/Resolve/install work
