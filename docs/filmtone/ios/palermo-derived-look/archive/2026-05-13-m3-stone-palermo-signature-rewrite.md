# M3 Stone Palermo Signature Rewrite

Article foundation: docs/filmtone/articles/2026-05-13-palermo-derived-look/

## Goal

Use the Palermo PowerGrade analysis to strengthen Stone's film density and
color separation without importing or cloning vendor assets.

## Read-Only References

- docs/filmtone/handoff/2026-05-13-palermo-powergrade-analysis.md

## Edit Targets

- packages/film-lab-core/src/creative-pack-01-generator.ts
- packages/film-lab-core/src/creative-pack-01.ts
- packages/film-lab-core/src/creative-pack-01.test.ts
- scripts/build-creative-luts.ts generated outputs / manifest
- apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneBuiltInCatalog.swift

## Checklist

- [x] Add original Stone signature shaping from Palermo measured behavior
- [x] Regenerate Creative Pack 01 cubes and manifest
- [x] Update Swift catalog SHA pins
- [x] Lock behavior with focused tests
- [x] Run minimum verification
- [x] Build and install on owner iPhone for visual review

## Done Conditions

- Stone keeps protected blacks while gaining stronger skin density and sky/cyan
  separation.
- Generated cube is not byte-identical to vendor Palermo assets.
- `bun run scripts/build-creative-luts.ts --verify`, focused creative-pack test,
  Phase 0 contract, `bun run verify:ios`, and `git diff --check` pass.

## Stop Conditions

- Done conditions met.
- 3 consecutive verification failures on the same issue.
- The source analysis proves insufficient to improve the Look without copying
  vendor transforms.

## Out Of Scope

- Shipping vendor `.drx`, `.cube`, or preview images.
- Renaming Stone/Urban/Noir.
- Broad UI/QA work before the core image result is credible.

## Implementation Capture

- 動機:
  Palermo analysis showed the useful product signal is the measured LUT and
  stackable behavior, not the opaque DRX body.

- 解決したいこと:
  Current Stone is safe but still thinner than the Palermo reference in skin
  density and sky/cyan separation.

- 解決方法:
  `applyStoneDisplayPalermoTransform` の display-domain Palermo sample 後に
  `applyStonePalermoSignature` を追加した。中身は neutral blue suppression、
  warm-skin density、cyan/sky red suppression、green density を入力色相と
  luma でゲートするオリジナル pass。vendor LUT の endpoint をコピーせず、
  Stone の `sourceCubeTransform` は `filmtone-stone-dlogm-palermo-display-v2`
  に上げ、cube / manifest / Swift SHA pin / focused test を更新した。
  Owner review で「色味の質感は上がったが光学とグローが少し弱い」と
  確認されたため、追加で Stone の局所光学 baseline を上げた:
  `bloomStrength 0.10 -> 0.135`, `bloomRadius 0.52 -> 0.60`,
  `halationIntensity 0.045 -> 0.065`, `rgbShift 0.0016 -> 0.0021`,
  `lensSoftness 0.070 -> 0.082`。`bloomThreshold`, `fade`, `diffusion`
  は据え置き、Look Director の Stone practical-light bloom / halation /
  rgbShift gain だけを上げた。

- ブロッカー:
  新規 worktree には CocoaPods の `Pods-App.debug.xcconfig` が無く、最初の
  `bun run verify:ios` が build 前に失敗した。`pod install` で worktree local
  の Pods を生成して再実行した。

- 驚き / 違和感:
  M2.2 Stone は白天井と黒床はすでに悪くなかった。薄さの主因は luma ではなく、
  肌の blue separation と空/cyan の red suppression が Palermo 解析値より弱いことだった。

## Verification

- `bun run scripts/build-creative-luts.ts --regenerate`: pass
- `bun test packages/film-lab-core/src/creative-pack-01.test.ts`: 8 pass
- `bun run scripts/build-creative-luts.ts --verify`: pass
- `bun run build:core`: pass
- `bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh`: pass
- `bun run verify:ios`: pass after `pod install` in the new worktree
- `git diff --check`: pass
- `xcodebuild -workspace ios/App/App.xcworkspace -scheme App -configuration Debug -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' -derivedDataPath .build/ios-device build`: **BUILD SUCCEEDED**
- `xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 .build/ios-device/Build/Products/Debug-iphoneos/App.app`: pass
- After Stone optics lift:
  - `bun test packages/film-lab-core/src/creative-pack-01.test.ts`: 9 pass
  - `bun run scripts/build-creative-luts.ts --verify`: pass
  - `bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh`: pass
  - `bun run build:core`: pass
  - `bun run verify:ios`: pass
  - `git diff --check`: pass
  - device `xcodebuild ... -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9'`: **BUILD SUCCEEDED**
  - device install: pass

## Owner Visual Gate

Installed on iPhone 17 Pro `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9` for visual
review. Primary check: same source, None vs Stone. Confirm stronger skin
density and cyan/sky separation without black lift or global haze. Second
install includes the recommended Stone-only localized optics/glow lift.
