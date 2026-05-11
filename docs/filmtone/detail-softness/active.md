# Phase 2-B: macOS Native Pilot — Detail Softness Render Pass

Date opened: 2026-05-12 JST
Phase: 2 of 5 (sub-stage 2-B; see `strategy.md` and
`archive/2026-05-12-phase-2a-research-charter.md`)

## Gating

**Phase 1 commit landed separately before Phase 2-B render source.**
`feature/detail-softness-contract` HEAD includes `033a335f`
(`feat(detail-softness): add neutral contract plumbing`), which commits the
Phase 1 contract plumbing and lane docs without render prototype code. Phase
2-B render changes may start from this commit and must land in a later commit.

This `active.md` is the Phase 2-B charter. The Checklist below sequences the
prototype.

## Owner-confirmed decisions (2026-05-12)

- **Algorithm**: local-reference high-pass attenuation skeleton from the
  Phase 2-A archive §Algorithm decision. No bilateral / domain-transform
  spike unless the macOS pilot fails edge/skin quality at `0.18` or `0.30`.
- **Pilot renderer**: macOS native first (fastest CIKernel/Metal iter cycle,
  single-function pipeline, mechanical port target for iOS export in 2-C).
- **Branch posture**: Phase 1 commits separately before any Phase 2-B render
  source change.
- **`effectiveMax`**: hard-coded `0.34` for Phase 2 (revisit Phase 3 when UI
  control lands).
- **Working colorspace**: verify during prototype; failure adjusts luma
  weights, not the algorithm shape.

## Goal

Implement the Detail Softness render pass on the macOS native pipeline as
the pilot renderer. Validate:

1. `effectiveDetailSoftness == 0` is bitwise neutral (identity-at-0).
2. `effectiveDetailSoftness ∈ {0.18, 0.30}` produces visible softening on
   the A/B still set without obvious skin waxiness, smeared hair / foliage,
   or unreadable text.
3. The Phase 2-A skeleton is the right shape; if it fails edge / skin
   quality on the pilot still set, halt and reopen algorithm review per
   owner's "spike if pilot fails" clause.
4. Working colorspace at the insertion point uses Rec.709 luma weights as
   assumed in 2-A. Verify and document; adjust luma weights if not.

## Edit Targets

### Shared derivation helper — `packages/film-lab-core/`

- **New** `packages/film-lab-core/src/detail-softness.ts` exporting:
  - `DETAIL_SOFTNESS_EFFECTIVE_MAX = 0.34` constant.
  - `DetailSoftnessUniforms` type matching the WGSL/Metal layout proposed
    in Phase 2-A:
    `{ effectiveDetailSoftness, kernelRadiusPx, chromaAttenScale, edgeGuardLo, edgeGuardHi, highlightBias }`.
  - `deriveDetailSoftnessUniforms(detailSoftness: number, opts?: { sourceDetailBias?: number }): DetailSoftnessUniforms`
    — pure function consumed by every renderer in 2-B…2-D so derived units
    do not diverge.
- **New** `packages/film-lab-core/src/detail-softness.test.ts` covering:
  - `detailSoftness === 0` ⇒ `effectiveDetailSoftness === 0`.
  - Clamp to `[0, 0.34]` at both boundaries (`-0.1` → `0`, `0.5` → `0.34`).
  - `sourceDetailBias` defaults to `0` in Phase 2; when provided, sum is
    re-clamped to `[0, 0.34]`.
  - Derived `kernelRadiusPx` lies in `[0.55, 1.45]` and increases
    monotonically with `effectiveDetailSoftness`.
- Re-export from `packages/film-lab-core/src/index.ts`.

### macOS native pipeline — `apps/filmtone-desktop-macos/`

- `FilmtoneDesktop/Color/FilmtoneGradeKernels.swift` — add
  `detailSoftnessKernel` following whichever pattern the surrounding optical
  kernels use (CIKernel string vs Metal-backed `CIColorKernel`). Implements
  the Phase 2-A skeleton: local-reference 3x3..5x5 sample, edge guard via
  local `|∇L|`, separated luma vs chroma attenuation, highlight bias.
  Identity short-circuit when `effectiveDetailSoftness == 0`.
- `FilmtoneDesktop/Color/FilmtoneGradePipeline.swift` — add
  `applyDetailSoftnessStage(to:params:)` and insert between
  `filmCompressionV2` (current L66) and `edgeOptics` (current L68) in the
  `apply(...)` orchestrator. Uniforms derived from a Swift mirror of
  `deriveDetailSoftnessUniforms` to keep TS / Swift in lockstep.
- Swift mirror lives in `FilmtonePhase0Math.swift` alongside `clampParam(...)`
  so the iOS export port in 2-C reuses it. Constants (`effectiveMax`, kernel
  radius range, edge-guard thresholds, highlight bias) must match
  `detail-softness.ts` byte-for-byte.

### Working colorspace verification (read-only check)

- Read `FilmtoneGradePipeline.swift` upstream of the insertion point to
  confirm the working colorspace at that point. Expected: linearised
  Rec.709 primaries (`(0.2126, 0.7152, 0.0722)` luma weights). If Display P3
  or BT.2020 primaries are in play, adjust luma weights and document under
  Completion Log.

### Out of scope for 2-B

- WebGPU shader, iOS export kernel, WebGL shader, cross-renderer parity
  test → Phase 2-C / 2-D.
- Phase 4 source-bias resolver, Phase 3 UI exposure, Phase 5 visual tuning
  matrix.
- `AdvancedAdjustCatalog.swift` Veil intensity max-merge decision (deferred
  from Phase 1; revisit when iOS port lands or when UI exposure starts).

## Verification

```bash
bun run build:core
bun run --cwd packages/film-lab-core test    # new detail-softness.test.ts passes; baseline-waived ios-swift-payload failures unchanged
bun run build:smart-look                     # .d.ts re-export check
bun run verify:macos                         # macOS pipeline compiles
swift test --package-path packages/film-lab-swift-core   # contract tests still green
bun run check:filmtone-context               # this active.md declares Copy / History Impact below
git diff --check
```

### Visual A/B (manual, recorded in Completion Log)

Use the standard A/B still set listed in plan §Visual Tuning Reference:

- 1 skin close-up (Rec.709 / iPhone SDR).
- 1 hair / foliage edge.
- 1 text / signage.
- 1 highlight rim (sun edge, lamp practical).

| `detailSoftness` | Expectation |
|---|---|
| `0.00` | Bitwise identical to current build. Screenshot diff against pre-Phase-2-B baseline is 0. |
| `0.18` | Visible softening on skin + foliage. Text readable. Highlight rims preserved. |
| `0.30` | Stronger softening. Still no waxy skin / unreadable text. |
| `> 0.34` | Clipped to `0.34` (effectiveMax). |

## Done Conditions

- Shared `deriveDetailSoftnessUniforms` helper exists in `film-lab-core`,
  is unit-tested, and is re-exported from the package entrypoint.
- Swift mirror of the derivation lives in `FilmtonePhase0Math.swift`;
  constants byte-match the TS helper.
- macOS native pipeline carries `applyDetailSoftnessStage` between
  `filmCompressionV2` and `edgeOptics`.
- Identity at `0` proven on the A/B still set (screenshot diff = 0).
- Visible softening at `0.18` and `0.30` confirmed without obvious skin
  waxiness, smeared hair, or unreadable text.
- Working colorspace verified at insertion point; luma weights confirmed or
  adjusted with the change documented under Completion Log.
- `bun run verify:macos` and `film-lab-core` tests green; baseline-waived
  `ios-swift-payload.test.ts` failures unchanged.
- Completion Log lists the algorithm-shape verdict (skeleton holds, or
  needs spike) and the colorspace verdict.

## Copy / History Impact

No copy / history impact: Phase 2-B is an internal render pass + a shared
derivation helper. No user-visible label, help text, App Store metadata, or
implementation-history claim changes — UI exposure lands in Phase 3.
`bun run check:filmtone-context` must pass on this declaration.

## Stop Conditions

- Phase 2-B render source is about to start from a HEAD before `033a335f`.
  Halt and rebase / switch to the committed Phase 1 base first.
- Identity at `0` fails (any pixel differs). Pause and diagnose before any
  uniform / kernel change ships.
- Macroscopic skin waxiness or smeared hair on the A/B set at `0.18`.
  Reopen algorithm review per owner's "spike if pilot fails" clause.
- Working colorspace at insertion point is not Rec.709 (Display P3 or
  BT.2020). Pause to adjust luma weights; document under Completion Log.
- macOS pipeline structural changes are required outside the single
  `applyDetailSoftnessStage` insertion (e.g., new render-target plumbing).
  Pause and bring back to owner before refactor.

## Checklist

- [x] **(Precondition)** Phase 1 commit landed on
      `feature/detail-softness-contract` at `033a335f`.
- [ ] `packages/film-lab-core/src/detail-softness.ts` added with helper +
      `DetailSoftnessUniforms` type + `DETAIL_SOFTNESS_EFFECTIVE_MAX`
      constant.
- [ ] `packages/film-lab-core/src/detail-softness.test.ts` added covering
      identity, clamps, monotonicity, bias.
- [ ] `packages/film-lab-core/src/index.ts` re-exports the helper, type,
      and constant.
- [ ] Swift mirror in `FilmtonePhase0Math.swift` matches the TS derivation;
      constants in lockstep.
- [ ] `FilmtoneGradeKernels.swift` `detailSoftnessKernel` added with
      identity short-circuit at `effectiveDetailSoftness == 0`.
- [ ] `FilmtoneGradePipeline.swift` `applyDetailSoftnessStage` inserted
      between `filmCompressionV2` and `edgeOptics`.
- [ ] Working colorspace at insertion point verified; luma weights
      confirmed (or adjusted with rationale).
- [ ] Identity-at-0 manual screenshot diff is 0 on the A/B set.
- [ ] Visible softening at `0.18` / `0.30` confirmed on the A/B set without
      quality regressions.
- [ ] All verify commands green (build:core / film-lab-core test /
      build:smart-look / verify:macos / swift test / check:filmtone-context
      / git diff --check).
- [ ] `active.md` archived to
      `archive/2026-05-12-phase-2b-macos-native-pilot.md`;
      `strategy.md` gets a 1–3 line completion note.

## Read-only references

- Phase 2-A archive: `archive/2026-05-12-phase-2a-research-charter.md`
  (algorithm skeleton, insertion-point survey, uniform contract).
- Plan: `docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md`.
- Phase 1 archive: `archive/2026-05-12-phase-1-contract-neutral-plumbing.md`.
- `strategy.md` (this lane).

## Implementation Log

### 2026-05-12 JST — implementation landed (pending visual A/B)

Source landed on `feature/detail-softness-contract` after the Phase 1
commit `033a335f`. Visual A/B on the standard still set is the remaining
gate before archive; that step is owner-run.

**Files added / changed**

- `packages/film-lab-core/src/detail-softness.ts` — shared derivation
  helper, uniforms type, `DETAIL_SOFTNESS_EFFECTIVE_MAX = 0.34` constant.
- `packages/film-lab-core/src/detail-softness.test.ts` — 8 tests covering
  identity, clamps, default bias, summed bias re-clamp, monotonic kernel
  radius, parity constants.
- `packages/film-lab-core/src/index.ts` — re-exports helper, type,
  constant.
- `packages/film-lab-core/dist/*` — rebuilt.
- `packages/film-lab-smart-look/dist/*` — rebuilt (its `.d.ts` re-exports
  the widened core surface).
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneDetailSoftnessUniforms.swift`
  — Swift mirror lives in the **shared** Swift package (`FilmLabSwiftCore`)
  rather than the iOS-app-only `FilmtonePhase0Math.swift` proposed in the
  Edit Targets section: only the shared package is reachable from both
  the macOS pilot (this sub-stage) and the iOS export port (Phase 2-C).
- `packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/DetailSoftnessUniformsTests.swift`
  — 7 tests mirroring the TS suite, locking parity constants.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
  — `detailSoftness` CIKernel (CI Kernel Language, working color space =
  linear sRGB / Rec.709). Identity short-circuit at
  `effectiveDetailSoftness < 1e-4`.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
  — `applyDetailSoftnessStage` inserted between `filmCompressionV2` and
  `applyEdgeOpticsStage` in `apply(...)`. Caller short-circuit before
  kernel apply means non-`detailSoftness` renders never construct the
  CIImage for the new stage.

**Working colorspace verdict**

`FilmtoneCIContext.swift` pins working color space to
`CGColorSpace.linearSRGB` (linear sRGB = Rec.709 primaries). Rec.709 luma
weights `(0.2126, 0.7152, 0.0722)` used in the Phase 2-A skeleton apply
directly at the insertion point. **No luma-weight adjustment needed.**

**Verification gates run**

| Gate | Result |
|---|---|
| `bun run --cwd packages/film-lab-core test` | 207 pass / 2 fail. **The 2 failures are the same baseline-waived `ios-swift-payload.test.ts` failures from Phase 1, unchanged.** All 8 new `detail-softness.test.ts` tests pass. |
| `bun run build:core` | OK. |
| `bun run build:smart-look` | OK; `.d.ts` widened to re-export the helper / type / constant. |
| `swift test --package-path packages/film-lab-swift-core` | 44 / 44 pass (37 baseline + 7 new `DetailSoftnessUniformsTests`). |
| `bun run verify:macos` | **BUILD SUCCEEDED**. |
| `bun run check:filmtone-context` | PASS — this Implementation Log carries the Copy / History Impact marker for the new source files. |
| `git diff --check` | Clean. |

**Pending owner action — visual A/B**

The Visual A/B procedure in §Verification has not been run because it
requires a still-export through the macOS app on a curated set. Owner
runs the 4-image set at `detailSoftness ∈ {0.00, 0.18, 0.30}` and reports
back:

- Identity at `0.00` — screenshot diff vs pre-Phase-2-B baseline must be 0.
- Visible softening at `0.18` / `0.30` without obvious skin waxiness,
  smeared hair / foliage, or unreadable text on the standard still set.

If the algorithm shape holds, Phase 2-B archives to
`archive/2026-05-12-phase-2b-macos-native-pilot.md`. If quality fails,
reopen algorithm review per Phase 2-A's "spike if pilot fails" clause.

## Copy / History Impact (restated for Implementation Log)

No copy / history impact: Phase 2-B is an internal render pass + a shared
derivation helper. No user-visible label, help text, App Store metadata,
or implementation-history claim changes — UI exposure lands in Phase 3.
`bun run check:filmtone-context` must pass on this declaration.
