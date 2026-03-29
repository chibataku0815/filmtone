/**
 * Film Lab デスクトップ — 動画書き出しの公開ポリシー
 *
 * @overview 公開製品の正は WebGL accurate。高速 ffmpeg 経路を将来再有効化しても、
 * 既定値は accurate のままにし、「高速・近似」は opt-in に留める。
 */

/**
 * @description 公開 UI の既定は常に WebGL accurate。
 * build-time flag の ON/OFF に関係なく、見た目一致のほうを初期選択にする。
 */
export function defaultVideoExportWebglAccurate(): boolean {
  return true;
}

/**
 * @description 高速経路を実行してよいのは、機能フラグが有効で、かつユーザーが accurate を明示的に外したときだけ。
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
