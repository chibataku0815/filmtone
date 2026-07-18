# Progress: Spatial Metal Host

Plan (read-only planning source):
`/Users/chibatakumi/.codex/worktrees/filmtone-davinci-optical-planning/docs/filmtone/davinci-plugin/workstreams/spatial-metal-host.md`

Owner: `SPATIAL-HOST`; master state is director-owned
Last synced: 2026-07-18 JST

## State

`Review — additive source complete; build/runtime verification not authorized`

## Assignment

- Delegation source: `019f7573-3066-72c1-9b47-02c586416354`
- Worktree: `/Users/chibatakumi/.codex/worktrees/0a1c/filmtone`
- Assigned and confirmed HEAD: `cb9b465414029e15abae9cac2e6895d4dd64ff84`
- Parallel peer: `OPTICS-CONTRACT`
- Exclusive source area:
  `apps/filmtone-resolve-ofx/Sources/Host/Spatial/**`
- Existing `RenderContext`, `MetalImageView`, `ModuleProcessor`, RenderGraph,
  Film Breath, Gate Weave, and Film Damage processors remain read-only.

## Checklist

- [x] Confirm clean/base and exact exclusive Host paths.
- [x] Freeze additive spatial encode and resource-plan ABI.
- [x] Implement coordinator-owned command encoding.
- [x] Implement bounded ping-pong and scratch/mip ownership.
- [x] Record format, alignment, bounds, queue, lifetime, and memory ceiling.
- [x] Inspect exclusive diff and return handoff.

## Public Source Handoff

- `SpatialModuleProcessor.h` freezes Spatial ABI version 1. A feature exposes
  identity, a bounded `SpatialResourcePlan`, and local pass encoding through
  `SpatialMetalCommandContext`; it receives no queue, command buffer, or raw
  Metal resource and therefore cannot commit through the ABI.
- `SpatialResourcePlan` declares an exact feature-pass count, total mip level
  count, full-frame behavior, clamp-to-edge policy, extended-range
  preservation, and alpha preservation. Invalid, undeclared, or unfulfilled
  plans fail closed before commit.
- `SpatialResourceScope` exposes only execution-token-checked views into two
  coordinator-owned texture pyramids. Level zero is graph ping-pong; higher
  levels are module-scoped scratch. The maximum active request is allocated
  once and the same levels are reused sequentially across all spatial modules.
- `SpatialMetalCommandContext` accepts pipeline, texture, inline-uniform, and
  full-grid dispatch descriptors. It rejects fast math, in-place read/write
  aliasing, writes to the retained full-resolution input, expired resources,
  partial write grids, and pass-count drift.
- `encodeSpatialMetalSequence` preflights all active modules, performs
  buffer-to-texture conversion, encodes modules in supplied order, converts
  the requested window back to the Host buffer, and commits one command
  buffer. An empty window or all-identity graph returns `noWork` without
  allocation, conversion, or commit.

## Frozen Geometry And Sampling

- Spatial v1 accepts only float RGBA Host buffers and internal
  `MTLPixelFormatRGBA32Float`; no lower-precision or CPU fallback exists.
- Host row bytes must be positive, float4-aligned, large enough for bounds,
  and representable by v1 shader indices. Compute bridge kernels are used
  instead of Metal blit copies, so no undocumented 256-byte Host-row
  alignment is assumed.
- Source/output bounds must be identical and must agree with optional
  `RenderContext` bounds. Modules populate full bounds; only the requested
  render window is copied back to Host output.
- Texture row zero maps to Host `bounds.y1`. Canonical coordinates use
  `renderScale`, explicit clip pixel aspect ratio, and the logical display
  short axis. The nearer frame edges map approximately to `-1/+1`; positive Y
  follows increasing Host Y.
- Spatial v1 edge behavior is explicit clamp-to-edge. Transparent/zero,
  repeat, mirror, implicit color management, global RGB clamp, and alpha
  modification are outside the contract. No raw sampler is exposed; feature
  kernels use integer texture reads and explicit manual interpolation so
  RGBA32Float filterability is not silently assumed.

## Frozen Ordering, Lifetime, And Failure Semantics

- Spatial conversion and feature passes use the Host-provided queue and one
  coordinator-owned command buffer. Feature code has no commit/wait/readback
  surface.
- The command buffer is committed only after every module fulfills its exact
  pass/output plan. Any preflight, allocation, pipeline, encoder, binding, or
  plan failure returns false without committing this graph, so this graph has
  not modified Host output.
- A successful `encoded` result means asynchronous work was committed. No
  hidden wait, readback, or synchronous post-commit error poll is added; later
  accepted processors remain ordered by committing their existing command
  buffers afterward on the same queue.
- Private textures are released by the local owner after commit; the Metal
  command buffer retains referenced resources for GPU execution.

## UHD Memory Contract

- Two complete 3840x2160 RGBA32F pyramids are exactly `353,889,760` tight
  bytes (`337.50 MiB`). Two level-zero surfaces alone are `265,420,800` bytes
  (`253.125 MiB`).
- The spatial pool hard ceiling is `402,653,184` bytes (`384 MiB`). The host
  checks tight bytes, Metal heap size/alignment estimates, and actual
  `allocatedSize`; the largest accounted value is enforced.
- The accepted three-module graph can require at most two later UHD RGBA32F
  transitions: `265,420,800` bytes (`253.125 MiB`). Integration passes this as
  a following-queue reservation before spatial commit.
- Spatial allocation plus following-queue reservation must fit the fixed
  integrated ceiling of `671,088,640` bytes (`640 MiB`). Allocation remains
  bounded independently of the number of active spatial modules.
- Host source/output buffers and pipeline-cache objects are externally owned
  and are not counted as plugin transient graph storage.

## Remaining Integration Work

- `SPATIAL-INTEGRATION` owns adding `SpatialMetalHost.mm` to the build source
  list, passing OFX clip pixel aspect ratio, supplying the bounded temporal
  reservation, scheduling the five processors, and connecting the final
  spatial-to-temporal graph.
- Each feature worker owns only its feature processor/pipelines and consumes
  the frozen ABI. No feature may add graph storage or command-buffer commits.
- The existing temporal RenderGraph still contains its accepted fixed
  maximum of two transition buffers; it was intentionally not edited here.

## Director Review Correction

- Director review found that `encodeComputePass` marked
  `moduleOutputWritten` during binding validation. A module that ignored that
  failed pass could therefore satisfy the later pass-count check without ever
  successfully dispatching a write to its declared output.
- Binding validation now records `targetsModuleOutput` locally. The durable
  `moduleOutputWritten` flag is updated only after pipeline/view/encoder setup
  and dispatch all succeed.
- Equivalent plan-fulfillment state mutation was reviewed in the same path.
  `encodedFeaturePassCount` was already incremented only after successful
  dispatch; no other pre-success mutation remains.

## Verification

- Start gate: `git status --short --branch` was clean and HEAD matched the
  assigned base before edits.
- Per owner authorization, tests, test files, build, Resolve, install, and Git
  writes were not performed.
- Static exclusive-area inspection passed: status contains only the three new
  `Host/Spatial` files and this progress record; HEAD remains the assigned
  base. The spatial source contains exactly one command-buffer commit and no
  wait/readback, private `MTLBuffer` allocation, or lower-precision format.
- Director correction inspection confirms both `moduleOutputWritten` and
  `encodedFeaturePassCount` mutate only after successful dispatch.
- No trailing whitespace was found in the exclusive files.

## Copy / History Impact

- No copy/history impact: this workstream adds an internal, unintegrated Host
  ABI and changes no public label, parameter, release, or compatibility claim.
- Article Opportunity: `Developer note`, only after integration and runtime
  verification make the execution/memory claims true in product.
- Change-History Opportunity: `Yes` — this records the transition from
  processor-owned command buffers and per-transition allocation to a bounded,
  coordinator-owned spatial graph while preserving the accepted processors.
