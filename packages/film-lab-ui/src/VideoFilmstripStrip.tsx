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

/**
 * @description サムネ列をすき間なく並べるため、先頭と末尾だけ角丸を残します。
 * @param index 現在のサムネ番号
 * @param slotCount 並んでいるサムネ総数
 */
function getFilmstripSlotRadiusClass(index: number, slotCount: number): string {
  if (slotCount <= 1) {
    return "rounded-[0.8rem]";
  }
  if (index === 0) {
    return "rounded-l-[0.8rem]";
  }
  if (index === slotCount - 1) {
    return "rounded-r-[0.8rem]";
  }
  return "rounded-none";
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
  gapPx = 0,
  placeholderCount = 12,
  stripAriaLabel,
  onSeekRequested,
}: VideoFilmstripStripProps) {
  /** @description tray の上下左右余白。見た目を均等にそろえるため同じ値を使います。 */
  const trayInsetPx = 4;
  const slots: { url: string | null }[] =
    isGenerating && thumbnails.length === 0
      ? Array.from({ length: placeholderCount }, () => ({ url: null }))
      : thumbnails.map((u) => ({ url: u.length > 0 ? u : null }));

  const effectiveCount = Math.max(slots.length, 1);
  /** @description 80px 幅サムネが横長に見える表示高さ。 */
  const thumbHeightPx = Math.max(28, Math.min(32, Math.round(thumbWidthPx * 0.4)));
  /** @description tray 全体の高さ。サムネ高さと均等 inset から組み立てます。 */
  const trayHeightPx = thumbHeightPx + trayInsetPx * 2;
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
    const innerRectLeft = rect.left + trayInsetPx;
    const innerRectWidth = Math.max(1, rect.width - trayInsetPx * 2);
    const nextTime = filmstripClientXToTime(e.clientX, innerRectLeft, innerRectWidth, duration);
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
          "relative mx-auto my-2 w-full max-w-[min(720px,100%-4.5rem)] min-w-0 overflow-hidden rounded-[1.35rem] border border-white/[0.14] bg-white/[0.08] shadow-[0_18px_34px_rgba(0,0,0,0.24),inset_0_1px_0_rgba(255,255,255,0.14),inset_0_-1px_0_rgba(255,255,255,0.05)] backdrop-blur-xl",
          disabled ? "" : "cursor-pointer",
        ]
          .filter(Boolean)
          .join(" ")}
        style={{ height: `${trayHeightPx}px` }}
        role="group"
        aria-label={stripAriaLabel}
        aria-disabled={disabled}
        onPointerDown={handlePointerDown}
      >
        <div
          className="pointer-events-none absolute z-0 rounded-full bg-white/10 blur-xl"
          style={{
            left: `${trayInsetPx}px`,
            right: `${trayInsetPx}px`,
            top: "2px",
            height: "10px",
          }}
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-0 z-0 bg-[linear-gradient(180deg,rgba(255,255,255,0.12)_0%,rgba(255,255,255,0.04)_38%,rgba(255,255,255,0.02)_100%)]"
          aria-hidden
        />
        <div
          className="pointer-events-none absolute z-10 w-2 bg-gradient-to-r from-black/12 to-transparent"
          style={{
            left: `${trayInsetPx}px`,
            top: `${trayInsetPx}px`,
            bottom: `${trayInsetPx}px`,
          }}
          aria-hidden
        />
        <div
          className="pointer-events-none absolute z-10 w-2 bg-gradient-to-l from-black/12 to-transparent"
          style={{
            right: `${trayInsetPx}px`,
            top: `${trayInsetPx}px`,
            bottom: `${trayInsetPx}px`,
          }}
          aria-hidden
        />
        <div
          className="pointer-events-none absolute z-20"
          style={{
            left: `${trayInsetPx}px`,
            right: `${trayInsetPx}px`,
            top: `${trayInsetPx}px`,
            bottom: `${trayInsetPx}px`,
          }}
          aria-hidden
        >
          <div
            className="absolute inset-y-0 w-[4px] -translate-x-1/2 rounded-full bg-white/95 shadow-[0_0_16px_rgba(255,255,255,0.58)]"
            style={{ left: `${playheadPercent}%` }}
          />
        </div>
        <div
          className="pointer-events-none absolute z-[1]"
          style={{ inset: `${trayInsetPx}px` }}
          aria-hidden
        >
          <div
            className="grid h-full w-full min-w-0"
            style={{
              gridTemplateColumns: `repeat(${effectiveCount}, minmax(0, 1fr))`,
              gap: `${gapPx}px`,
            }}
          >
            {slots.map((slot, idx) => (
              <div
                key={idx}
                className={[
                  "overflow-hidden bg-black/14",
                  getFilmstripSlotRadiusClass(idx, slots.length),
                ]
                  .filter(Boolean)
                  .join(" ")}
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
          className="pointer-events-none absolute z-10 w-2 bg-gradient-to-r from-white/[0.03] to-transparent"
          style={{
            left: `${trayInsetPx}px`,
            top: `${trayInsetPx}px`,
            bottom: `${trayInsetPx}px`,
          }}
          aria-hidden
        />
        <div
          className="pointer-events-none absolute z-10 w-2 bg-gradient-to-l from-white/[0.03] to-transparent"
          style={{
            right: `${trayInsetPx}px`,
            top: `${trayInsetPx}px`,
            bottom: `${trayInsetPx}px`,
          }}
          aria-hidden
        />
      </div>
    </div>
  );
}
