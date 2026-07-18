# Progress: Filmtone Spatial Integration

Plan (read-only planning source):
`/Users/chibatakumi/.codex/worktrees/filmtone-davinci-optical-planning/docs/filmtone/davinci-plugin/workstreams/spatial-integration.md`

Owner: `SPATIAL-INTEGRATION`; master state is director-owned
Last synced: 2026-07-18 JST

## State

`Review — integration source complete; build, Metal, Resolve, runtime, and visual proof remain unauthorized`

## Assignment

- Task: `019f75a9-8f4e-7352-85ae-e4122d1928a2`
- Worktree:
  `/Users/chibatakumi/.codex/worktrees/72be83d2-b4c9-499a-b7cd-12456a1552ad/filmtone`
- Assigned and confirmed clean base:
  `729d65472a6f08d2996f3dd464a91266580199b0`
- Planning source and director progress were read-only.
- Exclusive edit surface: `Sources/Integration/**`,
  `Sources/Host/FilmtoneFinishPlugin.cpp`, OFX `Makefile`, `Info.plist`, and
  this progress record.

## Frozen Inputs Confirmed

- Resolve Spatial Contract v1; 14 generated persistent definitions and three
  generated Node Role choices.
- Spatial Module ABI v1; one coordinator-owned command buffer and two reused
  RGBA32F pyramids.
- Enforced ceilings: 384 MiB spatial transient and 640 MiB integrated
  transient, including the integration-provided following-queue reservation.
- Accepted feature source commits:
  - Texture Softness `a0c4567994b2b480474640552baefc21263b7cbd`
  - Peripheral Chromatic Shift `ed6319da1c7e2797062013db06e80febbdaca891`
  - Lens Softness `3ce67d3b21577dcf9e6d39c06f31acbd6f2c9169`
  - Deep Glow `8d82f5860e8d46bac31e550cff10ae375390cf77`
  - Vignette `bc1c16b0d358fc54171077960538ce0dccf10b6b`
- Accepted feature folders, generated/canonical contracts, Spatial Host, and
  existing Film Breath, Gate Weave, and Film Damage folders remained read-only.

## Checklist

- [x] Confirm clean integration base and accepted revisions.
- [x] Register Node Role and the generated spatial parameters.
- [x] Change the public label/description/CFBundleName to `Filmtone` while
      retaining the compatibility plugin ID.
- [x] Connect the role-aware final graph in its exact frozen order.
- [x] Preserve old-project defaults, configured identity, and temporal fps
      behavior.
- [x] Connect bounded Spatial resources and accepted film command buffers on
      the Host queue.
- [x] Inspect the exclusive source diff and record verification debt.
- [x] Prepare the delegation handoff for director review.

## Parameter And Compatibility Decisions

- The descriptor and runtime parameter set consume
  `kFilmtoneSpatialParameterDefinitionsV1` for all 14 IDs, kinds, defaults,
  and ranges. No feature default/range was duplicated in Integration.
- `Node Role` choice options use the generated public labels as the actual OFX
  choices. The stored index remains the durable value; invalid values normalize
  to generated default `All`.
- `All` schedules both rails, `Optics` schedules only the five spatial
  features, and `Film Breath / Gate Weave / Film Damage` schedules only the
  accepted three film modules. Masking never writes or normalizes stored values
  beyond generated read-time range handling.
- Missing spatial fields use generated neutral defaults. A project predating
  the expansion therefore resolves to `All`, schedules no spatial pass, and
  retains the existing three-module behavior.
- Public descriptor label/grouping consume the generated
  `kFilmtonePublicDisplayName`; descriptor copy, render log label, and
  `CFBundleName` use `Filmtone`. Plugin/bundle identifier
  `com.chibatakumi.filmtone.finish` remains unchanged as internal persistence
  identity; version/release/package values were not changed.

## Graph And Identity

Exact scheduled order is:

```text
Texture Softness
  -> Peripheral Chromatic Shift
  -> Lens Softness
  -> Deep Glow
  -> Vignette
  -> Film Breath
  -> Gate Weave
  -> Film Damage
```

- Generated identity views filter every disabled/zero spatial feature before
  Spatial Host planning. All-neutral or role-masked-neutral configuration uses
  the existing identity path and performs no Spatial allocation.
- Temporal frame rate is required only when the selected role schedules a
  configured-active accepted film module. `Optics` and `All` with neutral film
  modules can run static spatial work without a valid temporal fps.
- The existing configured-active invalid-fps rejection remains for Film
  Breath, Gate Weave, and Film Damage. No fallback material clock was added.
- Existing accepted processor types, mappings, cadence, uniforms, and feature
  source remain unchanged.

## Resource And Command Ownership

- Spatial conversion and the five spatial modules encode through Spatial ABI
  v1 into one coordinator-owned command buffer, committed first on the
  Host-provided queue.
- Existing film processors commit their accepted command buffers afterward on
  the same queue. Queue order provides the dependency; Integration adds no
  wait, readback, private queue, or CPU/reduced-quality fallback.
- At most two plugin-owned full-frame RGBA32F temporal intermediates exist.
  When all three film modules follow Spatial, they reuse these as ping-pong:
  Spatial writes A, Breath writes B, Weave reuses A, and Damage writes Host
  output. Allocation is therefore bounded independently of active module count.
- The exact tight bytes for the one/two temporal intermediates are passed to
  Spatial Host as the following-queue reservation before its commit. Spatial
  Host continues to enforce the frozen 384 MiB spatial and 640 MiB integrated
  ceilings.
- Spatial source/output bounds remain identical; full-frame Gate Weave after a
  prior active stage retains the accepted full-bounds requirement. A lone
  aliased Gate Weave retains its distinct temporary and ordered identity copy.
- OFX source pixel aspect ratio is passed to Spatial Host. OFX premultiplication
  metadata is mapped explicitly to Deep Glow association behavior; opaque and
  unassociated inputs use the unassociated path. Float RGBA, extended-range
  RGB, source alpha, per-axis render scale, and edge policies remain owned by
  the frozen Host/features.

## Changed Files

- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishParameters.h`
- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishParameters.cpp`
- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishRenderGraph.h`
- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishRenderGraph.mm`
- `apps/filmtone-resolve-ofx/Sources/Host/FilmtoneFinishPlugin.cpp`
- `apps/filmtone-resolve-ofx/Makefile`
- `apps/filmtone-resolve-ofx/Resources/Info.plist`
- `docs/filmtone/davinci-plugin/workstreams/progress/spatial-integration.md`

## Verification

Performed:

- Clean/base start gate and complete read-only planning, director, foundation,
  five-feature, generated contract, Spatial Host, accepted feature, and current
  integration/connection-surface review.
- Read-only status/diff/source inspection for exclusive ownership, generated
  defaults/ranges, generated choice labels, role masks, exact pass order,
  configured identity, fps gate, queue ordering, ping-pong reuse, reservation,
  bounds, PAR, alpha association, public label, and compatibility identifier.

Not performed by explicit assignment prohibition:

- Tests, test files, or test-like verification.
- C++/Objective-C++ build, Metal compilation, or bundle generation.
- Resolve launch, plugin installation, runtime memory/pass reporting,
  identity/alpha/HDR/format renders, performance, or visual acceptance.
- Stage, commit, merge, rebase, push, release, or packaging work.

## Remaining Verification Debt

- Authorized build and Metal compilation must prove the new parameter/API and
  feature source list compile together.
- Resolve proof must cover public discovery as `Filmtone`, old-project loading,
  every Node Role, each isolated feature, exact default identity, combined
  ordering, invalid-fps behavior, same-frame determinism, alpha association,
  extended range, render scale/PAR, UHD memory reporting, and owner visual
  acceptance.
- Source completion is not build, Resolve, runtime, visual, package, release,
  or public-availability acceptance.

## Copy / History Impact

- Surface / reader / action: Resolve OFX descriptor and controls for a colorist
  choosing whether one node owns Optics, the three film modules, or the complete
  graph. The copy is literal and task-focused; it does not claim release or
  visual acceptance.
- Public copy update required: future Resolve usage/release copy must use
  `Filmtone`, explain Node Role when the two-instance CinePrint35 workflow is
  documented, and must not expose `Filmtone Finish` as the product name.
- Implementation history update required: preserve that the visible rename did
  not churn the compatibility Plugin ID, and that spatial execution introduced
  a bounded coordinator-owned graph without rewriting the accepted film
  processors.
- Release/App Store claim: none. Build, Resolve, distribution, and availability
  remain unverified and must not be stated as current public truth.
- Article Opportunity: **Full article** — hold until Resolve/runtime/visual and
  distribution truth gates pass; then the one-effect/two-role workflow and
  spatial expansion have a coherent product story.
- Change-History Opportunity: **Developer note** — the useful durable lesson is
  the compatibility-name split plus bounded same-queue Spatial-to-film command
  ownership; draft only after runtime proof.
