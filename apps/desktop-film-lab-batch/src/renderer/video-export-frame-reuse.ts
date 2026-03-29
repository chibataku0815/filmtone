/**
 * @fileoverview WebGL 動画書き出しで、出力フレームが同じソースフレームに相当するか判定する純関数
 *
 * @overview trusted CFR メタがあるときだけインデックスを返し、再利用判定に使う。
 * @limitations 実デコード順と ffprobe メタのずれは呼び出し側のフォールバックで吸収する。
 */

/**
 * @description 時刻とソース fps からソースフレーム番号（0 始まりの「何枚目」相当）
 * @param timeSec - 動画内秒
 * @param sourceFrameRate - ffprobe 信任済み fps
 * @param trusted - メタが信頼できるか
 */
export function computeTargetSourceFrameIndex(
  timeSec: number,
  sourceFrameRate: number | null,
  trusted: boolean,
): number | null {
  if (!trusted || sourceFrameRate === null || !Number.isFinite(timeSec)) {
    return null;
  }
  return Math.floor(timeSec * sourceFrameRate + 1e-6);
}

/**
 * @description 直前デコードと同じソースフレームならシーク＋ゲートを省略してよい
 */
export function shouldReuseDecodedSourceFrame(
  lastIndex: number | null,
  targetIndex: number | null,
): boolean {
  return (
    targetIndex !== null && lastIndex !== null && lastIndex === targetIndex
  );
}
