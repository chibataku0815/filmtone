# Progress: Filmtone Contract Adapter

Plan: [Filmtone Contract Adapter](../filmtone-contract-adapter.md)
Owner: future `ADAPTER` worker; master state is coordinator-owned
Last synced: 2026-07-18 JST

## State

`Running — clean-base gate passed`

## Assignment

- Task: `019f7438-f67e-7c11-80fc-81839b706589`
- Repository: Filmtone
- Worktree: `/Users/chibatakumi/.codex/worktrees/66f1/filmtone`
- Base: `a840634ac2a630df36b10d414ec1c4e53f27a6ce`
- Depends on: `CONTRACT`
- Blocks: `BREATH`, `WEAVE`, `DAMAGE`

## Current Loop

The clean/base gate passed. Film Damage v2.2, deterministic context v1, and
Finish mapping v1 are frozen for consumption; their build/test verification
debt remains in CONTRACT. The worker is resolving the adapter and generated
Film Breath handoff boundaries.

## Checklist

- [x] Record the frozen external contract version/revision and artifact paths.
- [x] Freeze the Filmtone base for dedicated worktree creation.
- [ ] Choose direct consumption over local generation where possible.
- [ ] Add the reproducible generic C++ consumption boundary.
- [ ] Add the reproducible Film Breath C++ handoff from Filmtone ownership.
- [ ] Convert OpenFX frame-time to explicit frame index and seconds using the
  resolved host frame rate; never use the 24 fps fallback in Resolve.
- [ ] Record stable includes, symbols, regeneration command, and limitations.
- [ ] Confirm no HOST, feature, native renderer, or shared registry edits.
- [ ] Return terminal handoff for coordinator review.

## Changed Files

None.

## Verification

- Performed: none.
- Authorization: no tests, builds, Resolve, installation, or Git writes.

## Blockers

No source blocker. Tests/builds remain unauthorized.

## Next Action

Continue the ADAPTER source-only worker loop to its terminal handoff.

## Handoff

Not started.
