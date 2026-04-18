"use client";

/**
 * @fileoverview Web / Desktop 共有 — プレビュー canvas の画をパネル背後に鏡写しし、CSS filter: blur で すりガラス化。
 *
 * @description
 * 2026-04-18 改訂: WebGPU accelerated canvas は Chromium の compositor で別レイヤーとして
 * 扱われ、`ctx.drawImage(webgpuCanvas)` が silent failure を起こす / `backdrop-filter` が
 * その pixel を読めない(compositor boundary 問題)。
 *
 * 対策として `canvas.captureStream(30)` でプレビュー canvas を MediaStream 化し、
 * `<video>` 要素の srcObject に挿す。video は通常の DOM 要素として描画されるため
 * CSS `filter: blur()` が確実に効く。WebGL / WebGPU 両 backend で同一 code path。
 *
 * @limitations
 * - 30 fps ミラー。動画再生時は追従。
 * - video element 1 つ分の追加 GPU 合成コストあり。
 * - Panel と canvas の位置合わせは object-fit: cover + 右寄せで済ませる(完全な pixel
 *   アライメントは不要、重 blur 下では視覚的に十分自然)。
 */

import { useEffect, useRef, type RefObject } from "react";
import type { FilmLabCanvasRef } from "./FilmLabCanvas";

/** @description 右パネルがキャンバス上に載るとき true を渡す */
export type FilmLabWebglPanelBackdropProps = {
  filmLabCanvasRef: RefObject<FilmLabCanvasRef | null>;
  panelRef: RefObject<HTMLElement | null>;
  enabled: boolean;
};

type CanvasWithCaptureStream = HTMLCanvasElement & {
  captureStream?: (frameRate?: number) => MediaStream;
};

/**
 * @description パネル矩形いっぱいに、背後プレビューの鏡像を blur 表示する video。
 */
export function FilmLabWebglPanelBackdrop({
  filmLabCanvasRef,
  panelRef: _panelRef,
  enabled,
}: FilmLabWebglPanelBackdropProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);

  useEffect(() => {
    if (!enabled) {
      return;
    }

    let cancelled = false;
    let attachRafId = 0;

    const attach = () => {
      if (cancelled) return;
      const video = videoRef.current;
      const src = filmLabCanvasRef.current?.getWebGlCanvas?.() as
        | CanvasWithCaptureStream
        | null;
      if (!video || !src) {
        attachRafId = window.requestAnimationFrame(attach);
        return;
      }
      if (typeof src.captureStream !== "function") {
        console.warn(
          "[FilmLabWebglPanelBackdrop] HTMLCanvasElement.captureStream unavailable",
        );
        return;
      }
      // Canvas may not be sized yet on very first attach — wait a frame.
      if (src.width < 2 || src.height < 2) {
        attachRafId = window.requestAnimationFrame(attach);
        return;
      }
      try {
        const stream = src.captureStream(30);
        streamRef.current = stream;
        video.srcObject = stream;
        void video.play().catch(() => {
          /* autoplay policy may block — muted+autoPlay should always pass in Electron */
        });
      } catch (err) {
        console.warn(
          "[FilmLabWebglPanelBackdrop] captureStream failed",
          err,
        );
      }
    };

    attachRafId = window.requestAnimationFrame(attach);

    return () => {
      cancelled = true;
      if (attachRafId) window.cancelAnimationFrame(attachRafId);
      const video = videoRef.current;
      if (video) {
        video.pause();
        video.srcObject = null;
      }
      const stream = streamRef.current;
      if (stream) {
        for (const track of stream.getTracks()) {
          track.stop();
        }
      }
      streamRef.current = null;
    };
  }, [enabled, filmLabCanvasRef]);

  if (!enabled) {
    return null;
  }

  return (
    <video
      ref={videoRef}
      muted
      autoPlay
      playsInline
      className="film-lab-webgl-backdrop-canvas pointer-events-none absolute inset-0 z-0 h-full w-full rounded-[inherit]"
      style={{
        objectFit: "cover",
        // パネルは画面右端。canvas の右側相当を見せると視覚的に自然。
        objectPosition: "100% center",
        // 2026-04-18: 28px blur + 0.78 brightness が若干効きすぎだったため、
        // 20px / 0.88 / saturate 1.18 に軽減。craft 感は残しつつ、背後が過度に
        // 沈み込まない level へ。
        filter: "blur(20px) saturate(1.18) brightness(0.88)",
        // blur エッジ隠し。scale も 1.18 → 1.12 に。
        transform: "scale(1.12)",
      }}
      aria-hidden
    />
  );
}
