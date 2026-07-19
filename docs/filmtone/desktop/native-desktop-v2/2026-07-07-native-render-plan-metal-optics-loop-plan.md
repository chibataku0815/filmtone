# Proposed Loop Plan: Native Render Plan And Metal Optics Probe

Date drafted: 2026-07-07 JST
Status: Candidate plan only. Do not treat this as the current active task while
`docs/filmtone/desktop/native-desktop-v2/active.md` exists.

## Placement

Promote this plan by pausing or archiving the current `active.md`, then copying
this scope into a new `active.md`. Do not run this in parallel with the current
Desktop/iPad performance-led export quality reset.

## Purpose

Turn the useful WebGL/WebGPU and motion-rendering lessons from
`vector-motion-author`, `visual-effect-core`, `motion-grammar-lab`, and the
existing Filmtone WebGPU renderer into Swift-native Filmtone product work.

The goal is not to embed a browser GPU runtime in Desktop. The product-quality
path is:

- keep `FilmtoneGradeRecipe` / `FilmtoneResolvedGrade` / `FilmtonePhase0Params`
  as Filmtone runtime truth,
- add a thin native render-plan and capability layer,
- prove a Desktop Metal optics path for the highest-cost optical stages,
- keep Core Image as the baseline backend and fallback,
- record unsupported or approximate capabilities explicitly.

## Product Goal

Create the minimum native architecture that lets Desktop choose and explain its
render backend per effect pass without changing user-visible grading behavior
until a Metal optics path is deliberately enabled.

The first product win should be better control over heavy optical passes:
Glow Family, Backlight Veil scatter, Vignette, depth/ray-angle prefilters, and
future grain/motion timing work.

## Product Boundary

- `vector-motion-author` evidence is design context, not Filmtone identity.
- `visual-effect-core` render-plan concepts may inform the shape, but
  Filmtone must not replace its runtime grade contract with generic
  `VisualRecipe`.
- WebGPU shader code is parity evidence. Swift native implementation should use
  Core Image and Metal.
- iOS `FilmtoneMetalOpticsRenderer` is the closest owned implementation source
  for a Desktop Metal probe.
- Host/source names such as WebGPU, WGSL, AE, or vector authoring must not
  become Filmtone product model names or UI labels.

## Loop Model

Run this as short product-quality loops. Each loop must end with one of:

- a focused code/doc change inside this scope,
- a product decision recorded in the Loop Log,
- or a stop-condition report.

Per-loop rhythm:

1. Observe only the named files and the relevant dirty diff.
2. Decide the product responsibility: render-plan contract, backend selection,
   optical fidelity, timing determinism, or capability truth.
3. Change the smallest product-core surface that resolves the issue.
4. Record the result in the Loop Log before moving on.
5. Skip broad verification unless the user explicitly asks for testing in the
   current task.

## Edit Targets When Active

Primary Desktop targets:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneRenderPlan.swift`
  (new, if the plan is accepted)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoComposition.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCIContext.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtoneOpticalScatterMath.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`

Possible shared/native targets:

- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/`

Documentation targets:

- `docs/filmtone/desktop/native-desktop-v2/active.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` only for a final
  1-3 line completion note or a required direction decision.

## Read-Only References

Filmtone references:

- `apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneMetalOpticsRenderer.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneRayAngleOptics.swift`
- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/halation-depth-prefilter.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/gradeUniforms.ts`
- `packages/film-lab-renderer/src/webgpu/compositeUniforms.ts`

Sibling-repo references:

- `/Volumes/SamsungPortableSSDX5001/documents/forestone/vector-motion-author/docs/gpu-canvas-convergence-e1-plan.md`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/packages/visual-render-core/src/features/render-plan/`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/packages/filmtone-pack/src/features/compatibility/grade-params.ts`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/motion-grammar-lab/docs/decisions/0005-mixed-renderer-composition-strategy.md`

## Checklist

- [ ] Loop 0 - Intake: confirm the current `active.md` is closed or paused, then
  classify local dirty Desktop/iOS render changes into read-only evidence vs.
  editable surfaces.
- [ ] Loop 1 - Native render-plan contract: define pass ids, backend ids, and
  capability reason tokens for current Desktop grade stages without changing
  rendering behavior.
- [ ] Loop 2 - Plan builder: derive a native render plan from
  `FilmtoneResolvedGrade`, source profile, video timing, and optical filter
  selection.
- [ ] Loop 3 - No-behavior pipeline wiring: let the existing Core Image path
  consume the plan order while preserving current output.
- [ ] Loop 4 - Metal optics decision: decide whether Desktop should adapt the
  iOS Metal optics renderer directly, share a Swift core helper, or keep the
  first pass Desktop-local.
- [ ] Loop 5 - Metal optics probe: add a disabled or explicitly gated Desktop
  Metal path for Glow Family + optional Vignette, with Core Image fallback.
- [ ] Loop 6 - One-clock frame context: consolidate preview/export time,
  frame index, fps, source seed, and output timing into a shared native frame
  context.
- [ ] Loop 7 - Capability/fidelity manifest: record which effects are native,
  approximate, fallback-only, or unsupported across Core Image, Desktop Metal,
  iOS Metal, WebGPU, and sidecar.
- [ ] Loop 8 - Product decision: choose the next active implementation slice:
  Metal optics expansion, depth/ray-angle Desktop parity, grain timing, or
  manifest-driven UI/export messaging.
- [ ] Record Copy / History Impact, Article Opportunity, and
  Change-History Opportunity.
- [ ] Archive the promoted `active.md` when Done conditions are met.

## Loop Log

Fill this only after the plan is promoted to `active.md`.

| Loop | Result | Product Decision | Follow-up |
|---|---|---|---|
| 0 | Pending | Pending | Pending |
| 1 | Pending | Pending | Pending |
| 2 | Pending | Pending | Pending |
| 3 | Pending | Pending | Pending |
| 4 | Pending | Pending | Pending |
| 5 | Pending | Pending | Pending |
| 6 | Pending | Pending | Pending |
| 7 | Pending | Pending | Pending |
| 8 | Pending | Pending | Pending |

## Verification

Do not run tests, test suites, test commands, or test-like verification unless
the user explicitly asks for testing in the current task.

When testing is explicitly requested, use the smallest proof for the changed
surface:

- Render-plan no-behavior wiring:
  - focused compile/build command chosen from the changed target,
  - `bun run verify:desktop` only when explicitly requested.
- Metal optics probe:
  - focused Desktop build or native verify command only when explicitly
    requested,
  - visual/export comparison on owner-provided footage only when requested.
- Shared Swift contract changes:
  - package build or focused Swift test only when explicitly requested.
- Formatting:
  - `git diff --check` only when explicitly requested.

Skipped at plan creation: all test and verification commands, because the
current user request only asks for a plan document.

## Done Conditions

- Native Desktop has an explicit render-plan type that maps current grade stages
  to backend/capability decisions without changing current output.
- Existing Core Image rendering can stay the default while a Metal optics path
  is selected by explicit capability/gate rules.
- The first Desktop Metal optics candidate is either implemented behind a gate
  or rejected with a concrete product reason.
- Preview/export frame timing has a single native source of truth, or the
  remaining divergence is recorded as the next active task.
- Capability/fidelity truth is explicit enough to prevent silent claims of
  parity for unsupported effects.
- No WebGPU/WKWebView runtime is introduced into Native Desktop.
- No `visual-effect-core` or `vector-motion-author` model becomes Filmtone
  runtime truth.

## Stop Conditions

- The current `active.md` cannot be paused or archived cleanly.
- The work requires a milestone restructure rather than one scoped native
  render/optics task.
- Metal probe work requires changing release behavior, signing, packaging, or
  App Store state.
- Output fidelity changes in a way that needs owner visual judgment and no
  owner footage or decision is available.
- The same explicitly requested verification command fails 3 consecutive times.

## Out Of Scope

- Legacy Electron Desktop.
- WKWebView, Safari, or WebGPU embedding in the native macOS app.
- Full rewrite of `FilmtoneGradePipeline`.
- Full migration to `VisualRecipe` or LookGraph runtime.
- New public copy, release notes, App Store metadata, or portfolio updates.
- Broad QA harness work before the core render decision is made.
- Creating or modifying test files unless explicitly requested.
- Staging, committing, pushing, or tagging.

## Copy / History Impact

No copy/history impact: this is a candidate planning document only.

Article Opportunity: Developer note only if a later active task lands a real
native render-plan or Metal optics change.

Change-History Opportunity: Yes, if promoted and implemented. The history should
explain that Filmtone reused WebGPU-era render/pass lessons by moving toward a
Swift-native Core Image + Metal backend model, not by embedding WebGPU in the
native product.
