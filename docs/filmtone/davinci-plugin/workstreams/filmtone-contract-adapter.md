# Workstream: Filmtone Contract Adapter

Document role: immutable workstream plan
Execution progress: [ADAPTER progress](progress/filmtone-contract-adapter.md)
Runs in Filmtone after: `Contract And Product Mapping`
Blocks: Film Breath, Gate Weave, Film Damage

## New Chat Start

Read the Filmtone `AGENTS.md`, plugin `strategy.md`, coordinator `progress.md`,
`delegation.md`, the accepted CONTRACT handoff, this plan, and
`progress/filmtone-contract-adapter.md`. Work in one clean dedicated Filmtone
worktree. The external repository is read-only in this chat.

## Goal

Create the smallest reproducible Filmtone-owned adapter/generation boundary
that exposes the accepted external finish contract and existing Film Breath
behavior to the C++/Objective-C++ OFX feature modules without copying generic
contract authority into Filmtone.

## Context

- Generic Film Damage and Gate Weave schema, defaults, and deterministic
  reference remain owned by `visual-effect-core`.
- Film Breath behavior remains owned by Filmtone core.
- The initial OFX implementation needs a stable generated/public C++ handoff,
  not handwritten parallel constants.
- The HOST workstream owns only generic processor interfaces; this adapter
  must not edit its host files.

## Constraints

- Consume the exact accepted CONTRACT artifact/version.
- Treat OpenFX `RenderArguments.time` as host frame-time, not seconds. The
  adapter must derive `hostTimeSeconds = time / resolvedFrameRate`, pass an
  explicit integral frame index, and never rely on the contract's 24 fps
  compatibility fallback for Resolve renders.
- Use the same derived seconds for Film Breath cadence.
- Generated files must name their owning source and regeneration command.
- Do not hand-edit generated output after creation.
- Do not copy external TypeScript contracts or defaults into a Filmtone-local
  source-of-truth schema.
- Do not modify native macOS/iOS renderer kernels.
- Do not edit `apps/filmtone-resolve-ofx/Sources/Host/`, feature folders,
  shared registration/build files, or master `progress.md`.
- No camera input transform, film stocks, print, grain, or halation fields.

## Exclusive Edit Area

The coordinator freezes exact paths from the accepted CONTRACT handoff. The
default proposed ownership is:

```text
packages/film-lab-core/        # source/generator only where Film Breath owns it
apps/filmtone-resolve-ofx/Sources/Generated/
apps/filmtone-resolve-ofx/Scripts/GenerateContracts/
```

If the accepted external package supplies a directly consumable generated C++
artifact, prefer consuming it and keep the Filmtone generator surface smaller.

## Expected Output

- Reproducible C++ handoff for the accepted generic finish recipe/uniforms.
- Reproducible C++ handoff for Filmtone Film Breath constants/temporal
  semantics.
- Stable include/module paths for BREATH, WEAVE, and DAMAGE.
- A host-time adapter that converts Resolve/OpenFX frame-time to the frozen
  deterministic context without changing HOST files.
- Regeneration command and ownership note.
- A handoff listing exact external version/revision, generated files, public
  symbols, unsupported mappings, and verification state.

## Acceptance Criteria

- External generic defaults remain external source of truth.
- Film Breath constants have one Filmtone source of truth.
- Generated output is deterministic by construction and not hand-authored.
- Feature workers can consume public C++ symbols without editing source
  contracts or generators.
- No native macOS/iOS effect behavior changes.
- No shared host/registry/build file changes.

## Non-Goals

- External contract edits.
- OFX factory, host scaffold, Metal algorithms, UI, integration, or tuning.
- Test files, builds, Resolve launch, installation, packaging, or release.

## Stop Conditions

- CONTRACT is not accepted or its artifact/version is ambiguous.
- Correct consumption requires copying generic contract authority into
  Filmtone.
- Required edit paths overlap owner changes or another workstream.
- A shared host/registry/build file must change before INTEGRATION.
- The same explicitly authorized operation fails three consecutive times.

## Handoff

Recorded in [ADAPTER progress](progress/filmtone-contract-adapter.md).
