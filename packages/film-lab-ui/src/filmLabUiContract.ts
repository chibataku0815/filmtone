/**
 * @fileoverview Filmtone（Film Lab）の **UI contract** を life#87 向けにまとめた正本です。
 *
 * @description
 * - Web と Desktop は **同じ道具の別モード**に見えることを目標に、`FilmLabControlPanelCore` の
 *   情報の順序・プリセット主経路・翻訳の出どころをここで固定します。
 * - **やること**: 設計レビューや wrapper 実装時に「shared に何が入るか」を迷わないための索引。
 * - **やらないこと**: renderer、export パイプライン、native ダイアログ、Smart Look 完成の扱い（これらは contract 外）。
 *
 * @limitations
 * - 実 DOM／クラス名のすべてを列挙しません。変更時は `FilmLabControlPanelCore.tsx` と併読してください。
 * - `next-intl` のキー全文は `apps/web/messages/{en,ja}.json` の `film-lab` ツリーを正とします（Desktop も同 JSON を読み込みます）。
 */

/**
 * Core が `useTranslations` で参照する名前空間。Web / Desktop とも同じ JSON を渡すこと。
 */
export const FILM_LAB_NEXT_INTL_NAMESPACE = "film-lab" as const;

/**
 * プリセット選択の **primary path**（life#86 完了後もここが唯一の入口）。
 * 別コンポーネントで二重にプリセット一覧を出さないこと。
 */
export const FILM_LAB_PRESET_PRIMARY_SURFACE_ID = "PresetSearchSelect" as const;

/**
 * `FilmLabControlPanelCore` 内コンテンツの **論理ブロック順**（上から）。
 * 順序を変えるときは必ず Core の JSX とセットで更新し、Web/Desktop で意味がずれないか確認します。
 */
export const FILM_LAB_CONTROL_PANEL_SECTION_ORDER = [
  /** Quick / Pro 切替＋モード説明 */
  "modeToggle",
  /** 寄付・プレゼンモード（Web の donationUi スロットがあるときだけ表示） */
  "donationPresentMode",
  /** セクション見出し + beforePresets + PresetSearchSelect + preset intensity */
  "presets",
  /**
   * `slots.renderAfterPresets` / `afterPresets` — Web: Smart Look 等。Desktop: 未使用なら空。
   */
  "wrapperAfterPresets",
  /**
   * 2 カラムグリッド: Color / Effects（Quick は子ブロック順が変わる）、Compare、LUT、Histogram 等。
   */
  "colorAndEffectsGrid",
  /** `ShortcutHelp` オーバーレイ（ショートカット一覧） */
  "shortcutHelpOverlay",
] as const;

/**
 * 論理ブロック ID（`FILM_LAB_CONTROL_PANEL_SECTION_ORDER` の要素型）。
 */
export type FilmLabControlPanelSectionId =
  (typeof FILM_LAB_CONTROL_PANEL_SECTION_ORDER)[number];

/**
 * Wrapper が差し込める拡張点 ID（`FilmLabControlPanelCoreSlots` と対応）。
 * Platform 固有 UI はここに閉じ、Core 本体の並びは上記 section order を崩さないこと。
 */
export const FILM_LAB_WRAPPER_SLOT_IDS = [
  "beforePresets",
  "afterPresets",
  "afterLut",
  "donationUi",
  "lpExpandButton",
  "renderAfterPresets",
  "renderAfterLut",
] as const;

export type FilmLabWrapperSlotId = (typeof FILM_LAB_WRAPPER_SLOT_IDS)[number];

/**
 * メッセージ JSON のパス（モノレポからの参照用）。実ファイルはビルド対象アプリ側にあります。
 */
export const FILM_LAB_MESSAGES_MANIFEST_PATH =
  "apps/web/messages/{en,ja}.json#film-lab" as const;
