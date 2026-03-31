/**
 * WebGL2 Support Detection & Pixel Ratio Utility
 *
 * Hoisted from apps/web/src/shared/gl/ for shared renderer consumers.
 */

export function isWebGL2Supported(): boolean {
  if (typeof document === "undefined") return false;

  const canvas = document.createElement("canvas");
  return canvas.getContext("webgl2") !== null;
}

/**
 * デバイスに応じたピクセル比を取得（モバイルや低電力デバイスでは制限をかける）
 */
export function getOptimalPixelRatio(maxRatio: number = 1.5): number {
  if (typeof window === "undefined") return 1;
  return Math.min(window.devicePixelRatio, maxRatio);
}
