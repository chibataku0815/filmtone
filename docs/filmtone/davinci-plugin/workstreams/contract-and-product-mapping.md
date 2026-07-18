# Workstream: Contract And Product Mapping

Document role: immutable workstream plan
Execution progress: [CONTRACT progress](progress/contract-and-product-mapping.md)
Runs in parallel with: `OFX Host Foundation`
Blocks: Filmtone Contract Adapter

## New Chat Start

Ask the new chat to read:

1. `delegation.md` from the Filmtone planning source;
2. the external `visual-effect-core/AGENTS.md`;
3. the Filmtone repository `AGENTS.md` as read-only product-boundary context;
4. `docs/filmtone/davinci-plugin/strategy.md`;
5. `docs/filmtone/davinci-plugin/progress.md`;
6. this workstream;
7. `progress/contract-and-product-mapping.md`;
8. the external `docs/product-premise.md`,
   `docs/north-star.md`, `docs/strategy.md`, and `docs/active.md` before any
   external-repo edit.

This task writes only to a clean dedicated `visual-effect-core` worktree.
Filmtone is read-only. Test creation/execution requires separate explicit
authorization in that task.

## Goal

Freeze one portable, versioned contract handoff for Filmtone Finish so the OFX
feature chats do not invent independent time, seed, Gate Weave, Film Damage, or
default semantics.

## Context

- Filmtone already owns `filmBreathAmount` and matching TypeScript/Swift Film
  Breath implementations.
- Filmtone sidecars already carry `filmBreathAmount`, `dustAmount`, and
  `scratchAmount`.
- Generic Film Damage contract v2 revision 2.1 already owns Dust, Scratches,
  Fibers, Stains, Flicker, Gate Weave, Gate Wear, Defocus, normalization, and a
  deterministic CPU reference.
- The current generic Gate Weave contract lacks rotation and independent X/Y
  amplitudes.
- `@forestone/filmtone-pack` currently maps Film Breath to `motion.breath` but
  classifies `dustAmount` and `scratchAmount` as lossy because the standalone
  Film Damage recipe is outside `VisualRecipe`.

## Constraints

- Preserve generic ownership in `@forestone/visual-effect-core` and
  `@forestone/visual-render-core`.
- Preserve Filmtone taste and compatibility ownership in
  `@forestone/filmtone-pack` and `packages/film-lab-core`.
- Do not copy the external contract into Filmtone.
- Do not put Filmtone names, presets, sidecars, or UI copy into generic
  packages.
- Do not modify native macOS/iOS render kernels; they are read-only evidence.
- Make any Gate Weave schema change additive and explicitly versioned.
- Keep edge compensation in the renderer/host layer, not the generic recipe.
- No camera input transform, film-stock, print, grain, or halation fields.
- Do not edit the proposed OFX app scaffold; this chat owns contracts and
  handoff generation only.

## Required Decisions

- Canonical render context fields: host time, frame index derivation, frame
  rate, render scale, bounds, seed, and per-module random-stream salts.
- Gate Weave generic fields needed for independent translation and rotation.
- Whether the existing Film Damage contract revision can be extended or needs
  a new contract version.
- A public Filmtone finish-mapping API that maps existing flat params into a
  standalone Film Damage recipe without forcing Film Damage into
  `VisualRecipe`.
- A generated/public C++ handoff for the external recipe/uniform layout.
- The external artifact boundary that the separate Filmtone ADAPTER workstream
  can consume without copying generic authority.
- Default values and stable parameter IDs consumed by the OFX wrapper.

## Expected Output

- A public, versioned external contract artifact that C++/Objective-C++ can
  consume without a handwritten Filmtone copy.
- Generic Gate Weave semantics sufficient for X, Y, rotation, cadence, and
  instability; host edge safety remains outside the recipe.
- A finish-specific `filmtone-pack` mapping for current Film Breath / Dust /
  Scratch compatibility plus neutral defaults for new fields.
- A deterministic timing and seed specification shared by all three feature
  modules.
- A short handoff recording exact public symbols, generated file paths,
  contract versions, and unresolved limitations.
- Return this workstream's Status/Handoff to the coordinator for recording in
  the dedicated progress file; do not write to the dirty planning source or
  master `progress.md`.

## Acceptance Criteria

- One source owns every default, range, and semantic field.
- Generated C++ output can be reproduced from its owning source; it is never
  hand-edited.
- The same input contract can drive CPU reference and Metal implementation.
- Film Breath, Gate Weave, and Damage receive independent deterministic random
  streams from one seed.
- Existing Filmtone params remain backward-compatible and default-neutral.
- Dust/Scratch are no longer silently dropped by the finish-specific mapping.
- Unsupported or lossy mappings remain explicit.

## Non-Goals

- OpenFX factory or bundle implementation.
- Metal shaders.
- Resolve UI controls.
- Sidecar schema migration or Lua automation.
- Visual tuning, presets, packaging, signing, or release work.

## Stop Conditions

- The external repo has another active task that cannot be safely paused or
  redirected.
- Correct implementation requires copying a contract into Filmtone.
- Contract changes would break existing external consumers rather than remain
  additive.
- The work expands into renderer implementation.
- Three consecutive failures of the same explicitly authorized verification.

## Handoff

Recorded in [CONTRACT progress](progress/contract-and-product-mapping.md).
