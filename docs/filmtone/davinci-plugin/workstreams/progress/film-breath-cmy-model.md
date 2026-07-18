# Progress: Film Breath CMY Model

Date: 2026-07-19 JST  
Workstream: `FILM-BREATH-CMY-MODEL`  
Plan: `../film-breath-cmy-model.md`  
Owner: `/root/film_breath_cmy_model`; master state is coordinator-owned

## State

`Accepted — source interface and implementation; build and visual verification deferred`

## Assignment

- Task ID: `/root/film_breath_cmy_model`
- Worktree:
  `/Users/chibatakumi/.codex/worktrees/72be83d2-b4c9-499a-b7cd-12456a1552ad/filmtone`
- Base: `202907ea34b43d1e03e78c2db5125d4d7a722fef`
- Start-gate exception: exact assigned-file hashes replace the clean-status gate;
  see the immutable plan.
- Authorized operations: source edits and this progress record only.
- Explicitly unauthorized: tests, build, Resolve, install, generation, and Git
  writes.

## Checklist

- [x] Base and assigned-file hashes confirmed
- [x] Local five-component offsets struct introduced
- [x] Period-driven deterministic frame model implemented
- [x] Amount and component responses wired with exact identity
- [x] Scoped diff inspected read-only
- [x] Handoff recorded

## Worker Record

- Start gate passed: `HEAD` is the assigned base and both exclusive source
  files match the immutable-plan SHA-256 values.
- The pre-existing dirty snapshot was left intact under the coordinator's
  narrow exception; no build output or installed bundle was touched.
- Replaced the generated temperature/tint alias with a Resolve-local
  `exposure / contrast / cyanDensity / magentaDensity / yellowDensity` value
  object and an exact zero constant.
- `periodFrames` is finite-defaulted to `24`, rounded and clamped to `1...120`.
  It scales the deterministic frame lattices; frame zero and negative frames
  use the same signed-lattice path as every other frame.
- Exposure, tonal slope, and all three CMY lanes share a two-scale carrier and
  have independently salted detail. The three density lanes remain independent
  and zero-centred rather than being reconstructed from two white-balance axes.
- Film Breath Amount scales all five outputs directly. The three response
  controls scale their respective families after canonical sampling, and the
  amount-zero/all-response-zero path is exact identity.
- Static consumer inspection found the parallel Metal source reading the five
  frozen field names exactly. Final source hashes are:
  - `FilmBreathOffsets.h`:
    `8d3bb457f25d589c7d26e8ddfa0cbcb8a45302162e48b06e9581ee9de500c55f`
  - `FilmBreathOffsets.cpp`:
    `0ac8699a2f8f1105bcb2e74bf61cdf692d36d20386eb98d0f1b7f8121c6e1414`

## Handoff

Terminal state: Review — source complete; verification deferred  
Repository / worktree / base: Filmtone / `/Users/chibatakumi/.codex/worktrees/72be83d2-b4c9-499a-b7cd-12456a1552ad/filmtone` / `202907ea34b43d1e03e78c2db5125d4d7a722fef`  
Changed files: `FilmBreathOffsets.h`, `FilmBreathOffsets.cpp`, this progress record  
Public interfaces or artifacts: Resolve-local five-double `FilmBreathOffsets`; no public plugin or generated-contract change  
Decisions fixed: Period is an integer-frame correlation interval; Amount scales exposure, tonal slope, and independent signed C/M/Y densities from one shared deterministic event  
Remaining work: coordinator combines the three Film Breath handoffs, then performs the separately authorized build and owner visual cadence/colour review  
Blocker: none for source; execution proof requires unauthorized build/Resolve work  
Verification performed: assigned base/hash gate, scoped diff inspection, old-field search, and read-only five-field consumer compatibility inspection  
Verification not performed: tests, test-like checks, build, Resolve, install, generation, or visual A/B  
Stop reason: immutable-plan source acceptance conditions reached

## Coordinator Acceptance

- Accepted with the exact final hashes recorded above.
- Cross-workstream review confirmed that the Metal consumer reads all five
  frozen fields and that the UI workstream provides the bounded Period value.
- Runtime cadence, strength, and visual character remain unclaimed until a
  later authorized build and owner review.
