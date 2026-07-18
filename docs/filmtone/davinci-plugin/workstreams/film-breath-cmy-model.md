# Film Breath CMY Model

Date: 2026-07-19 JST  
Workstream ID: `FILM-BREATH-CMY-MODEL`  
Coordinator: Spatial Director  
State at dispatch: `Ready`

## Goal

Replace the Resolve-local Film Breath temperature/tint carrier with a
deterministic frame-domain exposure, contrast, and subtractive CMY density
model. This workstream owns only the temporal model and its local value object;
it does not own pixel processing or OpenFX parameter registration.

## Product Evidence And Fixed Interpretation

- Dehancer describes Film Breath as frame-to-frame exposure, contrast, and
  colour variation and describes its Colour component as random subtractive
  transformations similar to a CMY Color Head:
  <https://www.dehancer.com/learn/article/breath>
- CMY Color Head is a subtractive optical-filter model with Cyan-Red,
  Magenta-Green, and Yellow-Blue axes:
  <https://www.dehancer.com/learn/article/cmy-color-head-and-print-toning>
- These sources establish the phenomenon and axis family, not Filmtone parity,
  coefficient, or profile claims. Filmtone must implement its own bounded,
  deterministic model.

The previous temperature/tint interpretation is rejected. Film Breath color is
not a white-balance oscillator.

## Repository And Start Snapshot

- Implementation worktree:
  `/Users/chibatakumi/.codex/worktrees/72be83d2-b4c9-499a-b7cd-12456a1552ad/filmtone`
- Git base: `202907ea34b43d1e03e78c2db5125d4d7a722fef`
- Pre-dispatch tracked diff SHA-256:
  `ca3ba2b4548e8dd7907748b3ae208ec66ffa5884257842f143e8a45f0e07bc40`
- Assigned-file start hashes:
  - `FilmBreathOffsets.h`: `041cd33991ac5f056cdf8f8e2c0da822b72e873c9120688413e2c27547b836c7`
  - `FilmBreathOffsets.cpp`: `db4df5fc5666bf7ed46ebd470120a0c73765f04c975a01a3920bb7f7830e66ca`

The integration worktree is intentionally dirty because its exact source is
currently installed and being reviewed by the owner. For this recovery wave,
the coordinator authorizes a narrow exception to delegation.md's clean-start
gate: verify the base and both assigned-file hashes, then edit only the files
below. Any assigned-file hash mismatch before the first edit is a stop
condition. Do not touch, rebuild, reinstall, or restart the review bundle.

## Exclusive Edit Area

- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathOffsets.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathOffsets.cpp`
- `docs/filmtone/davinci-plugin/workstreams/progress/film-breath-cmy-model.md`

The progress record is in the director worktree, not the implementation
worktree. No generated contract, shared package, Integration, Gate Weave, or
Film Damage file belongs to this task.

## Frozen Local Interface

Define the Resolve-local value object with this semantic shape:

```cpp
struct FilmBreathOffsets final {
    double exposure;
    double contrast;
    double cyanDensity;
    double magentaDensity;
    double yellowDensity;
};
```

`resolveFilmBreathOffsets()` continues to accept `FilmBreathParameters` and
`RenderContext`. `isFilmBreathIdentity()` remains the identity gate. Do not
change the processor public ABI.

## Implementation Requirements

1. Read a finite integer `periodFrames` from `FilmBreathParameters`, clamped to
   the UI contract `1...120`; the default is `24` frames.
2. Use host frame time directly. Frame zero and negative frames are ordinary
   deterministic samples; there is no start envelope or forced-zero frame.
3. Exposure, contrast, and three CMY densities share a slow breathing carrier
   but receive decorrelated detail so they feel like one emulsion event rather
   than five independent oscillators.
4. `Period` controls the correlation/breath interval. It must visibly affect
   cadence without requiring render history and must remain deterministic under
   random frame access.
5. `Film Breath Amount` is the global Impact and scales every component.
   Exposure, Tonal, and Color Response remain component amplitude controls.
6. CMY lanes are zero-centred, bounded, and not reducible to a two-axis
   temperature/tint mapping. Avoid long plateaus at bounds.
7. Finite-invalid input resolves safely. Amount zero and all-response-zero are
   exact identity.

## Acceptance

- The local offsets contain exposure, contrast, C, M, and Y density values.
- Period changes cadence in the frame domain while preserving deterministic
  random access.
- No timeline-start fade or exact-zero special case remains.
- Public plugin name, plugin ID, Node Role, graph ordering, Gate Weave, and Film
  Damage are unchanged.
- The worker returns the delegation.md Handoff Schema with build and visual
  verification explicitly deferred.

## Prohibitions And Stop Conditions

Do not run tests, test-like checks, builds, Resolve, install, generation, or Git
writes. Do not edit this plan after dispatch. Stop on assigned-file drift,
scope conflict, required shared-contract edits, or implementation completion.

