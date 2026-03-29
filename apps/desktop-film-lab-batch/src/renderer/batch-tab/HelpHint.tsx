/**
 * @fileoverview 補足の長文を表示する ℹ ボタン（Electron でも確実に見えるカスタムツールチップ）
 *
 * @description
 * 以前は OS 標準の `title` だけに頼っていましたが、Electron / Chromium では
 * ホバーしても出ない・極端に遅いことがあります。表示は **fixed + body への portal** で
 * 自分で描画し、クリップや親の overflow に引っ張られないようにします。
 *
 * @limitations
 * - 画面端では位置を clamp します。超長文は縦スクロールできます。
 * - キーボードは Tab でフォーカス＋Esc で閉じます。
 */

import { Info } from "@phosphor-icons/react";
import {
  useCallback,
  useEffect,
  useId,
  useLayoutEffect,
  useRef,
  useState,
} from "react";
import { createPortal } from "react-dom";

/**
 * @description HelpHint の入力。tip にツールチップ全文を渡す。
 */
export type HelpHintProps = {
  /**
   * @description 表示する説明（改行は \n で入れられる。white-space: pre-wrap）
   */
  tip: string;
  /**
   * @description アイコンのみのときの簡短い aria-label（tip 全文を繰り返さない）
   */
  assistiveLabel?: string;
  /** @description ボタンに追加するクラス名 */
  className?: string;
};

/**
 * @description ツールチップの位置（fixed、ビューポート基準）
 */
type TooltipCoords = {
  top: number;
  left: number;
};

const TOOLTIP_MAX_W_PX = 320;
const TOOLTIP_VIEWPORT_MARGIN = 8;
const TOOLTIP_MAX_H_PX = 280;

/**
 * @description アンカー位置に合わせて fixed 用の top/left（translate -50% X）を計算する
 * @param anchorEl - ℹ ボタンの DOM
 * @param tooltipEl - 既に描画済みのツールチップ（高さ計測用）。null なら仮の高さで上方向フリップのみ簡易判定
 */
function computeTooltipCoords(
  anchorEl: HTMLElement,
  tooltipEl: HTMLElement | null,
): TooltipCoords {
  const gap = 8;
  const r = anchorEl.getBoundingClientRect();
  const vw = window.innerWidth;
  const vh = window.innerHeight;

  const tw = Math.min(TOOLTIP_MAX_W_PX, vw - TOOLTIP_VIEWPORT_MARGIN * 2);
  const th =
    tooltipEl?.getBoundingClientRect().height ?? Math.min(120, TOOLTIP_MAX_H_PX);

  let topBelow = r.bottom + gap;
  let topAbove = r.top - gap - th;
  const preferBelow = topBelow + th <= vh - TOOLTIP_VIEWPORT_MARGIN;
  const top = preferBelow
    ? topBelow
    : Math.max(TOOLTIP_VIEWPORT_MARGIN, topAbove);

  let left = r.left + r.width / 2;
  const half = tw / 2;
  left = Math.max(
    TOOLTIP_VIEWPORT_MARGIN + half,
    Math.min(vw - TOOLTIP_VIEWPORT_MARGIN - half, left),
  );

  return { top, left };
}

/**
 * @description ℹ ボタン。ホバー・フォーカス・タップで補足を表示する。
 */
export function HelpHint(props: HelpHintProps) {
  const { tip, assistiveLabel = "補足説明", className = "" } = props;
  const tipId = useId();
  const btnRef = useRef<HTMLButtonElement | null>(null);
  const tooltipRef = useRef<HTMLDivElement | null>(null);
  const [open, setOpen] = useState(false);
  const [coords, setCoords] = useState<TooltipCoords>({ top: 0, left: 0 });

  const closeIfNotFocused = useCallback(() => {
    requestAnimationFrame(() => {
      if (btnRef.current && document.activeElement === btnRef.current) return;
      setOpen(false);
    });
  }, []);

  const reposition = useCallback(() => {
    const btn = btnRef.current;
    if (!btn) return;
    setCoords(
      computeTooltipCoords(btn, tooltipRef.current),
    );
  }, []);

  useLayoutEffect(() => {
    if (!open) return;
    reposition();
    /** @description portal 直後に高さが確定するので 1 フレーム後にもう一度合わせる */
    const id = requestAnimationFrame(() => reposition());
    return () => cancelAnimationFrame(id);
  }, [open, tip, reposition]);

  useEffect(() => {
    if (!open) return;
    const onScrollOrResize = () => reposition();
    window.addEventListener("resize", onScrollOrResize);
    window.addEventListener("scroll", onScrollOrResize, true);
    return () => {
      window.removeEventListener("resize", onScrollOrResize);
      window.removeEventListener("scroll", onScrollOrResize, true);
    };
  }, [open, reposition]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (e: MouseEvent | PointerEvent) => {
      const t = e.target as Node;
      if (btnRef.current?.contains(t)) return;
      if (tooltipRef.current?.contains(t)) return;
      setOpen(false);
    };
    document.addEventListener("pointerdown", onPointerDown, true);
    return () =>
      document.removeEventListener("pointerdown", onPointerDown, true);
  }, [open]);

  const tooltipEl =
    open && typeof document !== "undefined" ? (
      <div
        ref={tooltipRef}
        id={tipId}
        role="tooltip"
        className="pointer-events-auto z-[2147483647] max-h-[min(17.5rem,calc(100vh-2rem))] w-[min(20rem,calc(100vw-1rem))] overflow-y-auto rounded-lg border border-[var(--fl-border-default)] bg-[var(--fl-bg-raised)] px-3 py-2 text-left text-xs leading-snug text-[var(--fl-text-primary)] shadow-lg outline-none"
        style={{
          position: "fixed",
          top: coords.top,
          left: coords.left,
          transform: "translateX(-50%)",
          maxWidth: TOOLTIP_MAX_W_PX,
        }}
      >
        <span className="whitespace-pre-wrap">{tip}</span>
      </div>
    ) : null;

  return (
    <>
      <button
        ref={btnRef}
        type="button"
        className={`inline-flex shrink-0 items-center justify-center rounded p-0.5 text-[var(--fl-text-tertiary)] outline-none hover:bg-[var(--fl-bg-interactive)] hover:text-[var(--amber-11)] focus-visible:ring-2 focus-visible:ring-[var(--fl-focus-ring)] ${className}`}
        aria-label={`${assistiveLabel}（詳細の表示・非表示）`}
        aria-expanded={open}
        aria-controls={open ? tipId : undefined}
        aria-describedby={open ? tipId : undefined}
        onMouseEnter={() => setOpen(true)}
        onMouseLeave={closeIfNotFocused}
        onFocus={() => setOpen(true)}
        onBlur={() => setOpen(false)}
        onPointerDown={(e) => {
          /** @description マウスはホバーで表示する。タッチだけトグル（click だとホバー機と二重になる） */
          if (e.pointerType !== "touch") return;
          setOpen((v) => !v);
        }}
      >
        <Info size={16} weight="regular" aria-hidden />
      </button>
      {tooltipEl ? createPortal(tooltipEl, document.body) : null}
    </>
  );
}
