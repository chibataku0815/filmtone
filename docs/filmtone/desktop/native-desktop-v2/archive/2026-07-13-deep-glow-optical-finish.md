# Active: Deep Glow Optical Finish

Date opened: 2026-07-13 JST
Milestone: M3 Native Color And Optics Parity
Status: Complete
Approved source plan: `2026-07-13-deep-glow-loop-plan.md`

## Goal

Turn the existing Backlight Veil compatibility family into Filmtone's
user-facing `Deep Glow` feature. Improve its highlight-radiance falloff where
the current native implementations support a focused correction, keep existing
sidecars readable, and use one visible name across Desktop and iPad/iPhone
surfaces.

This is one optical-feature task. The UI naming work exists to expose the same
feature contract and is not a separate editing-UI milestone.

## Fixed Decisions

- Canonical visible feature name in English and Japanese: `Deep Glow`.
- Visible variants: `Subtle`, `Balanced`, `Strong`; Japanese short labels:
  `控えめ`, `標準`, `強め`.
- Standalone names: `Deep Glow - Subtle`, `Deep Glow - Balanced`, and
  `Deep Glow - Strong`, localized only at the strength label when needed.
- Preserve `backlightVeil-1-8`, `backlightVeil-1-4`,
  `backlightVeil-1-2`, and the `backlightVeil` family value as compatibility
  identifiers.
- Do not migrate the sidecar schema solely to rename an internal identifier.
- New helpers must describe Filmtone optical responsibility and must not use
  Vecmo, AE, source-tool, or implementation-order names.
- Do not claim exact Vecmo, AE, Plugin Everything, or third-party parity.

## Edit Targets

Shared contracts and generation:

- `packages/film-lab-core/src/optical-filter-profiles.ts`
- `packages/film-lab-core/src/ios-optical-filter-payload.ts`
- `packages/film-lab-core/src/ios-optical-filters-swift.ts`
- `packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md`
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/`

Native Desktop:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/`

Native iPad/iPhone:

- `apps/capacitor-film-lab-ios/ios/App/App/Editor/`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/`
- `apps/capacitor-film-lab-ios/ios/App/App/Optics/`

Lane records:

- `docs/filmtone/desktop/native-desktop-v2/active.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` only for the final
  1-3 line completion note.

Generated Swift must not be hand-edited. Update its TypeScript owner and use
the repository generator.

## Read-Only References

- `docs/filmtone/filmtone-copy-quality-harness.md`
- `docs/filmtone/filmtone-copy-context-sync.md`
- `docs/filmtone/desktop/native-desktop-v2/2026-07-13-deep-glow-loop-plan.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-07-07-native-desktop-ipad-export-quality-reset.md`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCIContext.swift`
- `packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts`
- Current Vecmo `main` optical source listed in the approved plan, treated only
  as external implementation evidence.

## Checklist

- [x] Loop 0 - Freeze the dirty-worktree boundary and reference revision.
- [x] Loop 1 - Inventory every in-scope visible legacy label.
- [x] Loop 2 - Confirm compatibility ids and sidecar boundary.
- [x] Loop 3 - Read the current three variants and identify the largest
  source-proven radiance residual.
- [x] Loop 4 - Correct Deep Glow band weighting without changing unrelated
  glow families.
- [x] Loop 5 - Separate Deep Glow strength response from radius.
- [x] Loop 6 - Keep Subtle, Balanced, and Strong ordered around one falloff law.
- [x] Loop 7 - Apply canonical Desktop naming and grouping.
- [x] Loop 8 - Apply canonical iPad naming and grouping.
- [x] Loop 9 - Align Desktop CI, iOS/iPad CI, and iOS/iPad Metal behavior.
- [x] Loop 10 - Trace still/video preview and export routing.
- [x] Loop 11 - Record the iPhone exposure decision.
- [x] Loop 12 - Record copy/history impact and remove stale candidate wording.
- [x] Archive this file when all Done conditions are met.

## Loop Log

| Loop | Result | Product Decision | Follow-up |
|---|---|---|---|
| 0 | Complete | Vecmo reference is current `main` at `27069187`; existing Filmtone edits in iPad controls, film-damage kernels, and strategy are owner work | Preserve and layer only focused changes |
| 1 | Complete | `Deep Glow` is the fixed visible name; map 1/8 -> Subtle, 1/4 -> Balanced, 1/2 -> Strong | Update shared catalog, Desktop/iPhone/iPad UI, and generated payload |
| 2 | Complete | Preserve `backlightVeil-*`, `backlightVeil`, density values, and sidecar fields | No schema migration |
| 3 | Complete | The legacy recursive weights couple radius to aggregate energy; linear strength compensates for that coupling | Correct only the Deep Glow main Bloom field |
| 4 | Complete | Use a Filmtone-owned regularized inverse-square law, weight each main-field octave once, normalize, then reconstruct coarse-to-fine | Halation, Diffusion, and non-profile Glow retain legacy reconstruction; no Vecmo contract copied |
| 5 | Complete | Map authored Bloom strength through a Filmtone-owned exponential exposure gain only when optical scatter resolves | Existing profile values stay compatible |
| 6 | Complete | Keep 0.20 / 0.38 / 0.60 and existing threshold, black-retention, warm-scatter values | Semantic order is Subtle / Balanced / Strong |
| 7 | Complete | Desktop group, chips, summaries, help, and profile display names use `Deep Glow` | Internal ids unchanged |
| 8 | Complete | iPad group and chips use localized Deep Glow strengths | Existing accessibility ids remain stable |
| 9 | Complete | Desktop CI and iOS CI use the same normalized formula; iOS Metal calls the iOS resampling owner for identical weights/gain | No kernel change to unrelated film-damage work |
| 10 | Complete | Desktop still/video preview and export pass one grade recipe into one pipeline call; iOS still/video preview and export share one `FilmtoneExportSession.applyGrade` path | No second Deep Glow application found |
| 11 | Complete | `ship`: iPhone already exposes the shared Strength Sheet, now labeled Deep Glow with localized strengths | No new iPhone surface added |
| 12 | Complete | Keep the public claim to Filmtone's own controlled highlight-radiance feature | Release-note only; retain one compatibility-history paragraph |

## Verification

Do not run tests, test suites, test commands, copy checks, or test-like
verification unless the user explicitly requests them in the current task.

Completed source generation:

- `bun run generate:ios-swift` regenerated
  `FilmtoneOpticalFiltersGenerated.swift` from the TypeScript owner.

Completed source inspection:

- Confirmed no in-scope runtime string literal still exposes `Backlight Veil`,
  `Light Bloom`, or `光のにじみ`.
- Traced Desktop still/video preview and export to one
  `FilmtoneGradePipeline.apply` call per frame.
- Traced iOS/iPad still/video preview and export through the shared
  `FilmtoneExportSession.applyGrade` path.
- Confirmed Desktop CI, iOS CI, and iOS Metal select normalized main-field
  weighting and exposure gain only when the compatibility profile resolves.

Skipped because testing was not explicitly requested in the current task:
builds, tests, visual test harnesses, owner-footage comparisons, copy/context
checks, and `git diff --check`.

## Done Conditions

- [x] Every in-scope visible feature label uses exactly `Deep Glow`.
- [x] No visible `Backlight Veil`, `Light Bloom`, `光のにじみ`, or density-only
  feature name remains on Desktop or iPad/iPhone.
- [x] Standalone variants use the canonical Deep Glow names and grouped controls
  use only the approved short strength labels.
- [x] Existing compatibility ids, family values, generated payloads, and sidecars
  remain readable without a schema break.
- [x] Deep Glow radius controls reach without an uncontrolled total-energy jump;
  unrelated glow families retain their existing reconstruction behavior.
- [x] Deep Glow strength has an exposure-like radiance progression independent of
  radius.
- [x] Subtle, Balanced, and Strong remain numerically ordered by authored
  strength, threshold, scatter, and black-retention values. Visual footage
  comparison was skipped under the current no-testing rule.
- [x] Desktop CI, iOS/iPad CI, and iOS/iPad Metal source paths apply the same
  accepted Deep Glow weighting and strength law.
- [x] Still/video preview and export routing does not add a second application or
  silent fallback.
- [x] iPhone exposure is explicitly recorded as `ship`, `hidden`, or `defer`.
- [x] Copy / History Impact, Article Opportunity, and Change-History Opportunity
  are recorded without a third-party parity claim.

## Stop Conditions

- Compatibility cannot be preserved without a sidecar/schema migration.
- The work requires a new shared cross-repo rendering contract.
- Existing dirty work overlaps a required target in a way that cannot be
  separated without discarding another task's changes.
- A source change creates an unresolved Desktop/iPad or preview/export split.
- Product acceptance depends on unavailable owner footage or owner judgment
  after all source-level work that can be completed independently is done.
- A release/App Store/portfolio claim becomes necessary before its truth gate
  is authorized.
- The same explicitly requested verification command fails 3 consecutive
  times.

## Out Of Scope

- Legacy Electron Desktop.
- Exact Vecmo, AE, or third-party plug-in parity.
- A shared cross-repo effect contract or Vecmo runtime adoption.
- Object-scoped emission/base separation, arbitrary blend modes, fringe, lens
  dirt, image-based glow, or independent RGB radii.
- Unrelated optical-family retuning.
- Public landing page, App Store metadata, portfolio, release packaging,
  signing, upload, submission, or publication.
- Broad iPhone feature work beyond exposing the existing profile consistently.
- Test-file changes, staging, commits, pushes, tags, or submodule updates.

## Unexpected Blockers

None. Existing owner changes overlapped the iPad control file and native
film-damage kernels, but the Deep Glow edits were isolated without discarding
or rewriting that work.

## Copy / History Impact

- Public copy update required: native user-facing feature labels change from
  Backlight Veil and density-only wording to `Deep Glow` plus three strengths.
- Implementation history update required: no standalone history source change;
  preserve one context paragraph in this archived task explaining the retained
  compatibility family.
- Release/App Store claim: none; this task does not state shipped release or
  store availability.
- Article Opportunity: `Release-note only` until owner visual acceptance and a
  later release truth gate exist.
- Change-History Opportunity: `Context paragraph` because the visible product
  name changes while internal compatibility ids intentionally remain stable.

Context paragraph: Filmtone originally exposed this optical profile family as
Backlight Veil with density-shaped compatibility ids. The visible product name
is now Deep Glow with semantic strength variants, while the old ids remain the
transport contract so existing projects and sidecars continue to resolve. The
new radiance falloff is Filmtone-owned and uses external Deep Glow work only as
design evidence, not as a copied renderer contract or parity claim.

## Remaining Product Risk

The source-level behavior and ordering are complete, but no owner-footage
visual comparison was run because the task did not explicitly request testing.
The next release QA should inspect bright practicals, windows, neon, and
backlight footage before making a shipped visual-quality claim.
