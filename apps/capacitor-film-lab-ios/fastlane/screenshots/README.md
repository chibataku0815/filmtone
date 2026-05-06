# App Store Screenshots

Localized App Store screenshots for the `release` lane.

## Current Set

poster-v2 (v1.2 submission, 2026-04-25) is still the current screenshot set.

各 screenshot ロケール 5 枚、`iPhone 17 Pro Max-NN_<slug>.png` (1290×2796, 6.9 inch display 想定)。

| # | Slug | 内容 |
|---|------|------|
| 01 | `hero` | ヒーローカット — 「撮った素材を、作品の色へ。」/ Cinematic Teal & Orange プリセットカード |
| 02 | `preset` | プリセット選択 |
| 03 | `quick` | Quick 調整(3 軸) |
| 04 | `lut` | Creative LUT 読み込み |
| 05 | `export` | 書き出し |

正本マスター: `/Volumes/SamsungPortableSSDX5001/documents/life/docs/artifacts/2026-04-25-filmtone-ios-app-store-sample-photos/`(SVG ソース付き)

## ASC アップロード時の注意

- iPhone 6.5 インチ枠は **「6.9 インチディスプレイを使用」トグルをオン**にして 1290×2796 のまま投入(ロケールごとに独立設定)
- トグルが効かない場合は 1284×2778 にリサイズ:
  ```bash
  sips -z 2778 1284 input.png --out output.png
  ```

## Locale Scope

- Metadata locales: `ja` / `en-US` / `en-GB`
- Screenshot locales: `ja` / `en-US` (Snapfile `languages` と一致)
- `en-GB` currently reuses screenshot fallback behavior unless a dedicated UK
  screenshot set is created.

## TODO

- **Vocabulary lock 対応**: 現 poster-v2 に vocab lock 前の旧NG語が残存(2026-05-01 の vocab lock 前素材、root CLAUDE.md §6 / life commit `5ce6d55`)。次回提出時は **「動画」表記の poster-v3** を生成して差し替えること
- **UI 反映**: 現行 Liquid Glass IA + Creative Pack 01 (Stone / Urban) を反映した新ヒーロー / Look / LUT カットへ更新

## 参考

- 撮影 lane: `bundle exec fastlane ios screenshots`(現状は手動配置でも `release` lane が動く)
- ASC submission(v1.2): 2026-04-26 ed83bb0(release(filmtone-ios): bump to 1.2 (build 1) for App Store ship)
