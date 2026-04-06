"use client";

import { useTranslations } from "next-intl";
import type { ProgressiveQualityLabel } from "./use-progressive-load";

type QualityBadgeProps = {
  /** @description 画面に見えているプレビュー品質ラベルです */
  qualityLabel: ProgressiveQualityLabel;
};

/**
 * @description Progressive loading 中だけ表示する品質バッジです。
 * 処理中であることをユーザーに伝えるため、パルスアニメーション付きのドットを表示します。
 */
export function QualityBadge({ qualityLabel }: QualityBadgeProps) {
  const tApp = useTranslations("film-lab.desktop.app");
  const visible = qualityLabel === "thumbnail" || qualityLabel === "proxy";
  const label =
    qualityLabel === "proxy"
      ? tApp("qualityBadgeProxy")
      : tApp("qualityBadgeThumbnail");

  return (
    <>
      {visible && (
        <style>{`
          @keyframes fl-badge-pulse {
            0%, 100% { opacity: 0.5; }
            50% { opacity: 1; }
          }
        `}</style>
      )}
      <div
        style={{
          position: "fixed",
          bottom: 80,
          left: 20,
          zIndex: 99999,
          display: "flex",
          alignItems: "center",
          gap: 6,
          background: visible ? "rgba(0,0,0,0.75)" : "transparent",
          color: visible ? "#fff" : "transparent",
          padding: "5px 12px",
          borderRadius: 8,
          fontSize: 11,
          fontWeight: 500,
          letterSpacing: "0.02em",
          pointerEvents: "none",
          transition: "opacity 300ms",
          opacity: visible ? 1 : 0,
          border: visible ? "1px solid rgba(255,255,255,0.12)" : "none",
          animation: visible ? "fl-badge-pulse 2s ease-in-out infinite" : "none",
        }}
        role="status"
        aria-live="polite"
        aria-label={
          visible
            ? tApp("qualityBadgeSdAria")
            : tApp("qualityBadgeFullAria")
        }
      >
        <span
          style={{
            width: 6,
            height: 6,
            borderRadius: "50%",
            background: "#3b82f6",
            flexShrink: 0,
          }}
        />
        {label}
      </div>
    </>
  );
}
