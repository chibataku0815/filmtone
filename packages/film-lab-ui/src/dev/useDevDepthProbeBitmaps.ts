/**
 * @fileoverview `FilmLabCanvas` の legacy depth-probe bitmap ロード hook です。
 *
 * @description
 * `?depthProbe=1|2` が付いているときだけ、事前バンドルした probe フレームを
 * decode してこの hook が返す ref に載せます。Shared runtime depth track
 * （`depthTrack` prop）が来ているときはそちらが優先されます（呼び出し側の
 * animate loop 側の優先順位はそのまま）。
 *
 * `useRef` + `useEffect`（deps: `[]`）の 2 hooks のみで完結する自己完結の
 * effect のため、`FilmLabCanvas` 本体からはこの 1 回の hook 呼び出しに
 * 置き換えても、他の effect との相対順序は変わりません。
 */
import { useEffect, useRef, type RefObject } from "react";
import {
  DEV_DEPTH_PROBE_DATA_URIS,
} from "../dev-depth-probe-data";
import { readDepthProbeFlag } from "./filmLabCanvasDevProbes";

/**
 * @returns 現在デコード済みの legacy depth-probe ビットマップ配列（無効時/未デコード時は null）。
 */
export function useDevDepthProbeBitmaps(): RefObject<ImageBitmap[] | null> {
  /**
   * Legacy debug fallback frames loaded from `?depthProbe=1|2`.
   */
  const depthProbeBitmapsRef = useRef<ImageBitmap[] | null>(null);

  /**
   * Legacy debug fallback: decode the pre-bundled probe frames when the URL
   * asks for `?depthProbe=1|2`. Shared runtime depth tracks still win.
   */
  useEffect(() => {
    if (!readDepthProbeFlag()) return;
    let cancelled = false;
    (async () => {
      try {
        const blobs = await Promise.all(
          DEV_DEPTH_PROBE_DATA_URIS.map((uri) => fetch(uri).then((r) => r.blob())),
        );
        const bitmaps = await Promise.all(blobs.map((b) => createImageBitmap(b)));
        if (cancelled) {
          bitmaps.forEach((b) => b.close());
          return;
        }
        depthProbeBitmapsRef.current = bitmaps;
        console.log(
          `[FilmLabCanvas] dev-depth-probe: loaded ${bitmaps.length} depth keyframes`,
        );
      } catch (err) {
        console.error("[FilmLabCanvas] dev-depth-probe: decode failed", err);
      }
    })();
    return () => {
      cancelled = true;
      depthProbeBitmapsRef.current?.forEach((b) => b.close());
      depthProbeBitmapsRef.current = null;
    };
  }, []);

  return depthProbeBitmapsRef;
}
