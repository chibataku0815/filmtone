# baseline-C — iOS canonical export reference

Phase 2 C3 truth gate. **iOS app**(`apps/capacitor-film-lab-ios/`、v1.2 public)で
canonical CIColorKernel pipeline を通した still export 結果を、ここにピン留めする。

`baseline-A` (Phase 0、JPEG capture) / `baseline-B` (Phase 0 → highlight lift PNG)
は **legacy WebGL render path** から生成されているため、iOS 移植後の
canonical CIColorKernel pipeline と stage graph が異なる。Phase 1b の
`golden-parity-macos.ts` が `macOS↔baseline-B` で 13.69dB に張り付くのはこれが原因。

baseline-C は **正本** の役割:
- iOS app の canonical CIColorKernel kernel sources を verbatim lift した macOS
  Native Desktop と直接 1:1 比較できる
- macOS↔baseline-C で **>= 35-40 dB** が出れば、native lift の math が iOS と
  identical と確認できる
- 以降の macOS 内 regression は baseline-C 固定で完結

## ディレクトリ構造

```
baseline-C/
├── reset/
│   ├── 01-highlight-sunset.png
│   ├── 02-highlight-backlit.png
│   ├── ... (10 source images)
├── iphone/
│   ├── 01-highlight-sunset.png
│   └── ... (10 images, 共通)
├── softBlue/
│   └── ... (10 images)
└── amberGlow/
    └── ... (10 images)
```

`<preset>` は `bun run generate:swift` が出す built-in preset 名 (reset / iphone /
softBlue / amberGlow) と一致。`<image>` は `source-images/<image>.png` の stem
と一致。dimensions も source に合わせる (1280x720)。

## 生成方法 (iOS Simulator manual workflow)

iOS pbxproj 編集禁止 (Native Desktop master handoff §6 invariant #1)
かつ XCUITest target 追加禁止のため、UI 自動化は使わない。代わりに iOS
Simulator で手動 export を行い、container から `xcrun simctl` で抽出する。
**hybrid 戦略** (Phase 2 C1+C2 chunk 着手時 user 確定):
- 開発 iteration は **iOS Simulator** (`xcrun simctl` で extract)。CIColorKernel
  は deterministic なので GPU family 差異は kernel 領域では極小
- baseline-C 確定は **実機 1 回のみ** (iOS v1.2 public、v1.5 Metal optics lane
  は無触)
- 以降 regression は **macOS 内完結** (baseline-C 固定)

### Simulator 手順

1. **Simulator 起動 + iOS app build**:
   ```bash
   xcrun simctl boot "iPhone 17 Pro"   # or any installed iPhone runtime
   open -a Simulator
   cd apps/capacitor-film-lab-ios && fastlane ios build_for_sim   # or open Xcode → Run on Simulator
   ```

2. **source 画像を Simulator にコピー**:
   ```bash
   for src in apps/desktop-film-lab-batch/test/golden/source-images/*.png; do
     xcrun simctl addmedia booted "$src"
   done
   ```
   `addmedia` は Photos library に画像を追加する。app 内の Photo picker から
   select 可能。

3. **iOS app で各 (image, preset) を export**:
   - Photo picker で `<image>.png` を選択
   - preset 切替 → `<preset>` を選ぶ
   - export → save to Files
   - 各 (preset, image) で 1 回繰り返し → 計 4 × 10 = 40 export

4. **container から PNG を抽出**:
   ```bash
   APP_ID=co.fores-tone.filmtone   # iOS app bundle id
   CONTAINER=$(xcrun simctl get_app_container booted "$APP_ID" data)
   # exported files が Documents/ 配下に保存されている前提
   cp "$CONTAINER/Documents/<exported-name>.png" \
      apps/desktop-film-lab-batch/test/golden/baseline-C/<preset>/<image>.png
   ```

5. **配置確認**:
   ```bash
   bun run scripts/golden-parity-ios-vs-macos.ts --preset reset
   ```

### 実機手順 (baseline-C 確定 1 回のみ)

simulator 結果が安定したら **iPhone 実機 1 回** で同じ matrix を再撮影し、最終
baseline-C として置き換える。実機⇄simulator で kernel 差異がないことを確認後、
以降の regression は macOS 内完結 (実機を tag に縛らない)。

```bash
# 実機 build (fastlane 経由、iOS pbxproj 無触の前提で)
cd apps/capacitor-film-lab-ios && fastlane ios local_release
xcrun devicectl device install app --device <UDID> ...
# AirDrop / Files App で macOS に転送、上の baseline-C/ 配下に配置
```

## 解釈

| 結果 | 意味 |
|---|---|
| **macOS↔baseline-C >= 40 dB** | native lift の math が iOS canonical と identical (期待値) |
| **macOS↔baseline-C 30-40 dB** | 軽微な差分 (色域 round-trip / pixel format alignment 等)、要調査 |
| **macOS↔baseline-C < 30 dB** | 本質的な差分。Metal CIKernel port (案 C step 3) または factory contract の bug。 |

**reset preset** (params identity) は両方 source bit-identical roundtrip になる
ので **macOS↔baseline-C ∞ dB が期待値**。これが出ない場合、CIImage(contentsOf:)
の input options (Phase 2 C1 で `applyOrientationProperty` / `toneMapHDRtoSDR` /
`sourceFallbackColorSpace` を追加) が iOS と一致していない可能性がある。
