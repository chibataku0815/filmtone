# Progress: Filmtone Contract Adapter

Plan: [Filmtone Contract Adapter](../filmtone-contract-adapter.md)
Owner: `ADAPTER` worker; master state is coordinator-owned
Last synced: 2026-07-18 JST

## State

`Accepted — source integrated; verification debt retained`

## Assignment

- Task: `019f7438-f67e-7c11-80fc-81839b706589`
- Repository: Filmtone
- Worktree: `/Users/chibatakumi/.codex/worktrees/66f1/filmtone`
- Base: `a840634ac2a630df36b10d414ec1c4e53f27a6ce`
- Result commit: `7e33462357a2532d16713c813fdd65ea04d70ebd`
- Combined source commit: `fcb3e85`
- Depends on: `CONTRACT`
- Blocks: `BREATH`, `WEAVE`, `DAMAGE`

## Current Loop

Source implementation, generator materialization, and read-only scope review
are complete. Film Damage v2.2, deterministic context v1, Finish mapping v1,
and Film Breath contract v1 are frozen for feature consumption. Build/test
verification debt remains explicit.

## Checklist

- [x] Record the frozen external contract version/revision and artifact paths.
- [x] Freeze the Filmtone base for dedicated worktree creation.
- [x] Choose generated, provenance-checked consumption without local ownership.
- [x] Add the reproducible generic C++ consumption boundary.
- [x] Add the reproducible Film Breath C++ handoff from Filmtone ownership.
- [x] Convert OpenFX frame-time to explicit frame index and seconds using the
  resolved host frame rate; never use the 24 fps fallback in Resolve.
- [x] Record stable includes, symbols, regeneration command, and limitations.
- [x] Confirm no HOST, feature, native renderer, or shared registry edits.
- [x] Return terminal handoff for coordinator review.

## Changed Files

- `packages/film-lab-core/src/film-breath.ts`
- `apps/filmtone-resolve-ofx/Scripts/GenerateContracts/`
- `apps/filmtone-resolve-ofx/Sources/Generated/Contracts/`

## Verification

- Performed: start/base gate, generator execution, frozen version/owner/hash
  validation, byte-for-byte external artifact comparison, and scope review.
- Not performed: tests, builds, TypeScript/C++ compile, numerical parity,
  Resolve, or installation.

## Blockers

No source blocker. Tests/builds remain unauthorized and retained as debt.

## Next Action

BREATH, WEAVE, and DAMAGE may consume the stable generated include. Return to
ADAPTER only if an accepted contract revision changes.

## Handoff

Stable include:
`apps/filmtone-resolve-ofx/Sources/Generated/Contracts/filmtone_finish_contracts.hpp`.
Public helpers include `makeFilmtoneFinishFilmBreathOffsetsV1`,
`makeFilmtoneFinishFilmDamageUniformsV1`, and `makeResolveRenderContextV1`.
