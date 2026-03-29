/**
 * Film Lab デスクトップ — 動画出力の製品キャップ定数
 *
 * @overview 読み込み解像度・最大尺・出力は FHD@30 に固定。実装の他ファイルから参照する単一ソース。
 * @limitations アップスケールはしない（出力はソースを FHD 以内に収めた解像度）。
 */

/** @description ソース動画の幅の上限（ピクセル） */
export const VIDEO_IMPORT_MAX_WIDTH = 3840;

/** @description ソース動画の高さの上限（ピクセル） */
export const VIDEO_IMPORT_MAX_HEIGHT = 2160;

/** @description ソース動画の長さの上限（秒） */
export const VIDEO_IMPORT_MAX_DURATION_SEC = 900;

/** @description 書き出しフレームレート（固定） */
export const VIDEO_EXPORT_FPS = 30;

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
  if (width > VIDEO_IMPORT_MAX_WIDTH || height > VIDEO_IMPORT_MAX_HEIGHT) {
    throw new Error(
      `動画が大きすぎます（最大 ${VIDEO_IMPORT_MAX_WIDTH}×${VIDEO_IMPORT_MAX_HEIGHT}）。実寸: ${width}×${height}`,
    );
  }
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
 * @description 書き出し総フレーム数（30fps）。duration 終端より先は作らない。
 * @param durationSec — ソースの長さ（秒）
 */
export function computeExportFrameCount(durationSec: number): number {
  const raw = Math.floor(durationSec * VIDEO_EXPORT_FPS + 1e-6);
  return Math.max(1, raw);
}
