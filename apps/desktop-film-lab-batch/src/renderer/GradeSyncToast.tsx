/**
 * @fileoverview 編集タブで「書き出しへ送る」を押したあとに出す、画面下のガラス風トーストです。
 *
 * @description
 * - 以前はヘッダー下の太い帯でしたが、キャンバスを見ながらでも気づけるよう **下中央の浮いたカード** にします。
 * - 背後をぼかす `backdrop-filter` でグラスモーフィズム風にし、**枠線（border）は付けません**（影と内側の弱い光で区切ります）。
 * - 左端だけ細いアンバー（またはエラー時は赤み）のグラデで、Filmtone の主ボタンと雰囲気を合わせます。
 *
 * @limitations
 * - `document.body` へ Portal するため、Electron の `#root` の `overflow` の影響を受けません。
 * - `backdrop-filter` が弱い環境では CSS で不透明度を上げるフォールバックがあります（`globals.css`）。
 */

import { CheckCircle, Info, XCircle } from "@phosphor-icons/react";
import { createPortal } from "react-dom";

/**
 * @description トーストに載せる文と、見た目の種類（アイコンと左アクセント色が変わります）。
 * @property message ユーザーに見せる本文（翻訳済み文字列）
 * @property variant 成功・注意・エラーのどれか
 */
export type GradeSyncToastPayload = {
  message: string;
  variant: "success" | "info" | "error";
};

/**
 * @description `GradeSyncToast` に渡す props です。
 * @property payload 表示内容。`null` のときは何も描画しません（Portal も出しません）。
 */
type GradeSyncToastProps = {
  payload: GradeSyncToastPayload | null;
};

/**
 * @description 種類に合う Phosphor アイコンを返します（装飾なので `aria-hidden` 側で隠します）。
 * @param variant 成功・注意・エラー
 */
function variantIcon(variant: GradeSyncToastPayload["variant"]) {
  const common = { size: 18, weight: "fill" as const, "aria-hidden": true as const };
  switch (variant) {
    case "success":
      return <CheckCircle {...common} className="shrink-0 text-[var(--amber-9)]" />;
    case "error":
      return <XCircle {...common} className="shrink-0 text-red-400" />;
    case "info":
      return <Info {...common} className="shrink-0 text-[var(--amber-10)]" />;
  }
}

/**
 * @description 編集→書き出し同期の結果を、ガラス風トーストとして `document.body` 直下に出します。
 * @param props.payload 表示するペイロード
 * @returns ポータルで描画する React ノード、または SSR 時など `document` が無いときは `null`
 */
export function GradeSyncToast(props: GradeSyncToastProps) {
  const { payload } = props;

  if (payload === null || typeof document === "undefined") {
    return null;
  }

  const accentClass =
    payload.variant === "error"
      ? "fl-grade-sync-toast__surface--error"
      : payload.variant === "info"
        ? "fl-grade-sync-toast__surface--info"
        : "fl-grade-sync-toast__surface--success";

  return createPortal(
    <div
      className="fl-grade-sync-toast"
      role="status"
      aria-live="polite"
      aria-atomic="true"
    >
      <div className={`fl-grade-sync-toast__surface ${accentClass}`}>
        <div className="fl-grade-sync-toast__row">
          {variantIcon(payload.variant)}
          <p className="fl-grade-sync-toast__text text-pretty">{payload.message}</p>
        </div>
      </div>
    </div>,
    document.body,
  );
}
