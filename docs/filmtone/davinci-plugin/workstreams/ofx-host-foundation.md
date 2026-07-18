# Workstream: OFX Host Foundation

Document role: immutable workstream plan
Execution progress: [HOST progress](progress/ofx-host-foundation.md)
Runs in parallel with: `Contract And Product Mapping`
Blocks: Film Breath, Gate Weave, Film Damage

## New Chat Start

Read the Filmtone `AGENTS.md`, the plugin `strategy.md`, `progress.md`,
`delegation.md`, this plan, and `progress/ofx-host-foundation.md`. Work in a
clean dedicated Filmtone worktree. Do not edit the external generic contracts
or any native macOS/iOS effect implementation.

## Goal

Create the smallest macOS arm64 OpenFX product scaffold that establishes a
correct Resolve host boundary and an exact-identity render path for the later
Filmtone Finish modules.

## Context

- No OpenFX target, bundle, source, build script, or product manifest currently
  exists in this repository.
- DaVinci Resolve 21.0.2 and its OpenFX SDK are installed locally.
- The official SDK Gain sample demonstrates float RGBA, Metal command queues,
  CPU processing, bundle layout, and `/Library/OFX/Plugins` installation.
- This workstream must not depend on the feature contract being finished; it
  creates interfaces, not effect behavior.

## Constraints

- Proposed root: `apps/filmtone-resolve-ofx/`.
- Target macOS Apple Silicon only.
- Use the installed OpenFX 1.4 SDK and support wrapper as read-only build
  inputs; do not vendor or copy them in the first core pass.
- Produce one `FilmtoneFinish.ofx.bundle` with one filter effect identity.
- Support float RGBA and preserve alpha.
- Mark the effect spatially aware; never claim LUT-generation compatibility.
- Metal is the product render path. An unsupported path must fail explicitly,
  not silently return a lower-quality approximation.
- All feature amounts default to zero; the scaffold output is exact identity.
- Do not install into `/Library/OFX/Plugins` or launch Resolve without explicit
  testing authorization.
- Do not edit root `package.json` in this workstream.

## Exclusive Edit Area

Create and own the initial host-only files under:

```text
apps/filmtone-resolve-ofx/
├── Makefile
├── Resources/
└── Sources/Host/
```

The exact names may follow the SDK sample, but feature implementations must
remain outside `Sources/Host/`.

## Expected Output

- OpenFX factory and effect instance skeleton.
- Source/output clip and float RGBA negotiation.
- Metal capability declaration and command-queue handoff.
- Shared immutable render-context and module-processor interfaces, with no
  effect-specific defaults embedded.
- Identity detection at default settings.
- Bundle resource and arm64 build layout.
- A build command and expected bundle output path recorded in the dedicated
  progress file's Handoff section.
- No local installation, Resolve manipulation, tests, or release packaging.

## Acceptance Criteria

- The scaffold has one clear owner for factory, host clips, render arguments,
  Metal queue, and pipeline cache.
- Feature modules can be added later without editing each other's files.
- The host interface carries time, frame rate, render scale, image bounds, and
  seed slots even if the contract workstream has not yet supplied final types.
- Identity bypass avoids Metal work.
- No 24 fps assumption exists.
- No global `0...1` clamp exists.
- Alpha remains untouched by the identity processor.

## Non-Goals

- Film Breath, Gate Weave, or Film Damage algorithms.
- Final parameter UI and public labels.
- Sidecar, DCTL, Lua, DRX, or Workflow Integration changes.
- SDK vendoring, signing, notarization, installer, or release automation.
- CPU quality fallback.

## Stop Conditions

- The official Resolve SDK requires an unsupported architecture or API.
- A host decision would freeze effect-specific parameters before the contract
  workstream completes.
- Work overlaps an existing dirty native file.
- Three consecutive failures of the same explicitly authorized verification.

## Handoff

Recorded in [HOST progress](progress/ofx-host-foundation.md).
