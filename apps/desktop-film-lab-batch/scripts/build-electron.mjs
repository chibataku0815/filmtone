/**
 * @file Electron の main / preload を esbuild でバンドルする
 * @overview package.json の scripts から呼びます。`FILM_LAB_DESKTOP_UPDATE_CHECK_URL` があルト main に埋め込みます。
 * @limitations preload には define を付けません（更新 URL は main のみ）。
 */
import * as esbuild from "esbuild";
import path from "node:path";
import { fileURLToPath } from "node:url";

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirPath = path.dirname(currentFilePath);
const desktopRootPath = path.resolve(currentDirPath, "..");

const embeddedUpdateCheckUrl =
  process.env.FILM_LAB_DESKTOP_UPDATE_CHECK_URL?.trim() ?? "";

const mainEntry = path.join(desktopRootPath, "electron", "main.ts");
const preloadEntry = path.join(desktopRootPath, "electron", "preload.ts");
const outMain = path.join(desktopRootPath, "dist-electron", "main.cjs");
const outPreload = path.join(desktopRootPath, "dist-electron", "preload.cjs");

await esbuild.build({
  entryPoints: [mainEntry],
  bundle: true,
  platform: "node",
  format: "cjs",
  outfile: outMain,
  external: ["electron"],
  define: {
    FILM_LAB_EMBEDDED_UPDATE_CHECK_URL: JSON.stringify(embeddedUpdateCheckUrl),
  },
});

await esbuild.build({
  entryPoints: [preloadEntry],
  bundle: true,
  platform: "node",
  format: "cjs",
  outfile: outPreload,
  external: ["electron"],
});
