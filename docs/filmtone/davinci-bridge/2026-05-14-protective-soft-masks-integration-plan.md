# Protective Soft Masks integration plan

Status: Integration planning, no runtime connection yet
Created: 2026-05-14 PM JST
Regenerated: 2026-05-15 JST

## Purpose

`packages/film-lab-core/src/protective-soft-masks/` に isolated CPU reference と
synthetic tests を置く前提で、これを Imported Grade runtime /
pre-LUT Log protection 方針に **どう結合するか**を安全に決める。

この doc は接続順、責務境界、quality gate、runtime/UI に入れる条件を定義する。

重要: この doc は runtime 接続そのものではない。まず real-frame validation を通し、
絵の改善が確認できたものだけを段階的に接続する。

## Expected Assets

Isolated modules:

```text
packages/film-lab-core/src/protective-soft-masks/
  types.ts
  math.ts
  summary.ts
  black-anchor.ts
  saturation-tamer.ts
  highlight-protect.ts
  shadow-protect.ts
  synthetic-harness.ts
  control-mapping.ts
  presets.ts
```

Tests:

```text
packages/film-lab-core/src/black-anchor-soft-mask.test.ts
packages/film-lab-core/src/protective-soft-masks/summary.test.ts
packages/film-lab-core/src/protective-soft-masks/saturation-tamer.test.ts
packages/film-lab-core/src/protective-soft-masks/highlight-protect.test.ts
packages/film-lab-core/src/protective-soft-masks/shadow-protect.test.ts
packages/film-lab-core/src/protective-soft-masks/synthetic-harness.test.ts
packages/film-lab-core/src/protective-soft-masks/control-mapping.test.ts
packages/film-lab-core/src/protective-soft-masks/presets.test.ts
```

Reference verification from the original isolated pass:

```text
71 pass / 273 expects
```

Boundary:

- not exported from `packages/film-lab-core/src/index.ts`
- not included in `dist/*`
- not connected to `ImportedGradeLook`
- not connected to macOS/iOS runtime
- not connected to shader / Metal / WebGPU
- not user-visible

## Product Mapping

The isolated modules map to product problems:

| Product problem | Module | Direction | Runtime intent |
|---|---|---|---|
| 黒浮き | `black-anchor.ts` | lower selected shadows | pre-LUT shadow anchoring |
| 彩度暴れ | `saturation-tamer.ts` | reduce chroma / saturation risk | pre-LUT gamut-ish compression |
| ハイライト破綻 | `highlight-protect.ts` | reduce bright chroma + roll off luma | pre-LUT highlight safety |
| 黒潰れ | `shadow-protect.ts` | lift recoverable shadows | pre-LUT toe recovery |

`synthetic-harness.ts` is not a product feature. It is a cheap regression guard.

`control-mapping.ts` is not UI. It defines the safe Basic control contract:

```text
Shadow Balance       -100..+100
Saturation Protect      0..100
Highlight Protect       0..100
```

Mapping:

- negative `Shadow Balance` -> `BlackAnchorOptions.amount`
- positive `Shadow Balance` -> `ShadowProtectOptions.amount`
- `Saturation Protect` -> `SaturationTamerOptions.amount`
- `Highlight Protect` -> `HighlightProtectOptions.amount`

This makes Black Anchor and Shadow Protect mutually exclusive at the basic control layer.

## Integration Principle

Do not connect all modules to runtime at once.

The first runtime integration should be narrow and visually motivated:

```text
Black Anchor only
```

Reason:

- current product pain is black float
- Black Anchor is the most direct response
- it has the lowest semantic ambiguity
- if this fails visually, adding more protections will hide the failure instead of solving it

After Black Anchor passes real-frame validation, add:

1. Saturation Tamer
2. Highlight Protect
3. Shadow Protect

Shadow Protect should remain disabled by default until a real black-crush fixture exists,
because it is the opposite of Black Anchor.

## Proposed Evaluation Order

For future runtime integration:

```text
input transform / working RGB
  -> Shadow Balance direction
       negative: Black Anchor
       positive: Shadow Protect
       zero: no shadow-direction protection
  -> Saturation Tamer
  -> Highlight Protect
  -> base look cube
  -> existing post-LUT intensity / output trims
```

Why this order:

- shadow placement happens before broad chroma decisions
- saturation compression reduces extreme chroma before highlight protection evaluates bright chroma
- highlight protection is last among protections so bright saturated leftovers are caught
- all of this remains pre-LUT, preserving the original thesis

Do not apply Black Anchor and Shadow Protect sequentially in the basic path.

## DB-M6 Quality Gate

DB-M6 should not start with shader work. It should start with real-frame evaluation.

Minimum real-frame fixture set:

| Fixture | Purpose | Required judgment |
|---|---|---|
| `black-float-log` | lifted / milky blacks after LUT | Black Anchor anchors blacks without crushing detail |
| `sat-runaway-log` | over-saturated color after LUT | Saturation Tamer reduces harsh chroma without gray wash |
| `highlight-break-log` | bright saturated highlight breakage | Highlight Protect reduces clipping feel without dirty whites |
| `black-crush-log` | shadow detail lost after LUT | Shadow Protect recovers detail without making blacks milky |

Optional:

| Fixture | Purpose |
|---|---|
| `skin-shift-log` | future Skin Protect research only; do not build correction without real samples |

For each fixture, compare:

```text
base cube only
base cube + subtle
base cube + standard
base cube + strong
```

Use `presets.ts` strengths as stable comparison points, not final tuning.

## Acceptance Criteria

Black Anchor:

- black floor appears more anchored
- midtones / skin are not visibly pulled down
- shadow detail remains visible
- noise does not become more prominent
- no obvious hue shift

Saturation Tamer:

- harsh chroma is reduced
- average luma should remain visually stable
- image does not become gray / dead
- skin-like warm colors are not over-muted in non-target frames

Highlight Protect:

- bright saturated areas feel less clipped / harsh
- neutral whites remain clean
- highlight color is not dirtied
- no global exposure loss

Shadow Protect:

- recoverable detail returns
- encoded black / noise floor is not lifted aggressively
- black level does not become milky
- should be mutually exclusive with Black Anchor in basic controls

## Metric Policy

Synthetic metrics are regression guards, not final quality judges.

Use metrics to catch obvious regressions:

- Black Anchor: `averageLumaDelta < 0` on shadow ramp
- Shadow Protect: `averageLumaDelta > 0` on shadow ramp
- Saturation Tamer: `averageChromaDelta < 0`, `averageLumaDelta ~= 0`
- Highlight Protect: `averageLumaDelta < 0`, `averageChromaDelta < 0`
- neutral midtones: affected count remains 0 for shadow-only protections

Summary metrics should include:

- luma:
  - `averageInputLuma`
  - `averageOutputLuma`
  - `averageLumaDelta`
  - min / max input-output luma
- chroma:
  - `averageInputChroma`
  - `averageOutputChroma`
  - `averageChromaDelta`
  - max input-output chroma
- saturation risk:
  - `averageInputSaturationRisk`
  - `averageOutputSaturationRisk`
  - `averageSaturationRiskDelta`
  - max input-output saturation risk
- masks:
  - `averageMask`
  - `affectedAverageMask`
  - `maxMask`

Use human visual review for final acceptance.

## Control Contract

Basic product controls should stay compact:

```text
Shadow Balance       -100..+100
Saturation Protect      0..100
Highlight Protect       0..100
```

`Shadow Balance` is intentionally bipolar:

- negative values mean black-float correction via Black Anchor
- positive values mean black-crush correction via Shadow Protect
- zero means no shadow-direction protection

This prevents Black Anchor and Shadow Protect from fighting in the Basic UI.

Advanced overrides may provide thresholds / softness / floors, but Basic controls own the final
`amount`.

## Tuning Profiles

Use three internal tuning profiles:

```text
subtle
standard
strong
```

Profile responsibilities:

- provide stable comparison points for synthetic and real-frame evaluation
- grow monotonically on synthetic ramps
- remain internal until real-frame review proves the naming / strength is useful

Expected monotonic behavior:

- Black Anchor: `subtle < standard < strong` makes `averageLumaDelta` more negative
- Shadow Protect: `subtle < standard < strong` makes `averageLumaDelta` more positive
- Saturation Tamer: `subtle < standard < strong` makes `averageChromaDelta` more negative
- Highlight Protect: `subtle < standard < strong` makes luma / chroma deltas more negative

## Connection Stages

### PSM-I0 — Isolated Reference

Reference state.

- CPU reference modules exist
- synthetic harness exists
- control mapping exists
- presets exist
- no product integration

### PSM-I1 — Real-Frame Harness

Add a non-user-facing evaluation path that can run fixture pixels through one protection and
export numeric summaries / before-after stills.

No runtime UI.
No schema change.
No shader change.

### PSM-I2 — Black Anchor Runtime Spike

Connect only Black Anchor before base cube in macOS runtime.

Constraints:

- hidden debug flag or developer-only path
- default off
- one frame fixture must pass visual review before user-facing exposure

### PSM-I3 — Basic Control Contract

Expose Basic controls in schema / UI only after Black Anchor runtime spike passes:

```text
Shadow Balance
Saturation Protect
Highlight Protect
```

At this stage, `Shadow Balance` can start with only negative values enabled if black float remains
the only validated path.

### PSM-I4 — Saturation / Highlight Runtime

Add Saturation Tamer and Highlight Protect after fixture validation.

Do not add Skin Protect here.

### PSM-I5 — Shadow Protect Runtime

Add Shadow Protect only after a black-crush fixture demonstrates need.

## Non-Goals Before Runtime Connection

- Skin Protect correction
- manual masks / brush / window UI
- ML segmentation
- Power Window parity
- Resolve qualifier parity
- exporting protection settings back to `.drx`
- public UI copy

## Open Decisions

1. Should DB-M6 be a pure quality harness milestone, or include Black Anchor runtime spike?
2. Should `Shadow Balance` ship as one bipolar control, or should product UI say `Black Anchor`
   first and hide Shadow Protect until later?
3. Should presets be user-facing names, or remain internal tuning profiles?
4. What working RGB space should shader integration use before base cube?
5. What real fixture format should DB-M6 standardize: still PNG/TIFF, sampled JSON pixels, or
   a small local image folder ignored by git?

## Decision For Now

Do not connect these modules to product runtime yet.

Next valuable task:

```text
DB-M6 real-frame quality harness plan / fixtures
```

Only after the black-float fixture passes should Black Anchor move into runtime.
