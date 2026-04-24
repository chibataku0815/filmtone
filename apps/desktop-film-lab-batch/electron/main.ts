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
  nativeImage,
  protocol,
  shell,
} from "electron";
import { existsSync } from "node:fs";
import { filmLabParamsSchema, type CameraOptics, type Params } from "film-lab-core";
import Store from "electron-store";
import {
  execFile,
  spawn,
  type ChildProcessByStdio,
  type ChildProcessWithoutNullStreams,
} from "node:child_process";
import { createReadStream } from "node:fs";
import fs from "node:fs/promises";
import { Readable, Writable } from "node:stream";
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
import { deriveCameraOpticsFromFfprobeMeta } from "./video-export-camera-optics";
import { deriveSourceFrameRateTrust } from "./video-export-probe-framerate";
import {
  classifySourceColorForExport,
  deriveSourceColorMetadataFromFfprobeStream,
  deriveVideoDisplayGeometryFromFfprobeStream,
  type SourceVideoMetadata,
} from "./video-export-source-metadata";
import {
  DesktopUpdateService,
  resolveDesktopUpdateCheckUrl,
} from "./desktop-update-service";
import { resolveVideoCliBinary } from "./ffmpeg-cli-resolve";
import {
  createVideoExportPipeController,
  describeVideoExportPipeUnavailable,
  type VideoExportPipeController,
} from "./video-export-stdin";
import {
  buildFfmpegRawvideoExportArgs,
  normalizeCameraOptics,
} from "./video-export-ffmpeg-args";
import {
  PROXY_CACHE_PROFILE_VERSION,
  buildProxyCacheKey,
  ensureProxyCacheRoot,
  getProxyCacheInfo,
  proxyCacheFilePath,
  pruneProxyCache,
  purgeProxyCache,
  roundProxyCacheDurationSec,
  touchProxyCacheEntry,
  upsertProxyCacheEntry,
} from "./proxy-cache";

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
type FfmpegExportChildProcess = ChildProcessByStdio<Writable, null, Readable>;

type FfmpegVideoExportSession = {
  sessionId: string;
  child: FfmpegExportChildProcess;
  stderrLines: string[];
  pipeController: VideoExportPipeController;
};

let activeVideoExport: FfmpegVideoExportSession | null = null;
let thumbnailProcess: ChildProcessWithoutNullStreams | null = null;
let proxyProcess: ChildProcessWithoutNullStreams | null = null;
let mezzanineProcess: ChildProcessWithoutNullStreams | null = null;

/**
 * @description Progressive loading で作った tmp ファイル一覧です。
 * アプリ終了時に残っていても拾って掃除できるよう、main プロセスで正として持ちます。
 */
const progressivePreviewTempPaths = new Set<string>();

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
 * @description proxy 進捗を送る IPC のチャンネル名。
 */
const PROXY_PROGRESS_CHANNEL = "film-lab-preview-proxy-progress";

/**
 * @description mezzanine 進捗の分母。画面は 0-99 / 100 で見せる。
 */
const MEZZANINE_PROGRESS_TOTAL = 100;

/**
 * @description proxy 進捗の分母。画面は 0-99 / 100 で見せる。
 */
const PROXY_PROGRESS_TOTAL = 100;

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
 * @description main から renderer に送る proxy 進捗。
 */
type ProxyProgressPayload = {
  /** @description 0 から 99 までの進み具合 */
  current: number;
  /** @description 分母。proxy は 100 固定 */
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
 * @description proxy の進捗を mainWindowRef へ送る。
 * @param current 0-99 で丸めた進み具合
 */
function sendProxyProgress(current: number): void {
  const win = mainWindowRef;
  if (win == null) {
    return;
  }
  const payload: ProxyProgressPayload = {
    current,
    total: PROXY_PROGRESS_TOTAL,
  };
  win.webContents.send(PROXY_PROGRESS_CHANNEL, payload);
}

/**
 * @description Progressive loading の tmp ファイルを cleanup 対象へ登録します。
 * @param tempPath tmp ファイルの絶対パス
 */
function registerProgressivePreviewTempPath(tempPath: string): void {
  progressivePreviewTempPaths.add(path.resolve(tempPath));
}

/**
 * @description Progressive loading の tmp ファイルを cleanup 対象から外します。
 * @param tempPath tmp ファイルの絶対パス
 */
function unregisterProgressivePreviewTempPath(tempPath: string): void {
  progressivePreviewTempPaths.delete(path.resolve(tempPath));
}

/**
 * @description Progressive loading の tmp をすべて削除します。アプリ終了時の置き土産対策です。
 */
async function cleanupProgressivePreviewTempFiles(): Promise<void> {
  const pendingPaths = [...progressivePreviewTempPaths];
  await Promise.all(
    pendingPaths.map(async (tempPath) => {
      try {
        await fs.unlink(tempPath);
      } catch {
        /* ignore */
      } finally {
        unregisterProgressivePreviewTempPath(tempPath);
      }
    }),
  );
}

/**
 * @description main がいま把握している動画書き出しフェーズ。黒画面やクラッシュの時刻と付き合わせる。
 */
function currentVideoExportPhase(): string {
  if (activeVideoExport !== null) {
    return "rawvideo";
  }
  if (thumbnailProcess !== null) {
    return "thumbnail";
  }
  if (proxyProcess !== null) {
    return "proxy";
  }
  if (mezzanineProcess !== null) {
    return "mezzanine";
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

function proxyCacheRoot(): string {
  return path.join(app.getPath("sessionData"), "film-lab-batch", "proxy-cache");
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
  cameraOptics: CameraOptics;
  sourceVideoMetadata: SourceVideoMetadata;
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
        "-show_streams",
        "-show_format",
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
  let videoStream: Record<string, unknown> | undefined;
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
        videoStream = o;
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

  const sourceFrameRateInfo = deriveSourceFrameRateTrust(
    avgFrameRate,
    rFrameRate,
  );
  const sourceColorMetadata = deriveSourceColorMetadataFromFfprobeStream(
    videoStream,
  );
  const sourceVideoMetadata: SourceVideoMetadata = {
    display: deriveVideoDisplayGeometryFromFfprobeStream({
      rawWidth: width,
      rawHeight: height,
      stream: videoStream,
    }),
    color: sourceColorMetadata,
    colorClass: classifySourceColorForExport(sourceColorMetadata),
    timing: sourceFrameRateInfo,
  };
  const cameraOptics = deriveCameraOpticsFromFfprobeMeta({
    rawWidth: width,
    rawHeight: height,
    stream: videoStream,
    format: fmt,
  });

  return {
    width: sourceVideoMetadata.display.displayWidth,
    height: sourceVideoMetadata.display.displayHeight,
    durationSec,
    hasAudio,
    videoCodec,
    sourceFrameRate: sourceFrameRateInfo.sourceFrameRate,
    sourceFrameRateTrusted: sourceFrameRateInfo.sourceFrameRateTrusted,
    fileSizeBytes,
    cameraOptics,
    sourceVideoMetadata,
  };
}

/**
 * @description Progressive loading の 1280px 系ステージに合わせた偶数解像度を計算します。
 * ffmpeg の `scale=1280:-2` と同じ考え方で、高さだけ偶数へそろえます。
 * @param sourceWidth 元動画の横幅
 * @param sourceHeight 元動画の縦幅
 * @returns proxy / thumbnail 用の幅高さ
 */
function computeProxyDimensions(
  sourceWidth: number,
  sourceHeight: number,
): { width: number; height: number } {
  const safeSourceWidth = Number.isFinite(sourceWidth) && sourceWidth > 0 ? sourceWidth : 1920;
  const safeSourceHeight =
    Number.isFinite(sourceHeight) && sourceHeight > 0 ? sourceHeight : 1080;
  const width = 1280;
  const height = Math.max(
    2,
    Math.round((width * safeSourceHeight) / safeSourceWidth) & ~1,
  );
  return { width, height };
}

const THUMBNAIL_FRAME_CANDIDATE_TIMES_SEC = [0.25, 0.5, 0.75, 1, 1.5, 2] as const;
const THUMBNAIL_BRIGHTNESS_THRESHOLD = 0.05;

/**
 * @description Stage 1 の JPEG サムネイル抽出引数を組み立てます。
 * -ss を入力前に置いて keyframe seek を優先し、最初の見える絵をできるだけ早く返します。
 */

/**
 * @description ffmpeg を低優先度で起動するヘルパー。
 * `nice -n 10` でラップし、CPU 負荷によるファン回転を抑えます。
 */
function spawnFfmpegNice(
  ffmpegPath: string,
  args: string[],
  options: { env?: NodeJS.ProcessEnv; stdio: import("child_process").StdioOptions },
): ChildProcessWithoutNullStreams {
  return spawn("nice", ["-n", "10", ffmpegPath, ...args], options) as ChildProcessWithoutNullStreams;
}

function buildFfmpegThumbnailArgs(
  inputPath: string,
  outputPath: string,
  seekSeconds: number,
): string[] {
  return [
    "-hide_banner",
    "-loglevel",
    "info",
    "-ss",
    `${seekSeconds}`,
    "-i",
    inputPath,
    "-frames:v",
    "1",
    "-q:v",
    "2",
    "-vf",
    "scale=1280:-2,format=yuv420p",
    "-y",
    outputPath,
  ];
}

function computeNativeImageAverageBrightness(imagePath: string): number {
  const image = nativeImage.createFromPath(imagePath);
  if (image.isEmpty()) {
    return 0;
  }
  const bitmap = image.toBitmap();
  if (bitmap.length === 0) {
    return 0;
  }
  let luminanceSum = 0;
  let pixelCount = 0;
  for (let i = 0; i < bitmap.length; i += 4) {
    const b = bitmap[i] / 255;
    const g = bitmap[i + 1] / 255;
    const r = bitmap[i + 2] / 255;
    luminanceSum += 0.2126 * r + 0.7152 * g + 0.0722 * b;
    pixelCount += 1;
  }
  return pixelCount > 0 ? luminanceSum / pixelCount : 0;
}

/**
 * @description Stage 2 の proxy 生成引数を組み立てます。
 * 全フレーム I-frame にして、再生開始とシークを軽くします。
 */
function buildFfmpegProxyArgs(
  inputPath: string,
  outputPath: string,
  useHwEncoder: boolean,
): string[] {
  const args = ["-hide_banner", "-loglevel", "info"];
  if (useHwEncoder) {
    args.push("-hwaccel", "videotoolbox");
  }
  args.push("-i", inputPath);
  args.push(
    "-vf",
    "colorspace=iall=bt709:all=bt709,scale=1280:-2,format=yuv420p",
  );
  if (useHwEncoder) {
    args.push(
      "-c:v",
      "h264_videotoolbox",
      "-b:v",
      "8M",
      "-g",
      "1",
      "-allow_sw",
      "1",
    );
  } else {
    args.push(
      "-c:v",
      "libx264",
      "-preset",
      "ultrafast",
      "-crf",
      "28",
      "-g",
      "1",
    );
  }
  args.push("-an", "-y", outputPath);
  return args;
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
  const args = ["-hide_banner", "-loglevel", "info"];
  if (useHwEncoder) {
    args.push("-hwaccel", "videotoolbox");
  }
  args.push("-i", inputPath);
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
  // colorspace フィルターで色空間を bt709 に正規化してから scale する。
  // ProRes 4444 (yuv444p12le, gbr) 等で swscaler が "Unsupported input" になるのを回避。
  args.push("-vf", `colorspace=iall=bt709:all=bt709,scale=${outW}:-2,format=yuv420p`);
  args.push("-c:a", "copy", "-y", outputPath);
  return args;
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
  const dock = app.dock;
  if (!dock) {
    return;
  }
  try {
    dock.setIcon(iconPath);
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
    process.exitCode = 0;
    app.quit();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[film-lab-desktop] smoke: ${message}`);
    process.exitCode = 1;
    app.quit();
  }
}

// Phase 3 T3-3 (DIRECTION §10 Phase 0 Case A safety-net). macOS arm64
// Electron 32 ships with `unsafeWebGPU` unflagged — Phase 0 疎通 confirmed
// adapter=apple/metal-3, deviceOk=true without this switch. Keeping the
// flag as a safety-net for older Electron builds and for DMG installs that
// might hit a stale Chromium feature gate; harmless when WebGPU is already
// enabled.
app.commandLine.appendSwitch("enable-unsafe-webgpu");

app.whenReady().then(async () => {
  console.log(
    "[film-lab-desktop] main: 動画 src は film-lab-video スキーム（path-to-file-url）。ログが file: なら bun run build:electron 未反映。",
  );
  applyDockIconIfMac();
  try {
    await ensureProxyCacheRoot(proxyCacheRoot());
    await pruneProxyCache(proxyCacheRoot());
  } catch (error) {
    console.warn("[film-lab-desktop][proxy-cache] startup prune failed", error);
  }
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
  try {
    thumbnailProcess?.kill("SIGKILL");
  } catch {
    /* ignore */
  }
  try {
    proxyProcess?.kill("SIGKILL");
  } catch {
    /* ignore */
  }
  try {
    mezzanineProcess?.kill("SIGKILL");
  } catch {
    /* ignore */
  }
  thumbnailProcess = null;
  proxyProcess = null;
  mezzanineProcess = null;
  void cleanupProgressivePreviewTempFiles();
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

ipcMain.handle("pick-metadata-json", async () => {
  const defaultPath =
    (await resolveExistingDir(desktopSettingsStore.get("lastOutputDir"))) ??
    (await resolveExistingDir(desktopSettingsStore.get("lastInputDir")));
  const r = await dialog.showOpenDialog({
    properties: ["openFile"],
    filters: [{ name: "JSON", extensions: ["json"] }],
    defaultPath,
  });
  if (r.canceled || r.filePaths.length === 0) return null;
  return r.filePaths[0]!;
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
  "write-file-utf8",
  async (_evt, payload: { filePath: string; text: string }) => {
    const { filePath, text } = payload;
    if (typeof filePath !== "string" || typeof text !== "string") {
      throw new TypeError("write-file-utf8: filePath / text が不正です");
    }
    const target = path.resolve(filePath);
    await fs.mkdir(path.dirname(target), { recursive: true });
    await fs.writeFile(target, text, "utf-8");
  },
);

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
  const dropFirstFrame = o.dropFirstFrame === true;
  const cameraOptics = normalizeCameraOptics(o.cameraOptics);

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
    dropFirstFrame,
    cameraOptics,
  });

  const ffmpeg = (() => {
    try {
      return resolveVideoCliBinary("ffmpeg");
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new Error(`ffmpeg が見つかりません。${msg}`);
    }
  })();
  let child: FfmpegExportChildProcess;
  try {
    const ffmpegStdio: ["pipe", "ignore", "pipe"] = ["pipe", "ignore", "pipe"];
    child = spawn(ffmpeg.commandPath, ffArgs, {
      env: ffmpeg.childEnv,
      stdio: ffmpegStdio,
    });
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

  const pipeController = createVideoExportPipeController(child);
  const sessionId = randomBytes(12).toString("hex");
  activeVideoExport = { sessionId, child, stderrLines, pipeController };

  console.log(
    `[film-lab-desktop] ffmpeg 起動 session=${sessionId} rawvideo ${width}x${height}@${fps} hasAudio=${hasAudio} dropFirstFrame=${dropFirstFrame} cli=${ffmpeg.commandPath} → ${outputVideoPath}`,
  );
  if (DEBUG_VIDEO_EXPORT_MAIN) {
    console.log(`[film-lab-desktop] ffmpeg argv: ${JSON.stringify(ffArgs)}`);
  }

  return { outputVideoPath, sessionId };
});

ipcMain.handle("video-export-write-frame", async (_evt, payload: unknown) => {
  if (!payload || typeof payload !== "object" || payload === null) {
    throw new TypeError("video-export-write-frame: payload が不正です");
  }
  const o = payload as Record<string, unknown>;
  const sessionId = typeof o.sessionId === "string" ? o.sessionId : "";
  const data = o.data;
  if (!sessionId) {
    throw new TypeError("video-export-write-frame: sessionId が空です");
  }
  if (!(data instanceof Uint8Array)) {
    throw new TypeError("video-export-write-frame: data が Uint8Array ではありません");
  }
  const sess = activeVideoExport;
  if (!sess) {
    throw new Error("video-export-write-frame: アクティブな書き出しがありません");
  }
  if (sess.sessionId !== sessionId) {
    throw new Error(
      "video-export-write-frame: アクティブな書き出しセッションが一致しません（stale IPC）",
    );
  }
  const { child, pipeController } = sess;
  const stdin = child.stdin;
  if (stdin == null || !stdin.writable) {
    const detail = describeVideoExportPipeUnavailable({
      stdin,
      controller: pipeController,
      childExitCode: child.exitCode,
      childSignal: child.signalCode ?? null,
    });
    const tail = sess.stderrLines.join("").slice(-2500);
    throw new Error(
      `video-export-write-frame: ${detail} | ffmpeg stderr(末尾): ${tail}`,
    );
  }
  const buf = Buffer.from(data.buffer, data.byteOffset, data.byteLength);
  const t0 = process.hrtime.bigint();
  try {
    await pipeController.write(buf);
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

ipcMain.handle("video-export-finish", async (_evt, sessionId: unknown) => {
  if (typeof sessionId !== "string" || sessionId.length === 0) {
    throw new TypeError("video-export-finish: sessionId が空です");
  }
  const sess = activeVideoExport;
  if (!sess) {
    throw new Error("video-export-finish: アクティブな書き出しがありません");
  }
  if (sess.sessionId !== sessionId) {
    throw new Error(
      "video-export-finish: アクティブな書き出しセッションが一致しません（stale IPC）",
    );
  }
  const { child, stderrLines, pipeController } = sess;

  pipeController.markFinishing();
  try {
    await pipeController.waitForPendingDrain();
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    const stderrTail = stderrLines.join("").slice(-8000);
    throw new Error(
      `video-export-finish: stdin drain 失敗 — ${msg} | ffmpeg stderr(末尾): ${stderrTail}`,
    );
  }
  child.stdin.end();

  const closeInfo = await pipeController.waitForClose();
  if (activeVideoExport?.sessionId === sessionId) {
    activeVideoExport = null;
  }
  const stderrTail = stderrLines.join("").slice(-8000);
  return { code: closeInfo.code, stderrTail };
});

ipcMain.handle("video-export-abort", async (_evt, sessionId: unknown) => {
  const requestedSessionId =
    typeof sessionId === "string" && sessionId.length > 0 ? sessionId : null;
  const sess = activeVideoExport;
  if (!sess) {
    return;
  }
  if (requestedSessionId && sess.sessionId !== requestedSessionId) {
    return;
  }
  disposeActiveVideoExport(
    requestedSessionId
      ? `video-export-abort IPC session=${requestedSessionId}`
      : "video-export-abort IPC",
  );
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
  } finally {
    unregisterProgressivePreviewTempPath(stagedPath);
  }
});

ipcMain.handle("video-preview-get-proxy-cache-info", async () => {
  return getProxyCacheInfo(proxyCacheRoot());
});

ipcMain.handle("video-preview-purge-proxy-cache", async () => {
  return purgeProxyCache(proxyCacheRoot());
});

/**
 * @description Progressive loading Stage 1: JPEG サムネイルを高速抽出します。
 */
ipcMain.handle(
  "video-preview-extract-thumbnail",
  async (
    _evt,
    payload: { filePath: string; sourceWidth: number; sourceHeight: number },
  ) => {
    if (typeof payload !== "object" || payload == null) {
      throw new TypeError("video-preview-extract-thumbnail: payload が空です");
    }
    const input = payload as {
      filePath?: unknown;
      sourceWidth?: unknown;
      sourceHeight?: unknown;
    };
    if (typeof input.filePath !== "string" || input.filePath.length === 0) {
      throw new TypeError("video-preview-extract-thumbnail: filePath が空です");
    }
    const abs = path.resolve(input.filePath);
    const st = await fs.stat(abs);
    if (!st.isFile()) {
      throw new Error(`video-preview-extract-thumbnail: ファイルではありません — ${abs}`);
    }
    const ffmpeg = (() => {
      try {
        return resolveVideoCliBinary("ffmpeg");
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        throw new Error(`video-preview-extract-thumbnail: ffmpeg が見つかりません。${msg}`);
      }
    })();
    const { width, height } = computeProxyDimensions(
      typeof input.sourceWidth === "number" ? input.sourceWidth : 0,
      typeof input.sourceHeight === "number" ? input.sourceHeight : 0,
    );
    const thumbnailCandidates: Array<{ outputPath: string; brightness: number }> = [];
    const cleanupThumbnailPath = async (tempPath: string): Promise<void> => {
      unregisterProgressivePreviewTempPath(tempPath);
      try {
        await fs.unlink(tempPath);
      } catch {
        /* ignore */
      }
    };
    const extractThumbnailCandidate = async (
      seekSeconds: number,
    ): Promise<{ outputPath: string; brightness: number } | null> => {
      const outputPath = path.join(
        os.tmpdir(),
        `film-lab-thumb-${randomBytes(8).toString("hex")}.jpg`,
      );
      registerProgressivePreviewTempPath(outputPath);
      try {
        await new Promise<void>((resolve, reject) => {
          const args = buildFfmpegThumbnailArgs(abs, outputPath, seekSeconds);
          if (DEBUG_VIDEO_EXPORT_MAIN) {
            console.log("[progressive-main] thumbnail ffmpeg args:", args.join(" "));
          }
          const child = spawnFfmpegNice(ffmpeg.commandPath, args, {
            env: ffmpeg.childEnv,
            stdio: ["ignore", "ignore", "pipe"],
          });
          thumbnailProcess = child;
          const stderrBuf: string[] = [];
          child.stderr?.on("data", (chunk: Buffer) => {
            stderrBuf.push(chunk.toString("utf8"));
          });
          child.on("error", (err) => {
            thumbnailProcess = null;
            console.error("[progressive-main] thumbnail spawn error:", err.message);
            reject(
              new Error(
                `video-preview-extract-thumbnail: ffmpeg spawn error: ${err.message}`,
              ),
            );
          });
          child.on("close", (code) => {
            thumbnailProcess = null;
            const stderr = stderrBuf.join("").slice(-4000);
            if (DEBUG_VIDEO_EXPORT_MAIN) {
              console.log(
                `[progressive-main] thumbnail ffmpeg exit code=${code} stderr=${stderr.slice(0, 500)}`,
              );
            }
            if (code === 0) {
              resolve();
              return;
            }
            reject(
              new Error(
                `video-preview-extract-thumbnail: ffmpeg exit code=${code} stderr: ${stderr}`,
              ),
            );
          });
        });
        const brightness = computeNativeImageAverageBrightness(outputPath);
        return { outputPath, brightness };
      } catch (err) {
        await cleanupThumbnailPath(outputPath);
        console.warn("video-preview-extract-thumbnail: candidate extraction failed", {
          seekSeconds,
          abs,
          err,
        });
        return null;
      }
    };

    let chosenThumbnail: { outputPath: string; brightness: number } | null = null;
    for (const seekSeconds of THUMBNAIL_FRAME_CANDIDATE_TIMES_SEC) {
      const candidate = await extractThumbnailCandidate(seekSeconds);
      if (candidate == null) {
        continue;
      }
      thumbnailCandidates.push(candidate);
      if (chosenThumbnail == null || candidate.brightness > chosenThumbnail.brightness) {
        chosenThumbnail = candidate;
      }
      if (candidate.brightness >= THUMBNAIL_BRIGHTNESS_THRESHOLD) {
        chosenThumbnail = candidate;
        break;
      }
    }

    if (chosenThumbnail == null) {
      throw new Error("video-preview-extract-thumbnail: すべての候補抽出に失敗しました");
    }

    const outputPath = chosenThumbnail.outputPath;
    await Promise.all(
      thumbnailCandidates
        .filter((candidate) => candidate.outputPath !== outputPath)
        .map(async (candidate) => cleanupThumbnailPath(candidate.outputPath)),
    );
    if (DEBUG_VIDEO_EXPORT_MAIN) {
      console.log(
        "[progressive-main] thumbnail written:",
        outputPath,
        width,
        height,
        `brightness=${chosenThumbnail.brightness.toFixed(4)}`,
      );
    }
    return { thumbnailPath: outputPath, width, height };
  },
);

/**
 * @description Progressive loading Stage 2: 低解像度 H.264 proxy を生成します。
 * HW encoder を優先し、失敗時は libx264 へフォールバックします。
 */
ipcMain.handle(
  "video-preview-generate-proxy",
  async (_evt, payload: { filePath: string; durationSec: number }) => {
    if (typeof payload !== "object" || payload == null) {
      throw new TypeError("video-preview-generate-proxy: payload が空です");
    }
    const input = payload as { filePath?: unknown; durationSec?: unknown };
    if (typeof input.filePath !== "string" || input.filePath.length === 0) {
      throw new TypeError("video-preview-generate-proxy: filePath が空です");
    }
    const safeDurationSec =
      typeof input.durationSec === "number" &&
      Number.isFinite(input.durationSec) &&
      input.durationSec > 0
        ? input.durationSec
        : 1;
    const abs = path.resolve(input.filePath);
    const st = await fs.stat(abs);
    if (!st.isFile()) {
      throw new Error(`video-preview-generate-proxy: ファイルではありません — ${abs}`);
    }
    const meta = await ffprobeVideoMeta(abs);
    const dimensions = computeProxyDimensions(meta.width, meta.height);
    const profile = {
      version: PROXY_CACHE_PROFILE_VERSION,
      width: dimensions.width,
      height: dimensions.height,
      encoderFlavor:
        process.platform === "darwin"
          ? "h264_videotoolbox-or-libx264"
          : "libx264",
      codec: "h264",
      bitrateLabel: "8M",
      gop: 1,
      scaleFilter: "colorspace=iall=bt709:all=bt709,scale=1280:-2,format=yuv420p",
    } as const;
    const key = buildProxyCacheKey({
      sourceSignature: {
        sourcePath: abs,
        sizeBytes: st.size,
        mtimeMs: st.mtimeMs,
        durationSecRounded: roundProxyCacheDurationSec(safeDurationSec),
      },
      proxyProfile: profile,
    });
    const cachePath = proxyCacheFilePath(proxyCacheRoot(), key);
    const cacheHit = await touchProxyCacheEntry(proxyCacheRoot(), key);
    if (cacheHit != null) {
      console.log(`[film-lab-desktop][proxy-cache] hit ${cacheHit.proxyPath}`);
      return {
        proxyPath: cacheHit.proxyPath,
        proxySizeBytes: cacheHit.sizeBytes,
        cacheHit: true,
      };
    }
    const ffmpeg = (() => {
      try {
        return resolveVideoCliBinary("ffmpeg");
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        throw new Error(`video-preview-generate-proxy: ffmpeg が見つかりません。${msg}`);
      }
    })();
    const outputPath = path.join(
      proxyCacheRoot(),
      `proxy-${key}.tmp-${randomBytes(8).toString("hex")}.mp4`,
    );

    const runTranscode = (useHwEncoder: boolean): Promise<void> =>
      new Promise((resolve, reject) => {
        const args = buildFfmpegProxyArgs(abs, outputPath, useHwEncoder);
        const child = spawnFfmpegNice(ffmpeg.commandPath, args, {
          env: ffmpeg.childEnv,
          stdio: ["ignore", "ignore", "pipe"],
        }) as ChildProcessWithoutNullStreams;
        proxyProcess = child;
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
          sendProxyProgress(current);
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
          proxyProcess = null;
          reject(
            new Error(`video-preview-generate-proxy: ffmpeg spawn error: ${err.message}`),
          );
        });
        child.on("close", (code) => {
          proxyProcess = null;
          if (code === 0) {
            resolve();
            return;
          }
          reject(
            new Error(
              `video-preview-generate-proxy: ffmpeg ${useHwEncoder ? "HW" : "SW"} exit code=${code} stderr: ${stderrBuf.join("").slice(-4000)}`,
            ),
          );
        });
      });

    try {
      try {
        await runTranscode(true);
      } catch (hwErr) {
        if (DEBUG_VIDEO_EXPORT_MAIN) {
          console.log(
            `[film-lab-desktop][proxy] HW encoder 失敗、SW fallback: ${hwErr instanceof Error ? hwErr.message : String(hwErr)}`,
          );
        }
        try {
          await fs.unlink(outputPath);
        } catch {
          /* ignore */
        }
        await runTranscode(false);
      }
    } catch (err) {
      try {
        await fs.unlink(outputPath);
      } catch {
        /* ignore */
      }
      throw err;
    }

    await fs.rename(outputPath, cachePath);
    const outStat = await fs.stat(cachePath);
    const nowIso = new Date().toISOString();
    await upsertProxyCacheEntry(proxyCacheRoot(), {
      key,
      sourcePath: abs,
      proxyPath: cachePath,
      sizeBytes: outStat.size,
      createdAt: nowIso,
      lastAccessedAt: nowIso,
      sourceSignature: {
        sourcePath: abs,
        sizeBytes: st.size,
        mtimeMs: st.mtimeMs,
        durationSecRounded: roundProxyCacheDurationSec(safeDurationSec),
      },
      proxyProfile: profile,
    });
    await pruneProxyCache(proxyCacheRoot());
    console.log(
      `[film-lab-desktop][proxy] 完了 ${cachePath} size=${(outStat.size / 1024 / 1024).toFixed(1)}MB`,
    );
    return {
      proxyPath: cachePath,
      proxySizeBytes: outStat.size,
      cacheHit: false,
    };
  },
);

ipcMain.handle("video-preview-abort-proxy", async () => {
  if (proxyProcess) {
    proxyProcess.kill("SIGTERM");
    setTimeout(() => {
      if (proxyProcess) {
        proxyProcess.kill("SIGKILL");
        proxyProcess = null;
      }
    }, 5000);
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
    registerProgressivePreviewTempPath(outputPath);

    const runTranscode = (useHw: boolean): Promise<void> =>
      new Promise((resolve, reject) => {
        const args = buildFfmpegMezzanineArgs(abs, outputPath, useHw, safeOutW, safeOutH);
        if (DEBUG_VIDEO_EXPORT_MAIN) {
          console.log(
            `[film-lab-desktop][mezzanine] ffmpeg ${useHw ? "HW" : "SW"} argv: ${JSON.stringify(args)}`,
          );
        }
        const child = spawnFfmpegNice(ffmpeg.commandPath, args, {
          env: ffmpeg.childEnv,
          stdio: ["ignore", "ignore", "pipe"],
        });
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
    } catch (err) {
      unregisterProgressivePreviewTempPath(outputPath);
      try {
        await fs.unlink(outputPath);
      } catch {
        /* ignore */
      }
      throw err;
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
