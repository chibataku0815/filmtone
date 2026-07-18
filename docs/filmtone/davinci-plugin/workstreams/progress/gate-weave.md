# Progress: Gate Weave

Plan: [Gate Weave](../gate-weave.md)
Owner: `WEAVE` worker; master state is coordinator-owned
Last synced: 2026-07-18 JST

## State

`Review — source Done; verification not authorized`

## Assignment

- ID: `WEAVE`
- Task: `019f7470-153f-7aa3-9797-77d4aa980bc6`
- Repository: Filmtone
- Worktree: `/Users/chibatakumi/.codex/worktrees/3fb973be-7602-4dd3-bf4c-c0acd3049ea3/filmtone`
- Base: `6130aae610de9f8c535f4e72d2078f2f1aabed66`
- Parallel peers: `BREATH`, `DAMAGE`

## Current Loop

The isolated source implementation is complete. The pure resolver preserves
the frozen v2.2 temporal equations and Gate Weave stream salt, and the local
processor encodes a render-scale-aware Metal inverse warp with constant crop
edge safety. Static review corrected the legacy vertical-jitter ratio to derive
directly from generated contract defaults, with no local default-value copy.
Compile, Resolve, and visual proof remain outside authorization.

## Checklist

- [x] Confirm accepted Gate Weave fields and module interface.
- [x] Confirm Foundation Freeze SHA and exclusive feature directory.
- [x] Implement inverse-coordinate subpixel X/Y translation and rotation.
- [x] Implement safe edge compensation without black-edge flashes.
- [x] Preserve cadence across supported frame rates and render scales.
- [x] Preserve wide-gamut floats and alpha.
- [x] Record sampling, maximum transform, bounds, and limitations.
- [x] Return terminal handoff for coordinator review.

## Changed Files

- `apps/filmtone-resolve-ofx/Sources/Effects/GateWeave/GateWeaveTransform.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/GateWeave/GateWeaveTransform.cpp`
- `apps/filmtone-resolve-ofx/Sources/Effects/GateWeave/GateWeaveProcessor.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/GateWeave/GateWeaveProcessor.mm`
- `docs/filmtone/davinci-plugin/workstreams/progress/gate-weave.md`

## Verification

- Performed: clean worktree and exact-base gate; read-only accepted-interface
  and deterministic-reference inspection; repeated read-only changed-file and
  exclusive-scope inspection; static-review ownership correction and narrow
  source/progress diff re-read, including confirmation that the handwritten
  `0.012` / `0.0066` copies are absent from the resolver.
- Authorization: no tests, builds, Resolve, installation, or Git history
  writes.
- Not performed: tests, test files, build, compiler/type checks, Metal library
  compilation, numerical/reference parity, image renders, Resolve launch,
  installation, performance measurement, or stage/commit/merge/rebase/push.

## Blockers

No source blocker. Compile and product-quality proof remain explicit,
unauthorized verification debt.

## Next Action

Coordinator review, then INTEGRATION-owned source-list, parameter, and pass-graph
wiring. QUALITY later owns compiled, visual, and performance proof.

## Handoff

### Public interfaces and artifacts

- `GateWeaveTransform`, `GateWeaveMotionEnvelope`,
  `resolveGateWeaveTransform`, and `resolveGateWeaveMotionEnvelope` are pure C++
  interfaces consuming the generated Film Damage v2.2 and deterministic
  context v1 types.
- `GateWeaveProcessor` implements `host::ModuleProcessor` locally and consumes
  a generated `FilmtoneFinishMappingV1`, retaining its normalized
  `FilmDamageRecipeV2`. Host `explicitSeed` overrides the mapping's recipe seed;
  both paths derive the frozen independent Gate Weave stream.
- `GateWeaveEdgeSafetyMode::automaticCrop` is the only supported local safety
  mode. Final control naming and registration remain INTEGRATION-owned.

### Decisions fixed

- Cadence, phase, per-frame jitter hashes, travel-axis suppression, format
  instability, and the revision-2.2 legacy vertical-jitter envelope mirror the
  accepted external deterministic reference. Jitter zero leaves only smooth
  cycles-per-second motion.
- The revision-2.2 vertical-jitter compatibility ratio is derived from a
  constexpr default-constructed generated `FilmDamageGateWeave`; the feature
  folder owns no handwritten copy of those external default amplitudes.
- X/Y amplitudes use the canonical full-frame short axis and are converted by
  each render-scale component. The Metal pass rotates in canonical coordinates
  around the full source center, converting frozen screen-down Y and clockwise
  degrees to OpenFX's Y-up coordinates.
- Sampling is a normalized 4-by-4 Catmull-Rom reconstruction over float RGBA.
  RGB and alpha are resampled together with no `0...1` or alpha clamp.
- Edge safety derives one conservative crop from the complete parameter motion
  envelope, output bounds, render scale, rotation, and cubic footprint. It is
  constant across time, so it neither exposes black nor pumps zoom per frame;
  valid footprints never engage the shader's defensive index clamp.

### Maximum transform and bounds

- At unit global gain, amount 1, jitter 1, and the accepted field maxima, the
  `film35mm` envelope is X `9.25%` and Y `7.9545%` of canonical short axis,
  with `8.75°` clockwise rotation. The broadest accepted `film8mm` profile is X
  `14.3375%`, Y `12.3295%`, and `13.5625°`; automatic crop covers these limits.
- Active sampling requires float RGBA, positive pixel-aligned row strides,
  distinct source/output Metal buffers, full source/output bounds matching the
  Host context, and source dimensions of at least 4 by 4 pixels. Render-window
  subsets use the full output bounds for one seam-free safety scale.
- Extreme rotation necessarily crops visible image area; final taste tuning is
  QUALITY-owned. No CPU, OpenCL, CUDA, bilinear, or reduced-quality fallback is
  present.

### Copy / history impact

- No copy/history impact: this is isolated, unregistered module source and does
  not yet make a public availability claim.
- Article Opportunity: **No story** at this stage.
- Change-History Opportunity: **No**; the frozen ownership and product
  direction did not change.
