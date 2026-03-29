/**
 * Film Lab デスクトップ — 動画書き出しの公開ポリシー
 *
 * @overview 編集タブの見え方に寄せた書き出しを優先し、体験の既定は WebGL 逐次（編集画面どおり）に寄せる。
 * 速さ優先の高速 ffmpeg（近似）はオプションで、チェックを外して選ぶ。
 */

/**
 * @description 既定は編集画面どおり（WebGL 逐次）。`ENABLE_FFMPEG_FAST_VIDEO_EXPORT` が false のときは
 * UI 側で WebGL 固定のままなので、この値は実質上書きされないが矛盾は起きない。
 */
export function defaultVideoExportWebglAccurate(): boolean {
  return true;
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
