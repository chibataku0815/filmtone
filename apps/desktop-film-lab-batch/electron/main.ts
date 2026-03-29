/**
 * Film Lab バッチ — Electron メインプロセス
 *
 * @overview フォルダ選択とファイルの読み書きだけを担い、GPU はレンダラ（Chromium）に任せる。
 * @limitations パス検証は最小限。信頼できるローカル用途のスパイク向け。
 *
 * @description 設定は electron-store（userData 内 JSON）。ウィンドウ矩形と最後に選んだ入出力フォルダを覚える。
 */
import { app, BrowserWindow, dialog, ipcMain, protocol } from "electron";
import { existsSync } from "node:fs";
import { filmLabParamsSchema, type Params } from "film-lab-core";
import Store from "electron-store";
import { execFile, spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { createReadStream } from "node:fs";
import fs from "node:fs/promises";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import os from "node:os";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { promisify } from "node:util";

import { buildGradeApproximationVF } from "./video-export-grade-approx-vf";
import {
  FILM_LAB_VIDEO_PROTOCOL,
  absolutePathToVideoSrcUrl,
  buildFfmpegFastTranscodeArgs,
  parseFastTranscodeRequest,
} from "./video-export-fast-contract";
import {
  guessVideoContentType,
  parseHttpByteRange,
} from "./video-src-protocol";

const execFileAsync = promisify(execFile);

/**
 * @description Vite dev（http://127.0.0.1:5173）では `<video src="file://...">` が Chromium の URL safety で拒否される。本スキームでメインプロセス経由配信し、loadFile 本番とも同じ経路にそろえる。
 * @limitations パスは `path-to-file-url` IPC 経由の絶対パスのみ想定（ユーザー選択・ステージング済みファイル）。
 */
protocol.registerSchemesAsPrivileged([
  {
    scheme: FILM_LAB_VIDEO_PROTOCOL,
    privileges: {
      secure: true,
      standard: true,
      supportFetchAPI: true,
      corsEnabled: true,
      stream: true,
    },
  },
]);

const IMAGE_EXT = new Set([".jpg", ".jpeg", ".png"]);

/**
 * @description ffmpeg 子プロセスと stderr のバッファ（動画書き出しは同時に 1 本まで）
 */
type FfmpegVideoExportSession = {
  child: ChildProcessWithoutNullStreams;
  stderrLines: string[];
};

let activeVideoExport: FfmpegVideoExportSession | null = null;

/**
 * @description 高速トランスコード専用の子プロセス（rawvideo パイプとは別）。中断 IPC から kill する。
 */
let activeFastTranscodeChild: ChildProcessWithoutNullStreams | null = null;

/**
 * @description 進行中の ffmpeg を潰して参照を捨てる。レンダラが異常終了したあとに残るゾンビ対策。
 * @param reason ログ用（ターミナル）
 */
/**
 * @description 単発 ffmpeg（高速トランスコード）を kill する。
 * @param reason ログ用
 */
function disposeActiveFastTranscode(reason: string): void {
  const child = activeFastTranscodeChild;
  if (child == null) {
    return;
  }
  activeFastTranscodeChild = null;
  console.warn(`[film-lab-desktop] disposeActiveFastTranscode: ${reason}`);
  try {
    child.kill("SIGKILL");
  } catch {
    /* 既に終了 */
  }
}

function disposeActiveVideoExport(reason: string): void {
  const sess = activeVideoExport;
  if (sess == null) {
    return;
  }
  activeVideoExport = null;
  console.warn(`[film-lab-desktop] disposeActiveVideoExport: ${reason}`);
  try {
    sess.child.stdin?.destroy();
  } catch {
    /* stdin 欠如時など */
  }
  try {
    sess.child.kill("SIGKILL");
  } catch {
    /* 既に終了 */
  }
}

/**
 * @description 動画出力の stderr / IPC を増やすとき true（ターミナルに出す。UI ログとは別）
 */
const DEBUG_VIDEO_EXPORT_MAIN =
  process.env.FILM_LAB_DEBUG_VIDEO_EXPORT === "1" ||
  process.env.FILM_LAB_DEBUG_VIDEO_EXPORT === "true";

/**
 * @description build 済み Desktop を自動起動し、Smart Look UI が pending のまま hidden かを確認して終了する。
 */
const DESKTOP_SMOKE_PENDING =
  process.env.FILM_LAB_DESKTOP_SMOKE_PENDING === "1" ||
  process.env.FILM_LAB_DESKTOP_SMOKE_PENDING === "true";

/**
 * @description デスクトップアプリ用の永続キー（型で書き忘れを防ぐ）
 */
type DesktopFilmLabSettings = {
  /** @description 前回終了時のウィンドウ bounds */
  windowBounds?: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  /** @description 入力フォルダ選択の最後のパス（存在しなければ無視） */
  lastInputDir: string | null;
  /** @description 出力フォルダ選択の最後のパス */
  lastOutputDir: string | null;
};

/**
 * @description アプリ設定ストア。バッチ再開 JSON とは別ファイル。
 */
const desktopSettingsStore = new Store<DesktopFilmLabSettings>({
  name: "film-lab-desktop-settings",
  defaults: {
    lastInputDir: null,
    lastOutputDir: null,
  },
});

/** @description バッチ再開用セッション JSON（レンダラが V1 形で保存） */
const BATCH_SESSION_BASENAME = "film-lab-batch-session.json";

/**
 * @description app ready 後に呼ぶ。userData 配下のセッションファイル絶対パス。
 */
function batchSessionFilePath(): string {
  return path.join(app.getPath("userData"), BATCH_SESSION_BASENAME);
}

function isImageFile(fileName: string): boolean {
  const lower = fileName.toLowerCase();
  const ext = path.extname(lower);
  return IMAGE_EXT.has(ext);
}

/**
 * @description ffprobe の JSON から動画ストリームと尺・音声有無を取り出す
 * @throws ffprobe 失敗時や動画ストリーム欠如時
 */
async function ffprobeVideoMeta(absPath: string): Promise<{
  width: number;
  height: number;
  durationSec: number;
  hasAudio: boolean;
  /** @description 先頭の動画ストリームの codec_name（HEVC 不可など切り分け用） */
  videoCodec: string;
}> {
  let stdout: string;
  try {
    const r = await execFileAsync(
      "ffprobe",
      [
        "-v",
        "error",
        "-show_entries",
        "stream=codec_type,width,height,codec_name",
        "-show_entries",
        "format=duration",
        "-of",
        "json",
        absPath,
      ],
      { maxBuffer: 10 * 1024 * 1024 },
    );
    stdout = r.stdout as string;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(
      `ffprobe 実行失敗（PATH に ffmpeg/ffprobe がありますか？）: ${msg}`,
    );
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(stdout) as unknown;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(`ffprobe JSON 解析失敗: ${msg}`);
  }

  if (typeof parsed !== "object" || parsed === null) {
    throw new Error("ffprobe JSON がオブジェクトではありません");
  }
  const root = parsed as { streams?: unknown; format?: unknown };
  const streams = Array.isArray(root.streams) ? root.streams : [];
  let width = 0;
  let height = 0;
  let hasAudio = false;
  let videoCodec = "";
  for (const s of streams) {
    if (typeof s !== "object" || s === null) continue;
    const o = s as Record<string, unknown>;
    if (o.codec_type === "audio") {
      hasAudio = true;
      continue;
    }
    if (o.codec_type === "video" && width === 0) {
      const w = typeof o.width === "number" ? o.width : Number(o.width);
      const h = typeof o.height === "number" ? o.height : Number(o.height);
      if (Number.isFinite(w) && Number.isFinite(h) && w > 0 && h > 0) {
        width = w;
        height = h;
        const cn = o.codec_name;
        videoCodec =
          typeof cn === "string" && cn.length > 0 ? cn : "";
      }
    }
  }
  if (width <= 0 || height <= 0) {
    throw new Error("ffprobe: 動画ストリームの幅・高さが取得できませんでした");
  }

  const fmt =
    typeof root.format === "object" && root.format !== null
      ? (root.format as Record<string, unknown>)
      : {};
  const durRaw = fmt.duration;
  const durationSec =
    typeof durRaw === "number"
      ? durRaw
      : typeof durRaw === "string"
        ? Number.parseFloat(durRaw)
        : Number.NaN;
  if (!Number.isFinite(durationSec) || durationSec <= 0) {
    throw new Error("ffprobe: duration が不正です");
  }

  return { width, height, durationSec, hasAudio, videoCodec };
}

/**
 * @description プラットフォーム別のビデオコーデック引数（スループット優先）
 */
function ffmpegVideoCodecArgs(): string[] {
  if (process.platform === "darwin") {
    return ["-c:v", "h264_videotoolbox", "-b:v", "12M", "-allow_sw", "1"];
  }
  return ["-c:v", "libx264", "-preset", "veryfast", "-crf", "21"];
}

function buildFfmpegRawvideoExportArgs(opts: {
  width: number;
  height: number;
  fps: number;
  hasAudio: boolean;
  inputVideoPath: string;
  outputVideoPath: string;
}): string[] {
  const { width, height, fps, hasAudio, inputVideoPath, outputVideoPath } = opts;
  const videoCodec = ffmpegVideoCodecArgs();
  const head: string[] = [
    "-hide_banner",
    "-loglevel",
    "error",
    "-y",
    "-f",
    "rawvideo",
    "-pix_fmt",
    "rgba",
    "-s",
    `${width}x${height}`,
    "-r",
    String(fps),
    "-i",
    "pipe:0",
  ];
  if (hasAudio) {
    head.push(
      "-i",
      inputVideoPath,
      "-map",
      "0:v:0",
      "-map",
      "1:a:0",
      "-shortest",
    );
  } else {
    head.push("-an");
  }
  head.push(...videoCodec);
  if (hasAudio) {
    head.push("-c:a", "copy");
  }
  head.push(outputVideoPath);
  return head;
}

async function listImagePathsInDir(dir: string): Promise<string[]> {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const out: string[] = [];
  for (const e of entries) {
    if (!e.isFile()) continue;
    if (!isImageFile(e.name)) continue;
    out.push(path.join(dir, e.name));
  }
  return out.sort((a, b) => path.basename(a).localeCompare(path.basename(b)));
}

/**
 * @description フォルダが実在するか確認し、ダイアログの defaultPath に使える文字列だけ返す。
 */
async function resolveExistingDir(
  dir: string | null | undefined,
): Promise<string | undefined> {
  if (dir == null || typeof dir !== "string" || dir.length === 0) {
    return undefined;
  }
  try {
    const st = await fs.stat(dir);
    if (st.isDirectory()) return dir;
  } catch {
    /* パス無効 */
  }
  return undefined;
}

/**
 * @description メインは `dist-electron/main.cjs` なので `__dirname` は `dist-electron`。その1つ上の `resources/` に 1024px PNG を置く。
 * @returns Film Lab シンボルの絶対パス
 */
function resolveFilmLabIconPath(): string {
  return path.join(__dirname, "..", "resources", "film-lab-icon.png");
}

/**
 * @description macOS では開発時も `.app` の `Info.plist` アイコンが効かないため Dock が Electron 標準のままになる。`app.dock.setIcon` で差し替える。
 * @limitations Windows はタスクバーが主に exe の埋め込みアイコン頼み。Linux は将来 `BrowserWindow.icon` 中心。
 */
function applyDockIconIfMac(): void {
  if (process.platform !== "darwin") {
    return;
  }
  const iconPath = resolveFilmLabIconPath();
  if (!existsSync(iconPath)) {
    console.warn(
      `[film-lab-desktop] main.applyDockIconIfMac: アイコン PNG が無いためスキップ — path=${iconPath}`,
    );
    return;
  }
  try {
    app.dock.setIcon(iconPath);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.warn(
      `[film-lab-desktop] main.applyDockIconIfMac: app.dock.setIcon 失敗 — path=${iconPath} — ${msg}`,
    );
  }
}

function createWindow(): BrowserWindow {
  /**
   * @description ローカルで Vite が動いているとき、ウィンドウは `file://` ではなくこの URL を開く。
   * `FILM_LAB_DESKTOP_RENDERER_URL` を優先（製品向けの名前）。従来の `VITE_DEV_SERVER_URL` もそのまま使える。
   */
  const rendererHotReloadUrl =
    process.env.FILM_LAB_DESKTOP_RENDERER_URL?.trim() ||
    process.env.VITE_DEV_SERVER_URL?.trim() ||
    "";

  const savedBounds = desktopSettingsStore.get("windowBounds");
  const hasSavedSize =
    savedBounds &&
    Number.isFinite(savedBounds.width) &&
    Number.isFinite(savedBounds.height) &&
    savedBounds.width >= 400 &&
    savedBounds.height >= 320;

  const iconPath = resolveFilmLabIconPath();
  const iconOption = existsSync(iconPath) ? { icon: iconPath } : {};

  /**
   * @description `backgroundColor` をダークにしておくと、WebKit スクロールバー周りやロード直後にライトの下地が見えにくい（Radix slate-1 に近い色）。
   */
  const win = new BrowserWindow({
    backgroundColor: "#0d0d0f",
    show: !DESKTOP_SMOKE_PENDING,
    ...(hasSavedSize
      ? {
          x: savedBounds!.x,
          y: savedBounds!.y,
          width: savedBounds!.width,
          height: savedBounds!.height,
        }
      : { width: 960, height: 720 }),
    ...iconOption,
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  win.on("close", () => {
    if (!win.isDestroyed()) {
      const b = win.getBounds();
      desktopSettingsStore.set("windowBounds", b);
    }
  });

  if (rendererHotReloadUrl.length > 0) {
    void win.loadURL(rendererHotReloadUrl);
    // win.webContents.openDevTools();
  } else {
    void win.loadFile(
      path.join(__dirname, "../dist/renderer/index.html"),
    );
  }

  return win;
}

async function runPendingRuntimeSmoke(win: BrowserWindow): Promise<void> {
  try {
    await new Promise<void>((resolve, reject) => {
      const handleFinish = (): void => {
        cleanup();
        resolve();
      };

      const handleFail = (
        _event: Electron.Event,
        code: number,
        description: string,
        validatedUrl: string,
      ): void => {
        cleanup();
        reject(
          new Error(
            `Desktop smoke failed to load renderer: code=${code} description=${description} url=${validatedUrl}`,
          ),
        );
      };

      const timeoutId = setTimeout(() => {
        cleanup();
        reject(new Error("Desktop smoke timed out before the renderer finished loading"));
      }, 30_000);

      const cleanup = (): void => {
        clearTimeout(timeoutId);
        win.webContents.removeListener("did-finish-load", handleFinish);
        win.webContents.removeListener("did-fail-load", handleFail);
      };

      if (!win.webContents.isLoadingMainFrame()) {
        cleanup();
        resolve();
        return;
      }

      win.webContents.on("did-finish-load", handleFinish);
      win.webContents.on("did-fail-load", handleFail);
    });

    await new Promise((resolve) => setTimeout(resolve, 1_000));

    const result = (await win.webContents.executeJavaScript(
      `(() => {
        const bodyText = document.body?.innerText ?? "";
        const hasCanvasOpen = Boolean(document.querySelector('[data-testid="film-lab-open"]'));
        const matchedSmartLookText = [
          "見本に色味を合わせる（AI・beta）",
          "Match colors to a sample (AI, beta)",
          "見本の写真を選ぶ",
          "Pick sample photo",
          "見本に合わせる",
          "Match sample look",
        ].filter((text) => bodyText.includes(text));

        return {
          hasCanvasOpen,
          matchedSmartLookText,
        };
      })()`,
      true,
    )) as {
      hasCanvasOpen: boolean;
      matchedSmartLookText: string[];
    };

    if (!result.hasCanvasOpen) {
      throw new Error("Desktop smoke did not find the main Film Lab canvas");
    }
    if (result.matchedSmartLookText.length > 0) {
      throw new Error(
        `Desktop smoke found Smart Look UI unexpectedly: ${result.matchedSmartLookText.join(", ")}`,
      );
    }

    console.log(
      "[film-lab-desktop] smoke: pending Smart Look UI stays hidden in Desktop runtime.",
    );
    app.exitCode = 0;
    app.quit();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[film-lab-desktop] smoke: ${message}`);
    app.exitCode = 1;
    app.quit();
  }
}

app.whenReady().then(() => {
  console.log(
    "[film-lab-desktop] main: 動画 src は film-lab-video スキーム（path-to-file-url）。ログが file: なら bun run build:electron 未反映。",
  );
  applyDockIconIfMac();
  protocol.handle(FILM_LAB_VIDEO_PROTOCOL, async (request) => {
    let abs: string;
    let fileSize = 0;
    try {
      const u = new URL(request.url);
      const raw = u.searchParams.get("path");
      if (raw == null || raw.length === 0) {
        return new Response("film-lab-video: path query が空です", {
          status: 400,
        });
      }
      abs = path.resolve(decodeURIComponent(raw));
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return new Response(`film-lab-video: URL 解析失敗 — ${msg}`, {
        status: 400,
      });
    }
    try {
      const st = await fs.stat(abs);
      if (!st.isFile()) {
        return new Response(`film-lab-video: ファイルではありません — ${abs}`, {
          status: 404,
        });
      }
      fileSize = st.size;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return new Response(`film-lab-video: パス不正 — ${abs} — ${msg}`, {
        status: 404,
      });
    }
    try {
      const range = parseHttpByteRange(request.headers.get("range"), fileSize);
      const contentType = guessVideoContentType(abs);

      if (request.headers.has("range") && range == null) {
        const headers = new Headers({
          "Content-Range": `bytes */${fileSize}`,
          "Access-Control-Allow-Origin": "*",
          "Accept-Ranges": "bytes",
        });
        return new Response("film-lab-video: Range 不正", {
          status: 416,
          headers,
        });
      }

      const stream = createReadStream(
        abs,
        range
          ? { start: range.start, end: range.end }
          : undefined,
      );
      const headers = new Headers({
        "Access-Control-Allow-Origin": "*",
        "Accept-Ranges": "bytes",
        "Content-Type": contentType,
        "Content-Length": String(
          range ? range.end - range.start + 1 : fileSize,
        ),
      });
      if (range) {
        headers.set(
          "Content-Range",
          `bytes ${range.start}-${range.end}/${fileSize}`,
        );
      }
      return new Response(Readable.toWeb(stream) as ReadableStream, {
        status: range ? 206 : 200,
        headers,
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return new Response(`film-lab-video: ストリーム配信失敗 — ${abs} — ${msg}`, {
        status: 500,
      });
    }
  });

  const mainWindow = createWindow();
  if (DESKTOP_SMOKE_PENDING) {
    void runPendingRuntimeSmoke(mainWindow);
  }
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

ipcMain.handle("desktop-prefs-get", async () => {
  const lastInputDir =
    (await resolveExistingDir(desktopSettingsStore.get("lastInputDir"))) ??
    null;
  const lastOutputDir =
    (await resolveExistingDir(desktopSettingsStore.get("lastOutputDir"))) ??
    null;
  return { lastInputDir, lastOutputDir };
});

/**
 * @description レンダラから最終フォルダを保存（バッチ実行開始時に同期する用）
 */
ipcMain.handle("desktop-prefs-set", async (_evt, payload: unknown) => {
  if (!payload || typeof payload !== "object" || payload === null) {
    throw new TypeError("desktop-prefs-set: payload がオブジェクトではありません");
  }
  const o = payload as Record<string, unknown>;
  if (typeof o.lastInputDir === "string" && o.lastInputDir.length > 0) {
    desktopSettingsStore.set("lastInputDir", o.lastInputDir);
  }
  if (typeof o.lastOutputDir === "string" && o.lastOutputDir.length > 0) {
    desktopSettingsStore.set("lastOutputDir", o.lastOutputDir);
  }
});

ipcMain.handle("pick-input-dir", async () => {
  const defaultPath = await resolveExistingDir(
    desktopSettingsStore.get("lastInputDir"),
  );
  const r = await dialog.showOpenDialog({
    properties: ["openDirectory", "createDirectory"],
    defaultPath,
  });
  if (r.canceled || r.filePaths.length === 0) return null;
  const chosen = r.filePaths[0]!;
  desktopSettingsStore.set("lastInputDir", chosen);
  return chosen;
});

ipcMain.handle("pick-output-dir", async () => {
  const defaultPath = await resolveExistingDir(
    desktopSettingsStore.get("lastOutputDir"),
  );
  const r = await dialog.showOpenDialog({
    properties: ["openDirectory", "createDirectory"],
    defaultPath,
  });
  if (r.canceled || r.filePaths.length === 0) return null;
  const chosen = r.filePaths[0]!;
  desktopSettingsStore.set("lastOutputDir", chosen);
  return chosen;
});

ipcMain.handle("pick-grade-json", async () => {
  const defaultPath =
    (await resolveExistingDir(desktopSettingsStore.get("lastInputDir"))) ??
    (await resolveExistingDir(desktopSettingsStore.get("lastOutputDir")));
  const r = await dialog.showOpenDialog({
    properties: ["openFile"],
    filters: [{ name: "JSON", extensions: ["json"] }],
    defaultPath,
  });
  if (r.canceled || r.filePaths.length === 0) return null;
  return r.filePaths[0]!;
});

ipcMain.handle("list-images", async (_evt, dir: string) => {
  if (typeof dir !== "string" || dir.length === 0) {
    throw new TypeError("pick-input-dir: list-images(dir) — dir が空です");
  }
  return listImagePathsInDir(dir);
});

ipcMain.handle("read-file-utf8", async (_evt, filePath: string) => {
  if (typeof filePath !== "string") {
    throw new TypeError("read-file-utf8: filePath が文字列ではありません");
  }
  return fs.readFile(filePath, "utf-8");
});

ipcMain.handle("read-file-buffer", async (_evt, filePath: string) => {
  if (typeof filePath !== "string") {
    throw new TypeError("read-file-buffer: filePath が文字列ではありません");
  }
  const buf = await fs.readFile(filePath);
  return new Uint8Array(buf);
});

ipcMain.handle(
  "read-cube-relative-to-grade",
  async (_evt, gradeJsonPath: string, relPath: string) => {
    if (typeof gradeJsonPath !== "string" || typeof relPath !== "string") {
      throw new TypeError(
        "read-cube-relative-to-grade: gradeJsonPath / relPath が不正です",
      );
    }
    const abs = path.resolve(path.dirname(gradeJsonPath), relPath);
    return fs.readFile(abs, "utf-8");
  },
);

ipcMain.handle("batch-session-read", async () => {
  const target = batchSessionFilePath();
  try {
    const txt = await fs.readFile(target, "utf-8");
    return JSON.parse(txt) as unknown;
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    if (err.code === "ENOENT") return null;
    throw e;
  }
});

ipcMain.handle("batch-session-write", async (_evt, payload: unknown) => {
  if (payload === undefined) {
    throw new TypeError("batch-session-write: payload が undefined です");
  }
  const target = batchSessionFilePath();
  await fs.writeFile(target, JSON.stringify(payload, null, 2), "utf-8");
});

ipcMain.handle("batch-session-clear", async () => {
  const target = batchSessionFilePath();
  try {
    await fs.unlink(target);
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    if (err.code === "ENOENT") return;
    throw e;
  }
});

ipcMain.handle(
  "write-output-file",
  async (
    _evt,
    payload: { outputDir: string; fileName: string; data: Uint8Array },
  ) => {
    const { outputDir, fileName, data } = payload;
    if (
      typeof outputDir !== "string" ||
      typeof fileName !== "string" ||
      !(data instanceof Uint8Array)
    ) {
      throw new TypeError(
        "write-output-file: outputDir / fileName / data が不正です",
      );
    }
    const safeName = path.basename(fileName);
    const target = path.join(outputDir, safeName);
    await fs.mkdir(outputDir, { recursive: true });
    await fs.writeFile(target, Buffer.from(data));
    return target;
  },
);

ipcMain.handle("path-to-file-url", async (_evt, filePath: string) => {
  if (typeof filePath !== "string" || filePath.length === 0) {
    throw new TypeError("path-to-file-url: filePath が空です");
  }
  const abs = path.resolve(filePath);
  try {
    const st = await fs.stat(abs);
    if (!st.isFile()) {
      throw new Error(`path-to-file-url: ファイルではありません — ${abs}`);
    }
  } catch (e) {
    if (e instanceof Error && e.message.startsWith("path-to-file-url:")) {
      throw e;
    }
    throw new Error(`path-to-file-url: ファイルがありません — ${abs}`);
  }
  return absolutePathToVideoSrcUrl(abs);
});

ipcMain.handle("pick-input-video-file", async () => {
  const defaultPath = await resolveExistingDir(
    desktopSettingsStore.get("lastOutputDir"),
  );
  const r = await dialog.showOpenDialog({
    properties: ["openFile"],
    filters: [
      {
        name: "Video",
        extensions: ["mp4", "mov", "m4v", "webm", "mkv"],
      },
    ],
    defaultPath,
  });
  if (r.canceled || r.filePaths.length === 0) return null;
  return r.filePaths[0]!;
});

ipcMain.handle("video-export-probe", async (_evt, filePath: string) => {
  if (typeof filePath !== "string" || filePath.length === 0) {
    throw new TypeError("video-export-probe: filePath が空です");
  }
  const abs = path.resolve(filePath);
  return ffprobeVideoMeta(abs);
});

/**
 * @description 動画を WebGL せず ffmpeg 1 発で FHD 化（+ 任意 LUT3D）。速度優先・プレビューとは一致しない。
 */
ipcMain.handle("video-export-transcode-fast", async (_evt, payload: unknown) => {
  disposeActiveVideoExport("高速トランスコード直前");
  disposeActiveFastTranscode("再入前掃除");

  const {
    inputVideoPath,
    outputDir,
    outputFileName,
    width,
    height,
    fps,
    hasAudio,
    lutCubeAbsPath: lutRaw,
    gradeParams,
  } = parseFastTranscodeRequest(payload);

  const inAbs = path.resolve(inputVideoPath);
  const safeName = path.basename(outputFileName);
  const outputVideoPath = path.join(outputDir, safeName);
  let lutResolved: string | null = null;
  if (lutRaw.length > 0) {
    const lut = path.resolve(lutRaw);
    try {
      const st = await fs.stat(lut);
      if (!st.isFile()) {
        throw new Error("LUT がファイルではありません");
      }
      lutResolved = lut;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new Error(`video-export-transcode-fast: LUT パス不正 — ${lut} — ${msg}`);
    }
  }

  await fs.mkdir(outputDir, { recursive: true });

  const ffArgs = buildFfmpegFastTranscodeArgs({
    inputVideoPath: inAbs,
    outputVideoPath,
    width,
    height,
    fps,
    hasAudio,
    lutCubeAbsPath: lutResolved,
    gradeParams,
    videoCodecArgs: ffmpegVideoCodecArgs(),
  });

  let child: ChildProcessWithoutNullStreams;
  try {
    child = spawn("ffmpeg", ffArgs, {
      stdio: ["ignore", "ignore", "pipe"],
    }) as ChildProcessWithoutNullStreams;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(`video-export-transcode-fast: ffmpeg spawn 失敗 — ${msg}`);
  }

  const stderrLines: string[] = [];
  child.stderr?.on("data", (chunk: Buffer) => {
    stderrLines.push(chunk.toString("utf8"));
  });
  child.on("error", (err) => {
    stderrLines.push(`spawn error: ${err.message}`);
  });

  activeFastTranscodeChild = child;
  console.log(
    `[film-lab-desktop] ffmpeg 高速トランスコード ${width}x${height}@${fps} grade≈${gradeParams ? "yes" : "no"} LUT=${lutResolved ? "yes" : "no"} → ${outputVideoPath}`,
  );
  if (DEBUG_VIDEO_EXPORT_MAIN) {
    console.log(`[film-lab-desktop] ffmpeg fast argv: ${JSON.stringify(ffArgs)}`);
  }

  const code: number | null = await new Promise((resolve) => {
    child.on("close", (c) => resolve(c));
  });
  activeFastTranscodeChild = null;

  return {
    code,
    stderrTail: stderrLines.join("").slice(-8000),
    outputVideoPath,
  };
});

ipcMain.handle("video-export-start", async (_evt, payload: unknown) => {
  disposeActiveFastTranscode("rawvideo 直前");
  if (activeVideoExport !== null) {
    disposeActiveVideoExport(
      "新規 video-export-start の前に前回セッションを破棄（ゾンビ・二重開始防止）",
    );
  }
  if (!payload || typeof payload !== "object" || payload === null) {
    throw new TypeError("video-export-start: payload が不正です");
  }
  const o = payload as Record<string, unknown>;
  const inputVideoPath =
    typeof o.inputVideoPath === "string" ? o.inputVideoPath : "";
  const outputDir = typeof o.outputDir === "string" ? o.outputDir : "";
  const outputFileName =
    typeof o.outputFileName === "string" ? o.outputFileName : "";
  const width = typeof o.width === "number" ? o.width : 0;
  const height = typeof o.height === "number" ? o.height : 0;
  const fps = typeof o.fps === "number" ? o.fps : 0;
  const hasAudio = Boolean(o.hasAudio);

  if (
    !inputVideoPath ||
    !outputDir ||
    !outputFileName ||
    width <= 0 ||
    height <= 0 ||
    fps <= 0
  ) {
    throw new TypeError(
      "video-export-start: inputVideoPath / outputDir / outputFileName / width / height / fps が不正です",
    );
  }

  const inAbs = path.resolve(inputVideoPath);
  const safeName = path.basename(outputFileName);
  const outputVideoPath = path.join(outputDir, safeName);
  await fs.mkdir(outputDir, { recursive: true });

  const ffArgs = buildFfmpegRawvideoExportArgs({
    width,
    height,
    fps,
    hasAudio,
    inputVideoPath: inAbs,
    outputVideoPath,
  });

  let child: ChildProcessWithoutNullStreams;
  try {
    child = spawn("ffmpeg", ffArgs, {
      stdio: ["pipe", "ignore", "pipe"],
    }) as ChildProcessWithoutNullStreams;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(`ffmpeg を起動できません: ${msg}`);
  }

  const stderrLines: string[] = [];
  child.stderr?.on("data", (chunk: Buffer) => {
    stderrLines.push(chunk.toString("utf8"));
  });

  child.on("error", (err) => {
    stderrLines.push(`spawn error: ${err.message}`);
  });

  activeVideoExport = { child, stderrLines };

  console.log(
    `[film-lab-desktop] ffmpeg 起動 rawvideo ${width}x${height}@${fps} hasAudio=${hasAudio} → ${outputVideoPath}`,
  );
  if (DEBUG_VIDEO_EXPORT_MAIN) {
    console.log(`[film-lab-desktop] ffmpeg argv: ${JSON.stringify(ffArgs)}`);
  }

  return { outputVideoPath };
});

ipcMain.handle("video-export-write-frame", async (_evt, data: unknown) => {
  if (!(data instanceof Uint8Array)) {
    throw new TypeError("video-export-write-frame: data が Uint8Array ではありません");
  }
  const sess = activeVideoExport;
  if (!sess) {
    throw new Error("video-export-write-frame: アクティブな書き出しがありません");
  }
  const { child } = sess;
  const stdin = child.stdin;
  if (stdin == null || !stdin.writable) {
    throw new Error(
      "video-export-write-frame: ffmpeg stdin が利用できません（null または closed）",
    );
  }
  const buf = Buffer.from(data.buffer, data.byteOffset, data.byteLength);
  const t0 = process.hrtime.bigint();
  try {
    /**
     * @description 単発 write+コールバックだと 1 フレーム数十 MB 級でバッファ溢れ・デッドロックしうる。pipeline でバックプレッシャー継承。
     */
    await pipeline(Readable.from(buf), stdin, { end: false });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const tail = sess.stderrLines.join("").slice(-2500);
    throw new Error(
      `video-export-write-frame: stdin pipeline 失敗 — ${msg} | ffmpeg stderr(末尾): ${tail}`,
    );
  }
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  if (DEBUG_VIDEO_EXPORT_MAIN || ms > 2500) {
    console.log(
      `[film-lab-desktop] video-export-write-frame ok bytes=${buf.length} ms=${ms.toFixed(1)} stdin.writable=${stdin.writable}`,
    );
  }
});

ipcMain.handle("video-export-finish", async () => {
  const sess = activeVideoExport;
  if (!sess) {
    throw new Error("video-export-finish: アクティブな書き出しがありません");
  }
  const { child, stderrLines } = sess;
  activeVideoExport = null;

  child.stdin.end();

  const code: number | null = await new Promise((resolve) => {
    child.on("close", (c) => resolve(c));
  });

  const stderrTail = stderrLines.join("").slice(-8000);
  return { code, stderrTail };
});

ipcMain.handle("video-export-abort", async () => {
  disposeActiveFastTranscode("video-export-abort IPC");
  disposeActiveVideoExport("video-export-abort IPC");
});

ipcMain.handle("video-export-stage-source", async (_evt, filePath: string) => {
  if (typeof filePath !== "string" || filePath.length === 0) {
    throw new TypeError("video-export-stage-source: filePath が空です");
  }
  const abs = path.resolve(filePath);
  const st = await fs.stat(abs);
  if (!st.isFile()) {
    throw new Error(`video-export-stage-source: ファイルではありません — ${abs}`);
  }
  const ext = path.extname(abs) || ".mov";
  const staged = path.join(
    os.tmpdir(),
    `film-lab-video-src-${randomBytes(8).toString("hex")}${ext}`,
  );
  await fs.copyFile(abs, staged);
  return { stagedPath: staged };
});

ipcMain.handle("video-export-unlink-staged", async (_evt, stagedPath: string) => {
  if (typeof stagedPath !== "string" || stagedPath.length === 0) return;
  try {
    await fs.unlink(path.resolve(stagedPath));
  } catch {
    /* ignore */
  }
});
