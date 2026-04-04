/**
 * Film Lab バッチ — Electron メインプロセス
 *
 * @overview フォルダ選択とファイルの読み書きだけを担い、GPU はレンダラ（Chromium）に任せる。
 * @limitations パス検証は最小限。信頼できるローカル用途のスパイク向け。
 *
 * @description 設定は electron-store（userData 内 JSON）。ウィンドウ矩形と最後に選んだ入出力フォルダを覚える。
 */
import {
  app,
  BrowserWindow,
  dialog,
  ipcMain,
  protocol,
  shell,
} from "electron";
import { existsSync } from "node:fs";
import { filmLabParamsSchema, type Params } from "film-lab-core";
import Store from "electron-store";
import { execFile, spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { createReadStream } from "node:fs";
import fs from "node:fs/promises";
import { Readable } from "node:stream";
import os from "node:os";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { promisify } from "node:util";

import {
  FILM_LAB_VIDEO_PROTOCOL,
  absolutePathToVideoSrcUrl,
  guessVideoContentType,
  parseHttpByteRange,
} from "./video-src-protocol";
import { deriveSourceFrameRateTrust } from "./video-export-probe-framerate";
import {
  DesktopUpdateService,
  resolveDesktopUpdateCheckUrl,
} from "./desktop-update-service";
import { resolveVideoCliBinary } from "./ffmpeg-cli-resolve";

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
let mezzanineProcess: ChildProcessWithoutNullStreams | null = null;

/** @description 更新案内 IPC の送り先ウィンドウ（最初に作ったもの） */
let mainWindowRef: BrowserWindow | null = null;

/** @description 案 C: 公開 JSON を読むだけの更新チェッカー。スモーク時は未初期化のまま */
let desktopUpdateService: DesktopUpdateService | null = null;

/**
 * @description 進行中の ffmpeg を潰して参照を捨てる。レンダラが異常終了したあとに残るゾンビ対策。
 * @param reason ログ用（ターミナル）
 */

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
 * @description rawvideo の各フレーム成功ログは、明示時だけ細かく出す。
 *   既定は quiet にし、明らかに遅い write だけを観測用に残す。
 */
const VERBOSE_VIDEO_EXPORT_MAIN =
  process.env.FILM_LAB_VERBOSE_VIDEO_EXPORT === "1" ||
  process.env.FILM_LAB_VERBOSE_VIDEO_EXPORT === "true";

const SKIP_MEZZANINE =
  process.env.FILM_LAB_SKIP_MEZZANINE === "1" ||
  process.env.FILM_LAB_SKIP_MEZZANINE === "true";

/**
 * @description mezzanine 進捗を送る IPC のチャンネル名。
 */
const MEZZANINE_PROGRESS_CHANNEL = "film-lab-video-export-mezzanine-progress";

/**
 * @description mezzanine 進捗の分母。画面は 0-99 / 100 で見せる。
 */
const MEZZANINE_PROGRESS_TOTAL = 100;

/**
 * @description main から renderer に送る mezzanine 進捗。
 */
type MezzanineProgressPayload = {
  /** @description 0 から 99 までの進み具合 */
  current: number;
  /** @description 分母。mezzanine は 100 固定 */
  total: number;
};

/**
 * @description ffmpeg stderr に出る `time=HH:MM:SS.xx` を秒へ変換する。
 * @param timecode ffmpeg の time= の後ろに出る文字列
 * @returns {number | null} 秒。読めないときは null。
 */
function parseFfmpegTimecodeToSeconds(timecode: string): number | null {
  const parts = timecode.trim().split(":");
  if (parts.length !== 3) {
    return null;
  }
  const hours = Number(parts[0]);
  const minutes = Number(parts[1]);
  const seconds = Number(parts[2]);
  if (
    !Number.isFinite(hours) ||
    !Number.isFinite(minutes) ||
    !Number.isFinite(seconds)
  ) {
    return null;
  }
  return hours * 3600 + minutes * 60 + seconds;
}

/**
 * @description mezzanine の進捗を mainWindowRef へ送る。
 * @param current 0-99 で丸めた進み具合
 */
function sendMezzanineProgress(current: number): void {
  const win = mainWindowRef;
  if (win == null) {
    return;
  }
  const payload: MezzanineProgressPayload = {
    current,
    total: MEZZANINE_PROGRESS_TOTAL,
  };
  win.webContents.send(MEZZANINE_PROGRESS_CHANNEL, payload);
}

/**
 * @description main がいま把握している動画書き出しフェーズ。黒画面やクラッシュの時刻と付き合わせる。
 */
function currentVideoExportPhase(): string {
  if (activeVideoExport !== null) {
    return "rawvideo";
  }
  return "idle";
}

/**
 * @description Electron の details オブジェクトを 1 行 JSON にする。循環参照でも落ちないようにする。
 */
function safeDesktopDebugJson(value: unknown): string {
  try {
    return JSON.stringify(value);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return `[unserializable:${msg}]`;
  }
}

/**
 * @description process / Electron / export phase の共通コンテキスト。異常時ログに毎回付ける。
 */
function desktopProcessContext(): string {
  return (
    `platform=${process.platform} electron=${process.versions.electron} ` +
    `chrome=${process.versions.chrome} pid=${process.pid} export=${currentVideoExportPhase()}`
  );
}

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
  /** @description avg/r_frame_rate が一致するときの代表 fps。不信任なら null */
  sourceFrameRate: number | null;
  /** @description 両方が有限かつ差が小さいとき true */
  sourceFrameRateTrusted: boolean;
  /** @description WebCodecs 経路のメモリ上限判定用（readFile 前に参照） */
  fileSizeBytes: number;
}> {
  const ffprobe = (() => {
    try {
      return resolveVideoCliBinary("ffprobe");
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new Error(
        `ffprobe が見つかりません。動画の読み込みと書き出しには ffmpeg / ffprobe が必要です。${msg}`,
      );
    }
  })();
  if (DEBUG_VIDEO_EXPORT_MAIN) {
    console.log(
      `[film-lab-desktop] resolved ffprobe via ${ffprobe.source}: ${ffprobe.commandPath}`,
    );
  }
  let stdout: string;
  try {
    const r = await execFileAsync(
      ffprobe.commandPath,
      [
        "-v",
        "error",
        "-show_entries",
        "stream=codec_type,width,height,codec_name,avg_frame_rate,r_frame_rate",
        "-show_entries",
        "format=duration",
        "-of",
        "json",
        absPath,
      ],
      {
        maxBuffer: 10 * 1024 * 1024,
        env: ffprobe.childEnv,
      },
    );
    stdout = r.stdout as string;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(
      `ffprobe 実行失敗（resolved=${ffprobe.commandPath}）: ${msg}`,
    );
  }

  let fileSizeBytes = 0;
  try {
    const st = await fs.stat(absPath);
    if (st.isFile()) fileSizeBytes = st.size;
  } catch {
    fileSizeBytes = 0;
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
  let avgFrameRate: unknown;
  let rFrameRate: unknown;
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
        avgFrameRate = o.avg_frame_rate;
        rFrameRate = o.r_frame_rate;
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

  const { sourceFrameRate, sourceFrameRateTrusted } =
    deriveSourceFrameRateTrust(avgFrameRate, rFrameRate);

  return {
    width,
    height,
    durationSec,
    hasAudio,
    videoCodec,
    sourceFrameRate,
    sourceFrameRateTrusted,
    fileSizeBytes,
  };
}

/**
 * @description 1 フレームぶんの raw RGB を ffmpeg stdin に書き、バックプレッシャー時は drain まで待つ
 */
function writeStdinWithDrain(
  stdin: NodeJS.WritableStream,
  chunk: Buffer,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const onErr = (e: Error) => {
      cleanup();
      reject(e);
    };
    const cleanup = () => {
      stdin.removeListener("error", onErr);
    };
    stdin.once("error", onErr);
    try {
      const ok = stdin.write(chunk);
      if (ok) {
        cleanup();
        resolve();
      } else {
        stdin.once("drain", () => {
          cleanup();
          resolve();
        });
      }
    } catch (e) {
      cleanup();
      reject(e instanceof Error ? e : new Error(String(e)));
    }
  });
}

/**
 * @description stdin.write を呼び即座に resolve。バックプレッシャー中なら前回の drain を先に待つ。
 * renderer が seek と並列で IPC を走らせるための非同期パイプライン用。
 */
let pendingDrain: Promise<void> | null = null;

function writeStdinPipelined(
  stdin: NodeJS.WritableStream,
  chunk: Buffer,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const doWrite = () => {
      const onErr = (e: Error) => {
        stdin.removeListener("error", onErr);
        reject(e);
      };
      stdin.once("error", onErr);
      try {
        const ok = stdin.write(chunk);
        stdin.removeListener("error", onErr);
        if (!ok) {
          pendingDrain = new Promise<void>((drainResolve) => {
            stdin.once("drain", () => { drainResolve(); });
          });
        } else {
          pendingDrain = null;
        }
        resolve();
      } catch (e) {
        stdin.removeListener("error", onErr);
        reject(e instanceof Error ? e : new Error(String(e)));
      }
    };

    if (pendingDrain) {
      pendingDrain.then(doWrite, reject);
    } else {
      doWrite();
    }
  });
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

/**
 * @description Visually lossless mezzanine 用の ffmpeg 引数を組み立てる。
 *   Chromium の <video> が decode できる H.264 all-I-frame を使用。
 *   useHwEncoder=true で h264_videotoolbox（Apple Silicon HW）、false で libx264（SW fallback）。
 *   -g 1: 全フレームが IDR → seek が瞬時。
 *   高ビットレート: visually lossless（ProRes 422 相当品質）。
 */
function buildFfmpegMezzanineArgs(
  inputPath: string,
  outputPath: string,
  useHwEncoder: boolean,
  outW: number,
  outH: number,
): string[] {
  const args = ["-hide_banner", "-loglevel", "info", "-i", inputPath];
  if (useHwEncoder) {
    args.push(
      "-c:v", "h264_videotoolbox",
      "-b:v", "80M",
      "-g", "1",
      "-allow_sw", "1",
    );
  } else {
    args.push(
      "-c:v", "libx264",
      "-crf", "4",
      "-preset", "ultrafast",
      "-g", "1",
    );
  }
  args.push("-vf", `scale=${outW}:-2`);
  args.push("-c:a", "copy", "-y", outputPath);
  return args;
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
  // Color management: WebGL readPixels emits full-range sRGB (0-255) in bottom-up row order.
  // vflip restores top-down order (zero-copy row pointer swap in ffmpeg).
  // scale converts full range to limited range (16-235) for H.264 standard compliance,
  // and BT.709 color metadata tags ensure correct player interpretation.
  // See: .claude/knowledge/patterns/2026-03-03-ffmpeg-encoder-pitfalls-pattern.md §4
  //
  // life#89 / portfolio#12: 先頭の表示フレームだけがほぼ真っ黒に乗り Finder サムネが黒になる。
  // gl.finish だけでは再現が残ったため、raw 列で n==0 を捨て setpts で詰める（映像は 1 フレーム短い）。
  // hasAudio + -shortest では短い映像に合わせて音声端が切り詰められる。
  const colorFilterChain =
    "vflip,scale=in_range=full:out_range=limited,select=gte(n\\,1),setpts=N/FRAME_RATE/TB";
  head.push(
    "-vf",
    colorFilterChain,
    "-color_range",
    "tv",
    "-colorspace",
    "bt709",
    "-color_trc",
    "bt709",
    "-color_primaries",
    "bt709",
  );
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
    show: !DESKTOP_SMOKE_PENDING,
    titleBarStyle: "hidden",
    trafficLightPosition: { x: 14, y: 8 },
    vibrancy: "under-window",
    visualEffectState: "active",
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

  win.on("closed", () => {
    if (mainWindowRef === win) {
      mainWindowRef = null;
    }
  });

  win.webContents.once("did-finish-load", () => {
    desktopUpdateService?.onRendererLoaded();
  });

  win.webContents.on("render-process-gone", (_event, details) => {
    console.error(
      `[film-lab-desktop] render-process-gone wcId=${win.webContents.id} ${desktopProcessContext()} details=${safeDesktopDebugJson(details)}`,
    );
  });
  win.webContents.on("unresponsive", () => {
    console.warn(
      `[film-lab-desktop] renderer-unresponsive wcId=${win.webContents.id} ${desktopProcessContext()}`,
    );
  });
  win.webContents.on("responsive", () => {
    console.log(
      `[film-lab-desktop] renderer-responsive wcId=${win.webContents.id} ${desktopProcessContext()}`,
    );
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

  if (!DESKTOP_SMOKE_PENDING) {
    desktopUpdateService = new DesktopUpdateService(
      () => mainWindowRef,
      resolveDesktopUpdateCheckUrl,
      () => app.getVersion(),
      () => activeVideoExport !== null,
    );
    desktopUpdateService.startSchedule();
  }

  const mainWindow = createWindow();
  mainWindowRef = mainWindow;
  if (DESKTOP_SMOKE_PENDING) {
    void runPendingRuntimeSmoke(mainWindow);
  }
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      const w = createWindow();
      mainWindowRef = w;
    }
  });
});

app.on("child-process-gone", (_event, details) => {
  console.error(
    `[film-lab-desktop] child-process-gone ${desktopProcessContext()} details=${safeDesktopDebugJson(details)}`,
  );
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

app.on("will-quit", () => {
  desktopUpdateService?.dispose();
  desktopUpdateService = null;
});

ipcMain.handle("desktop-update-set-export-busy", (_evt, busy: unknown) => {
  if (typeof busy !== "boolean") {
    throw new TypeError(
      "desktop-update-set-export-busy: busy が boolean ではありません",
    );
  }
  desktopUpdateService?.setRendererExportBusy(busy);
});

ipcMain.handle("desktop-update-dismiss", (_evt, version: unknown) => {
  if (typeof version !== "string" || version.length === 0) {
    throw new TypeError("desktop-update-dismiss: version が空です");
  }
  desktopUpdateService?.dismissVersion(version);
});

ipcMain.handle("desktop-update-open-external", async (_evt, url: unknown) => {
  if (typeof url !== "string" || url.length === 0) {
    throw new TypeError("desktop-update-open-external: url が空です");
  }
  try {
    await shell.openExternal(url);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(
      `desktop-update-open-external: shell.openExternal 失敗 url=${url} detail=${msg}`,
    );
  }
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

ipcMain.handle("video-export-start", async (_evt, payload: unknown) => {
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

  const ffmpeg = (() => {
    try {
      return resolveVideoCliBinary("ffmpeg");
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new Error(`ffmpeg が見つかりません。${msg}`);
    }
  })();
  let child: ChildProcessWithoutNullStreams;
  try {
    child = spawn(ffmpeg.commandPath, ffArgs, {
      env: ffmpeg.childEnv,
      stdio: ["pipe", "ignore", "pipe"],
    }) as ChildProcessWithoutNullStreams;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(
      `ffmpeg を起動できません: resolved=${ffmpeg.commandPath} — ${msg}`,
    );
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
    `[film-lab-desktop] ffmpeg 起動 rawvideo ${width}x${height}@${fps} hasAudio=${hasAudio} cli=${ffmpeg.commandPath} → ${outputVideoPath}`,
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
    // Pipelined write: enqueue to stdin and return immediately.
    // Backpressure (drain) is deferred to the next write call,
    // allowing the renderer to start seeking the next frame in parallel.
    await writeStdinPipelined(stdin, buf);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const tail = sess.stderrLines.join("").slice(-2500);
    throw new Error(
      `video-export-write-frame: stdin write/drain 失敗 — ${msg} | ffmpeg stderr(末尾): ${tail}`,
    );
  }
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  if (VERBOSE_VIDEO_EXPORT_MAIN || ms > 100) {
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

  // Drain any pending pipelined write before closing stdin
  if (pendingDrain) {
    await pendingDrain;
    pendingDrain = null;
  }
  child.stdin.end();

  const code: number | null = await new Promise((resolve) => {
    child.on("close", (c) => resolve(c));
  });

  const stderrTail = stderrLines.join("").slice(-8000);
  return { code, stderrTail };
});

ipcMain.handle("video-export-abort", async () => {
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

/**
 * @description HEVC 等の重いソースを ProRes 422 mezzanine に事前トランスコードする。
 *   HW encoder (prores_videotoolbox) を優先し、失敗時は SW (prores_ks) にフォールバック。
 */
ipcMain.handle(
  "video-export-transcode-mezzanine",
  async (_evt, payload: { filePath: string; durationSec: number; outW: number; outH: number }) => {
    if (typeof payload !== "object" || payload == null) {
      throw new TypeError(
        "video-export-transcode-mezzanine: payload が空です",
      );
    }
    const input = payload as {
      filePath?: unknown;
      durationSec?: unknown;
      outW?: unknown;
      outH?: unknown;
    };
    if (typeof input.filePath !== "string" || input.filePath.length === 0) {
      throw new TypeError(
        "video-export-transcode-mezzanine: filePath が空です",
      );
    }
    const safeDurationSec =
      typeof input.durationSec === "number" &&
      Number.isFinite(input.durationSec) &&
      input.durationSec > 0
        ? input.durationSec
        : 1;
    const safeOutW =
      typeof input.outW === "number" && input.outW > 0
        ? Math.round(input.outW)
        : 1920;
    const safeOutH =
      typeof input.outH === "number" && input.outH > 0
        ? Math.round(input.outH)
        : 1080;
    if (SKIP_MEZZANINE) {
      throw new Error(
        "video-export-transcode-mezzanine: FILM_LAB_SKIP_MEZZANINE=1 でスキップ",
      );
    }

    const abs = path.resolve(input.filePath);
    const st = await fs.stat(abs);
    if (!st.isFile()) {
      throw new Error(
        `video-export-transcode-mezzanine: ファイルではありません — ${abs}`,
      );
    }

    const ffmpeg = (() => {
      try {
        return resolveVideoCliBinary("ffmpeg");
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        throw new Error(`ffmpeg が見つかりません。${msg}`);
      }
    })();

    const outputPath = path.join(
      os.tmpdir(),
      `film-lab-mezzanine-${randomBytes(8).toString("hex")}.mp4`,
    );

    const runTranscode = (useHw: boolean): Promise<void> =>
      new Promise((resolve, reject) => {
        const args = buildFfmpegMezzanineArgs(abs, outputPath, useHw, safeOutW, safeOutH);
        if (DEBUG_VIDEO_EXPORT_MAIN) {
          console.log(
            `[film-lab-desktop][mezzanine] ffmpeg ${useHw ? "HW" : "SW"} argv: ${JSON.stringify(args)}`,
          );
        }
        const child = spawn(ffmpeg.commandPath, args, {
          env: ffmpeg.childEnv,
          stdio: ["ignore", "ignore", "pipe"],
        }) as ChildProcessWithoutNullStreams;
        mezzanineProcess = child;

        let lastSentCurrent = -1;
        const emitProgress = (elapsedSec: number): void => {
          const current = Math.min(
            99,
            Math.max(0, Math.floor((elapsedSec / safeDurationSec) * 100)),
          );
          if (current <= lastSentCurrent) {
            return;
          }
          lastSentCurrent = current;
          sendMezzanineProgress(current);
        };

        const stderrBuf: string[] = [];
        let stderrTailText = "";
        child.stderr?.on("data", (chunk: Buffer) => {
          const chunkText = chunk.toString("utf8");
          stderrBuf.push(chunkText);
          stderrTailText = `${stderrTailText}${chunkText}`.slice(-2048);
          const matches = [
            ...stderrTailText.matchAll(
              /time=([0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.\d+)?)/g,
            ),
          ];
          const timecode = matches[matches.length - 1]?.[1];
          if (!timecode) {
            return;
          }
          const elapsedSec = parseFfmpegTimecodeToSeconds(timecode);
          if (elapsedSec == null) {
            return;
          }
          emitProgress(elapsedSec);
        });
        emitProgress(0);
        child.on("error", (err) => {
          mezzanineProcess = null;
          reject(
            new Error(
              `ffmpeg mezzanine spawn error: ${err.message}`,
            ),
          );
        });
        child.on("close", (code) => {
          mezzanineProcess = null;
          if (code === 0) {
            resolve();
          } else {
            const tail = stderrBuf.join("").slice(-4000);
            reject(
              new Error(
                `ffmpeg mezzanine ${useHw ? "HW" : "SW"} exit code=${code} stderr: ${tail}`,
              ),
            );
          }
        });
      });

    // HW encoder first, SW fallback
    try {
      await runTranscode(true);
    } catch (hwErr) {
      if (DEBUG_VIDEO_EXPORT_MAIN) {
        console.log(
          `[film-lab-desktop][mezzanine] HW encoder 失敗、SW fallback: ${hwErr instanceof Error ? hwErr.message : String(hwErr)}`,
        );
      }
      // Remove partial output from HW attempt
      try {
        await fs.unlink(outputPath);
      } catch {
        /* ignore */
      }
      await runTranscode(false);
    }

    const outStat = await fs.stat(outputPath);
    console.log(
      `[film-lab-desktop][mezzanine] 完了 ${outputPath} size=${(outStat.size / 1024 / 1024).toFixed(1)}MB`,
    );
    return { mezzaninePath: outputPath, mezzanineSizeBytes: outStat.size };
  },
);

ipcMain.handle("video-export-abort-mezzanine", async () => {
  if (mezzanineProcess) {
    mezzanineProcess.kill("SIGTERM");
    setTimeout(() => {
      if (mezzanineProcess) {
        mezzanineProcess.kill("SIGKILL");
        mezzanineProcess = null;
      }
    }, 5000);
  }
});
