/**
 * @file Electron の main / preload を esbuild でバンドルする
 * @overview package.json の scripts から呼びます。`FILM_LAB_DESKTOP_UPDATE_CHECK_URL` があルト main に埋め込みます。
 * @limitations preload には define を付けません（更新 URL は main のみ）。
 */
import * as esbuild from "esbuild";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirPath = path.dirname(currentFilePath);
const desktopRootPath = path.resolve(currentDirPath, "..");
const workspaceRootPath = path.resolve(desktopRootPath, "../..");

function readEnvVarFromFile(filePath, key) {
  let text = "";
  try {
    text = fs.readFileSync(filePath, "utf8");
  } catch {
    return "";
  }
  const matcher = new RegExp(`^${key}=(.*)$`, "m");
  const match = text.match(matcher);
  if (!match) {
    return "";
  }
  let value = match[1]?.trim() ?? "";
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1);
  }
  return value.trim();
}

function resolveEmbeddedUpdateCheckUrl() {
  const fromEnv = process.env.FILM_LAB_DESKTOP_UPDATE_CHECK_URL?.trim() ?? "";
  if (fromEnv.length > 0) {
    return fromEnv;
  }
  const candidateEnvPaths = [
    path.join(workspaceRootPath, ".env.local"),
    path.join(workspaceRootPath, ".env.production.local"),
    path.join(desktopRootPath, ".env.local"),
    path.join(desktopRootPath, ".env.production.local"),
  ];
  for (const envPath of candidateEnvPaths) {
    const value = readEnvVarFromFile(
      envPath,
      "FILM_LAB_DESKTOP_UPDATE_CHECK_URL",
    );
    if (value.length > 0) {
      return value;
    }
  }
  return "";
}

const embeddedUpdateCheckUrl = resolveEmbeddedUpdateCheckUrl();

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
