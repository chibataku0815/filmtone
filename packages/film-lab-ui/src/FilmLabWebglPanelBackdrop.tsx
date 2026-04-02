"use client";

/**
 * @fileoverview Web / Desktop 共有 — WebGL プレビュー canvas の画をパネル領域に切り出し、2D + CSS blur ですりガラス近似。
 *
 * @description
 * `backdrop-filter` は WebGL 背面や Transform を挟んだレイヤーで壊れやすい。
 * 毎フレーム `drawImage` で取り込み、バッファへ縮小してから `filter: blur()` を掛ける。
 * Web の `FilmLabFullPage` lg 展開時と同じ手法を Desktop でも共用する。
 *
 * @limitations
 * - CPU/GPU 負荷あり。
 * - パネルとキャンバスが画面内で重ならないときはインターセクションが小さく描画をスキップする。
 */

import { useEffect, useRef, type RefObject } from "react";
import type { FilmLabCanvasRef } from "./FilmLabCanvas";

/** @description 右パネルがキャンバス上に載るとき true を渡す */
export type FilmLabWebglPanelBackdropProps = {
  filmLabCanvasRef: RefObject<FilmLabCanvasRef | null>;
  panelRef: RefObject<HTMLElement | null>;
  enabled: boolean;
};

/**
 * @description パネル矩形いっぱいに、背後 WebGL のスナップショット＋スクリムを敷く canvas。
 */
export function FilmLabWebglPanelBackdrop({
  filmLabCanvasRef,
  panelRef,
  enabled,
}: FilmLabWebglPanelBackdropProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (!enabled) {
      return;
    }

    let alive = true;
    let rafId = 0;

    const tick = () => {
      if (!alive) {
        return;
      }
      rafId = requestAnimationFrame(tick);

      const canvas = canvasRef.current;
      const src = filmLabCanvasRef.current?.getWebGlCanvas?.();
      const panelEl = panelRef.current;
      if (!canvas || !src || !panelEl) {
        return;
      }

      const ctx = canvas.getContext("2d", { alpha: true, desynchronized: true });
      if (!ctx) {
        return;
      }

      const srcRect = src.getBoundingClientRect();
      const panelRect = panelEl.getBoundingClientRect();

      const interLeft = Math.max(panelRect.left, srcRect.left);
      const interTop = Math.max(panelRect.top, srcRect.top);
      const interRight = Math.min(panelRect.right, srcRect.right);
      const interBottom = Math.min(panelRect.bottom, srcRect.bottom);
      const interW = interRight - interLeft;
      const interH = interBottom - interTop;
      if (interW < 2 || interH < 2) {
        return;
      }

      const dpr = Math.min(2, typeof window !== "undefined" ? window.devicePixelRatio || 1 : 1);
      const destW = Math.max(1, Math.floor(panelEl.clientWidth * dpr));
      const destH = Math.max(1, Math.floor(panelEl.clientHeight * dpr));
      if (canvas.width !== destW || canvas.height !== destH) {
        canvas.width = destW;
        canvas.height = destH;
      }

      const sx = ((interLeft - srcRect.left) / srcRect.width) * src.width;
      const sy = ((interTop - srcRect.top) / srcRect.height) * src.height;
      const sw = (interW / srcRect.width) * src.width;
      const sh = (interH / srcRect.height) * src.height;

      try {
        ctx.clearRect(0, 0, destW, destH);
        ctx.drawImage(src, sx, sy, sw, sh, 0, 0, destW, destH);
        ctx.fillStyle = "rgba(6, 8, 12, 0.58)";
        ctx.fillRect(0, 0, destW, destH);
      } catch {
        /* drawImage が弾かれる環境は無視 */
      }
    };

    rafId = requestAnimationFrame(tick);
    return () => {
      alive = false;
      cancelAnimationFrame(rafId);
    };
  }, [enabled, filmLabCanvasRef, panelRef]);

  if (!enabled) {
    return null;
  }

  return (
    <canvas
      ref={canvasRef}
      className="film-lab-webgl-backdrop-canvas pointer-events-none absolute inset-0 z-0 rounded-[inherit]"
      style={{
        width: "100%",
        height: "100%",
        filter: "blur(22px) saturate(1.28)",
        transform: "scale(1.06)",
        boxShadow:
          "inset 0 0 48px rgba(0, 0, 0, 0.38), inset 0 0 0 1px rgba(255, 255, 255, 0.09)",
      }}
      aria-hidden
    />
  );
}
