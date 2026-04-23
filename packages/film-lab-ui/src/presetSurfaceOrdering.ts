/**
 * @file プリセット一覧を「Utility（Neutral）・Film Stock・Look」に並べ替える小さなヘルパー。
 * @description
 * 概要: `film-lab-core` の `PRESET_BUTTONS` は正本ですが、UI はここで **カテゴリ順を固定** して並べます。
 * 主な仕様:
 * - 同じカテゴリの中では、`PRESET_BUTTONS` に書いてある元の順番をそのまま使います。
 * - カテゴリの優先順位は `utility` → `filmStock` → `look` です。
 * 制限事項:
 * - ラベル文言やプリセットの追加・削除は `film-lab-core` 側で行い、このファイルは並べ替えだけを担当します。
 * - Quick / Pro の大きなパネル再設計（life#95）はここではしません。
 */
import { PRESET_BUTTONS } from "film-lab-core";

/**
 * 1 件分のプリセットボタン行（core の `PRESET_BUTTONS` の要素型）。
 */
export type PresetButtonRow = (typeof PRESET_BUTTONS)[number];

/**
 * カテゴリの並び順を数字にします。数字が小さいほど上に来ます。
 */
const presetCategoryRank: Record<PresetButtonRow["category"], number> = {
  utility: 0,
  filmStock: 1,
  look: 2,
};

/**
 * Web / Desktop 共通のプリセット surface 用に、`PRESET_BUTTONS` を並べ替えたコピーを返します。
 *
 * @param presetButtonRows - 並べ替え元（通常は `PRESET_BUTTONS` そのもの）
 * @returns カテゴリ順→同一カテゴリ内は元配列順の新しい配列
 */
export function orderPresetButtonsForSurface(
  presetButtonRows: readonly PresetButtonRow[],
): PresetButtonRow[] {
  return presetButtonRows
    .map((presetButtonRow, sourceIndex) => ({ presetButtonRow, sourceIndex }))
    .sort((a, b) => {
      const rankDiff =
        presetCategoryRank[a.presetButtonRow.category] -
        presetCategoryRank[b.presetButtonRow.category];
      if (rankDiff !== 0) {
        return rankDiff;
      }
      return a.sourceIndex - b.sourceIndex;
    })
    .map((entry) => entry.presetButtonRow);
}

/**
 * 検索で絞り込んだあとも、同じ並びルールをかけます。
 *
 * @param presetButtonRows - 通常は `PRESET_BUTTONS` 全体
 * @param predicate - 検索クエリなどに合う行だけ true にする関数
 */
export function filterPresetRowsForSearch(
  presetButtonRows: readonly PresetButtonRow[],
  predicate: (row: PresetButtonRow) => boolean,
): PresetButtonRow[] {
  return orderPresetButtonsForSurface(presetButtonRows.filter(predicate));
}
