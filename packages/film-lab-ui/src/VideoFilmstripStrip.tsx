"use client";

import type { PointerEvent as ReactPointerEvent } from "react";

/**
 * @fileoverview 動画トランスポート用の **フィルムストリップ**（サムネ列＋移動プレイヘッド）です（life#102）。
 *
 * @description
 * - サムネ列は filmstrip の対象時間帯として静置し、**白線の playhead 側が移動**して現在位置を示します。
 * - サムネの時刻は等間隔（0 … duration）に対応し、line の位置だけを 0〜100% で補間します。
 * - tray 上の pointer 位置から時刻を計算し、親の `videoPlaybackSeek()` 導線へつなぎます。
 *
 * @limitations
 * - サムネはあくまで目安であり、正確なフレーム編集には使えません。
 */
/**
 * @description 指定したインデックスのサムネ中心 X 座標を返します。
 * @param index 0 始まりのサムネ番号
 * @param thumbW 1 枚の幅（px）
 * @param gap サムネ間の隙間（px）
 */
function getFilmstripThumbCenterX(index: number, thumbW: number, gap: number): number {
  return index * (thumbW + gap) + thumbW / 2;
}

/**
 * @description 再生時刻（秒）をストリップ上の X 座標（左端からの px）に写像します。
 * @param time 現在時刻（秒）
 * @param duration 動画の長さ（秒）
 * @param count サムネの枚数
 * @param thumbW 1 枚の幅（px）
 * @param gap サムネ間の隙間（px）
 */
export function filmstripTimeToContentX(
  time: number,
  duration: number,
  count: number,
  thumbW: number,
  gap: number,
): number {
  if (count <= 0 || !Number.isFinite(duration) || duration <= 0 || !Number.isFinite(time)) {
    return thumbW / 2;
  }
  const t = Math.max(0, Math.min(duration, time));
  if (count === 1) {
    return thumbW / 2;
  }
  const times = Array.from({ length: count }, (_, i) => (i / (count - 1)) * duration);
  const xs = Array.from({ length: count }, (_, i) => getFilmstripThumbCenterX(i, thumbW, gap));
  if (t <= times[0]) {
    return xs[0];
  }
  if (t >= times[count - 1]) {
    return xs[count - 1];
  }
  let i = 0;
  while (i < count - 1 && t > times[i + 1]) {
    i += 1;
  }
  const t0 = times[i];
  const t1 = times[i + 1];
  const x0 = xs[i];
  const x1 = xs[i + 1];
  const r = (t - t0) / (t1 - t0);
  return x0 + r * (x1 - x0);
}

/**
 * @description tray 上の pointer 位置を時刻（秒）へ写像します。
 * @param clientX ポインタの x 座標
 * @param rectLeft tray 左端
 * @param rectWidth tray 幅
 * @param duration 動画長（秒）
 */
export function filmstripClientXToTime(
  clientX: number,
  rectLeft: number,
  rectWidth: number,
  duration: number,
): number {
  if (!Number.isFinite(rectWidth) || rectWidth <= 0) {
    return 0;
  }
  if (!Number.isFinite(duration) || duration <= 0) {
    return 0;
  }
  const ratio = Math.max(0, Math.min(1, (clientX - rectLeft) / rectWidth));
  return ratio * duration;
}

export type VideoFilmstripStripProps = {
  /** @description サムネ画像（data URL）。空文字のマスはスケルトン表示。 */
  thumbnails: string[];
  /** @description いまサムネを生成中なら true（プレースホルダ列を出す） */
  isGenerating: boolean;
  /** @description 再生位置（秒） */
  currentTime: number;
  /** @description 動画の長さ（秒） */
  duration: number;
  /** @description 書き出し busy などで操作を抑止するとき true */
  disabled: boolean;
  /** @description 1 枚のサムネ幅（px） */
  thumbWidthPx: number;
  /** @description サムネ同士の隙間（px） */
  gapPx?: number;
  /** @description 生成中プレースホルダの個数 */
  placeholderCount?: number;
  /** @description ストリップ全体の `aria-label` */
  stripAriaLabel: string;
  /** @description strip クリック / タップ時の seek 要求 */
  onSeekRequested?: (time: number) => void;
};

/**
 * @description フィルムストリップ行の UI。
 */
export function VideoFilmstripStrip({
  thumbnails,
  isGenerating,
  currentTime,
  duration,
  disabled,
  thumbWidthPx,
  gapPx = 3,
  placeholderCount = 12,
  stripAriaLabel,
  onSeekRequested,
}: VideoFilmstripStripProps) {
  const slots: { url: string | null }[] =
    isGenerating && thumbnails.length === 0
      ? Array.from({ length: placeholderCount }, () => ({ url: null }))
      : thumbnails.map((u) => ({ url: u.length > 0 ? u : null }));

  const effectiveCount = Math.max(slots.length, 1);
  const thumbHeightPx = Math.max(42, Math.min(50, Math.round(thumbWidthPx * 0.6)));
  const playheadPercent =
    Number.isFinite(duration) && duration > 0 && Number.isFinite(currentTime)
      ? Math.max(0, Math.min(100, (currentTime / duration) * 100))
      : 0;

  if (!isGenerating && thumbnails.length === 0) {
    return null;
  }

  const handlePointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (disabled || !onSeekRequested) {
      return;
    }
    const rect = e.currentTarget.getBoundingClientRect();
    const nextTime = filmstripClientXToTime(e.clientX, rect.left, rect.width, duration);
    e.preventDefault();
    e.stopPropagation();
    onSeekRequested(nextTime);
  };

  return (
    <div
      className={[
        "flex w-full min-w-0 flex-col px-4 pt-4",
        disabled ? "pointer-events-none opacity-40" : "",
      ]
        .filter(Boolean)
        .join(" ")}
    >
      <div
        className={[
          "relative mx-auto my-2 h-[4.2rem] w-full max-w-[min(720px,100%-4.5rem)] min-w-0 overflow-hidden rounded-[1.35rem] border border-white/[0.22] bg-white/[0.08] px-4 shadow-[0_16px_34px_rgba(0,0,0,0.24),inset_0_1px_0_rgba(255,255,255,0.16),inset_0_-1px_0_rgba(255,255,255,0.04)] backdrop-blur-xl",
          disabled ? "" : "cursor-pointer",
        ]
          .filter(Boolean)
          .join(" ")}
        role="group"
        aria-label={stripAriaLabel}
        aria-disabled={disabled}
        onPointerDown={handlePointerDown}
      >
        <div
          className="pointer-events-none absolute inset-x-5 top-1 z-0 h-6 rounded-full bg-white/12 blur-xl"
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-0 z-0 bg-[linear-gradient(180deg,rgba(255,255,255,0.12)_0%,rgba(255,255,255,0.04)_38%,rgba(255,255,255,0.02)_100%)]"
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-y-0 left-0 z-10 w-[3.25rem] bg-gradient-to-r from-black/38 via-black/10 to-transparent"
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-y-0 right-0 z-10 w-[3.25rem] bg-gradient-to-l from-black/38 via-black/10 to-transparent"
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-y-[0.55rem] z-20 w-[4px] -translate-x-1/2 rounded-full bg-white/95 shadow-[0_0_14px_rgba(255,255,255,0.52)]"
          style={{ left: `${playheadPercent}%` }}
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-0 z-[1] flex items-center"
          aria-hidden
        >
          <div
            className="grid w-full min-w-0"
            style={{
              height: `${thumbHeightPx}px`,
              gridTemplateColumns: `repeat(${effectiveCount}, minmax(0, 1fr))`,
              gap: `${gapPx}px`,
            }}
          >
            {slots.map((slot, idx) => (
              <div
                key={idx}
                className="overflow-hidden rounded-[0.8rem] bg-black/16 shadow-[inset_0_1px_0_rgba(255,255,255,0.1),inset_1px_0_0_rgba(255,255,255,0.03),0_0_0_1px_rgba(255,255,255,0.035),0_10px_18px_rgba(0,0,0,0.08)] backdrop-blur-sm"
              >
                {slot.url ? (
                  <img
                    src={slot.url}
                    alt=""
                    className="block h-full w-full object-cover"
                    draggable={false}
                  />
                ) : (
                  <div className="h-full w-full animate-pulse bg-white/[0.06]" />
                )}
              </div>
            ))}
          </div>
        </div>
        <div
          className="pointer-events-none absolute inset-y-0 left-0 z-10 w-9 bg-gradient-to-r from-white/[0.07] to-transparent"
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-y-0 right-0 z-10 w-9 bg-gradient-to-l from-white/[0.07] to-transparent"
          aria-hidden
        />
      </div>
    </div>
  );
}
