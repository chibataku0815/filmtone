# Progress: Film Breath

Plan: [Film Breath](../film-breath.md)
Owner: `BREATH` worker; master state is coordinator-owned
Last synced: 2026-07-18 JST

## State

`Review — final source correction complete; coordinator acceptance pending`

## Assignment

- Task: `019f746f-c80c-7b90-963d-f6cd3b05ef95`
- Repository: Filmtone
- Worktree: `/Users/chibatakumi/.codex/worktrees/e9c57c76-3e12-4d11-b2d7-7dbb1c661cbc/filmtone`
- Base: `6130aae610de9f8c535f4e72d2078f2f1aabed66`
- Parallel peers: `WEAVE`, `DAMAGE`

## Current Loop

Coordinator disposition A required a final source correction before BREATH can
be accepted. Film Breath v1 now uses canonical cadence only, carries the
generated Finish parameter struct for Variation / Enabled / Amount, resolves
actual OFX frame-time, and calls the frozen Film Breath facade directly. Only
the three advanced response controls remain feature-local. The next proof
requires coordinator review and the unauthorized Integration/build/Resolve
wave.

## Checklist

- [x] Confirm accepted Film Breath C++ handoff and module interface.
- [x] Confirm Foundation Freeze SHA and exclusive feature directory.
- [x] Implement deterministic mean-neutral photometric movement.
- [x] Preserve wide-gamut floats and alpha.
- [x] Use canonical Film Breath cadence and defer adjustable cadence.
- [x] Keep base IDs/defaults owned by generated Finish mapping definitions.
- [x] Call the frozen Film Breath facade with exact Resolve host seconds.
- [x] Keep random stream independent from WEAVE and DAMAGE.
- [x] Record symbols, uniforms, limitations, and verification state.
- [x] Return terminal handoff for coordinator review.

## Changed Files

- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathParameters.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathOffsets.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathOffsets.cpp`
- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathProcessor.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathProcessor.mm`
- `docs/filmtone/davinci-plugin/workstreams/progress/film-breath.md`

## Public Interfaces And Uniforms

- Parameters: `FilmBreathParameters` carries generated
  `forestone::filmtone::FilmtoneFinishParametersV1 finishParameters` plus the
  three local response values.
- Local metadata: `FilmBreathParameterDescriptor` and the three-entry
  `kFilmBreathParameterDescriptors` array for exposure, tonal, and color
  response only.
- Base metadata/defaults: generated
  `kFilmtoneFinishParameterDefinitions`; Variation, Film Breath Enabled, and
  Film Breath Amount are not redefined locally.
- Pure C++ offsets: `FilmBreathOffsets`, `resolveFilmBreathOffsets`, and
  `isFilmBreathIdentity`.
- Processor: `FilmBreathProcessor final : host::ModuleProcessor`.
- Metal pipeline cache key:
  `filmtone.finish.film-breath.photometric.v1`; function:
  `filmtoneFilmBreathV1`; fast math disabled.
- Uniform layout, in order: `sourceRowStridePixels`,
  `outputRowStridePixels`, `width`, `height`, `exposure`, `contrast`,
  `temperature`, `tint` (32 bytes, 16-byte aligned).

## Fixed Decisions And Limitations

- Resolve frame-time uses timeline fps when valid and source fps only as a
  fallback; no local material-frame-rate constant exists.
- `makeResolveRenderContextV1` always receives the actual OFX frame-time.
  `makeFilmtoneFinishFilmBreathOffsetsV1` then consumes that exact context
  directly, preserving actual host seconds, frame index, and frame rate.
- Film Breath v1 exposes canonical cadence only. Adjustable cadence is deferred
  until a future generated contract/facade supports it without weakening the
  Resolve time contract.
- The host explicit seed, when present, takes precedence over Variation and is
  reduced to the frozen 32-bit deterministic seed domain. The frozen Film
  Breath stream salt remains the only module decorrelation source.
- Exposure, tonal, and color responses default to `1.0` and are limited to
  `0...1`, so advanced controls attenuate independently without exceeding the
  canonical offset maxima.
- Pixel order mirrors Filmtone evidence: EV exposure, three-piece tonal
  contrast, then temperature/tint response. RGB is not globally clamped and
  source alpha is written unchanged.
- The module has no playback-history state, cumulative accumulator, CPU,
  OpenCL, CUDA, or silent reduced-quality fallback.
- Integration registration, final labels/page order, build-source wiring,
  compiled Metal proof, Resolve behavior, visual tuning, and empirical cadence
  or temporal-mean measurement remain outside this workstream.

## Verification

- Performed: clean/base start gate; complete assigned documents and accepted
  interface reads; repeated `git status --short --untracked-files=all` scope
  inspection; direct source reads; targeted read-only symbol/invariant search;
  static correction review confirming no cadence field/descriptor/evaluation,
  generated base ownership, actual-time adapter input, and direct frozen-facade
  invocation.
- Not performed: tests, test files, compiler or syntax checks, builds, Metal
  compilation, Resolve launch, installation, profiling, visual acceptance, or
  Git stage/commit/merge/rebase/push.

## Blockers

No source blocker. Compiled and product-quality proof remains blocked only by
the explicit prohibition on builds/tests/Resolve in this feature wave.

## Next Action

Coordinator reviews the isolated source and incorporates it into INTEGRATION.
That wave owns registration, parameter labels/page order, pass-graph and build
source wiring. A later authorized QUALITY wave owns compiled, numerical,
visual, canonical-cadence, alpha, extended-range, and random-access proof.
Adjustable cadence remains deferred beyond Film Breath contract v1.

## Copy / History Impact

- No copy/history impact: this is isolated, unregistered source and does not
  make a release, availability, UI, or parity claim true.
- Article Opportunity: **Full article remains deferred** until Resolve visual
  acceptance and distribution are true.
- Change-History Opportunity: no additional entry; implementation follows the
  already recorded Foundation ownership and new-surface decision.

## Handoff

Terminal state: Review — final source correction complete; coordinator acceptance pending

Repository / worktree / base: Filmtone / `/Users/chibatakumi/.codex/worktrees/e9c57c76-3e12-4d11-b2d7-7dbb1c661cbc/filmtone` / `6130aae610de9f8c535f4e72d2078f2f1aabed66`

Changed files: five files under `Sources/Effects/FilmBreath/` plus this assigned progress record; no shared/coordinator-owned implementation file changed

Public interfaces or artifacts: `FilmBreathParameters` carrying generated `FilmtoneFinishParametersV1`, three local response descriptors, `resolveFilmBreathOffsets`, `isFilmBreathIdentity`, `FilmBreathProcessor`, `filmtoneFilmBreathV1`, and the eight-field `FilmBreathMetalUniformsV1` layout recorded above

Decisions fixed: Film Breath v1 uses canonical cadence only; adjustable cadence is deferred; actual OFX frame-time feeds the frozen Resolve adapter; the frozen Film Breath facade consumes that exact context directly; generated definitions own Variation / Enabled / Amount IDs, defaults, and representation; explicit-seed precedence; bounded response attenuation; Filmtone exposure/three-piece-tonal/temperature/tint order; unclamped RGB; preserved alpha; Metal-only point pass

Remaining work: coordinator acceptance review, Integration registration/build wiring using generated base metadata plus three local response descriptors, then explicitly authorized compiled/numerical/Resolve/visual proof; adjustable cadence remains deferred

Blocker: no source blocker; verification actions are unauthorized

Verification performed: clean/base gate and read-only source/scope/invariant inspection, including cadence-removal, generated-base-ownership, and actual OFX time -> adapter -> frozen facade traces

Verification not performed: tests, compiler checks, builds, Metal compilation, Resolve, installation, profiling, visual or numerical acceptance, and Git writes

Stop reason: requested final source correction completed; coordinator acceptance and further proof remain outside this worker's authorized actions
