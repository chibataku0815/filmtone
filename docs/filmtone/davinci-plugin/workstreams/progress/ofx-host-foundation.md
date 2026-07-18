# Progress: OFX Host Foundation

Plan: [OFX Host Foundation](../ofx-host-foundation.md)
Owner: `HOST` worker; master state is coordinator-owned
Last synced: 2026-07-18 JST

## State

`Accepted — source integrated; verification debt retained`

## Assignment

- Task: `019f7416-9bd1-7e12-a95e-cfee8eda1797`
- Repository: Filmtone
- Worktree: `/Users/chibatakumi/.codex/worktrees/a45d/filmtone`
- Base: `a840634ac2a630df36b10d414ec1c4e53f27a6ce`
- Result commit: `325488e2ab86e5c25459949702ea880a888ac12d`
- Combined source commit: `fcb3e85`
- Dependencies: planning accepted
- Blocks: Foundation Freeze

## Current Loop

Source implementation and read-only inspection are complete. The next proof is
an arm64 bundle build, which was not authorized in the worker task.

## Checklist

- [x] Confirm dedicated repository, clean worktree, and assigned base.
- [x] Add one macOS arm64 OpenFX Filter factory and bundle layout.
- [x] Negotiate float RGBA source/output clips.
- [x] Declare Metal-only rendering and reject unsupported render paths.
- [x] Add immutable render context and generic module-processor boundary.
- [x] Add host-owned Metal pipeline cache.
- [x] Add exact identity detection and defensive Metal blit.
- [x] Keep feature defaults, parameter IDs, and algorithms out of HOST.
- [x] Compare the source statically with installed Resolve SDK headers/samples.
- [ ] Build the arm64 bundle.
- [ ] Inspect binary architecture, exported OFX entry points, and bundle layout.
- [ ] Confirm Resolve discovery and identity rendering.

## Changed Files

- `apps/filmtone-resolve-ofx/Makefile`
- `apps/filmtone-resolve-ofx/Resources/Info.plist`
- `apps/filmtone-resolve-ofx/Sources/Host/FilmtonePlugin.cpp`
- `apps/filmtone-resolve-ofx/Sources/Host/MetalIdentityBlit.{h,mm}`
- `apps/filmtone-resolve-ofx/Sources/Host/MetalPipelineCache.{h,mm}`
- `apps/filmtone-resolve-ofx/Sources/Host/ModuleProcessor.h`
- `apps/filmtone-resolve-ofx/Sources/Host/RenderContext.h`

## Decisions And Interfaces

- Plugin ID: `com.chibatakumi.filmtone.finish`
- Build command: `make -C apps/filmtone-resolve-ofx`
- Expected bundle: `apps/filmtone-resolve-ofx/build/FilmtoneFinish.ofx.bundle`
- Filter is spatially aware, float RGBA, Metal-only, and exact identity while no
  modules are registered.
- No 24 fps assumption, global clamp, or CPU/OpenCL/CUDA fallback was added.

## Verification

- Performed: clean/base check; official SDK header/sample comparison; complete
  read-only file and ownership inspection.
- Not performed: compile, build, tests, plist lint, Resolve launch, bundle
  installation, Git stage/commit/merge/rebase/push.

## Blockers

Explicit build/verification authorization is required before compiled-host
acceptance, but the reviewed source boundary is accepted for feature work.

## Next Action

Feature modules may implement against `RenderContext`, `ModuleProcessor`, and
`MetalPipelineCache`. After authorization, run only the smallest arm64 bundle
build and artifact inspection. Resolve installation/discovery remains later.

## Handoff

The source scope is integrated with no static blocking finding. Compile,
bundle, and Resolve verification remain explicit debt.
