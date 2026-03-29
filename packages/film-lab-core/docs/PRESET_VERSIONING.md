# Film Lab Core — プリセット・Look ID のバージョン管理

## 単一の真実

- グレード数値: `src/presets.ts` の `PRESETS`
- 機械 ID: `src/look-ids.ts` の `lookIdForPreset()` → `look:mp:{presetKey}:{PRESET_VERSION}`

## `PRESET_VERSION` を上げるとき（破壊的変更）

次を **必ず**満たすこと。

1. **CHANGELOG**（リポジトリルートまたは `packages/film-lab-core`）に条項を書く: 何が変わり、既存の共有 URL（`?v=1&p=`）がどうなるか。
2. **Remotion / バッチ JSON** を使っている場合は、同じ条項をクライアント向けリリースノートに転載。
3. 可能なら **旧 Look ID を読みだけ残す**（非推奨マッピング）か、マイグレーションスクリプトを用意する。

## 数値だけ変える場合（非破壊）

- `presetKey` と `PRESET_VERSION` が同じなら、**同じ Look ID** のまま数値を調整できる。  
- それでも見た目は変わるため、**ヒーロープリセット**はスナップショットまたは目視で回帰する（life: プリセット品質マスター計画）。

## 新しい `PresetName` を追加するとき

1. `presets.ts` にエントリ追加。
2. `look-ids.ts` の `LOOK_ID_BY_PRESET` が自動で型により追従するか確認（`PresetName` 連動）。
3. Web の `preset-data.ts` に `PRESET_BUTTONS` を追加。
4. i18n（`messages/*.json`）にラベル・ヒントを追加（方針は life Comm ストリーム参照）。
