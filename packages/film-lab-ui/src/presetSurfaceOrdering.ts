/**
 * @file Base Look 一覧を「Utility（Neutral）・Film Stock・Look」に並べ替える小さなヘルパー。
 * @description
 * 概要: `film-lab-core` の `BASE_LOOK_BUTTONS` は正本ですが、UI はここで **カテゴリ順を固定** して並べます。
 * 主な仕様:
 * - 同じカテゴリの中では、`BASE_LOOK_BUTTONS` に書いてある元の順番をそのまま使います。
 * - カテゴリの優先順位は `utility` → `filmStock` → `look` です。
 * 制限事項:
 * - ラベル文言や Base Look の追加・削除は `film-lab-core` 側で行い、このファイルは並べ替えだけを担当します。
 * - Quick / Pro の大きなパネル再設計（life#95）はここではしません。
 */
import { BASE_LOOK_BUTTONS } from "film-lab-core";

/**
 * 1 件分の Base Look ボタン行（core の `BASE_LOOK_BUTTONS` の要素型）。
 */
export type BaseLookButtonRow = (typeof BASE_LOOK_BUTTONS)[number];

/** @deprecated Use {@link BaseLookButtonRow}. */
export type PresetButtonRow = BaseLookButtonRow;

/**
 * カテゴリの並び順を数字にします。数字が小さいほど上に来ます。
 */
const baseLookCategoryRank: Record<BaseLookButtonRow["category"], number> = {
  utility: 0,
  filmStock: 1,
  look: 2,
};

/**
 * Web / Desktop 共通の Base Look surface 用に、`BASE_LOOK_BUTTONS` を並べ替えたコピーを返します。
 *
 * @param baseLookButtonRows - 並べ替え元（通常は `BASE_LOOK_BUTTONS` そのもの）
 * @returns カテゴリ順→同一カテゴリ内は元配列順の新しい配列
 */
export function orderPresetButtonsForSurface(
  baseLookButtonRows: readonly BaseLookButtonRow[],
): BaseLookButtonRow[] {
  return baseLookButtonRows
    .map((baseLookButtonRow, sourceIndex) => ({ baseLookButtonRow, sourceIndex }))
    .sort((a, b) => {
      const rankDiff =
        baseLookCategoryRank[a.baseLookButtonRow.category] -
        baseLookCategoryRank[b.baseLookButtonRow.category];
      if (rankDiff !== 0) {
        return rankDiff;
      }
      return a.sourceIndex - b.sourceIndex;
    })
    .map((entry) => entry.baseLookButtonRow);
}

/**
 * 検索で絞り込んだあとも、同じ並びルールをかけます。
 *
 * @param baseLookButtonRows - 通常は `BASE_LOOK_BUTTONS` 全体
 * @param predicate - 検索クエリなどに合う行だけ true にする関数
 */
export function filterPresetRowsForSearch(
  baseLookButtonRows: readonly BaseLookButtonRow[],
  predicate: (row: BaseLookButtonRow) => boolean,
): BaseLookButtonRow[] {
  return orderPresetButtonsForSurface(baseLookButtonRows.filter(predicate));
}
