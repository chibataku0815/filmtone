# Phase 2-A: Algorithm Spec + Insertion-Point Survey

Date opened: 2026-05-12 JST
Date archived: 2026-05-12 JST
Phase: 2 of 5 (see `../strategy.md`)
Sub-stage: 2-A (research-only; no source code changes in this subtask)

## Why this sub-stage exists

Phase 2 as a whole (Real Render Pass) spans WebGL + WebGPU + macOS native +
iOS export and is far larger than a single 30-minute slice. This sub-stage
freezes the algorithm direction, locks the canonical pipeline insertion
point in each of the four renderers, and proposes the uniform / kernel
contract Phase 2-B will compile against. No shader, no Swift kernel, no
TypeScript pipeline file was modified by Phase 2-A.

Output of Phase 2-A is this document. Phase 2-B onwards depends on the
owner-confirmed decisions recorded in the Completion Log below.

## Goal (Phase 2-A)

1. Pick the Detail Softness algorithm shape from
   `docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md`
   (§Algorithm Direction) and record it as a concrete, implementable kernel
   skeleton.
2. Locate the exact stage boundary in every renderer where the new pass
   sits, citing the function / shader file + line range it inserts between.
3. Propose a uniform / kernel parameter contract that all four renderers
   can share (so `bun run check:filmtone-context` and renderer parity stay
   sane).
4. Decompose Phase 2 into sequential 30-min-or-less sub-stages 2-B / 2-C /
   2-D / 2-E so each future subtask has a single clear deliverable.
5. Surface the open questions that block 2-B (algorithm direction confirm,
   pilot renderer pick, Phase 1 commit-landing dependency).

Out of scope for 2-A: writing the pass; writing tests; building anything;
committing anything.

## Algorithm decision (proposal — owner-confirmed; see Completion Log)

Adopted from plan §Algorithm Direction. Concrete skeleton:

```
// Inputs
//   srcRGB       — graded, tone-compressed linear color (after print? no — see Stage Insertion)
//   srcLuma      — luma derived from srcRGB (Rec.709 weights for now;
//                   revisit if the working colorspace is BT.2020)
// Uniforms
//   effectiveDetailSoftness ∈ [0, 0.34]   // user `detailSoftness` clamped + source bias (Phase 4 adds bias)
//   kernelRadiusPx                          // 0.55..1.45 scaled by effective value
//   chromaAttenScale                        // chroma reduction factor < 1
//   edgeGuardSlope                          // sensitivity to local |∇L|
//   highlightBias                           // strengthens softening near hot/edge highlights

// Per-pixel pseudo
let localRef = smallRadiusLocalReference(srcRGB, kernelRadiusPx);  // separable 3x3..5x5, not pure Gaussian
let detail   = srcRGB - localRef;                                   // high-frequency residual

let lumaGrad = abs(d/dx srcLuma) + abs(d/dy srcLuma);
let edgeGuard = smoothstep(edgeGuardHi, edgeGuardLo, lumaGrad);     // 1.0 in flat areas, ~0 on hard edges
let highlightWeight = mix(1.0, highlightBias, smoothstep(0.6, 0.9, srcLuma));

let lumaAtten   = effectiveDetailSoftness * edgeGuard * highlightWeight;
let chromaAtten = lumaAtten * chromaAttenScale;

let detailLuma   = dot(detail, lumaWeights);
let detailChroma = detail - detailLuma * lumaWeights;

let softened = srcRGB - (detailLuma * lumaWeights * lumaAtten)
                      - (detailChroma                  * chromaAtten);

return softened;
```

This is **not** Gaussian blur. It is local-reference high-pass attenuation
with edge guard, separated into luma and chroma channels so flat skin and
mid-tone texture lose acutance while hard structural edges (text, hair,
foliage outlines, hot highlights) are protected.

`effectiveDetailSoftness: 0` ⇒ both atten factors are `0` ⇒ output bitwise
equals `srcRGB` ⇒ render-path neutrality demanded by `strategy.md` §
Measurable Done Conditions is preserved.

## Stage insertion points (per renderer)

Goal: insert after tone compression / base grade, before edge optics +
glow + grain + creative LUT + print. Matches plan §Pipeline Placement.

### macOS native — Desktop

File: `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
Current order (`apply(...)`, lines ~60-110):

```
baseGradeV2 → filmCompressionV2 → edgeOptics → glowFamily → vignette → grain → creativeLut → printStage
```

Phase 2 inserts between `filmCompressionV2` (line 66) and `edgeOptics`
(line 68). New stage method: `applyDetailSoftnessStage(to:params:)`.
Kernel lives next to existing optical kernels (`FilmtoneGradeKernels.swift`).

### iOS export — Capacitor app

Pipeline is split across two files:

- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift`
  carries the non-optics color half (input LUT, base grade, tone
  compression, creative LUT, print) — `applyToneCompressionStage(...)` at
  L100 is the last grade-side stage today.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
  carries the optics half (edge optics, glow family, vignette, grain).

Insertion: at the end of `GradeRenderPipeline.applyToneCompressionStage`
output, before the optics half consumes it. Concretely the new stage is
called in `FilmtoneExportSession` between the grade-half output and the
optics-half input. New kernel routine in
`Export/Internal/OpticalKernels.swift` (consistent with where the other
spatial CIKernels live).

### WebGPU — shared renderer

File: `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts`
Glow pipelines: `bloomPrefilter`, `halationPrefilter`, plus depth
variants. They sample the graded RT and feed pyramids.

Phase 2 inserts a full-resolution pass between the grade output target
(today's `rtColorGraded`-equivalent in WebGPU) and the bloom / halation
prefilter sources. New shader lives at
`packages/film-lab-renderer/src/webgpu/shaders/detail-softness.frag.wgsl.ts`.
The output RT replaces the graded RT as the input bound to bloom /
halation / composite stages — composite must read the softened RT to keep
preview/export parity.

### WebGL — shared renderer

File: `packages/film-lab-renderer/src/webgl/WebGLBackend.ts`
Mirror structure. New shader:
`packages/film-lab-renderer/src/webgl/shaders/detail-softness.frag.ts`.
Same RT swap.

### Cross-renderer parity rule

Bloom / halation / diffusion / composite ALL read from the post-softness
RT when `effectiveDetailSoftness > 0`. None of them read the hard graded
RT for "punchier glow seed" — that would break the
"before glow, hard digital edges do not over-feed bloom" reasoning in the
plan and create preview/export divergence. When `effectiveDetailSoftness
== 0`, the pass either short-circuits (cheap RT-copy / skip) or runs as
identity; either way the output is bit-identical to the current pipeline.

## Uniform / kernel contract (proposal — owner-confirmed shape)

Shared shape across all four renderers, fed from the unified phase0
params:

```
struct DetailSoftnessUniforms {
  effectiveDetailSoftness : f32   // clamp(detailSoftness + sourceDetailBias, 0, effectiveMax)
  kernelRadiusPx          : f32   // derived from effective value
  chromaAttenScale        : f32   // constant for Phase 2; tunable in Phase 5
  edgeGuardLo             : f32   // luma-grad smoothstep low edge
  edgeGuardHi             : f32   // luma-grad smoothstep high edge
  highlightBias           : f32   // highlight-edge bias factor
  _pad                    : f32
}
```

Phase 2 keeps `sourceDetailBias` at `0` (the resolver lands in Phase 4).
`effectiveDetailSoftness` therefore equals the user value clamped to
`effectiveMax = 0.34`.

Derived-uniform helpers live in `packages/film-lab-core/src/`:

- New file proposed: `detail-softness.ts` exporting
  `deriveDetailSoftnessUniforms(detailSoftness, opts?) => { ... }`
  so WebGL / WebGPU / macOS / iOS all consume the same derivation. Avoids
  the recurring "renderers diverge on derived units" failure mode.

## Phase 2 decomposition (proposal — owner-confirmed pilot pick)

| Sub-stage | Scope | Deliverable | Exit gate |
|---|---|---|---|
| **2-A** (this doc) | Algorithm + insertion-point + uniform contract. **Owner review of 2-A before 2-B.** | This document, no code change. | Owner confirmed algorithm direction + pilot renderer pick + Phase 1 commit-landing posture (2026-05-12). |
| **2-B** | Pilot prototype on macOS native (owner pick). Includes shared `detail-softness.ts` derivation helper + Swift kernel + the pipeline insertion. Identity at `0` enforced by visual diff. | Compiles, identity diff = 0, A/B still set proves visible softening at `0.18` / `0.30` without quality regressions. | Visual check on the standard A/B still set. |
| **2-C** | Port to second renderer (iOS export — mechanical port from macOS, both CIImage / Metal). Cross-renderer parity test added. | Two renderers parity within tolerance. | Parity test in CI. |
| **2-D** | Port to remaining two renderers (WebGPU then WebGL). | All four renderers carry the pass. | Identity-at-0 + cross-parity green on all four. |
| **2-E** | Light visual validation against the `Phase 5: Visual Tuning Matrix` mini-set (4-6 clips, not the full matrix). Tuning Phase remains Phase 5. | Sample clips show "softer but readable" on text / hair / foliage / skin at `0.18`. | Owner sign-off. |

## Open questions blocking Phase 2-B (resolved — see Completion Log)

1. **Algorithm confirm** — Adopt the local-reference high-pass attenuation
   skeleton above? Or run a small bilateral / domain-transform spike first?
2. **Pilot renderer pick** — Plan doc §Open Questions Q4 leaves this open.
   Recommendation: **macOS native first** because (a) CIKernel/Metal iter
   cycles are fastest, (b) the desktop pipeline already has all 8 stages
   in a single Swift function so the insertion is mechanically cheap, and
   (c) the iOS export pipeline is a clean port target since both use
   CIImage / Metal-backed kernels. Alternative: WebGPU first to lock the
   parity baseline in the most-tested renderer.
3. **Phase 1 commit landing** — `feature/detail-softness-contract` head is
   still `95f1be03` (= `main`); all 27 Phase 1 files are uncommitted in
   the worktree. Phase 2-B must NOT start in this same worktree without
   either (a) Phase 1 being committed first or (b) explicit owner consent
   to bundle Phase 1 + Phase 2-B prototype into one branch.
4. **`effectiveMax` clamp** — Plan recommends `0.34`. Keep as wired
   constant in 2-B, expose as preset-tunable later? Recommended: hard-code
   in Phase 2, revisit Phase 3 when the UI control lands.
5. **Working colorspace check** — Rec.709 luma weights are used in the
   skeleton. Confirm Desktop / iOS pipelines actually grade in Rec.709
   primaries before this pass, otherwise the luma vector is wrong. Quick
   check during 2-B prototype is acceptable.

## Read-only references

- Plan: `docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md`
- `../strategy.md` (this lane)
- Phase 1 archive: `2026-05-12-phase-1-contract-neutral-plumbing.md`
  — Phase 1 contract layer (key `detailSoftness`, range `[0,1]`, default
  `0`, plumbed through every contract surface) is the contract Phase 2
  consumes. Phase 1 commit-landing status (open question 3) determines
  Phase 2-B branch base.

## Checklist (Phase 2-A only)

- [x] Plan doc algorithm direction read and condensed into a concrete
      kernel skeleton.
- [x] All four renderer insertion points located, file + line cited.
- [x] Cross-renderer uniform / kernel contract proposed.
- [x] Phase 2 decomposition drafted (2-A → 2-E).
- [x] Open questions enumerated for owner review.
- [x] Owner reviewed algorithm + pilot renderer + Phase 1 commit posture
      (2026-05-12 JST — see Completion Log).

## Verification (Phase 2-A only)

No code change ⇒ no build / test gate beyond:

```bash
bun run check:filmtone-context   # this doc declares Copy / History Impact below
git diff --check                 # whitespace hygiene on this file
```

Both gates: PASS (2026-05-12 JST, gate run during Phase 2-A close-out).

## Done Conditions (Phase 2-A only)

- Algorithm direction recorded above and acceptable to owner.
- Insertion points cited so Phase 2-B can start editing without re-survey.
- Uniform contract proposed; owner can challenge fields before they
  multiply across four renderers.
- Phase 2 decomposition lists a single deliverable per sub-stage.

## Copy / History Impact

No copy / history impact: Phase 2-A is internal architecture scoping
only. No user-visible label, help text, App Store metadata, or
implementation-history claim changes. `bun run check:filmtone-context`
must pass on this declaration.

## Stop Conditions

- Owner rejects the algorithm shape ⇒ pause, run a bilateral /
  domain-transform spike before reopening 2-B.
- Owner flags a wrong insertion point in any renderer ⇒ fix here before
  any shader / kernel work.
- Phase 1 commit landing slips and owner declines bundling ⇒ Phase 2-B
  remains paused on this branch.

## Completion Log

Closed 2026-05-12 JST on `feature/detail-softness-contract` in the
`filmtone-detail-softness` worktree. Phase 2-A deliverable is this
document.

### Owner decisions (received 2026-05-12)

| Question | Decision |
|---|---|
| Algorithm | Adopt local-reference high-pass attenuation skeleton (§Algorithm decision). **No** bilateral / domain-transform spike unless the macOS pilot fails edge/skin quality at `0.18` / `0.30`. |
| Pilot renderer | macOS native first. |
| Phase 1 commit landing | Phase 1 must be committed **separately** before Phase 2-B render source touches. Do **not** bundle Phase 1 contract plumbing with render prototype work. |
| `effectiveMax` clamp | Hard-code `0.34` in Phase 2. Revisit Phase 3 when the UI control lands. |
| Working colorspace | Verify during macOS prototype. Failure changes the luma weights, not the algorithm. |

### Verification results

| Gate | Result |
|---|---|
| `bun run check:filmtone-context` | PASS — marker present in this archive and in the new `active.md`. |
| `git diff --check` | Clean. |

### Hand-off to Phase 2-B

Phase 2-B charter lives in `../active.md`. Render source touches are
gated on Phase 1 commit landing on this branch — when `feature/detail-softness-contract`
HEAD advances past `95f1be03`, Phase 2-B can proceed per its Checklist.
