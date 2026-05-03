/**
 * @fileoverview コントロールパネル周りの **視覚トークン**（Tailwind クラス束）です。
 *
 * @description
 * Web / Desktop で同じ UI family に寄せるため、`FilmLabControlPanelCore` と同系の見出し・トグル・面の class を
 * ここにまとめます。life#87 の P2（文法レベルの共有）に該当し、Desktop 専用の重い chrome は含めません。
 *
 * @limitations
 * - トークン名と値を変えたら、Web の wrapper（例: BrowserStorage）で同じトークンを import して揃えてください。
 * - 一行が長いのは意図的です（Tailwind のユーティリティをそのまま束ねるため）。
 */

/**
 * パネル最外の「カード」面（Web の既定 `surface="card"`）。
 * 外側パネルと同様に backdrop で背面をぼかす（ネストしてもグラスブラーが途切れにくい程度の透過）。
 */
export const filmLabPanelSurfaceCard =
  "@container w-full min-w-0 rounded-lg border border-white/12 bg-black/65 p-4 backdrop-blur-xl backdrop-saturate-150 sm:p-5";

/**
 * Desktop 右パネルなど、`surface="bare"` のときの幅・アダプタ用ラッパー。
 */
export const filmLabPanelSurfaceBare = "@container w-full min-w-0";

/**
 * Quick / Pro 切替の外枠（角丸ボーダーのグループ）。
 * モバイルは横幅いっぱいのセグメント、sm 以上は中身幅に収まる inline-flex（右に無駄な空きを出さない）。
 */
export const filmLabModeToggleGroupShell =
  "flex w-full max-w-full flex-nowrap items-stretch gap-0.5 rounded-lg border border-white/10 p-1 sm:inline-flex sm:w-auto";

/**
 * モード切替ボタン共通（アクティブ状態は `filmLabModeToggleSegmentActive` / `filmLabModeToggleSegmentInactive` と併用）。
 */
export const filmLabModeToggleButtonBase =
  "min-w-[4rem] flex-1 whitespace-nowrap rounded-md px-3 py-2 text-center text-[11px] font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400/65 focus-visible:ring-offset-2 focus-visible:ring-offset-black/50 sm:flex-none sm:px-4";

/** 選択中のモードセグメント */
export const filmLabModeToggleSegmentActive = "bg-[var(--accent-amber1)] text-black";

/** 非選択のモードセグメント */
export const filmLabModeToggleSegmentInactive = "text-white/55 hover:text-white/75";

/**
 * Look ブロック下の区切り（下ボーダー + 余白）。
 */
export const filmLabLookSectionDividerBlock = "mb-4 min-w-0 border-b border-white/[0.06] pb-4";

/**
 * セクションタイトル（ uppercase の小さな見出し）。`SectionHeader` と Web wrapper の見出しで共用。
 */
export const filmLabSectionHeaderTitle =
  "mb-2 mt-3 text-[10px] font-medium uppercase tracking-[0.15em] text-white/40 first:mt-0";

/**
 * アコーディオン型の見出しボタン（`CollapsibleHeader`）。
 */
export const filmLabCollapsibleHeaderButton =
  "mb-2 mt-3 flex w-full items-center gap-1.5 text-[10px] font-medium uppercase tracking-[0.15em] text-white/40 transition-colors hover:text-white/60 first:mt-0";

/**
 * 寄付・プレゼントモードの囲い（薄い面 + ボーダー）。
 */
export const filmLabDonationPresentRowShell =
  "mt-2 flex cursor-pointer items-start gap-2.5 rounded-lg border border-white/[0.06] bg-white/[0.03] p-2.5";

/**
 * `ToggleHeader` の見出し側テキスト。
 */
export const filmLabToggleHeaderTitle =
  "text-[10px] font-semibold uppercase tracking-[0.15em] text-white/65";

/**
 * `ToggleHeader` のスイッチ ON 時のトラック。
 */
export const filmLabToggleHeaderTrackOn =
  "border-[color-mix(in_srgb,var(--accent-amber1)_70%,transparent)] bg-[var(--accent-amber1)]";

/**
 * `ToggleHeader` のスイッチ OFF 時のトラック。
 */
export const filmLabToggleHeaderTrackOff = "border-white/25 bg-[#1c1c1c] hover:border-white/35";

/**
 * @param {boolean} active Quick と Pro のどちらが押されているか
 * @returns {string} モードボタンに付ける className
 */
export function filmLabModeToggleButtonClassName(active: boolean): string {
  return [
    filmLabModeToggleButtonBase,
    active ? filmLabModeToggleSegmentActive : filmLabModeToggleSegmentInactive,
  ].join(" ");
}

/**
 * @param {"card" | "bare"} surface Core の `surface` と同じ意味
 * @returns {string} パネルルートの className
 */
export function filmLabPanelRootClassName(surface: "card" | "bare"): string {
  return surface === "bare" ? filmLabPanelSurfaceBare : filmLabPanelSurfaceCard;
}
