/**
 * @fileoverview ffprobe のフレームレート文字列をパースし、CFR メタの信任を判定する（メインプロセス／テスト共用）
 *
 * @overview `avg_frame_rate` と `r_frame_rate` がどちらも有限で、差が小さいときだけ信頼する。
 * @limitations 信頼できない場合は `sourceFrameRate: null`。実際のフレーム配列までは保証しない。
 */

/**
 * @description ffprobe の "30000/1001" や "30" 形式を fps にする
 * @param rate - stream の avg_frame_rate / r_frame_rate
 * @returns 正の fps、または解析不能なら null
 */
export function parseFfprobeFrameRateRate(rate: unknown): number | null {
  if (typeof rate !== "string" || rate.length === 0) {
    return null;
  }
  const parts = rate.split("/");
  if (parts.length === 1) {
    const n = Number(parts[0]);
    return Number.isFinite(n) && n > 0 ? n : null;
  }
  if (parts.length === 2) {
    const num = Number(parts[0]);
    const den = Number(parts[1]);
    if (!Number.isFinite(num) || !Number.isFinite(den) || den === 0) {
      return null;
    }
    const q = num / den;
    return Number.isFinite(q) && q > 0 ? q : null;
  }
  return null;
}

export type SourceFrameRateTrustReason =
  | "missing-or-invalid-rate"
  | "rates-diverged"
  | "within-absolute-tolerance"
  | "within-relative-tolerance";

export type SourceFrameRateTrustResult = {
  avgFrameRate: string | null;
  rFrameRate: string | null;
  avgFrameRateParsed: number | null;
  rFrameRateParsed: number | null;
  sourceFrameRate: number | null;
  sourceFrameRateTrusted: boolean;
  trustReason: SourceFrameRateTrustReason;
};

function frameRateText(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

/**
 * @description 両方パースでき、差が相対 0.5% 以内または絶対 0.01 fps 以内なら trusted
 * @param avgFrameRate - ffprobe stream.avg_frame_rate
 * @param rFrameRate - ffprobe stream.r_frame_rate
 */
export function deriveSourceFrameRateTrust(
  avgFrameRate: unknown,
  rFrameRate: unknown,
): SourceFrameRateTrustResult {
  const a = parseFfprobeFrameRateRate(avgFrameRate);
  const r = parseFfprobeFrameRateRate(rFrameRate);
  const base = {
    avgFrameRate: frameRateText(avgFrameRate),
    rFrameRate: frameRateText(rFrameRate),
    avgFrameRateParsed: a,
    rFrameRateParsed: r,
  };
  if (a === null || r === null) {
    return {
      ...base,
      sourceFrameRate: null,
      sourceFrameRateTrusted: false,
      trustReason: "missing-or-invalid-rate",
    };
  }
  const diff = Math.abs(a - r);
  const hi = Math.max(a, r);
  const relOk = hi > 0 && diff / hi <= 0.005;
  const absOk = diff <= 0.01;
  if (!relOk && !absOk) {
    return {
      ...base,
      sourceFrameRate: null,
      sourceFrameRateTrusted: false,
      trustReason: "rates-diverged",
    };
  }
  return {
    ...base,
    sourceFrameRate: (a + r) / 2,
    sourceFrameRateTrusted: true,
    trustReason: absOk
      ? "within-absolute-tolerance"
      : "within-relative-tolerance",
  };
}
