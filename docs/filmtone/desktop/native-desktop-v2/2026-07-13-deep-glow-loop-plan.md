# Proposed Loop Plan: Filmtone Deep Glow

Date drafted: 2026-07-13 JST
Status: Completed. Promoted on 2026-07-13 and archived as
`archive/2026-07-13-deep-glow-optical-finish.md`.

## Placement

Promote this plan by creating a new `active.md` from this exact scope after
owner acceptance. There is no current `active.md` at draft time. The previous
Desktop/iPad performance-led export quality reset remains archived at
`archive/2026-07-07-native-desktop-ipad-export-quality-reset.md`.

This is one Native Desktop v2 / native iPad optical-feature task. It owns the
user-visible rename from Backlight Veil to Deep Glow and the focused optical
quality work required for that name to be truthful. It is not a release,
portfolio, or legacy Electron task.

## Owner Decision

The canonical user-facing feature name is:

- English: `Deep Glow`
- Japanese: `Deep Glow`
- Canonical capitalization: `Deep Glow`

All in-scope user-visible labels, menus, help text, profile names, and localized
catalog entries must use this name. Do not show `Backlight Veil`, `Light Bloom`,
or `光のにじみ` as parallel feature names after the task is complete.

Variant labels:

- English: `Subtle`, `Balanced`, `Strong`
- Japanese: `控えめ`, `標準`, `強め`

When a variant name must stand alone, use `Deep Glow - Subtle`,
`Deep Glow - Balanced`, and `Deep Glow - Strong`, with the corresponding
Japanese strength label. When the UI already has a `Deep Glow` group heading,
show only the short strength labels.

Internal compatibility is intentionally separate from visible naming:

- keep `backlightVeil-1-8`, `backlightVeil-1-4`, and `backlightVeil-1-2`,
- keep the `backlightVeil` family value,
- keep existing sidecar and generated-payload compatibility,
- do not introduce a schema migration solely to make internal ids match the
  display name.

Any future internal-id migration is a separate contract task. New rendering
helpers introduced by this task must use optical-domain responsibilities rather
than Vecmo, AE, validation-stage, or source-tool names.

## Purpose

Turn the current Backlight Veil implementation into Filmtone's Deep Glow
feature: a plainly named, visibly useful highlight-radiance control for video
that preserves dark values and remains consistent across native preview and
export.

The name must be supported by the result. A label-only rename is insufficient.
The accepted effect should produce a continuous bright-core-to-wide-tail field
without turning the entire frame into haze or flattening the shot's black level.

## Product Responsibility

This task owns:

- the canonical `Deep Glow` user-visible name,
- the Subtle / Balanced / Strong presentation,
- compatibility aliases from existing `backlightVeil-*` ids,
- the Backlight Veil profile values that become Deep Glow variants,
- normalized multi-resolution glow weighting where current source proves it is
  needed,
- an exposure-like strength response if it improves the accepted footage
  without changing unrelated glow families,
- Desktop and iPad preview/export consistency,
- the decision for any currently exposed iPhone label,
- copy/history impact recording.

This task does not own:

- exact parity with the Plugin Everything Deep Glow product,
- exact Vecmo pixel parity,
- Vecmo Look Graph or WebGL runtime adoption,
- a new shared cross-repo effect contract,
- release packaging, App Store metadata, or portfolio publication,
- unrelated optical-family retuning.

## Copy Brief

- Surface: literal UI feature/group/profile labels, not marketing copy.
- Primary reader: a Desktop or iPad editor reviewing bright, neon, window-lit,
  or backlit footage before export.
- Moment: the footage looks too hard or the highlights do not spread enough,
  and the editor is choosing an optical finish.
- Unresolved feeling: the editor wants bright areas to radiate without losing
  shadow separation or learning diffusion-filter density terminology.
- Next action: choose a Deep Glow strength, compare it on the footage, and keep
  or remove it before export.
- Not for: users expecting a third-party plug-in clone, motion-graphics node
  controls, manufacturer-certified filter emulation, or automatic relighting.
- Claim class: `Candidate` until implementation and explicitly requested visual
  verification are complete.
- Source evidence: current Filmtone linear-sRGB glow pipeline, soft-knee plates,
  tent mip reconstruction, Backlight Veil scatter math, profile catalog, and
  current Vecmo Deep Glow as external rendering evidence.
- Reversibility buffer: visible aliases may change while internal compatibility
  ids remain stable; no sidecar schema claim is made.

## Current Technical Baseline

Filmtone already provides the core optical structure:

- linear-sRGB working color,
- configurable bloom and halation soft-knee extraction,
- six-level bloom and halation pyramids,
- tent downsample and progressive tent upsample,
- separate bloom, halation, and diffusion plates,
- direct transmission, black retention, scatter strength, highlight
  reactivity, warm scatter, and spectral-tail controls,
- native Desktop and iPad/iOS CI/Metal implementations.

Current Vecmo `main` adds useful reference evidence through commits
`cb4ff4ef` and `1e6ece12`:

- linear-light smooth-threshold radiance extraction,
- normalized inverse-square-like octave weighting,
- separation of radius/reach from exposure/energy,
- coarse-to-fine tent reconstruction,
- exposure-like intensity mapping,
- scoped emission/base separation,
- optional blend mode, fringe, and display dither.

The previous plan's description of Vecmo as only threshold extraction,
multi-scale blur, and screen-like compositing is superseded.

## Adoption Boundary

Adopt or evaluate inside Filmtone:

- normalized radius-dependent band weights so radius primarily controls reach,
- exposure-like strength behavior so low-energy tails can become visible
  without a linear-opacity feel,
- continuous core, middle bloom, and wide-tail falloff,
- stable black retention and highlight ownership,
- one result across still preview, video preview, still export, and video
  export for each supported native rail.

Keep from the existing Filmtone model:

- user/profile-controlled soft knee,
- bloom + halation + diffusion separation,
- Backlight Veil optical scatter coefficients behind the Deep Glow display
  name,
- warm scatter and spectral-tail behavior,
- unclamped internal scatter headroom where the current pipeline supports it,
- linear-sRGB native processing.

Do not adopt by default:

- Vecmo object-selection emission/base separation; Filmtone applies the feature
  to completed footage rather than vector-object target sets,
- arbitrary blend-mode controls,
- radial RGB fringe as a new Deep Glow control,
- display dither inside the glow stage unless real 8-bit exports show banding,
- Vecmo types, ids, graph contracts, shader names, or UI terminology,
- claims of AE or third-party plug-in compatibility.

## Visual Acceptance Target

Use bright practicals, windows, neon, reflective highlights, and sun/backlight
footage as the owner-review set.

The accepted result must show:

- bright image content, not opaque geometry or the entire frame, driving glow,
- one continuous falloff from core to medium bloom to wide low-energy tail,
- no hard halo boundary, blocky mip footprint, cross, column, or rectangular
  spill,
- radius changing reach without causing an uncontrolled jump in total energy,
- strength changing apparent radiance without behaving like simple opacity,
- retained black separation at Subtle and Balanced,
- intentional haze only at Strong,
- warm halation remaining subordinate to the main luminous field,
- no new hue shift in neutral highlights unless existing warm/spectral profile
  controls request it.

## Loop Model

Run short product-quality loops. Each loop ends with one of:

- one focused source/doc change inside this scope,
- one product decision recorded in the Loop Log,
- or a stop-condition report.

Per-loop rhythm:

1. Read only the named target files and overlapping dirty diff.
2. State the single issue for the loop.
3. Make the smallest change that resolves that issue.
4. Update the active checklist and Loop Log immediately.
5. Do not run tests, test-like verification, or copy checks unless the user
   explicitly requests them in that execution task.

## Edit Targets When Active

Primary shared targets:

- `packages/film-lab-core/src/optical-filter-profiles.ts`
- `packages/film-lab-core/src/ios-optical-filter-payload.ts`
- `packages/film-lab-core/src/ios-optical-filters-swift.ts`
- `packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md`
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneOpticalFilterEditorCatalog.swift`
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/EditorAdvancedAdjustCatalog.swift`

Primary Desktop targets:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtoneDesktopStrings.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtoneOpticalScatterMath.swift`

Primary iPad/iOS targets:

- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Pad/FilmtonePadAdjustPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneMetalOpticsRenderer.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneOpticalFiltersGenerated.swift`

Do not hand-edit generated Swift. Change the TypeScript source and regenerate
through `bun run generate:ios-swift` only when verification/code generation is
explicitly authorized in the execution task.

Documentation targets:

- `docs/filmtone/desktop/native-desktop-v2/active.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` only for a final 1-3
  line completion note or a required direction decision.

## Read-Only References

Filmtone references:

- `docs/filmtone/filmtone-copy-quality-harness.md`
- `docs/filmtone/filmtone-copy-context-sync.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-07-07-native-desktop-ipad-export-quality-reset.md`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCIContext.swift`
- `packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts`

External reference evidence from Vecmo `main`:

- `src/shared/gpu-lens/surface.ts`
- `src/entities/scene/model/gpu-raster-adapter.ts`
- `src/entities/scene/model/source-optics.ts`
- `docs/product-knowledge/deep-glow-source-driven-compositor.md`

Read these from the current `main` ref in
`/Volumes/SamsungPortableSSDX5001/documents/forestone/vector-motion-author`.
The repository's currently checked-out worktree may be on another branch, so do
not assume its working file equals `main` without checking.

## Checklist

- [ ] Loop 0 - Intake and dirty-boundary freeze: confirm no current `active.md`,
  classify overlapping Filmtone edits, and record the Vecmo reference revision.
- [ ] Loop 1 - Visible-name inventory: find every in-scope `Backlight Veil`,
  density-only label, help string, menu item, profile display name, and localized
  catalog value. Produce the exact replacement map before editing strings.
- [ ] Loop 2 - Compatibility boundary: keep `backlightVeil-*` and
  `backlightVeil` internal values, define display aliases, and confirm that no
  sidecar schema migration is required.
- [ ] Loop 3 - Baseline visual read: inspect current Subtle-equivalent,
  Balanced-equivalent, and Strong-equivalent output on the owner footage set and
  identify the largest visible residual.
- [ ] Loop 4 - Band-weight correction: evaluate and, if supported by the
  baseline, implement normalized radius-dependent mip weighting in the shared
  native implementations without changing unrelated glow families.
- [ ] Loop 5 - Exposure response: evaluate an internal Deep Glow strength
  mapping that separates radiance gain from radius. Preserve existing profile
  values or migrate them through explicit compatibility math.
- [ ] Loop 6 - Variant tuning: tune Subtle, Balanced, and Strong around one
  accepted falloff law. Keep black retention and warm scatter deliberate.
- [ ] Loop 7 - Desktop naming/UI pass: replace visible Backlight Veil naming,
  ensure standalone and grouped labels use the canonical form, and confirm text
  fits existing controls.
- [ ] Loop 8 - iPad naming/UI pass: apply the same canonical label and strength
  vocabulary to the native iPad editor/export surfaces.
- [ ] Loop 9 - Native render-path parity: inspect Desktop CI, iPad/iOS CI, and
  iPad/iOS Metal implementations for the same weighting and strength behavior;
  do not claim parity from one path's code alone.
- [ ] Loop 10 - Preview/export routing: confirm the selected profile id and
  strength reach still/video preview and still/video export without double
  application or silent fallback.
- [ ] Loop 11 - iPhone exposure decision: if the feature is visible on iPhone,
  use `Deep Glow`; otherwise record `defer` or `hidden` without adding a new
  surface in this task.
- [ ] Loop 12 - Copy/history impact: remove stale public-candidate wording,
  record release-note and change-history classification, and keep third-party
  parity claims out of public copy.
- [ ] Archive the promoted `active.md` after all Done conditions are met.

## Loop Log

Fill this only after the plan is promoted to `active.md`.

| Loop | Result | Product Decision | Follow-up |
|---|---|---|---|
| 0 | Pending | Pending | Pending |
| 1 | Pending | `Deep Glow` is the fixed visible name | Pending |
| 2 | Pending | Preserve compatibility ids by default | Pending |
| 3 | Pending | Pending | Pending |
| 4 | Pending | Pending | Pending |
| 5 | Pending | Pending | Pending |
| 6 | Pending | Pending | Pending |
| 7 | Pending | Pending | Pending |
| 8 | Pending | Pending | Pending |
| 9 | Pending | Pending | Pending |
| 10 | Pending | Pending | Pending |
| 11 | Pending | Pending | Pending |
| 12 | Pending | Pending | Pending |

## Verification

Do not run tests, test suites, test commands, copy checks, or test-like
verification unless the user explicitly requests them in the execution task.

When explicitly requested, use the smallest proof for the changed surface:

- Shared catalog/generated payload:
  - `bun run build:core`
  - `bun run generate:ios-swift`
- Desktop UI/render:
  - focused native build or `bun run verify:desktop`
  - owner visual comparison on the agreed footage set
- iPad UI/render/export:
  - focused `xcodebuild` for `App-iPad`
  - `bun run verify:ios`
- Copy/context:
  - `bun run check:filmtone-copy`
  - `bun run check:filmtone-context`
- Formatting:
  - `git diff --check`

Skipped at plan creation: all test and verification commands, including the
Japanese copy checker, because the current request asks only for a plan.

## Done Conditions

- Every in-scope user-visible feature label uses exactly `Deep Glow`.
- No visible `Backlight Veil`, `Light Bloom`, `光のにじみ`, or density-only
  feature name remains on Desktop or iPad.
- Standalone variants read `Deep Glow - Subtle`, `Deep Glow - Balanced`, and
  `Deep Glow - Strong`, with natural Japanese strength labels where localized.
- Existing `backlightVeil-*` ids, family values, generated payloads, and
  sidecars remain readable without a silent schema break.
- Radius controls reach without an uncontrolled total-energy jump, or the Loop
  Log records evidence for retaining the current weighting.
- Strength produces a useful radiance progression without behaving like simple
  opacity.
- Subtle, Balanced, and Strong have a visible, ordered progression and retain
  black separation according to the Visual Acceptance Target.
- Desktop and iPad supported native preview/export paths apply the same selected
  Deep Glow profile and accepted optical law.
- iPhone exposure is explicitly recorded as `ship`, `hidden`, or `defer`.
- No source code, UI, or public candidate copy claims exact AE, Vecmo, or
  third-party Deep Glow parity.
- Copy / History Impact, Article Opportunity, and Change-History Opportunity are
  recorded.

## Stop Conditions

- Existing `backlightVeil-*` compatibility cannot be preserved without a
  sidecar/schema migration decision.
- The work requires a new shared cross-repo rendering contract rather than a
  focused Filmtone optical implementation.
- The current dirty work overlaps a required target in a way that cannot be
  separated without discarding another task's changes.
- Visual tuning requires owner judgment and the agreed footage or owner review
  is unavailable.
- A change that improves one native path creates an unresolved preview/export
  or Desktop/iPad divergence.
- Public release/App Store/portfolio claims become necessary before their truth
  gates are authorized.
- The same explicitly requested verification command fails 3 consecutive times.

## Out Of Scope

- Legacy Electron Desktop.
- Exact Vecmo, AE, or Plugin Everything Deep Glow parity.
- New WebGPU/WKWebView runtime in Native Desktop.
- New object-scoped emission/base compositing in Filmtone.
- Arbitrary user-facing glow blend modes, lens dirt, image-based glow, or
  independent RGB radii.
- Public landing-page, App Store metadata, release-note, or portfolio edits.
- Release packaging, signing, upload, submission, or publication.
- Broad iPhone feature work beyond the visibility decision.
- Creating or modifying test files unless explicitly requested.
- Staging, committing, pushing, tagging, or portfolio submodule updates.

## Copy / History Impact

Copy / History Impact: user-facing copy update required when implemented. The
visible optical feature name changes from Backlight Veil to Deep Glow across
native Desktop and iPad surfaces. Internal compatibility names remain
implementation details and must not leak into UI or public copy.

The public claim must remain narrow: Filmtone has a feature named Deep Glow that
creates controlled highlight radiance in its own native optical pipeline. Do
not describe it as the third-party plug-in, an AE port, or a Vecmo-equivalent
renderer.

Article Opportunity: `Release-note only` until the feature ships and owner
visual acceptance is recorded. Promote to `Developer note` only if the
normalized band-weight/exposure work produces a durable implementation lesson
with verified footage evidence.

Change-History Opportunity: `Context paragraph`. Record that the original
Backlight Veil compatibility family was retained internally while the visible
feature became Deep Glow and its optical falloff was tightened. Do not rewrite
earlier history as if the original Backlight Veil implementation never existed.
