# Film Compression V3 Active Task

Date opened: 2026-05-12 JST
Milestone: Detail Softness follow-up / Film Compression V3

## Goal

Replace the current luma-only `filmCompressionV2` behavior with a filmic
color/density compression stage that reduces digital color pressure before
`detailSoftness` and before glow / halation / diffusion.

The target is not a named stock emulation. The product target is negative-like
highlight latitude, dense saturated-light rolloff, protected skin / paper / sky
transitions, and shadows that retain color life.

## Edit Targets

- `packages/film-lab-core/src/`:
  canonical scalar V3 model, color-only baker, tests, package exports.
- `packages/film-lab-renderer/src/`:
  WebGL and WebGPU film compression shader parity.
- `packages/film-lab-swift-core/`:
  Swift scalar mirror and parity tests.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/`:
  macOS native CIKernel and call-site naming.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/`:
  iOS CIKernel and sidecar color baker.
- `apps/capacitor-film-lab-ios/scripts/swift/test-baseGrade-v2-clipping.swift`:
  compression probes updated to V3 behavior.

## Read-only References

- `docs/filmtone/detail-softness/2026-05-12-film-color-compression-research.md`
- ACES Output Transform / Chroma Compression / Reference Gamut Compression
  docs cited in the implementation plan.
- Kodak VISION3 500T technical data as product-direction reference only.

## Checklist

- [x] Add canonical V3 scalar model and unit tests.
- [x] Port V3 math to color-only baker and iOS sidecar baker.
- [x] Port V3 math to WebGL and WebGPU shaders.
- [x] Port V3 math to macOS and iOS CIKernels.
- [x] Add Swift scalar mirror and parity coverage.
- [x] Run focused and package verification.
- [x] Record Copy / History Impact and archive this active task on completion.

## Verification

- `bun run --cwd packages/film-lab-core test`
- `bun run build:core`
- `bun run build:renderer`
- `swift test --package-path packages/film-lab-swift-core`
- `bun run --cwd apps/capacitor-film-lab-ios verify:baseGrade-v2`
- `bun run verify:ios`
- `bun run verify:macos`
- `git diff --check`

## Done Conditions

- `compressionAmount == 0` is identity.
- Neutral gray stays neutral.
- Bright saturated samples compress chroma more than midtone samples.
- Skin / warm hue direction is protected from excessive desaturation.
- Shadows retain chroma and do not collapse to gray.
- V3 is present across color-only, WebGL, WebGPU, macOS native, iOS export, and
  iOS sidecar surfaces.
- Stage order remains:
  `baseGradeV2 -> filmCompressionV3 -> detailSoftness -> edgeOptics -> glowFamily -> vignette -> grain -> creativeLut -> printStage`.

## Stop Conditions

- Stop after 3 consecutive verification failures on the same gate.
- Stop if the V3 model requires new public parameters or schema changes.
- Stop if hue protection cannot be kept without reverting to per-channel RGB
  compression.
- Stop if native/Web parity requires broad unrelated renderer rewrites.

## Out of Scope

- New UI controls or public copy.
- Named Kodak / 500T / VISION3 product claims.
- Grain, optical filter, LUT recipe, or source-detail compensation retuning.
- Portfolio updates, commits, pushes, or release metadata.

## Unexpected Blockers

- `bun run --cwd packages/film-lab-core test` still has the two known
  pre-existing `ios-swift-payload.test.ts` failures around `hiddenDefaults`
  count and `CONTRACT_DEFAULT_KEY_ORDER` drift. The new V3 tests pass and the
  failures do not reference Film Compression V3.

## Verification Run

- PASS: `bun test packages/film-lab-core/src/film-compression-v3.test.ts packages/film-lab-core/src/bake-color-only.test.ts`
- PASS: `swift test --package-path packages/film-lab-swift-core`
- PASS: `bun run build:renderer`
- PASS: `bun run --cwd apps/capacitor-film-lab-ios verify:baseGrade-v2`
- PASS: `bun run build:core`
- PASS: `bun run verify:ios`
- PASS: `bun run verify:macos`
- PASS: `git diff --check`
- PASS: `bun run check:filmtone-context`
- PARTIAL BASELINE: `bun run --cwd packages/film-lab-core test` =
  240 pass / 2 fail, with the known unrelated iOS Swift payload drift.

## Copy / History Impact

No public copy impact: no user-facing copy, labels, release notes, App Store
metadata, download, privacy, account/cloud, codec/export, or version claims were
changed.

Article Opportunity: Developer note.

Change-History Opportunity: Developer note. This change is a meaningful
implementation-history point: `filmCompressionV2` luma-only shoulder became
Film Compression V3 with chroma-density rolloff before Detail Softness and
optics.
