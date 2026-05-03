# Filmtone Native Desktop v2 Strategy

Date: 2026-05-04 JST

This file is the strategic source of truth for the Native Desktop v2 lane.
Keep it short. Do not put implementation steps or file-level details here.

## Goal

Replace the current Electron Desktop product lane with a macOS 26 native
SwiftUI/AppKit application that matches or beats the current Desktop release on
preview quality, still export, video export, sidecar correctness, and user-facing
Mac experience.

The native app must remain a parallel lane until it is clearly better than the
shipping Electron rail.

## Measurable Done Conditions

- Native macOS app opens still images and videos with native controls.
- Native preview, still export, and video export use the iOS-canonical Filmtone
  grade pipeline for the supported built-in Looks.
- Still and video exports write sidecars without a schema bump.
- Look vocabulary is unified before any public release cutover.
- Electron Desktop release behavior remains unchanged until the native lane is
  explicitly promoted.
- The app can be built, smoke-tested, signed/notarized, and distributed as the
  primary Desktop release candidate.

## Milestones

| ID | Milestone | Depends on | Status | Done Conditions |
|---|---|---|---|---|
| M1 | Native Contract And Skeleton | none | Complete | Native app builds, launches a native window, uses SwiftUI/AppKit controls, and does not change the Electron release rail. |
| M2 | Still And Video Vertical Slice | M1 | Complete | Still and video open, preview, export, and sidecar paths work through the native app. |
| M3 | Native Color And Optics Parity | M2 | In progress | Built-in Looks use the iOS-canonical color and optics stages; performance is acceptable at 4K; remaining parity gaps are explicit. |
| M4 | Shared Contract Consolidation | M3 | Deferred | Shared Swift contract ownership is clear, generated Swift remains generated-only, and iOS/macOS consume the same canonical contract without destabilizing the iOS lane. |
| M5 | Native Editing UI | M3 | Not started | Core Desktop workflows are usable in native UI: look selection, preview navigation, export controls, progress/cancel, and Finder integration. |
| M6 | Release Cutover | M4, M5 | Not started | Signed/notarized app, release QA, public copy, portfolio/submodule updates, and Look vocabulary gate are complete. |

## Current Strategic State

- M1 and M2 are complete.
- M3 is the active milestone.
- M3 has completed the source-color foundation, modern AVFoundation migration,
  RayAngleOptics, initial optical stages, and 4K performance measurement.
- The current active task is the M3 checkpoint for the C5b/C5d work already
  present in the worktree.
- Baseline-C population is intentionally treated as quality shell work unless
  formal parity proof is requested.
- M4 SPM consolidation remains deferred until native behavior is stable enough
  that module movement will not distract from product quality.

## Constraints

- macOS target is macOS 26 only.
- SwiftUI-first; AppKit only for macOS-specific interop and platform behavior.
- iOS is the canonical color/optics reference, but the iOS project must remain
  untouched unless the active task explicitly says otherwise.
- Electron Desktop remains the shipping rail until release cutover.
- Sidecar changes are additive only; avoid schema bumps until a product need
  requires one.
- Generated Swift must not be hand-edited.
- Use `bun` for repository commands.
- Keep `packages/film-lab-renderer/dist/` and `packages/film-lab-smart-look/dist/`
  tracked.

## Open Questions

- When will Desktop Look Unification land on main, enabling sidecar dual emit?
- Does baseline-C need to be populated now, or only when formal QA is requested?
- Should SPM consolidation happen before or after Native Editing UI work?
- Should deprecated Core Image kernel construction be migrated to Metal CIKernel
  before release cutover or tracked as a post-parity hardening task?
- What is the minimum signed/notarized distribution surface for the first native
  Desktop release candidate?

## Completion Log

- 2026-05-03: M1 completed with the native macOS skeleton and generated Swift
  contract lane.
- 2026-05-03: M2 completed with native still/video vertical slices and sidecar
  output.
- 2026-05-04: M3 advanced through source-color foundation, AVFoundation async
  migration, optics work, and performance measurement. Current checkpoint is
  captured in `active.md`.
- 2026-05-04: M3 C5b/C5d checkpoint clean — sourceSeed verbatim from iOS,
  pipeline order matches canonical, build/parity green. LOW gaps (Input/Creative
  LUT, printContrast abs, terminal `cropped`) tracked but no-op for built-in 4
  presets. Archived as `archive/2026-05-04-c5b-c5d-checkpoint.md`. Awaiting
  user-manual commit (INV-7) before next active task is created.

## Operating Rules

- Read this file at session start and completion only.
- Read `active.md` every implementation turn.
- Do not implement without an `active.md`.
- Do not use old handoffs as current truth; they are historical references.
- Archive completed active tasks into `archive/` and append only a short
  milestone note here.
