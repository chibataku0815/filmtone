# Film Compression V3 Highlight Density Strong Probe

## Goal

Make the remaining high-saturation highlight landing problem visible and useful
for product judgment. Add a strong hue-preserving soft landing inside Film
Compression V3 so practical red/blue/cyan/magenta cores round off instead of
pinning to 1.0.

## Edit Targets

- `packages/film-lab-core/src/film-compression-v3.ts`
- `packages/film-lab-core/src/film-compression-v3.test.ts`
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneFilmCompressionV3.swift`
- `packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/FilmCompressionV3Tests.swift`
- `packages/film-lab-renderer/src/webgl/shaders/filmlab.frag.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/filmlab.frag.wgsl.ts`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`

## Checklist

- [x] Add strong hue-preserving highlight density landing to TS SSOT
- [x] Lock practical-light behavior with focused scalar tests
- [x] Propagate identical math to Swift, WebGL, WGSL, iOS CIKernel, macOS CIKernel
- [x] Run focused verification

## Verification

- PASS: `bun test packages/film-lab-core/src/film-compression-v3.test.ts` =
  9 pass / 0 fail
- PASS: `bun run --cwd packages/film-lab-core test` = 243 pass / 0 fail
- PASS: `bun run build:core`
- PASS: `bun run build:renderer`
- PASS: `swift test --package-path packages/film-lab-swift-core` =
  68 pass / 0 fail
- PASS: `bun run --cwd apps/capacitor-film-lab-ios verify:baseGrade-v2` =
  9 probes green
- PASS: `bun run verify:ios`
- PASS: `bun run verify:macos`
- PASS: `git diff --check`

## Result

Added a strong hue-preserving highlight density landing after the existing V3
chroma compression. The landing maps high-saturation practical-light cores above
the 0.78 knee through a soft max target and scales only the chroma vector around
`shoulderY`, so Rec.709 luma and hue direction stay structurally stable while
red / blue / cyan / magenta cores visibly round off.

Focused scalar behavior now requires saturated practical cores to land below
0.92 at the probe setting while preserving hue direction (`cos > 0.999`) and
reducing chroma magnitude. Shadow identity remains unchanged.

## Copy / History Impact

No public copy impact: no user-facing strings, feature names, UI labels, release
notes, App Store metadata, download, privacy, account/cloud, codec/export, or
version claims changed.

Article Opportunity: Developer note only if the larger V3 color-compression
work becomes an implementation article. No standalone article.

Change-History Opportunity: Yes. This records why V3 moved from luma/chroma
compression alone to a hue-preserving highlight landing stage for practical
lights.

## Stop Conditions

Stop when Done is met, unexpected cross-surface drift appears, or the same
verification class fails 3 times.

## Out Of Scope

- UI/schema/payload key changes
- public naming or copy
- broad parity harness work
- release documentation cleanup
