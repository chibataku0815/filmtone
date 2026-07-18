# Filmtone contract generation

This boundary consumes frozen, externally owned C++ handoffs without making
Filmtone another owner of their TypeScript contracts or defaults. It also
generates the Film Breath C++ handoff from Filmtone's canonical
`packages/film-lab-core/src/film-breath.ts` contract.

The same run generates the Resolve spatial facade from
`packages/film-lab-core/src/resolve-spatial-contract.ts`. That Filmtone-owned
source freezes Node Role, the five spatial feature parameter surfaces,
old-project defaults, generic mapping decisions, and render-scale/aspect
semantics. Generic GlowRecipe and OpticsRecipe ownership remains external.

Run from the Filmtone repository root:

```bash
bun run apps/filmtone-resolve-ofx/Scripts/GenerateContracts/generate.ts \
  --external-root /absolute/path/to/visual-effect-core
```

The generator validates the frozen manifest version, contract revisions, owner
provenance, and SHA-256 hashes before writing. A mismatch fails explicitly and
does not refresh generated output. Generated files live under
`apps/filmtone-resolve-ofx/Sources/Generated/Contracts/`; feature modules use
`Generated/Contracts/filmtone_finish_contracts.hpp` as the stable umbrella
include when `Sources/` is on the include path.

The facade keeps feature use narrow:

- `filmtone::resolve::contracts::makeFilmtoneFinishFilmBreathOffsetsV1`
  derives the Film Breath stream seed and uses the context's exact host seconds.
- `filmtone::resolve::contracts::makeFilmtoneFinishFilmDamageUniformsV1`
  prepares the frozen uniforms used by both Gate Weave and Film Damage.
- `filmtone::resolve::contracts::makeResolveRenderContextV1` is the only
  Resolve frame-time conversion entry point.
- `filmtone_resolve_spatial.hpp` exposes generated parameter/feature metadata,
  role-scheduling helpers, and one normalized view per spatial feature. It
  preserves stored values when a role masks scheduling.

The spatial header and provenance header both embed SHA-256 values for the
canonical spatial contract, Filmtone reset defaults, the rgbShift limit, and
Detail Softness derivation. The umbrella header compares those values at
compile time so mixed-generation artifacts fail closed.

The Resolve time adapter requires a resolved frame rate. It converts OpenFX
frame-time to seconds, derives an explicit integral frame index from frame-time,
and returns failure for an invalid rate instead of using the external generic
24 fps compatibility fallback. Film Breath reads the same derived host seconds
from the returned context.
