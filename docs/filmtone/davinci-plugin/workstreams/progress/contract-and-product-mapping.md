# Progress: Contract And Product Mapping

Plan: [Contract And Product Mapping](../contract-and-product-mapping.md)
Owner: `CONTRACT` worker; master state is coordinator-owned
Last synced: 2026-07-18 JST

## State

`Review — interface frozen for ADAPTER; verification blocked`

## Assignment

- Task: `019f7416-8ed4-7023-947d-8f5d0570f38c`
- Repository: `visual-effect-core`
- Worktree: `/Users/chibatakumi/.codex/worktrees/7057/visual-effect-core`
- Base: `84efd1a8a5dae0edd3afb777a0428739f7c1e72b`
- Dependencies: planning accepted
- Blocks: `ADAPTER`

## Current Loop

Source implementation and read-only scope inspection are complete. The public
interface is frozen for ADAPTER consumption. Existing hash fixtures, new
contract tests, TypeScript/C++ builds, and parity proof remain unauthorized.

## Checklist

- [x] Confirm dedicated repository, clean worktree, and assigned base.
- [x] Confirm the external active-task policy permits this bounded no-row work.
- [x] Freeze additive Gate Weave X/Y/rotation semantics as Film Damage v2.2.
- [x] Freeze deterministic context v1 and independent stream-salt semantics.
- [x] Complete CPU/reference compatibility behavior in source.
- [x] Complete finish-specific `filmtone-pack` mapping v1.
- [x] Complete reproducible external C++ artifact generation boundary.
- [x] Regenerate the public headers and manifest successfully.
- [x] Perform final read-only scope/diff inspection.
- [x] Return terminal handoff for coordinator review.
- [ ] Update authorized legacy hashes and focused contract tests.
- [ ] Run authorized TypeScript/C++ build and ABI/parity verification.

## Changed Files

- `packages/visual-effect-core/src/features/film-damage/`
- `packages/visual-render-core/src/features/film-damage/`
- `packages/visual-render-core/src/features/deterministic-render-context/`
- `packages/filmtone-pack/src/features/finish/`
- external package exports, artifact metadata, and generation tooling
- `docs/active.md` only as required by the owning repository's task protocol

No Filmtone repository file is writable in this workstream.

## Decisions And Interfaces

- Existing Gate Weave fields remain backward-compatible.
- Independent X/Y amplitudes and rotation are additive.
- Explicit render context takes precedence while legacy inputs remain an
  intentional compatibility path.
- Filmtone-side consumption remains the separate `ADAPTER` responsibility.

## Verification

- Performed: clean/base gate and read-only source/diff inspection during the
  worker loop.
- Not authorized: tests, test files, builds, dependency installation, Git
  history writes, or Filmtone mutations.

## Blockers

The existing Film Damage tests pin revision 2.1 and legacy hashes. Updating
those tests and proving the generated ABI requires explicit authorization.

## Next Action

ADAPTER may consume the frozen interface immediately. Keep CONTRACT in Review
until its test/hash/build verification debt is explicitly authorized and
completed.

## Handoff

Terminal handoff reviewed. Public artifacts:

- Film Damage contract v2.2:
  `/Users/chibatakumi/.codex/worktrees/7057/visual-effect-core/packages/visual-effect-core/artifacts/cpp/forestone_film_damage_recipe.hpp`
- deterministic render context v1:
  `/Users/chibatakumi/.codex/worktrees/7057/visual-effect-core/packages/visual-render-core/artifacts/cpp/forestone_deterministic_render_context.hpp`
- Filmtone Finish mapping v1:
  `/Users/chibatakumi/.codex/worktrees/7057/visual-effect-core/packages/filmtone-pack/artifacts/cpp/forestone_filmtone_finish_mapping.hpp`
- manifest:
  `/Users/chibatakumi/.codex/worktrees/7057/visual-effect-core/packages/filmtone-pack/artifacts/filmtone-finish-contract-v1.json`

No Filmtone repository file was changed by CONTRACT.
