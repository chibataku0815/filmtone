/**
 * Renderer support detection & pixel ratio utilities.
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

let _webgpuSupportCache: boolean | null = null;
let _webgpuSupportInflight: Promise<boolean> | null = null;

/**
 * WebGPU adapter availability probe. Memoized across calls — the first
 * `navigator.gpu.requestAdapter()` result determines support for this
 * page lifetime. Returns `false` when `navigator.gpu` is absent (e.g.
 * non-browser contexts, unsupported Electron builds, or `?__test=0`
 * bypasses that null the API).
 */
export async function isWebGPUSupported(): Promise<boolean> {
  if (_webgpuSupportCache !== null) return _webgpuSupportCache;
  if (_webgpuSupportInflight) return _webgpuSupportInflight;

  _webgpuSupportInflight = (async () => {
    if (typeof navigator === "undefined") return false;
    const gpu = (navigator as Navigator & { gpu?: GPU }).gpu;
    if (!gpu) return false;
    try {
      const adapter = await gpu.requestAdapter();
      return adapter !== null;
    } catch {
      return false;
    }
  })();

  const result = await _webgpuSupportInflight;
  _webgpuSupportCache = result;
  _webgpuSupportInflight = null;
  return result;
}
