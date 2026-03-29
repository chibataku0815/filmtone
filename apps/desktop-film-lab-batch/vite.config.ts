/**
 * Film Lab デスクトップ — Vite（React + Tailwind + Web コンポーネント alias）
 */
import path from "node:path";
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(__dirname, "../web");

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, path.resolve(__dirname), "");
  const smartLookUi =
    env.VITE_FILM_LAB_SMART_LOOK_UI === "true" ? "true" : "";

  return {
  root: path.resolve(__dirname, "src/renderer"),
  base: "./",
  publicDir: path.resolve(webRoot, "public"),
  define: {
    "process.env.NEXT_PUBLIC_FILM_LAB_SMART_LOOK_UI": JSON.stringify(smartLookUi),
  },
  plugins: [react()],
  build: {
    outDir: path.resolve(__dirname, "dist/renderer"),
    emptyOutDir: true,
  },
  server: {
    port: 5173,
    fs: {
      allow: [webRoot, path.resolve(__dirname, "..")],
    },
  },
  resolve: {
    alias: {
      "@film-lab": path.join(webRoot, "src/features/interactive/film-lab"),
      "@/shared/gl": path.join(webRoot, "src/shared/gl"),
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
