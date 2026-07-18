# Workstream: Gate Weave

Document role: immutable workstream plan
Execution progress: [WEAVE progress](progress/gate-weave.md)
Parallel peers after unblock: Film Breath, Film Damage

## New Chat Start

Read the Filmtone `AGENTS.md`, plugin `strategy.md`, coordinator `progress.md`,
`delegation.md`, the completed CONTRACT, ADAPTER, and HOST handoffs, and this
plan plus `progress/gate-weave.md`. Edit only the Gate Weave feature folder and
dedicated progress record.

## Goal

Implement a true mechanical transport instability module that remaps the input
image with deterministic subpixel translation and rotation, rather than merely
moving scratch or gate overlays.

## Context

Filmtone does not currently implement true Gate Weave. The external generic
Film Damage contract has amount, frequency, jitter, and travel axis, while the
CONTRACT workstream must supply the approved independent X/Y and rotation
semantics. Dehancer is only a capability reference: period, translation,
rotation, and black-edge compensation are required behaviors, not values or UI
to copy.

## Constraints

- Consume the approved public generic Gate Weave contract handoff.
- Use host time/frame rate/seed; no prior-frame fetch or mutable timeline state.
- Use inverse-coordinate source sampling with high-quality subpixel filtering.
- Support independent X, Y, and rotation around frame center.
- Edge safety is host-render behavior and must not leak into the generic recipe.
- Apparent motion must scale correctly with render scale and aspect ratio.
- Preserve negative and greater-than-one RGB values and alpha.
- Do not add blur or motion blur unless separately authorized.
- Do not edit factory/build/manifest/shared-pass/sidecar/Lua/master progress
  files.

## Exclusive Edit Area

```text
apps/filmtone-resolve-ofx/Sources/Effects/GateWeave/
```

## Expected Output

- Deterministic Gate Weave transform resolver.
- Metal inverse-warp pass with subpixel sampling.
- Edge-safety modes sufficient for exact bypass and black-edge-free normal
  use; final UI naming remains Integration-owned.
- Isolated module interface and uniform contract.
- Handoff recording sampling method, bounds assumptions, maximum transform,
  changed files, and verification not run.

## Acceptance Criteria

- Amount zero is exact identity.
- Same time / fps / seed / params yields the same transform and pixels.
- X, Y, and rotation can be controlled independently.
- Higher cadence produces faster intentional movement without frame-to-frame
  white-noise jitter unless instability explicitly requests it.
- Edge safety enabled prevents black gaps at supported maximum transforms.
- Normal settings do not create visible softening, aliasing, or repeated edge
  smears.
- The transform random stream is independent from Breath and Damage.

## Non-Goals

- Film Breath, damage overlays, gate wear, overscan/perforations, stabilization,
  motion blur, or camera shake.
- CinePrint node automation.
- Final profile authoring or public copy.

## Stop Conditions

- The generic contract is still ambiguous or lacks required transform fields.
- Correct edge handling requires a shared host change not owned here.
- Sampling quality cannot be preserved within the approved Metal buffer model.
- Three consecutive failures of the same explicitly authorized verification.

## Handoff

Recorded in [WEAVE progress](progress/gate-weave.md).
