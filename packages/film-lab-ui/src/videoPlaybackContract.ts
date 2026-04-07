/**
 * @fileoverview 動画プレビュー（`HTMLVideoElement`）の **状態だけ** を型で共有します。
 *
 * @description
 * - life#75（Filmtone 動画トランスポート）で、キャンバスと UI を繋ぐための最小ペイロードです。
 * - 操作は `FilmLabCanvasRef` のメソッド（`videoPlaybackPlay` など）から行い、この型は **読み取り専用のスナップショット**です。
 *
 * @limitations
 * - `duration` が `NaN` の間は 0 を渡す実装に揃えます（UI は「0:00」と出せばよい）。
 */

/**
 * @description トランスポートバーが表示する再生状態。`hasVideo` が false のときはバーを出しません。
 */
export type VideoPlaybackRate = 1 | 2 | 3;

export type VideoPlaybackState = {
  /** @description ユーザー動画がキャンバスに載っているとき true（静止画・sample は false） */
  hasVideo: boolean;
  /** @description 可能性のあるときに限り、ポーズ中でない */
  isPlaying: boolean;
  /** @description 秒。`HTMLVideoElement.currentTime` */
  currentTime: number;
  /** @description 秒。未知のときは 0 */
  duration: number;
  /** @description 再生速度。1 / 2 / 3 の離散値 */
  playbackRate: VideoPlaybackRate;
};
