# Progress: Optics Contract And Parameter Facade

Plan (read-only planning source):
`/Users/chibatakumi/.codex/worktrees/filmtone-davinci-optical-planning/docs/filmtone/davinci-plugin/workstreams/optics-contract.md`

Owner: `OPTICS-CONTRACT`; master state is director-owned
Last synced: 2026-07-18 JST

## State

`Review — source complete; build/test/Resolve verification blocked by authorization`

## Assignment

- Task: delegated from `019f7573-3066-72c1-9b47-02c586416354`
- Worktree: `/Users/chibatakumi/.codex/worktrees/c523/filmtone`
- Assigned base / start HEAD: `cb9b465414029e15abae9cac2e6895d4dd64ff84`
- Start state: clean detached worktree
- Parallel peer: `SPATIAL-HOST`
- External repository mutation: forbidden; read-only audit used

## Ownership Audit

- Node Role, Resolve persistence IDs, role masks, old-project fallbacks, and
  the five spatial feature facades are Filmtone-owned.
- Deep Glow maps `bloomStrength`, `bloomThreshold`, `bloomRadius`, and
  `bloomSoftKnee` directly to the generic `GlowRecipe.bloom` 0..1 fields.
  Filmtone retains its own defaults. Generic `colorResponse` is not exposed and
  stays fixed at 0 (luminance-keyed selection) for contract v1.
- Lens Softness and Vignette map directly to the generic `OpticsRecipe` 0..1
  fields while retaining Filmtone product defaults and spatial rendering.
- `rgbShift` remains Filmtone-only at 0..0.005. It is not equivalent to generic
  `chromaticFringing`; the rejected unproved x200 conversion remains rejected.
- `detailSoftness` remains Filmtone-only. The renderer-only note in the
  external compatibility layer is stale: current canonical evidence is
  `packages/film-lab-core/src/detail-softness.ts` plus the committed native
  detail-layer render paths.
- No generic owner change is required.

## Deep Glow Source Decision

- Parameter authority: `packages/film-lab-core/src/params.ts`, reset defaults
  from `packages/film-lab-core/src/presets.ts`, and the 0..1 schema in
  `packages/film-lab-core/src/phase0-schema.ts`.
- Latest native Metal rendering evidence:
  `apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneMetalOpticsRenderer.swift`,
  orchestrated by
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`.
- Native implementation is read-only evidence, not copied source. Resolve owns
  a new Metal implementation behind the frozen facade.

## Frozen Contract v1

Canonical owner:
`packages/film-lab-core/src/resolve-spatial-contract.ts`

- Product display name: `Filmtone`.
- Compatibility plugin ID: `com.chibatakumi.filmtone.finish`.
- Parameter namespace remains `com.forestone.filmtone.finish` to match the
  existing persistent parameter surface.
- Read-time normalization uses finite clamp-to-range. Invalid Node Role values
  fail to `All`; boolean values normalize by enabled/non-enabled state.

| Durable ID suffix | Type | Unit | Default | Range | Identity driver |
|---|---|---|---:|---:|---|
| `nodeRole` | choice | stored index | `All (0)` | `0..2` | scheduling only |
| `deepGlow.enabled` | boolean | toggle | `false` | `0..1` | disabled |
| `deepGlow.amount` | real | normalized glow energy | `0` | `0..1` | `0` |
| `deepGlow.threshold` | real | normalized input luminance | `0.8` | `0..1` | structural |
| `deepGlow.radius` | real | normalized mip distribution | `0.4` | `0..1` | structural |
| `deepGlow.softKnee` | real | threshold-relative knee | `0.5` | `0..1` | structural |
| `peripheralChromaticShift.enabled` | boolean | toggle | `false` | `0..1` | disabled |
| `peripheralChromaticShift.amount` | real | per-axis frame fraction | `0` | `0..0.005` | `0` |
| `lensSoftness.enabled` | boolean | toggle | `false` | `0..1` | disabled |
| `lensSoftness.amount` | real | normalized optical softness | `0` | `0..1` | `0` |
| `textureSoftness.enabled` | boolean | toggle | `false` | `0..1` | disabled |
| `textureSoftness.amount` | real | normalized texture softness | `0` | `0..1` | `0` |
| `vignette.enabled` | boolean | toggle | `false` | `0..1` | disabled |
| `vignette.amount` | real | normalized multiplicative attenuation | `0` | `0..1` | `0` |

Feature identity is exact configured identity when disabled or when its
identity-driving amount is zero. Deep Glow structural values do not schedule
work while strength is zero.

## Render Scale And Aspect Freeze

- Every feature reconstructs full-resolution pixel geometry from host render
  scale independently on X and Y. Alpha remains the unsplit source alpha and
  negative / greater-than-one RGB remains legal.
- Deep Glow rebuilds its normalized pyramid for the active render scale and
  uses isotropic pixel filtering without axis stretch.
- Peripheral Chromatic Shift keeps the native radial v1 response (exponent
  `1.65`); the 0..0.005 amount is a per-axis frame fraction with outward red,
  centered green, and inward blue sampling.
- Lens Softness uses half-diagonal peripheral distance and expresses kernel
  radii in full-resolution pixels multiplied by host render scale.
- Texture Softness is center-inclusive and isotropic. The public 0..1 amount
  clamps to canonical effective maximum `0.65`; kernel radius is `1.0..2.5`
  full-resolution pixels with the remaining constants generated from
  `detail-softness.ts`.
- Vignette uses full-resolution pixel distance normalized by the half-diagonal
  and multiplies RGB by `clamp(1 - amount * radius^2, 0, 1)`.

## Backward Behavior

- Missing Node Role resolves to `All`.
- Missing spatial Enabled values resolve to `false`.
- Missing spatial values use generated defaults; every identity-driving amount
  is zero.
- Role masking changes scheduling only and never rewrites stored feature
  values.
- A project that predates all spatial fields schedules no spatial work and
  retains the existing Film Breath/Gate Weave/Film Damage behavior.

## Generated Handoff

- Generated facade:
  `apps/filmtone-resolve-ofx/Sources/Generated/Contracts/filmtone_resolve_spatial.hpp`.
- Stable umbrella:
  `apps/filmtone-resolve-ofx/Sources/Generated/Contracts/filmtone_finish_contracts.hpp`.
- Generator emits role metadata, 14 parameter definitions, five feature
  definitions, stored values, narrow normalized feature views, identity and
  role scheduling helpers, and Texture Softness derived constants.
- Facade and provenance both embed SHA-256 for the canonical contract, reset
  defaults, rgbShift limit, and Detail Softness source. Umbrella static asserts
  reject mixed-generation input hashes.
- Successful generation used the clean accepted external artifact worktree
  `/Users/chibatakumi/.codex/worktrees/7057/visual-effect-core` at
  `fc9311e9989e91297c5bd7cddf05355bd58d6c55`; all four external artifact
  hashes matched the existing frozen generator constants.

## Checklist

- [x] Confirm clean/base and exclusive files.
- [x] Classify canonical owner for Node Role and five features.
- [x] Resolve Deep Glow native source truth.
- [x] Freeze IDs, types, units, defaults, ranges, and identity.
- [x] Implement/revise versioned source contract and generated facade.
- [x] Record provenance and backward-project behavior.
- [x] Inspect exclusive diff and return handoff.

## Verification

- Read-only start gate: passed.
- Read-only source/ownership inspection: complete.
- Contract generation: completed with the accepted frozen external artifacts;
  generator reported 11 artifacts.
- Initial generation attempt against the owner-specified `/Volumes/...` source
  stopped because that checkout does not contain the frozen artifact
  directory. The command was not repeated; the clean accepted artifact
  worktree above supplied exact hash-matched inputs.
- Tests, test files, build, Resolve, install, staging, commit, merge, rebase,
  and push: not authorized and not performed.

## Exclusive Diff Review

- Changed paths are limited to the canonical core contract, the existing
  contract generator/README, generated Contract artifacts/umbrella/provenance,
  and this worker progress record.
- No feature folder, Host, Integration, Factory, Makefile, Info.plist, native
  renderer, external repository, planning source, or master progress file was
  changed.
- No external contract request remains. The only retained operational debt is
  that the owner-specified `/Volumes/.../visual-effect-core` checkout lacks the
  frozen artifact directory; regeneration currently needs another read-only
  owner checkout containing the exact hash-matched frozen artifacts.

## Copy / History Impact

- Public copy impact: integration will change the visible effect name to
  `Filmtone`; this foundation only freezes that already owner-approved value.
- Article Opportunity: `Developer note` after source integration; no draft in
  this workstream.
- Change-History Opportunity: yes — preserve the reason the public name changes
  while the compatibility plugin ID remains unchanged.
