# Progress: Filmtone Spatial Director

Plan source (read-only):
`/Users/chibatakumi/.codex/worktrees/filmtone-davinci-optical-planning/docs/filmtone/davinci-plugin/workstreams/filmtone-spatial-director.md`

Owner: `SPATIAL-DIRECTOR`
Last synced: 2026-07-18 JST

## State

`Complete — spatial source integrated; runtime proof retained as unauthorized debt`

## Assignment

- Director task: `019f7573-3066-72c1-9b47-02c586416354`
- Director worktree:
  `/Users/chibatakumi/.codex/worktrees/b613/filmtone`
- Director / implementation base:
  `cb9b465414029e15abae9cac2e6895d4dd64ff84`
- Base ref at launch: local `main`
- Planning source:
  `/Users/chibatakumi/.codex/worktrees/filmtone-davinci-optical-planning`
- Planning source policy: read-only; no write-back

## Source Truth Audit

- Director worktree began clean at the assigned base. Local `main` and the
  planning worktree HEAD both resolved to the same SHA.
- Planning worktree implementation-source diff is empty; its only changes are
  the tracked/untracked planning documents.
- Current OFX source still uses the accepted three-module `ModuleProcessor`
  boundary. Active multi-pass transitions allocate one full-frame RGBA32F
  intermediate each, so the planned additive spatial ABI/resource foundation
  is required.
- Generic `chromaticFringing` is not equivalent to Filmtone `rgbShift`; the
  current `filmtone-pack` compatibility mapping explicitly rejects an
  unproved x200 rescale.
- The compatibility note that calls `detailSoftness` neutral plumbing is stale
  relative to current Filmtone main, which contains the canonical derived
  uniforms and native renderer implementations. OPTICS-CONTRACT owns resolving
  that source-of-truth difference without mutating the external repository.
- No launch-blocking base, source ownership, or exclusive-folder conflict was
  found.

## Foundation Dispatch

| ID | Task | Worktree | Base | State |
|---|---|---|---|---|
| `OPTICS-CONTRACT` | `019f757a-8261-77f1-9d38-351efd092fd5` | `/Users/chibatakumi/.codex/worktrees/c523/filmtone` | `cb9b465414029e15abae9cac2e6895d4dd64ff84` | Accepted — source contract v1 frozen; unauthorized build/runtime proof retained |
| `SPATIAL-HOST` | `019f757a-8261-77f1-9d38-34f4fd70124e` | `/Users/chibatakumi/.codex/worktrees/0a1c/filmtone` | `cb9b465414029e15abae9cac2e6895d4dd64ff84` | Accepted — ABI/resource ceiling frozen after director correction |

## Foundation Review

- OPTICS-CONTRACT froze 14 persistent definitions, Node Role scheduling,
  neutral old-project defaults, direct generic mappings only where semantics
  match, and generated C++/provenance hashes. Static director review found no
  contract blocker.
- SPATIAL-HOST froze one coordinator-owned command buffer, two reusable
  RGBA32F mip pyramids, allocation-free identity handling, explicit
  clamp-to-edge/extended-range/alpha behavior, a 384 MiB spatial ceiling, and
  a 640 MiB integrated ceiling.
- Director review found that `moduleOutputWritten` was mutated before pipeline
  creation and dispatch succeeded. The same SPATIAL-HOST task corrected this
  fail-closed accounting path before ABI freeze.

## Foundation Freeze

- Contract: Resolve Spatial Contract v1, 14 persistent definitions, five
  normalized feature views, Node Role scheduling, neutral old-project
  fallback, role masks that do not mutate stored values, and generated
  C++/provenance hashes.
- ABI: Spatial Module ABI v1 with one coordinator-owned command buffer, one
  commit, execution-scoped image capabilities, full-frame RGBA32F passes,
  explicit clamp-to-edge handling, and no feature-visible queue/commit/wait/
  readback surface.
- Resource ceiling: two reused RGBA32F mip pyramids; 384 MiB enforced spatial
  transient ceiling; up to 253.125 MiB accepted following temporal reservation;
  640 MiB enforced integrated ceiling before commit.
- Corrected review finding: output-plan fulfillment now records a write only
  after successful pipeline/view/encoder setup and dispatch. Pass count was
  already post-success. No remaining source-level foundation blocker was
  found by static review.
- Verification boundary: build, tests, Resolve, installation, and runtime GPU
  memory/behavior proof remain explicitly unauthorized and were not performed.

## Wave Gate

- Five spatial feature tasks: source handoffs accepted from the exact common
  base; unauthorized runtime proof remains explicit debt.
- `SPATIAL-INTEGRATION`: source handoff accepted after all five feature
  handoffs; no other implementation workstream was active concurrently.
- Owner authorization resumed the lane. The two accepted foundation commits
  are integrated on `feature/resolve-spatial-foundation`.
- Frozen common feature base:
  `00711523fa09a6fc13d82374e31e94576b701a4a`.
- Clean five-feature integration base:
  `729d65472a6f08d2996f3dd464a91266580199b0` on
  `feature/resolve-spatial-five-feature-base`.
- Source-task terminal state: the manifest-limited integration commit is
  captured. Build/Metal/Resolve/runtime proof requires a separately authorized
  follow-up task.

## Completed Foundation Integration Manifest

Read-only recheck on 2026-07-18 JST confirmed that the director, both
foundation workers, and the planning worktree still resolve HEAD and local
`main` to `cb9b465414029e15abae9cac2e6895d4dd64ff84`. No accepted handoff path
overlaps another handoff path.

OPTICS-CONTRACT owns these eight paths:

- `apps/filmtone-resolve-ofx/Scripts/GenerateContracts/README.md`
- `apps/filmtone-resolve-ofx/Scripts/GenerateContracts/generate.ts`
- `apps/filmtone-resolve-ofx/Sources/Generated/Contracts/filmtone_finish_contract_provenance.hpp`
- `apps/filmtone-resolve-ofx/Sources/Generated/Contracts/filmtone_finish_contracts.hpp`
- `apps/filmtone-resolve-ofx/Sources/Generated/Contracts/filmtone_finish_contracts.provenance.json`
- `apps/filmtone-resolve-ofx/Sources/Generated/Contracts/filmtone_resolve_spatial.hpp`
- `docs/filmtone/davinci-plugin/workstreams/progress/optics-contract.md`
- `packages/film-lab-core/src/resolve-spatial-contract.ts`

SPATIAL-HOST owns these four paths:

- `apps/filmtone-resolve-ofx/Sources/Host/Spatial/SpatialMetalHost.h`
- `apps/filmtone-resolve-ofx/Sources/Host/Spatial/SpatialMetalHost.mm`
- `apps/filmtone-resolve-ofx/Sources/Host/Spatial/SpatialModuleProcessor.h`
- `docs/filmtone/davinci-plugin/workstreams/progress/spatial-metal-host.md`

The director owns only this additional path:

- `docs/filmtone/davinci-plugin/workstreams/progress/filmtone-spatial-director.md`

The authorized deterministic integration sequence completed as follows:

1. OPTICS-CONTRACT committed its eight paths as
   `52a47eaba4f919ebf28d6e8e971e8d40bb53d1ec` on
   `feature/resolve-spatial-optics-contract`.
2. SPATIAL-HOST committed its four paths as
   `8d6cdcb939cb4f0a0f50b9db07a080fbadc8674d` on
   `feature/resolve-spatial-host`.
3. The director created `feature/resolve-spatial-foundation` at the assigned
   base and cherry-picked OPTICS followed by HOST without a path conflict.
4. The integrated foundation tree is
   `00711523fa09a6fc13d82374e31e94576b701a4a`; this is the exact common base
   for all five feature tasks. The later director-record commit is deliberately
   not part of their implementation base.

## Resumed

- The owner explicitly authorized the recommended limited Git integration on
  2026-07-18 JST.
- The former authorization blocker is resolved. No feature task was started
  before both foundation commits were integrated into the common clean base.

## Feature Dispatch

All five start gates independently confirmed a clean detached worktree at
`00711523fa09a6fc13d82374e31e94576b701a4a`.

| Feature | Task | Worktree | State |
|---|---|---|---|
| Deep Glow | `019f7596-56cf-7d72-94c8-dd3aa69ad962` | `/Users/chibatakumi/.codex/worktrees/9e8cd883-a02c-444b-a983-379cfd04d516/filmtone` | Accepted — source handoff; runtime proof retained |
| Peripheral Chromatic Shift | `019f7596-3fd0-7e13-bf54-b44596be9db0` | `/Users/chibatakumi/.codex/worktrees/8f9701bf-400b-4276-b074-fcb4e46721fd/filmtone` | Accepted — source handoff; runtime proof retained |
| Lens Softness | `019f7596-6e00-7151-b0df-6831d8644e32` | `/Users/chibatakumi/.codex/worktrees/6794aa03-a64d-460e-a1ca-ee1a32aa192e/filmtone` | Accepted — source handoff; runtime proof retained |
| Texture Softness | `019f7596-86c6-7751-8440-c76023a0f475` | `/Users/chibatakumi/.codex/worktrees/6ddbb877-a231-4b0a-a762-ca57c335bf22/filmtone` | Accepted — source handoff; runtime proof retained |
| Vignette | `/root/vignette_feature` | `/Users/chibatakumi/.codex/worktrees/filmtone-spatial-vignette` | Accepted — source handoff; runtime proof retained |

The Codex project API accepted four concurrent worktree tasks and rejected the
fifth twice without creating a Vignette task. To keep the five-feature wave
parallel, Vignette uses a director-created clean detached worktree at the same
base and an internal parallel agent. Its edit and authorization boundaries are
identical to the four project tasks.

## Feature Handoff Acceptance Matrix

Every handoff must satisfy all common gates before feature-specific review:

- Diff is confined to its assigned feature folder and progress record.
- Foundation contract/generated facade/shared Host and sibling/accepted feature
  folders are unchanged.
- Processor uses only `SpatialModuleProcessor`, execution-scoped image views,
  and the coordinator command context; it cannot create/commit/wait/read back a
  command buffer or allocate unrelated graph storage.
- Disabled or zero identity schedules no passes and requests no spatial pool.
- Declared pass count/mip levels match every successful encode path, final
  output is written, and every pass covers its complete write target.
- RGBA32F extended-range RGB and source alpha are preserved; edge behavior is
  explicit clamp-to-edge with no transparent/black border fallback.
- Research Gate cites only primary papers or authoritative platform/vendor
  specifications and records the selected model, approximations, and
  unauthorized runtime/build debt.

Feature-specific acceptance:

| Feature | Frozen behavior to prove statically |
|---|---|
| Deep Glow | Continuous soft knee, multi-scale radius distribution, bounded energy/black protection, no halation/diffusion/streak additions |
| Peripheral Chromatic Shift | `rgbShift` 0..0.005 without x200 mapping, exponent 1.65, red outward/green center/blue inward, subpixel manual clamp sampling |
| Lens Softness | Continuous half-diagonal peripheral field, full-resolution radius normalization, restrained low/medium-frequency response distinct from Texture Softness |
| Texture Softness | Canonical effective clamp/constants, center-inclusive edge-aware base/detail attenuation, strong-edge/highlight/chroma protection, no peripheral mask |
| Vignette | Single pass/mip 0, half-diagonal display geometry, exact `rgb * clamp(1 - amount * radius^2, 0, 1)`, unchanged alpha |

### Accepted: Vignette

- Changed paths are limited to `Effects/Vignette/**` and its progress record.
- `VignetteProcessor` consumes only the generated normalized view, declares
  one full-frame pass and one mip, and requests no scratch resource.
- Display-space half-diagonal geometry includes pixel aspect ratio and
  independent X/Y render scale at pixel centers. The Metal kernel implements
  the exact frozen quadratic attenuation, multiplies RGB without a global
  clamp, and copies source alpha unchanged.
- Neutral view state is exact identity before Host allocation. Static review
  found no source-level blocker; Metal compilation, Resolve visuals, and
  runtime comparison remain unauthorized verification debt.

### Accepted: Deep Glow

- Changed paths are limited to `Effects/DeepGlow/**` and its progress record.
  Normal frames declare six total mip levels and eleven passes: five
  reduce/extract passes, five retain-copy passes, and one full-frame composite.
- The continuous quadratic soft knee selects only positive highlight energy;
  five 1/2–1/32 unit-sum tent levels are combined with radius-dependent weights
  normalized to one. Black has no haze floor, radius does not change total
  energy, RGB is not globally clamped, and no halation/diffusion/streak model
  was added.
- Every read/write pair respects the frozen two-pyramid plane-alias boundary.
  The final pass reads retained source-plane mips and writes only the graph
  output plane. Invocation tokens, mip-zero endpoints, full-frame dimensions,
  and distinct planes fail closed before encoding.
- Premultiplied input carries associated selected energy and filtered coverage
  in RGBA scratch mips. Each band is coverage-normalized, then associated once
  by destination alpha; constant partial-alpha input therefore avoids
  alpha-squared attenuation, zero-alpha output receives no glow, and source
  alpha is copied unchanged.

### Accepted: Peripheral Chromatic Shift

- Changed paths are limited to `Effects/PeripheralChromaticShift/**` and its
  progress record. The processor consumes the generated facade view and
  declares one full-frame pass at mip zero.
- The kernel uses the frozen unscaled `rgbShift` frame fraction and exponent
  `1.65`, samples red outward / green at center / blue inward, and preserves
  centered alpha. Manual bilinear reads clamp every coordinate to an edge
  texel without clamping extended-range RGB.
- Display-aspect canonical coordinates include PAR and independent render
  scale. A director-requested post-cast finite/positive uniform boundary now
  rejects pathological frame values before command encoding.

### Accepted: Lens Softness

- Changed paths are limited to `Effects/LensSoftness/**` and its progress
  record. One mip-zero pass uses a non-negative 17-tap PSF whose weights sum to
  one, so constant RGB energy is preserved.
- The frozen native response is retained: half-diagonal peripheral field,
  `smoothstep(0.25, 1)`, radial exponent `1.52`, amount exponent `0.78`, and
  mix ceiling `0.72`. The 1.6–3.45 full-resolution-pixel radius is scaled
  independently by X/Y render scale.
- Manual clamp sampling, center alpha copy, post-cast finite validation, and
  the distinct non-edge-aware optical PSF keep this separate from Texture
  Softness and within the frozen ABI.

### Accepted: Texture Softness

- Changed paths are limited to `Effects/TextureSoftness/**` and its progress
  record. One mip-zero pass consumes the generated effective amount, radius,
  range sigma, detail gates, chroma scale, and highlight bias without hidden
  tuning controls.
- The center-inclusive eight-neighbor bilateral reference and bounded
  base/detail attenuation reproduce the committed Filmtone detail-softness
  model. Range rejection, strong-detail release, chroma reduction, and
  highlight bias protect major edges and avoid importing Lens Softness's
  peripheral field.
- Radius follows independent render scale, all interpolation is explicit
  clamp-to-edge, alpha is copied from center, and RGB remains RGBA32Float with
  fast math disabled.

## Completed Feature Integration Manifest

The owner explicitly authorized the recommended limited Git operation. Each
feature worktree received one manifest-only commit, and every worktree was
clean after commit:

| Feature | Branch | Source commit | Integrated commit |
|---|---|---|---|
| Texture Softness | `feature/resolve-spatial-texture-softness` | `a0c4567994b2b480474640552baefc21263b7cbd` | `5423a34` |
| Peripheral Chromatic Shift | `feature/resolve-spatial-peripheral-chromatic-shift` | `ed6319da1c7e2797062013db06e80febbdaca891` | `0757108` |
| Lens Softness | `feature/resolve-spatial-lens-softness` | `3ce67d3b21577dcf9e6d39c06f31acbd6f2c9169` | `7bd9ddb` |
| Deep Glow | `feature/resolve-spatial-deep-glow` | `8d82f5860e8d46bac31e550cff10ae375390cf77` | `3d3a386` |
| Vignette | `feature/resolve-spatial-vignette` | `bc1c16b0d358fc54171077960538ce0dccf10b6b` | `729d654` |

The director created
`/Users/chibatakumi/.codex/worktrees/filmtone-spatial-five-feature-base`
from `00711523fa09a6fc13d82374e31e94576b701a4a`, then cherry-picked the five
commits in final graph order: Texture Softness, Peripheral Chromatic Shift,
Lens Softness, Deep Glow, Vignette. Read-only path comparison found each
integrated feature tree identical to its accepted source commit. The resulting
branch is clean at exact SHA
`729d65472a6f08d2996f3dd464a91266580199b0`.

Builds, tests, Resolve, installation, push, and release remain unauthorized.

## Spatial Integration Dispatch

- Task: `019f75a9-8f4e-7352-85ae-e4122d1928a2`
- Worktree:
  `/Users/chibatakumi/.codex/worktrees/72be83d2-b4c9-499a-b7cd-12456a1552ad/filmtone`
- Base: `729d65472a6f08d2996f3dd464a91266580199b0`
- Branch: `feature/resolve-spatial-integration`
- Commit: `202907ea34b43d1e03e78c2db5125d4d7a722fef`
- State: `Complete — clean source integration; build/Resolve proof retained`
- Exclusive edit surface: `Sources/Integration/**`,
  `Sources/Host/FilmtoneFinishPlugin.cpp`, OFX `Makefile`, `Info.plist`, and
  `progress/spatial-integration.md`.
- Accepted feature folders, generated contract, canonical source, Spatial Host
  foundation, and existing three feature folders are read-only.
- No quality/build/release worker was dispatched.

## Accepted: Spatial Integration

- The integration handoff is confined to the seven assigned OFX source/build
  surfaces plus `progress/spatial-integration.md`. Its worktree started at the
  exact five-feature base
  `729d65472a6f08d2996f3dd464a91266580199b0`. The accepted eight-file manifest
  is committed cleanly as
  `202907ea34b43d1e03e78c2db5125d4d7a722fef` on
  `feature/resolve-spatial-integration`.
- Public descriptor labels and `CFBundleName` now use `Filmtone`; the durable
  plugin and bundle identifier remains
  `com.chibatakumi.filmtone.finish`. Internal bundle/binary filenames and
  release versions were not changed.
- Node Role consumes the three generated public labels, defaults to `All`, and
  masks scheduling without changing stored values. All 14 generated spatial
  definitions supply their persistent IDs, kinds, defaults, and ranges; the
  five new feature surfaces therefore remain neutral for old projects.
- The exact scheduled graph is Texture Softness -> Peripheral Chromatic Shift
  -> Lens Softness -> Deep Glow -> Vignette -> Film Breath -> Gate Weave ->
  Film Damage. `Optics` excludes the film rail and the film-only role excludes
  the spatial rail.
- All-neutral and role-masked-neutral states retain the identity path. Invalid
  frame rate remains an error only for a configured-active, role-scheduled
  Film Breath/Gate Weave/Film Damage rail; static Optics does not invent or
  require a temporal clock.
- Spatial work commits once on the Host queue before accepted film processor
  command buffers. One or two full-frame RGBA32F transition buffers are reused
  as ping-pong for the following film rail, and their exact tight bytes are
  reserved through Spatial Host's frozen 640 MiB integrated ceiling before
  the spatial commit.
- Director and independent graph review found no source-level blocker. The
  existing Film Breath, Gate Weave, Film Damage, Spatial Host, generated
  contract, canonical contract, and five accepted feature folders are
  unchanged from the integration base.
- Source acceptance does not imply compilation, Resolve/runtime behavior,
  visual quality, packaging, release, or public availability. Build/Metal,
  old-project/Node Role, fps, alpha/HDR, PAR/render-scale, UHD memory report,
  queue execution, and visual proof remain explicit verification debt.
- Copy / History Impact: the Resolve surface now uses the owner-fixed public
  name and literal role guidance without a release claim. Future usage copy
  must describe the two-instance CinePrint35 workflow while preserving the
  compatibility-ID history. Article Opportunity: `Full article`, held until
  runtime/visual/distribution truth exists. Change-History Opportunity:
  `Developer note`, held until runtime proof.

## Verification / Operations

- Performed: read-only Git state/base/source inspection and planning/source
  comparison; authorized foundation branch creation, manifest-limited staging
  and commits, ordered cherry-picks, common feature-base ref creation, five
  clean/base start-gate checks, five exclusive source/diff reviews, and
  director-requested fail-closed/record corrections; authorized manifest-only
  feature commits and deterministic five-feature cherry-pick integration;
  integration ownership review, generated parameter/default/role comparison,
  public-name/compatibility-ID inspection, exact graph/identity/fps/resource
  review, an independent read-only RenderGraph review, and the explicitly
  authorized eight-file integration branch/commit capture.
- At source acceptance, tests, test-like verification, builds, Resolve,
  installation, merge, rebase, push, and release had not been performed. The
  later owner-authorized build/install/Resolve preparation is recorded below;
  tests, merge/rebase, push, and release remain unperformed.

## Manual Visual Review Preparation — 2026-07-19 JST

- The owner explicitly authorized build, installation, and Resolve preparation
  for manual visual review.
- `make -C apps/filmtone-resolve-ofx` completed successfully from integration
  commit `202907ea34b43d1e03e78c2db5125d4d7a722fef`. The only diagnostics were
  one existing macOS 15 `fastMathEnabled` deprecation warning in
  `MetalPipelineCache.mm` and one unused-parameter warning in the vendor OFX
  Support source.
- The generated arm64 bundle was installed at
  `/Library/OFX/Plugins/FilmtoneFinish.ofx.bundle`. Its installed binary and
  build binary both resolve to SHA-256
  `f8038d2f8b3a4654c098c4fa6b6bab61c2661b82b81dc8cd6cfadeba384b0499`.
- Resolve was restarted and loaded
  `com.chibatakumi.filmtone.finish` from the installed system bundle. The Color
  page displays the public `Filmtone` name and the five new spatial control
  groups in the existing quality project.
- The temporary `OFX_PLUGIN_PATH` launch override used to avoid the initial
  administrator-UI blocker was removed after the system bundle was confirmed.
- Manual owner visual acceptance was rejected on 2026-07-19 JST. Peripheral
  Chromatic Shift, Lens Softness, and Film Damage were judged effective enough
  to preserve. Deep Glow, Texture Softness, and Vignette were judged too
  conservative; Deep Glow in particular did not justify itself against
  Resolve's native Glow. Film Breath and Gate Weave were judged behaviorally
  incorrect rather than merely weak.
- Source diagnosis found that Deep Glow normalizes both every reduction kernel
  and the final mip mixture while limiting strength to one; radius therefore
  redistributes a fixed energy budget. Texture Softness caps its effective
  amount at `0.65` and its full-resolution radius at `2.5` pixels. Vignette is
  a center-fixed quadratic RGB attenuation with only one amount control.
- Film Breath currently combines four independent seconds-domain value-noise
  lanes with periods from `1.8` to `15.5` seconds and a `1.25` second startup
  envelope. Gate Weave currently blends multi-sine drift with deterministic
  per-frame scatter and exposes cycles per second. These do not match the
  requested frame-period stochastic behavior closely enough for visual
  acceptance.
- Quality recovery is blocked on an explicit owner scope override because the
  frozen plan made existing Film Breath and Gate Weave behavior/folders
  read-only. The proposed override preserves Peripheral Chromatic Shift, Lens
  Softness, and Film Damage, while reopening only Deep Glow, Texture Softness,
  Vignette, Film Breath, Gate Weave, their owning contracts/parameter UI, and
  required integration wiring. Foundation/ABI/resource ceilings remain frozen
  unless a concrete processor change proves a revision necessary.
- Automated tests remain outside the current request and were not run. Push
  and release were not performed.

## Visual Quality Recovery — 2026-07-19 JST

- The owner explicitly overrode the prior Film Breath / Gate Weave read-only
  freeze and authorized the recommended quality-recovery implementation,
  contract/UI updates, rebuild, reinstall, and renewed manual Resolve review.
- Preserved without behavioral edits: Peripheral Chromatic Shift, Lens
  Softness, and Film Damage.
- Reopened model work: Deep Glow, Film Breath, and Gate Weave. Reopened
  calibration/transfer work: Texture Softness and Vignette. Durable plugin and
  parameter IDs, neutral defaults, Node Role, graph order, Spatial ABI, and
  resource ceilings remain compatibility constraints.
- Acceptance returns to manual owner review. Automated tests and test-file work
  remain outside the current request; push and release remain unperformed.

### Quality-Recovery Implementation / Manual Review Build

- Deep Glow now separates spread shape from a nonlinear diffusion-energy
  response. Its five-mip / eleven-pass Spatial ABI and resource footprint are
  unchanged; the composite adds an HDR-safe luminance shoulder and preserves
  source hue, alpha, negative RGB, and extended range.
- Film Breath now uses a Resolve-local integer-frame stochastic carrier shared
  across exposure, tonal, and colour variation. Timeline frame zero is no
  longer forced to identity. The former fixed encoded-signal contrast regions
  were replaced by a distinct bounded log-luminance slope plus neutral/channel
  optical-density gains.
- Gate Weave's multi-sine oscillator was replaced by a bounded stochastic
  X/Y/rotation trajectory. The existing cadence field now acts as inverse
  correlation time; Instability increases short-correlation and per-frame
  registration scatter. The exact constant auto-crop envelope is retained.
- Texture Softness now uses two bilateral sampling rings, correct neutral-luma
  detail reconstruction, the full Amount range, and up to five full-resolution
  pixels of radius. Vignette now uses a mid-field-visible smooth radial falloff
  capped above black at maximum Amount.
- The canonical Resolve spatial source was updated and all eleven contract
  artifacts were regenerated from it. Persistent parameter IDs, neutral
  defaults, Node Role, graph order, Spatial ABI, and resource ceilings remain
  unchanged. Peripheral Chromatic Shift, Lens Softness, and Film Damage have
  no behavioral diff.
- `make -C apps/filmtone-resolve-ofx` completed successfully. The rebuilt and
  installed system binary both have SHA-256
  `01ed9dfc1edce4dec0c4697e0eb24c57ff5b71de62999d9714807a6803d88c53`.
  Resolve PID `71323` loaded that exact path from
  `/Library/OFX/Plugins/FilmtoneFinish.ofx.bundle`.
- The quality project is open on the Color page. Deep Glow is prepared at
  Strength `0.65`, Threshold `0.55`, Radius `0.72`, Soft Knee `0.68`; Film
  Breath and Gate Weave are enabled at Amount `1.0`. Texture Softness stores
  `0.65` and Vignette stores `0.55`, both disabled for isolated toggle review.
  Each changed Metal processor was activated once without a Resolve error
  dialog before the isolated review state was restored.
- Copy / History Impact: Resolve control labels/hints now describe diffusion,
  frame correlation, and stochastic registration literally; no release or
  public-availability claim was added. Article Opportunity: `Developer note`,
  held until owner visual acceptance. Change-History Opportunity: `Developer
  note`, because the conservative safety-first models were replaced after
  direct product review.
- Automated tests and test files were not run or changed. No commit, merge,
  rebase, push, packaging, or release operation was performed.

## Film Breath Subtractive-Color Correction Dispatch — 2026-07-19 JST

- Owner review corrected the quality-recovery interpretation: Film Breath
  color is not temperature/tint white-balance motion. Official product
  references describe random subtractive transformations similar to a CMY
  Color Head, alongside frame-varying exposure and tonal contrast.
- The director froze three immutable plans and three dedicated progress records:
  `FILM-BREATH-CMY-MODEL`, `FILM-BREATH-CMY-METAL`, and
  `FILM-BREATH-PERIOD-UI`.
- Parallel tasks:
  - `/root/film_breath_cmy_model`: `FilmBreathOffsets.h/.cpp`
  - `/root/film_breath_cmy_metal`: `FilmBreathProcessor.mm`
  - `/root/film_breath_period_ui`: `FilmBreathParameters.h` and the two
    `Integration/FilmtoneFinishParameters` files
- All three use integration base
  `202907ea34b43d1e03e78c2db5125d4d7a722fef`. Because the exact uncommitted
  quality build is actively open for owner review, the director recorded a
  narrow start-gate exception: each worker verifies its assigned-file hashes
  instead of requiring a globally clean worktree, and edits only an exclusive
  file set.
- No worker may build, run tests or Resolve, install, generate, or perform Git
  writes. The running Resolve process and installed bundle remain untouched
  while the owner inspects the remaining effects.
- Director integration begins only after all three Handoff Schema records
  return. Build/install/restart and renewed Film Breath visual review require a
  later explicit owner instruction.

### Accepted: Film Breath Subtractive-Color Source Wave

- All three parallel handoffs returned source-complete without a blocker and
  were accepted after coordinator cross-review. Their exclusive file sets did
  not overlap.
- The Resolve-local offsets are now exposure, tonal contrast, and independent
  signed C/M/Y densities. A shared stochastic carrier keeps the changes part of
  one emulsion event, while separately salted detail prevents the colour path
  from collapsing into temperature/tint or neutral-only breathing.
- New persistent parameter
  `com.forestone.filmtone.finish.filmBreath.periodFrames` is registered in the
  existing Advanced group with default `24`, range `1...120`, and complete
  describe/fetch/evaluate wiring. Existing parameter IDs/defaults remain
  unchanged.
- The Metal response uses signed stop-density transmission. Positive C/M/Y
  primarily absorbs R/G/B with small non-negative cross-coupling; it does not
  normalize density back to equal luminance. Exposure and bounded tonal slope
  remain separate, RGB is unclamped, and alpha passes through.
- Embedded Metal kernel and cache names advance to v4. The accepted combined
  integration diff SHA-256 is
  `efc9ce039b5932978a630fc384b7b1e29b963162447eb79869b0b83dc8d3febb`.
- Static acceptance is not a build or visual verdict. The currently loaded
  system bundle remains the previous quality build with binary SHA-256
  `01ed9dfc1edce4dec0c4697e0eb24c57ff5b71de62999d9714807a6803d88c53`;
  the owner can continue inspecting it without interruption.
- No tests, test-like checks, test files, build, Resolve operation, install,
  generation, or Git write was performed in this wave.
- Copy / History Impact: internal Film Breath labels now state subtractive CMY
  variation and Period literally; no release or parity claim exists. Article
  Opportunity: `No story` before visual acceptance. Change-History
  Opportunity: `Developer note` after acceptance, documenting why the earlier
  white-balance interpretation was rejected.
