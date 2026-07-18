# Workstream: Film Damage

Document role: immutable workstream plan
Execution progress: [DAMAGE progress](progress/film-damage.md)
Parallel peers after unblock: Film Breath, Gate Weave

## New Chat Start

Read the Filmtone `AGENTS.md`, plugin `strategy.md`, coordinator `progress.md`,
`delegation.md`, the completed CONTRACT, ADAPTER, and HOST handoffs, the
external Film Damage public contract/reference, this plan, and
`progress/film-damage.md`. Edit only the Film Damage feature folder and
dedicated progress record.

## Goal

Implement a Metal material-damage pass that retains Filmtone's dark debris,
broken scratch, and restrained sparkle character while consuming the generic
Dust / Fiber / Scratch / Stain / Gate Wear contract.

## Context

Native Filmtone already produces dark dust, debris, stains, fibers, broken
scratches, gate-edge dirt, and subtle local texture. The external generic
contract adds explicit lifetime, fade, polarity, scale, persistence, and
single-source deterministic reference semantics. The OFX implementation must
resolve that intent natively rather than copy the Core Image kernel or create a
fixed overlay.

## Constraints

- Consume only public generic contract/reference artifacts.
- Treat current native macOS/iOS kernels as read-only Filmtone taste evidence.
- Use procedural or Filmtone-owned material only; no Dehancer assets, samples,
  profile values, or random model.
- Implement Dust, Fibers/Hairs, Scratches, Stains, and Gate Wear independently.
- Do not implement the generic contract's Gate Weave or Flicker here; those are
  owned by the separate Gate Weave and Film Breath modules.
- Preserve per-artifact lifetime/fade and avoid frame-independent white-noise
  popping.
- Normalize scale by image dimensions/render scale so proxy and full-resolution
  renders retain the intended material size.
- Do not globally clamp float RGB to `0...1`; preserve alpha.
- Any local re-grain may exist only to integrate a scratch/debris edge. Do not
  add standalone film grain.
- Do not edit factory/build/manifest/shared-pass/sidecar/Lua/master progress
  files.

## Exclusive Edit Area

```text
apps/filmtone-resolve-ofx/Sources/Effects/FilmDamage/
```

## Expected Output

- Deterministic artifact-event resolver compatible with the external reference
  contract.
- Metal pass or isolated pass sequence for the approved artifact families.
- Debug-mask hooks local to the module for later authorized quality work.
- Isolated module interface and uniform/resource contract.
- Handoff recording implemented contract fields, intentional approximations,
  changed files, and verification not run.

## Acceptance Criteria

- All family amounts zero is exact identity.
- Each family can operate independently.
- Same time / fps / seed / params yields the same artifacts.
- Artifacts have coherent lifetimes, fades, placement, and temporal density;
  they do not look stuck to the digital screen or regenerated randomly every
  frame.
- Dark/neutral debris dominates normal Filmtone settings; white sparkle remains
  rare and subordinate.
- Scratches have breakup, gaps, taper, and non-uniform edges.
- Fibers/Hairs have persistence and organic curvature rather than straight
  repeated lines.
- No visible tiling or repeated asset pattern appears at UHD.

## Non-Goals

- Film Breath, Gate Weave image remap, standalone grain, halation, bloom,
  overscan/perforations, negative stock, or print response.
- Final presets, UI layout, public copy, or performance tuning.

## Stop Conditions

- The Metal implementation would require copying the external contract or
  fixture into Filmtone.
- A required field has no public semantic definition.
- Quality requires unlicensed/external visual assets.
- Three consecutive failures of the same explicitly authorized verification.

## Handoff

Recorded in [DAMAGE progress](progress/film-damage.md).
