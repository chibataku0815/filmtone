# Progress: Gate Weave Quality

Plan: [Gate Weave quality prompt](../gate-weave-quality-chat-prompt.md)
Owner: coordinator after upstream ownership correction
Last synced: 2026-07-18 JST

## State

`Closed with future iteration — revision 2.3 source/build/setup complete, but the owner did not award Gate Weave a passing visual verdict in this cycle`

## Authority And Decision

- Canonical base: `visual-effect-core` commit
  `6e7969a8a1ecff8519b7ef3dd0c6a0f24af1b61f` on
  `feature/filmtone-finish-contract`.
- Generic Gate Weave temporal semantics remain owned by
  `@forestone/visual-render-core`; Filmtone does not keep a private alternate
  model.
- The rejected local resolver proposal was re-expressed as Film Damage contract
  revision 2.3, regenerated through the public handoff, then mirrored by the
  OFX resolver.

## Integrated Semantics

- Five deterministic, decorrelated drift bands replace the short single-cycle
  motion while preserving random-access rendering.
- X, Y, and rotation use independent phase lanes and distinct spectral centers.
- Per-frame registration scatter is a bounded share of each axis rather than an
  additive envelope expansion.
- Slow bounded modulation varies vertical transport strength.
- Each axis is a convex drift/scatter blend, so absolute movement remains within
  its resolved amplitude. The OFX edge-safety envelope is therefore exact.
- Existing recipe fields, parameter ids, defaults, travel-axis behavior, stream
  salt, identity gates, and render-context cadence are preserved.

## Changed Surfaces

Upstream owner working tree:

- `packages/visual-effect-core/src/features/film-damage/types.ts`
- `packages/visual-render-core/src/features/film-damage/reference.ts`
- Film Damage/Filmtone generated artifacts and owner documentation

Filmtone Foundation and QUALITY working trees:

- `apps/filmtone-resolve-ofx/Sources/Effects/GateWeave/GateWeaveTransform.cpp`
- `apps/filmtone-resolve-ofx/Sources/Effects/GateWeave/GateWeaveTransform.h`
- `apps/filmtone-resolve-ofx/Scripts/GenerateContracts/generate.ts`
- generated Film Damage contract/provenance artifacts

The Filmtone generator is pinned to contract revision 2.3 and its new manifest
and effect-header hashes. Its revision guard now derives all revision characters
from the frozen value instead of hard-coding `2.2`.

## Review Result

- Static source comparison confirms the TypeScript reference and both Filmtone
  C++ working trees use the same band ratios, normalized weights, phase/scatter
  lanes, vertical modulation, scatter shares, identity conditions, travel-axis
  handling, and unit motion envelope.
- The installed evaluation bundle still contains the pre-tuning implementation.
  No visual claim is made for revision 2.3 yet.

## Remaining Core Work

1. Rebuild one combined bundle containing Film Breath v2, Gate Weave 2.3, and
   Film Damage v2.
2. Recheck default identity, isolated module activity, combined activity, and
   same-frame repeat in Resolve.
3. Owner-check normal settings on representative footage for mechanical
   character, chatter, crop/softness, and combined taste.

Only disqualifying findings belong to the current Internal Core Baseline cycle.

## Verification Debt

- Subsequent QUALITY closure: combined C++/Objective-C++ build, exact embedded
  Gate Weave Metal compile, evaluation install/hash, Resolve restart, and exact
  registry enumeration pass.
- Not run: revised-source Resolve render, numerical fixtures, performance
  measurement, or owner visual review.
- No test files were created or modified.
- No Git staging, commit, push, or branch-pointer write was performed.

## Copy / History Impact

- No public copy/history impact: this is an unverified internal effect-quality
  revision.
- Article Opportunity: `Developer note`, deferred until visual acceptance.
- Change-History Opportunity: record the ownership correction if this contract
  revision becomes accepted product history.
