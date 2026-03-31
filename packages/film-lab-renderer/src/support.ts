/**
 * WebGL2 Support Detection
 *
 * Hoisted from apps/web/src/shared/gl/support.ts for shared renderer consumers.
 */

export function isWebGL2Supported(): boolean {
  if (typeof document === "undefined") return false;

  const canvas = document.createElement("canvas");
  return canvas.getContext("webgl2") !== null;
}
