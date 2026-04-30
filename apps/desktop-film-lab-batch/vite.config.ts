/**
 * Film Lab デスクトップ — Vite（React + Tailwind + Web コンポーネント alias）
 *
 * @description ローカルでは `.env` 無しでも動くよう、`import.meta.env` の既定をここで埋める。
 * スマートルック UI は **明示 `VITE_FILM_LAB_SMART_LOOK_UI=true` 時のみ ON**（ペンディング中の既定は非表示）。
 * development のときだけ支援者スタブを既定 ON（スマートルックとは別）。
 */
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "../..");
const desktopPackageJson = JSON.parse(
  fs.readFileSync(path.resolve(__dirname, "package.json"), "utf-8"),
) as {
  version?: string;
};

/** @description よくあるローカル BFF。`VITE_FILM_LAB_API_ORIGIN` で上書き可。 */
const DEFAULT_BFF_ORIGIN = "http://127.0.0.1:3000";

/**
 * @description Desktop 向けに `import.meta.env` の実効値を決める（未設定なら既定）。
 * @param {string} mode - Vite の `development` | `production`
 * @param {NodeJS.ProcessEnv} env - `loadEnv` の結果
 */
function resolveDesktopFilmLabImportMeta(
  mode: string,
  env: Record<string, string>,
): {
  apiOrigin: string;
  assumeSupporter: string;
  smartLookUiFlag: string;
  smartLookRasterFlag: string;
} {
  const rawOrigin = env.VITE_FILM_LAB_API_ORIGIN?.trim() ?? "";
  const apiOrigin =
    rawOrigin.length > 0 ? rawOrigin.replace(/\/$/, "") : DEFAULT_BFF_ORIGIN;

  const assumeRaw = env.VITE_FILM_LAB_ASSUME_SUPPORTER?.trim().toLowerCase();
  let assumeSupporter: string;
  if (assumeRaw === "true") {
    assumeSupporter = "true";
  } else if (assumeRaw === "false") {
    assumeSupporter = "false";
  } else {
    assumeSupporter = mode === "development" ? "true" : "false";
  }

  /** @description opt-in のみ。未設定・false 以外の誤記はいったん OFF（Issue で再有効化手順を追う） */
  const uiRaw = env.VITE_FILM_LAB_SMART_LOOK_UI?.trim().toLowerCase();
  const smartLookUiFlag = uiRaw === "true" ? "true" : "";

  const rasterExplicit =
    env.VITE_FILM_LAB_SMART_LOOK_RASTER === "true" ||
    env.NEXT_PUBLIC_FILM_LAB_SMART_LOOK_RASTER === "true";
  const smartLookRasterFlag = rasterExplicit ? "true" : "";

  return {
    apiOrigin,
    assumeSupporter,
    smartLookUiFlag,
    smartLookRasterFlag,
  };
}

export { resolveDesktopFilmLabImportMeta };

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, path.resolve(__dirname), "");
  const resolved = resolveDesktopFilmLabImportMeta(mode, env);
  const {
    apiOrigin,
    assumeSupporter,
    smartLookUiFlag,
    smartLookRasterFlag,
  } = resolved;

  const viteSmartLookUiTruth = smartLookUiFlag === "true" ? "true" : "false";
  const viteSmartLookRasterTruth =
    smartLookRasterFlag === "true" ? "true" : "false";

  /**
   * @description Electron 起動時に `FILM_LAB_DEBUG_VIDEO_EXPORT=1` を付けると main と同じ条件で
   *   レンダラの WebCodecs bucket ログを有効にする（`process.env` は Vite 起動時に読む）。
   */
  const debugVideoExportTruth =
    process.env.FILM_LAB_DEBUG_VIDEO_EXPORT === "1" ||
    process.env.FILM_LAB_DEBUG_VIDEO_EXPORT === "true"
      ? "true"
      : "false";

  /**
   * @description 動画書き出しの各フレーム詳細ログは、明示時だけ有効にする。
   *   既定は quiet にして、bucket / profile / summary だけで観測する。
   */
  const verboseVideoExportTruth =
    process.env.FILM_LAB_VERBOSE_VIDEO_EXPORT === "1" ||
    process.env.FILM_LAB_VERBOSE_VIDEO_EXPORT === "true"
      ? "true"
      : "false";
  const webCodecsExportDisabled =
    process.env.FILM_LAB_DISABLE_WEBCODECS_EXPORT === "1" ||
    process.env.FILM_LAB_DISABLE_WEBCODECS_EXPORT === "true" ||
    process.env.FILM_LAB_ENABLE_WEBCODECS_EXPORT === "0" ||
    process.env.FILM_LAB_ENABLE_WEBCODECS_EXPORT === "false";
  const enableWebCodecsExportTruth = webCodecsExportDisabled ? "false" : "true";

  return {
    root: path.resolve(__dirname, "src/renderer"),
    base: "./",
    publicDir: path.resolve(repoRoot, "public"),
    define: {
      "import.meta.env.VITE_FILM_LAB_API_ORIGIN": JSON.stringify(apiOrigin),
      "import.meta.env.VITE_FILM_LAB_ASSUME_SUPPORTER":
        JSON.stringify(assumeSupporter),
      /** @description process-polyfill が参照してから feature-flags が読む（空マージで消さない） */
      "import.meta.env.VITE_FILM_LAB_SMART_LOOK_UI":
        JSON.stringify(viteSmartLookUiTruth),
      "import.meta.env.VITE_FILM_LAB_SMART_LOOK_RASTER":
        JSON.stringify(viteSmartLookRasterTruth),
      "process.env.NEXT_PUBLIC_FILM_LAB_SMART_LOOK_UI":
        JSON.stringify(smartLookUiFlag),
      "process.env.NEXT_PUBLIC_FILM_LAB_SMART_LOOK_RASTER":
        JSON.stringify(smartLookRasterFlag),
      "import.meta.env.VITE_FILM_LAB_DEBUG_VIDEO_EXPORT":
        JSON.stringify(debugVideoExportTruth),
      "import.meta.env.VITE_FILM_LAB_VERBOSE_VIDEO_EXPORT":
        JSON.stringify(verboseVideoExportTruth),
      "import.meta.env.VITE_FILM_LAB_ENABLE_WEBCODECS_EXPORT":
        JSON.stringify(enableWebCodecsExportTruth),
      "import.meta.env.VITE_FILMTONE_DESKTOP_VERSION": JSON.stringify(
        desktopPackageJson.version ?? "0.0.0",
      ),
      /**
       * @description Phase 1 T1-1: Filmtone backend select — desktop defaults to WebGPU.
       *   `WebGPUBackend` は dynamic import で載り、web ビルドでは `"webgl"` 固定により
       *   tree-shake される。desktop は WebGL へ silent downgrade せず、WebGPU
       *   bootstrap 失敗は caller 側で explicit error UI として扱う。
       */
      "import.meta.env.FILMTONE_BACKEND": JSON.stringify("webgpu"),
    },
    plugins: [react()],
    build: {
      outDir: path.resolve(__dirname, "dist/renderer"),
      emptyOutDir: true,
    },
    server: {
      /** @description `localhost` のみだと ::1 になり `wait-on http://127.0.0.1:5173` と Electron の URL がずれることがある */
      host: "127.0.0.1",
      port: 5173,
      /** @description 5173 占有時に勝手に別ポートへ逃げると Electron の URL とずれるので固定する */
      strictPort: true,
      fs: {
        allow: [repoRoot],
      },
    },
    resolve: {
      alias: {
        "@/shared/analytics": path.join(
          __dirname,
          "src/renderer/shims/shared-analytics.ts",
        ),
        "next/navigation": path.join(
          __dirname,
          "src/renderer/shims/next-navigation.ts",
        ),
      },
      dedupe: ["react", "react-dom"],
    },
  };
});
