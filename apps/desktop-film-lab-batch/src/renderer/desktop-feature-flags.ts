/**
 * @fileoverview Film Lab デスクトップ（バッチ UI）向けの機能フラグ
 *
 * @overview リリース前に「まだ十分でない」機能を UI から隠しつつ、コードと IPC は残すために使う。
 * @limitations ビルド時定数。遠隔トグルにはしない（必要なら electron-store 等で別途）。
 */

/**
 * @description `true` のときだけ「高速 ffmpeg（1 パス）」動画書き出しをユーザーが選べる。
 * `false` の間はチェックボックスを出さず、常に WebGL 逐次（プレビュー寄り・低速）のみ。
 * メインプロセスの `video-export-transcode-fast` や `video-export-grade-approx-vf` は温存する。
 */
export const ENABLE_FFMPEG_FAST_VIDEO_EXPORT = false;
