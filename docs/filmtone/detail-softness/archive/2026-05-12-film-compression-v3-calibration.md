# Film Compression V3 Product Calibration

Date opened: 2026-05-12 JST
Milestone: Detail Softness follow-up / Film Compression V3 product calibration

## Goal

Judge whether the current Film Compression V3 implementation actually reaches
the product target, and tune internal constants / curve shape if the visual
evidence says so. Public params (`compressionAmount`, `compressionRange`) stay
unchanged.

Target qualities (from the calibration prompt):

- Highlights hold density before turning white.
- Red / blue / cyan practical lights have rounded cores, not digital
  fluorescent edges.
- Skin / warm hues keep hue and density; no chalky pale-orange skin.
- White paper, sky, and wall gradients stay natural.
- Shadows preserve color and tone instead of becoming gray.
- Stone / Urban / Noir Look outputs remain dense without clipping or dulling.

## Edit Targets (only if tuning is needed)

- `packages/film-lab-core/src/film-compression-v3.ts` — scalar source of truth
- `packages/film-lab-core/src/film-compression-v3.test.ts` — invariants
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneFilmCompressionV3.swift`
- `packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/FilmCompressionV3Tests.swift`
- `packages/film-lab-renderer/src/webgl/shaders/filmlab.frag.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/filmlab.frag.wgsl.ts`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`

Sidecar (`FilmtoneExportSidecarBuilder.swift`) delegates to
`FilmtoneFilmCompressionV3.apply` and therefore inherits any Swift mirror tune
automatically — no scalar parity edits needed unless the model shape itself
changes.

## Read-only References

- `docs/filmtone/detail-softness/2026-05-12-film-color-compression-research.md`
- `docs/filmtone/detail-softness/archive/2026-05-12-film-compression-v3.md`

## Method

Pre-flight: there is no automated GPU pixel harness in this repo, and image
fixtures live behind native pipelines we can't run from CLI cheaply. The fastest
feedback loop is **scalar-mode synthetic probes**: feed representative cells
(skin, paper, sky, foliage, red/blue/cyan practicals, deep shadows) through the
TS scalar reference at `amount=0.85, range=0.55` (the Stone / Urban operating
point) and inspect:

- Δluma (should rolloff highlights, not crush)
- chroma-ratio out/in (should compress saturated highlights more than mids,
  shadows should keep ≥ ~90% chroma)
- hue cosine drift (should stay > 0.999 — the existing test bar)
- channel max after clamp (should round before 1.0 on red/cyan/blue cores)

Decide tuning from those numbers, then propagate verbatim to the 4 shader/CIKernel
ports because they all already share identical constants with the TS scalar.

## Checklist

- [x] Snapshot current V3 scalar behavior on the probe set.
- [x] Decide accept-as-is vs. tune. **Decided: tune (one-sided shoulder).**
- [x] Edit TS scalar (`shoulderY = min(luma, mix(luma, sigmoid, amt))`),
      mirror to Swift, WGSL, WebGL, iOS CIKernel, macOS CIKernel.
- [x] Tighten the existing `shadows keep chroma` test into a strict
      `shadows are identity-preserving` invariant (out == in for luma ≤ ~0.13
      where shadowRelease gates compression to zero). Update Swift
      parity-fixture expected values for the shadow row and the red-practical
      row (red-practical landed at {0.908, 0.075, 0.066} instead of
      {0.945, 0.098, 0.089} after lumaScale flattens to 1.0 below midtone).
- [x] Run core test, build:core, build:renderer, swift test,
      verify:baseGrade-v2, verify:ios, verify:macos, git diff --check.

## Verification (minimum)

```bash
bun run --cwd packages/film-lab-core test
bun run build:core
bun run build:renderer
swift test --package-path packages/film-lab-swift-core
bun run --cwd apps/capacitor-film-lab-ios verify:baseGrade-v2
git diff --check
```

If native shader code changes materially:

```bash
bun run verify:ios
bun run verify:macos
```

## Done Conditions

- V3 either accepted as visually good per the probe analysis, or tuned
  internally with mirrored math across the 4 GPU/CIKernel surfaces + Swift
  scalar mirror.
- `compressionAmount == 0` stays identity.
- Hue cosine drift stays > 0.999 across representative hues.
- Shadow chroma retention stays ≥ ~90%.
- Core tests pass; relevant native gates pass.

## Stop Conditions

- 3 consecutive verification failures on the same gate.
- Tuning requires new public parameters or schema changes (push to follow-up).
- Per-channel RGB compression appears as the only way to fix a probe →
  pause, do not regress to V2-pre.

## Out of Scope

- New UI controls or public copy.
- Public parameter renames, additions, payload key changes.
- Kodak / 500T / VISION3 product-name claims.
- Large GPU parity harness; portfolio updates; release work.
- Detail Softness re-tuning.

## Findings (scalar probe)

Probed at 4 operating points (Stone-iOS a=0.28 r=0.5, Urban-iOS a=0.40 r=0.5,
Noir-pack a=0.38 r=0.56, stress a=0.85 r=0.55) against 15 representative cells:
skin (mid / highlight / window-glow), white-paper, sky (mid / highlight),
wall-gradient, foliage, hair-shadow, red / blue / cyan / magenta practicals,
cool / warm deep shadows.

**Single product-quality regression found: shadow lift.**

The pre-tune sigmoid was a contrast bender centered at 0.5, not a film
shoulder. Below midtone, `sigmoid > luma`, so `mix(luma, sigmoid, amt) > luma`,
giving `lumaScale > 1` and *raising* the entire RGB triple. Numeric evidence
from the pre-tune probe:

| Cell           | luma in | luma out (Stone) | chroma % out (Stone) | luma out (stress) | chroma % (stress) |
|----------------|---------|------------------|----------------------|--------------------|--------------------|
| hair-shadow    | 0.084   | 0.105 (+25%)     | 125.3%               | 0.153 (+82%)       | 183.4%             |
| shadow-cool    | 0.059   | 0.083 (+41%)     | 141.8%               | 0.138 (+134%)      | 236.1%             |
| shadow-warm    | 0.075   | 0.097 (+29%)     | 129.7%               | 0.148 (+97%)       | 197.5%             |

Hue cosine stayed > 0.9998 throughout (the chroma vector kept its direction
because the lift was uniform across channels), but brightness and chroma
*magnitude* were both pulled up — the opposite of the filmic density target
"shadows preserve color and tone".

Other product-quality cells were within acceptable behavior at production
operating points (Stone / Urban / Noir):

- Skin mid: identity (luma 0.480 → 0.480, chroma 100%, no compression
  applied — below highlight knee).
- Skin highlight: 95-94% chroma retention, hue cos = 1.000.
- White paper: −2.7% luma drop at a=0.28, −3.7% at a=0.40. V2-inherited
  centered-sigmoid behavior; perceptual threshold but not catastrophic.
- Sky highlight: 88-92% chroma retention, hue preserved.
- Red / blue / cyan practicals: chroma compressed to 76-88%, hue preserved.
  Max channel pegs to 1.0 at production amounts because the chroma-magnitude
  guard reduces but doesn't bring the high channel below 1 (covered in
  Follow-up below).

## Tune Applied

One-sided shoulder in TS scalar + 4 GPU/CIKernel surfaces + Swift mirror:

```ts
// before
const shoulderY = mix(y, sigmoid, amt);

// after
const shoulderY = Math.min(y, mix(y, sigmoid, amt));
```

When `sigmoid > luma` (anywhere below the sigmoid's 50% crossover ≈ luma 0.5),
`min(luma, mix) = luma` and `lumaScale = 1` — perfect identity. Highlight
behavior unchanged because there `sigmoid < luma` and the min picks the
compressed value.

Post-tune scalar probe (same cells):

| Cell           | luma in | luma out (Stone) | chroma % (Stone) | luma out (stress) | chroma % (stress) |
|----------------|---------|------------------|------------------|--------------------|--------------------|
| hair-shadow    | 0.084   | 0.084 (identity) | 100.0%           | 0.084 (identity)   | 100.0%             |
| shadow-cool    | 0.059   | 0.059 (identity) | 100.0%           | 0.059 (identity)   | 100.0%             |
| shadow-warm    | 0.075   | 0.075 (identity) | 100.0%           | 0.075 (identity)   | 100.0%             |
| skin-mid       | 0.480   | 0.480            | 100.0%           | 0.480              | 100.0%             |
| skin-highlight | 0.767   | 0.760 (−1%)      | 95.5%            | 0.742 (−3%)        | 86.6%              |
| red-practical  | 0.340   | 0.328            | 88.5%            | 0.340              | 82.6%              |
| cyan-practical | 0.776   | 0.766            | 81.6%            | 0.750              | 52.5%              |

All highlight cells behave the same; all shadow cells now identity-preserve.

## Follow-up (not in scope for this slice)

- **Highlight density landing**: at production amounts, saturated practical
  cores still clip a single channel to 1.0 (red {1.10, 0.14, 0.08} → out.r
  pegs to 1.0). The chroma-magnitude compression does its job but it doesn't
  guarantee any specific channel stays below 1. A future calibration could
  add a hue-preserving soft cap (chroma uniformly attenuated when any channel
  exceeds 0.95) or a per-channel knee shoulder. Both are meaningful new math
  and need visual A/B to validate the trade-off with skin highlight chalkiness;
  out of scope for "constants / curve shape" tuning.
- **White paper at production amounts** (−3 to −4% luma at a=0.40): inherited
  V2 centered-sigmoid behavior. At perceptual threshold; only worth revisiting
  if the highlight-density follow-up replaces the centered sigmoid with a
  proper shoulder.

## Copy / History Impact

No copy/history impact: no user-facing copy, label, release note, App Store
metadata, fastlane string, payload key, schema field, or implementation-history
source was changed. Public params `compressionAmount` / `compressionRange`
behavior unchanged at `amount = 0`, unchanged at the saturated highlight cells,
and improved (identity-preserving) at shadows.

Article Opportunity: Developer note. Worth a short paragraph in the
implementation-history thread next to the V3 entry — "the original V3 shoulder
was a centered sigmoid that lifted shadows; the calibration pass made the
shoulder one-sided so deep blacks stay put and only highlights roll off".

Change-History Opportunity: Yes. This is a small but meaningful product
correction inside V3; the V3 chroma-compression machinery is unchanged but
the luma shape is now genuinely a film-shoulder, not a contrast bender.

## Verification Run

- PASS: `bun run --cwd packages/film-lab-core test` — 242 / 0
- PASS: `bun run build:core`
- PASS: `bun run build:renderer`
- PASS: `swift test --package-path packages/film-lab-swift-core` — 68 / 0
- PASS: `bun run --cwd apps/capacitor-film-lab-ios verify:baseGrade-v2` —
  all 9 probes green
- PASS: `bun run verify:ios` — all source-profile / Macbeth ΔE2000 / sidecar /
  look×veil energy merge sub-tests green
- PASS: `bun run verify:macos` — `** BUILD SUCCEEDED **`
- PASS: `git diff --check` — no whitespace errors
