/**
 * Film Lab デスクトップ — 動画書き出しの公開ポリシー
 *
 * @overview 品質の参照として WebGL accurate は残すが、体験の既定は高速 ffmpeg（近似）に寄せる。
 * プレビュー寄りの完全一致が必要なときだけユーザーが WebGL を選ぶ。
 */

/**
 * @description 既定は WebGL を使わない（高速 ffmpeg）。`ENABLE_FFMPEG_FAST_VIDEO_EXPORT` が false のときは
 * UI 側で WebGL 固定になるため、この値は実質上書きされる。
 */
export function defaultVideoExportWebglAccurate(): boolean {
  return false;
}

/**
 * @description 高速経路を実行してよいのは、機能フラグが有効で、かつ WebGL 正確モードがオフのとき。
 */
export function shouldUseFastVideoExport(options: {
  fastVideoExportEnabled: boolean;
  videoExportWebglAccurate: boolean;
}): boolean {
  return (
    options.fastVideoExportEnabled &&
    !options.videoExportWebglAccurate
  );
}
