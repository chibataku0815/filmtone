"use client";

/**
 * @fileoverview 動画トランスポート用の **フィルムストリップ**（サムネ列＋移動プレイヘッド）です（life#102）。
 *
 * @description
 * - サムネ列は filmstrip の対象時間帯として静置し、**白線の playhead 側が移動**して現在位置を示します。
 * - サムネの時刻は等間隔（0 … duration）に対応し、line の位置だけを 0〜100% で補間します。
 * - このコンポーネント自体は表示専用とし、iPhone 編集 UI に寄せた tray で見せます。
 *
 * @limitations
 * - サムネはあくまで目安であり、正確なフレーム編集には使えません（親が注記文案を渡します）。
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
  /** @description ストリップ全体の `aria-label` */
  stripAriaLabel: string;
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
  gapPx = 4,
  stripAriaLabel,
}: VideoFilmstripStripProps) {
  const slots: { url: string | null }[] =
    isGenerating && thumbnails.length === 0
      ? Array.from({ length: 12 }, () => ({ url: null }))
      : thumbnails.map((u) => ({ url: u.length > 0 ? u : null }));

  const effectiveCount = Math.max(slots.length, 1);
  const thumbHeightPx = Math.round(thumbWidthPx * 1.14);
  const playheadPercent =
    Number.isFinite(duration) && duration > 0 && Number.isFinite(currentTime)
      ? Math.max(0, Math.min(100, (currentTime / duration) * 100))
      : 0;

  if (!isGenerating && thumbnails.length === 0) {
    return null;
  }

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
        className="relative mx-auto my-2 h-[4.5rem] w-full max-w-[min(720px,100%-4.5rem)] min-w-0 overflow-hidden rounded-[1.15rem] border border-white/[0.18] bg-white/[0.09] px-2 shadow-[0_12px_36px_rgba(0,0,0,0.26)]"
        role="img"
        aria-label={stripAriaLabel}
      >
        <div
          className="pointer-events-none absolute inset-y-0 left-0 z-10 w-16 bg-gradient-to-r from-black/45 via-black/18 to-transparent"
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-y-0 right-0 z-10 w-16 bg-gradient-to-l from-black/45 via-black/18 to-transparent"
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-y-1 z-20 w-[3px] -translate-x-1/2 rounded-full bg-white/90 shadow-[0_0_12px_rgba(255,255,255,0.45)]"
          style={{ left: `${playheadPercent}%` }}
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-0 flex items-center"
          aria-hidden
        >
          <div
            className="grid h-[64px] w-full min-w-0"
            style={{
              height: `${thumbHeightPx}px`,
              gridTemplateColumns: `repeat(${effectiveCount}, minmax(0, 1fr))`,
              gap: `${gapPx}px`,
            }}
          >
            {slots.map((slot, idx) => (
              <div
                key={idx}
                className="overflow-hidden rounded-[0.72rem] bg-white/[0.08] ring-1 ring-black/10"
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
          className="pointer-events-none absolute inset-y-0 left-0 z-10 w-12 bg-gradient-to-r from-black/35 to-transparent"
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-y-0 right-0 z-10 w-12 bg-gradient-to-l from-black/35 to-transparent"
          aria-hidden
        />
      </div>
    </div>
  );
}
