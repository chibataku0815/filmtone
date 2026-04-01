/**
 * @fileoverview **現在のソース／状態**をユーザーに伝えるときの優先度と語彙の contract です（life#87 P3）。
 *
 * @description
 * - `FilmLabInteractiveSourceInfo`（`FilmLabCanvas`）が canvas 上の「何を見ているか」の正本です。
 * - Desktop の Export タブでは、Edit プレビューから Batch へ渡す **bridge 文言**（`film-lab.desktop.app`）が別系統で動きますが、
 *   **ユーザーが「正とすべき入力」を見失わない**という目的は同じです。
 * - このファイルは **型と並び順のドキュメント**が主で、canvas のコールバック形を変える必要はありません。
 *
 * @limitations
 * - Batch パネル固有の列挙（複数ファイルキュー等）はここに含めません（Desktop wrapper の責務）。
 */

/**
 * UI にソース関連情報を載せる推奨順序（**先頭ほどユーザーが先に読む**）。
 *
 * | 要素 | 意味 | Web の主な置き場 | Desktop の主な置き場 |
 * |------|------|------------------|---------------------|
 * | primaryFileIdentity | ファイル名・sample | ツールバー／キャプション | 同左、`absolutePath` は補助 |
 * | sourceRoleBadge | userMedia / smartLookDerived | キャプション横など | 同左 |
 * | compareSlotIndicator | A/B・Before-After | Compare HUD | 同左 |
 * | exportBridgeSyncState | Edit→Export の同期 | （通常なし） | Sticky footer 周り |
 */
export const FILM_LAB_SOURCE_DISPLAY_PRIORITY_ORDER = [
  "primaryFileIdentity",
  "sourceRoleBadge",
  "compareSlotIndicator",
  "exportBridgeSyncState",
] as const;

/**
 * ソース表示バンド ID（`FILM_LAB_SOURCE_DISPLAY_PRIORITY_ORDER` の要素型）。
 */
export type FilmLabSourceDisplayBand =
  (typeof FILM_LAB_SOURCE_DISPLAY_PRIORITY_ORDER)[number];
