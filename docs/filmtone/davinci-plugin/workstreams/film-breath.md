# Workstream: Film Breath

Document role: immutable workstream plan
Execution progress: [BREATH progress](progress/film-breath.md)
Parallel peers after unblock: Gate Weave, Film Damage

## New Chat Start

Read the Filmtone `AGENTS.md`, plugin `strategy.md`, coordinator `progress.md`,
`delegation.md`, the completed CONTRACT, ADAPTER, and HOST handoffs, and this
plan plus `progress/film-breath.md`. Use the recorded clean integration base
and edit only the Film Breath feature folder and dedicated progress record.

## Goal

Implement the existing Filmtone Film Breath behavior as a deterministic OFX
module with a compact Amount-first control model and optional advanced response
controls.

## Context

Canonical Filmtone behavior currently derives exposure, contrast, temperature,
and tint offsets from time plus seed using 1.8, 4.8, 8.6, and 15.5 second
correlated noise bands. Current maxima are exposure ±0.5 EV, contrast ±0.15,
temperature ±0.22, and tint ±0.12. The OFX module must preserve Filmtone's
character rather than copying Dehancer's random model.

## Constraints

- Consume the generated Film Breath C++ handoff from CONTRACT.
- Do not hand-copy the TypeScript or Swift constants into the effect folder.
- Preserve deterministic random access; never use playback-history state.
- Keep the mean response neutral and prevent cumulative drift.
- Basic UI is Amount-first. Advanced controls may scale cadence, exposure,
  tonal, and color responses without changing the canonical neutral defaults.
- Do not add camera/log profiles or input transforms.
- Do not globally clamp float RGB to `0...1`.
- Preserve alpha.
- Do not edit the OFX factory, root build list, bundle resources, shared Metal
  cache, sidecar writers, Lua importer, or master `progress.md`.

## Exclusive Edit Area

```text
apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/
```

## Expected Output

- A pure C++ temporal offset resolver using the frozen render context.
- A Metal photometric pass consuming the resolved offsets.
- An isolated module interface that Integration can register without changes.
- Clear parameter descriptors/metadata local to the module; final page order
  remains Integration-owned.
- A progress Handoff section with symbols, uniforms, changed files, known limitations,
  and verification not run.

## Acceptance Criteria

- Amount zero is exact identity.
- Same time / fps / seed / params yields the same offsets and pixels.
- Scrubbing or out-of-order export does not change the result.
- Exposure, tonal, and color movement are continuous, bounded, and
  independently scalable.
- The average image does not walk progressively brighter, darker, warmer, or
  greener over time.
- The module random stream is decorrelated from Gate Weave and Film Damage.
- No Dehancer profile values, labels, or implementation details are copied.

## Non-Goals

- Gate Weave, Film Damage, standalone flicker, grain, halation, or print color.
- Final Filmtone presets or public copy.
- Resolve node automation.
- Performance tuning beyond avoiding obviously redundant work.

## Stop Conditions

- Generated contract behavior does not match the current Filmtone source.
- Correct color modulation requires an unapproved input-color system.
- Shared host files must change before Integration.
- Three consecutive failures of the same explicitly authorized verification.

## Handoff

Recorded in [BREATH progress](progress/film-breath.md).
