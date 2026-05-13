# M2.1 — Stone Palermo Character Restore

Opened: 2026-05-13 JST
Lane: iOS Max Quality Look Director
Branch: `feature/ios-max-quality-look-director`
Worktree:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-ios-max-quality-look-director`

## Goal

Restore more of `DJI_DLOG-M-Palermo.cube`'s visible Stone character after owner
review found M2 technically stable but too diluted. Keep the M1C anti-haze
contract intact: no gray black floor, no milky veil, no broad night diffusion,
and no high-key sky glow.

## Product Posture

- Product quality is the priority. This is a color-character correction, not a
  conservative cleanup.
- Do not solve Palermo thinness by adding more runtime print / contrast /
  optics. The issue is that the Stone cube itself is mixed too weakly toward
  Palermo.
- Keep performance unchanged: cube generation changes cost nothing per-frame
  beyond the existing Creative LUT stage.

## Edit Targets

- `packages/film-lab-core/src/creative-pack-01-generator.ts`
- `packages/film-lab-core/src/creative-pack-01.test.ts`
- `apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-stone.cube`
- `apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json`
- `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneBuiltInCatalog.swift`
- This lane doc and `strategy.md` on completion.

## Implementation Plan

1. Increase Stone display-Palermo transform strength in mid/high regions and
   reduce the saturated-color penalty that was muting red practicals.
2. Keep `protectShadowFloor(...)` and black / shadow sample bounds strict.
3. Regenerate Creative Pack 01 LUTs and manifest.
4. Update Stone cube tests to assert stronger Palermo character while retaining
   black-floor and skin/highlight bounds.
5. Run focused pack tests, creative LUT verify, phase0 contract, `bun run
   verify:ios`, `git diff --check`, then install to the paired iPhone.

## Done Conditions

- Stone cube SHA is intentionally updated and pinned in the iOS catalog.
- Tests prove Stone is more Palermo-derived without lifting black/shadow sample
  luma beyond safe bounds.
- No Look Director anti-haze invariant is weakened.
- Verification gates pass.
- Debug iOS build is installed on the paired iPhone.

## Stop Conditions

- Stronger Palermo mix lifts black/shadow sample bounds and cannot be corrected
  without undoing the character restore.
- Cube regeneration unexpectedly changes Urban / Noir bytes.
- Verification fails three consecutive times.

## Verification

Run on 2026-05-13 JST:

```bash
bun run scripts/build-creative-luts.ts --regenerate
# Stone SHA intentionally changed to
# 0122ff6731439dcfd24a21a1b5440499ca897909aaeafea049359b61784a5bdd
# Urban / Noir SHA unchanged

bun test packages/film-lab-core/src/creative-pack-01.test.ts  # 7 pass / 0 fail
bun run scripts/build-creative-luts.ts --verify               # exit 0
bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh
# reports: Look Director resolver tests passed
bun run verify:ios                                            # exit 0
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -configuration Debug \
  -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -derivedDataPath .build/ios-device build                    # BUILD SUCCEEDED
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  .build/ios-device/Build/Products/Debug-iphoneos/App.app      # exit 0
bun run build:core                                             # exit 0
```

Implementation notes:

- Stone display-Palermo transform now mixes Palermo more strongly in
  mid/high regions and applies a smaller saturated-color penalty, so lantern /
  practical color is less diluted.
- Black/shadow sample bounds remain protected:
  - black luma ≈ 0.0215
  - shadow luma ≈ 0.0745
  - gray18 luma ≈ 0.1376
- No runtime Look Director handle was strengthened in this pass; performance
  posture is unchanged beyond the existing Creative LUT stage.

## Copy / History Impact

No public copy change. Article Opportunity remains Developer note unless owner
later confirms a visibly stronger before/after suitable for a short post.
