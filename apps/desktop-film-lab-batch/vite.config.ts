/**
 * Film Lab バッチ用 Vite 設定
 *
 * @overview Web Film Lab と同じ Viewport / MediaLoader を alias で参照し、デスクトップのレンダラだけをバンドルする。
 * @notes シェーダは `.ts` で export 済みのため raw ローダー不要。
 */
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(__dirname, "../web");

export default defineConfig({
  root: path.resolve(__dirname, "src/renderer"),
  base: "./",
  build: {
    outDir: path.resolve(__dirname, "dist/renderer"),
    emptyOutDir: true,
  },
  resolve: {
    alias: {
      "@film-lab": path.join(webRoot, "src/features/interactive/film-lab"),
      "@/shared/gl": path.join(webRoot, "src/shared/gl"),
    },
  },
});
