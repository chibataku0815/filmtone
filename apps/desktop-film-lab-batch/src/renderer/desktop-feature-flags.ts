/**
 * @fileoverview Film Lab デスクトップ（バッチ UI）向けの機能フラグ
 *
 * @overview リリース前に「まだ十分でない」機能を UI から隠しつつ、コードと IPC は残すために使う。
 * @limitations ビルド時定数。遠隔トグルにはしない（必要なら electron-store 等で別途）。
 */

/**
 * @description `false` のとき動画は **編集に近い WebGL 逐次のみ**（高速 ffmpeg 近似は UI に出さない）。
 * 実装コード（`video-export-ffmpeg-fast` 等）は検証・将来用にリポジトリに残す。
 */
export const ENABLE_FFMPEG_FAST_VIDEO_EXPORT = false;
