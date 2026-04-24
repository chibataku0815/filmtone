/**
 * Film Lab デスクトップ — 動画出力の製品キャップ定数
 *
 * @overview 読み込み解像度・最大尺・出力解像度の上限を管理する。fps は信頼できるソース fps を保持する。
 * @limitations アップスケールはしない（出力はソースを FHD 以内に収めた解像度）。
 */

/** @description ソース動画の幅の上限（ピクセル） */
export const VIDEO_IMPORT_MAX_WIDTH = 3840;

/** @description ソース動画の高さの上限（ピクセル） */
export const VIDEO_IMPORT_MAX_HEIGHT = 2160;

/** @description ソース動画の長さの上限（秒） */
export const VIDEO_IMPORT_MAX_DURATION_SEC = 900;

/** @description ソース fps を信頼できない場合の書き出しフレームレート */
export const VIDEO_EXPORT_FALLBACK_FPS = 24;

/** @description 書き出しの最大幅（FHD） */
export const VIDEO_EXPORT_MAX_WIDTH = 1920;

/** @description 書き出しの最大高さ（FHD） */
export const VIDEO_EXPORT_MAX_HEIGHT = 1080;

/**
 * @description アスペクトを保ったまま FHD の枠内に収め、必要なら縮小（拡大しない）
 * @param sourceW - ソース動画の幅（ピクセル）
 * @param sourceH - ソース動画の高さ（ピクセル）
 */
export function computeVideoExportDimensions(
  sourceW: number,
  sourceH: number,
): { outW: number; outH: number } {
  if (sourceW <= 0 || sourceH <= 0) {
    throw new Error(
      `computeVideoExportDimensions: 不正な解像度 sourceW=${sourceW}, sourceH=${sourceH}`,
    );
  }
  const scale = Math.min(
    VIDEO_EXPORT_MAX_WIDTH / sourceW,
    VIDEO_EXPORT_MAX_HEIGHT / sourceH,
    1,
  );
  const outW = Math.max(1, Math.round(sourceW * scale));
  const outH = Math.max(1, Math.round(sourceH * scale));
  return { outW, outH };
}

/**
 * @description ソースのメタデータが import 上限を満たすか検証する。満たさなければ例外。
 * @param width - ffprobe 等で得た幅
 * @param height - 高さ
 * @param durationSec - 長さ（秒）
 */
export function assertVideoImportWithinCaps(
  width: number,
  height: number,
  durationSec: number,
): void {
  // 解像度チェックは削除: mezzanine 変換が FHD にダウンスケールするため、
  // DCI 4K (4096) や 6K/8K 等のソースでも書き出し可能。
  void width;
  void height;
  if (
    !Number.isFinite(durationSec) ||
    durationSec <= 0 ||
    durationSec > VIDEO_IMPORT_MAX_DURATION_SEC
  ) {
    throw new Error(
      `動画の長さが範囲外です（最大 ${VIDEO_IMPORT_MAX_DURATION_SEC} 秒）。実測: ${durationSec}`,
    );
  }
}

/**
 * @description 書き出し総フレーム数。duration 終端より先は作らない。
 * @param durationSec — ソースの長さ（秒）
 * @param fps — 書き出し fps
 */
export function computeExportFrameCount(
  durationSec: number,
  fps = VIDEO_EXPORT_FALLBACK_FPS,
): number {
  const safeFps = sanitizeVideoExportFps(fps) ?? VIDEO_EXPORT_FALLBACK_FPS;
  const raw = Math.floor(durationSec * safeFps + 1e-6);
  return Math.max(1, raw);
}

/**
 * @description ffmpeg / UI に渡せる範囲の fps だけを採用する。
 */
export function sanitizeVideoExportFps(fps: number | null | undefined): number | null {
  if (typeof fps !== "number" || !Number.isFinite(fps)) {
    return null;
  }
  if (fps < 1 || fps > 120) {
    return null;
  }
  return fps;
}

/**
 * @description trusted CFR メタがある場合はソース fps を保持し、なければ従来の 24fps に戻す。
 */
export function selectVideoExportFps(opts: {
  sourceFrameRate: number | null;
  sourceFrameRateTrusted: boolean;
}): number {
  if (opts.sourceFrameRateTrusted) {
    const sourceFps = sanitizeVideoExportFps(opts.sourceFrameRate);
    if (sourceFps !== null) {
      return sourceFps;
    }
  }
  return VIDEO_EXPORT_FALLBACK_FPS;
}

/**
 * @description ログ/UI向けに過剰な小数を落とす。
 */
export function formatVideoExportFps(fps: number): string {
  if (!Number.isFinite(fps)) {
    return String(VIDEO_EXPORT_FALLBACK_FPS);
  }
  if (Math.abs(fps - Math.round(fps)) < 1e-6) {
    return String(Math.round(fps));
  }
  return fps.toFixed(3).replace(/0+$/u, "").replace(/\.$/u, "");
}
