# M2.2 — Stone Palermo-Primary Cube

Opened: 2026-05-13 JST
Lane: iOS Max Quality Look Director
Branch: `feature/ios-max-quality-look-director`
Worktree:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-ios-max-quality-look-director`

## Goal

Fix Stone still losing too much of `DJI_DLOG-M-Palermo.cube`'s character after
M2.1. The prior transform still mixed Palermo back toward identity, so the
reference LUT's color separation and density were structurally diluted. M2.2
should make Stone Palermo-primary while preserving only the black-floor safety
that prevents the earlier gray / milky failure mode.

## Product Posture

- Product quality and Palermo character are the priority.
- Do not add more runtime print / contrast / optics to compensate. The Stone
  cube itself must carry the color personality.
- Keep performance unchanged: this is a LUT asset regeneration, not a new render
  stage or per-frame analysis pass.

## Edit Targets

- `packages/film-lab-core/src/creative-pack-01-generator.ts`
- `packages/film-lab-core/src/creative-pack-01.test.ts`
- `apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-stone.cube`
- `apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json`
- `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneBuiltInCatalog.swift`
- `packages/film-lab-core/dist/*`
- This lane doc and `strategy.md` on completion.

## Implementation Plan

1. Replace the Stone display-Palermo identity-mix curve with a
   Palermo-primary output. Blend with input only in the deepest shadow band.
2. Keep `protectShadowFloor(...)` and strict black/shadow sample assertions.
3. Regenerate LUTs and manifest. Stone SHA should change; Urban / Noir should
   not.
4. Run Creative Pack tests, LUT verify, Phase 0 contract, `bun run verify:ios`,
   device build/install, `git diff --check`.

## Done Conditions

- Stone cube samples are visibly more Palermo-derived than M2.1.
- Black floor remains bounded and there is no runtime anti-haze regression.
- iPhone build is installed for owner visual review.
- Active archived and strategy completion log updated.

## Stop Conditions

- Palermo-primary output recreates gray black floor and cannot be bounded with
  shadow-only blending.
- Urban or Noir SHA changes unexpectedly.
- Verification fails three consecutive times.

## Verification

Run on 2026-05-13 JST:

```bash
bun run scripts/build-creative-luts.ts --regenerate
# Stone SHA intentionally changed to
# 0214095c88056b2b8db83de8d01eb359603a6683a33dced7e77f94ac03d6016a
# Urban / Noir SHA unchanged

bun test packages/film-lab-core/src/creative-pack-01.test.ts
# 7 pass / 0 fail / 122 expects

bun run scripts/build-creative-luts.ts --verify      # exit 0
bun run build:core                                   # exit 0
bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh
# reports: Look Director resolver tests passed
bun run verify:ios                                   # exit 0
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -configuration Debug \
  -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -derivedDataPath .build/ios-device build           # BUILD SUCCEEDED
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  .build/ios-device/Build/Products/Debug-iphoneos/App.app
# App installed: bundleID com.chibatakumi.film.lab.ios
```

Implementation notes:

- Stone cube generation is now Palermo-primary. It uses the protected
  D-Log-M-domain Palermo sample directly from low-mids upward.
- Only the deepest shadow band blends toward identity, so the black floor
  remains anchored while the Palermo density is no longer washed out by a
  whole-lattice identity mix.
- Representative Stone sample luma after M2.2:
  - black ≈ 0.0200
  - shadow ≈ 0.0689
  - gray18 ≈ 0.0952
  - mid gray ≈ 0.3900
  - high gray ≈ 0.6997
  - lantern red ≈ `[0.544, 0.0246, 0.00006]`
- No runtime Look Director handle was strengthened in this pass; performance
  posture is unchanged beyond the existing Creative LUT stage.
