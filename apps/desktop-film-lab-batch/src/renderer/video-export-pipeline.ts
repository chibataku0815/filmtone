/**
 * Film Lab デスクトップ — 動画グレード書き出し（WebGL Viewport + ffmpeg）
 *
 * @overview 1 本のソース動画を時刻単調にデコードし、画像バッチと同じ Viewport でグレードして raw RGBA を ffmpeg に流す。
 *   MP4/H.264 かつ条件一致時は WebCodecs + CanvasTexture を優先し、それ以外は HTMLVideoElement の seek。
 * @limitations 単一 GL 直列。ffprobe/ffmpeg は PATH 必須（Homebrew 等）。macOS では VideoToolbox を優先。
 */
import * as THREE from "three";
import {
  isWebGPUSupported,
} from "film-lab-renderer";
import type { CameraOptics } from "film-lab-core";
import type { FilmLabBatchBridge } from "./desktop-api";
import {
  assertVideoImportWithinCaps,
  computeExportFrameCount,
  computeVideoExportDimensions,
  VIDEO_EXPORT_FPS,
} from "./video-export-constants";
import type { BatchGradeState } from "./batch-pipeline";
import {
  computeTargetSourceFrameIndex,
  shouldReuseDecodedSourceFrame,
} from "./video-export-frame-reuse";
import {
  shouldAttemptWebCodecsAccurateExport,
  WebCodecsMp4ExportSession,
} from "./video-export-webcodecs";
import { createOffscreenRenderSession } from "./offscreen/create-offscreen-render-session";
import type { WebGLOffscreenRenderSession } from "./offscreen/offscreen-render-session";

/**
 * @description 各フレームの詳細ログは明示時だけ有効にする。
 *   既定は quiet にして、profile / summary / 遅いフレームだけを残す。
 */
const VIDEO_EXPORT_VERBOSE_TRACE =
  import.meta.env.VITE_FILM_LAB_VERBOSE_VIDEO_EXPORT === "true";

/**
 * @description quiet モードでも完全無言にはせず、一定間隔の進捗だけは残す。
 *   5 秒ごとなら React のログ更新負荷をかなり抑えつつ、人間の確認もしやすい。
 */
const VIDEO_EXPORT_PROGRESS_LOG_INTERVAL_FRAMES = VIDEO_EXPORT_FPS * 5;

/**
 * @description debug profile 用の追加集計。verbose を戻さず「後半で遅くなるか」を end-of-run だけで読む。
 */
const VIDEO_EXPORT_DEBUG_PROFILE =
  import.meta.env.VITE_FILM_LAB_DEBUG_VIDEO_EXPORT === "true";

/**
 * @description フレーム列を 4 区間へ分け、前半と後半の差を荒く比較する。
 */
const VIDEO_EXPORT_PROFILE_SEGMENT_COUNT = 4;

/**
 * @description UI progress callback を呼ぶ間隔。見た目は十分滑らかなまま、各フレームの再描画負荷を下げる。
 */
const VIDEO_EXPORT_PROGRESS_CALLBACK_INTERVAL_FRAMES = 4;

/** @description seek がこの時間（ms）無応答なら打ち切り（どこで固まったかログに出す） */
const SEEK_TIMEOUT_MS = 90_000;

/** @description rVFC が来ないとき 2×rAF に落とすまでの待ち（ms） */
const RVFC_TIMEOUT_MS = 250;

export type VideoExportProgress = {
  /** @description 進み具合。frames なら 1 始まり、mezzanine なら 0-99 を入れる */
  currentFrame: number;
  /** @description 総数。frames は総フレーム数、mezzanine は 100 固定 */
  totalFrames: number;
  /** @description いまの進捗の種類。mezzanine か frames かを App 側で見分ける。 */
  phase?: "mezzanine" | "frames";
};

/**
 * @description `seekVideoToTime` が返す 1 フレームぶんの計測（集計ログ用）
 */
export type SeekVideoTimingDetail = {
  seekWaitMs: number;
  decodeGateMs: number;
  usedSeek: boolean;
  usedRvfc: boolean;
  usedRafFallback: boolean;
  /** @description true のとき時刻単調の前方向 rVFC で進めた（キーフレームシークなし） */
  usedForwardScan?: boolean;
};

type VideoWithRvfc = HTMLVideoElement & {
  requestVideoFrameCallback?: (
    cb: (now: number, metadata: unknown) => void,
  ) => number;
  cancelVideoFrameCallback?: (handle: number) => void;
};

/**
 * @description ミリ秒配列の中央値（ソート破壊なし）
 */
function meanMs(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((x, y) => x + y, 0) / values.length;
}

/**
 * @description フレーム番号を 4 分割のどの区間に入れるか返す。
 */
function profileSegmentIndex(frameIndex: number, totalFrames: number): number {
  const safeTotalFrames = Math.max(1, totalFrames);
  return Math.min(
    VIDEO_EXPORT_PROFILE_SEGMENT_COUNT - 1,
    Math.floor((frameIndex * VIDEO_EXPORT_PROFILE_SEGMENT_COUNT) / safeTotalFrames),
  );
}

/**
 * @description 区間ごとの mean を `q1=... q2=...` 形式でまとめる。
 */
function formatProfileSegmentMeans(valuesBySegment: number[][]): string {
  return valuesBySegment.map((values, index) => `q${index + 1}=${meanMs(values).toFixed(1)}`).join(" ");
}

/**
 * @description ミリ秒配列の中央値（ソート破壊なし）
 */
function medianMs(values: number[]): number {
  if (values.length === 0) return 0;
  const s = [...values].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 === 1 ? s[m]! : ((s[m - 1]! + s[m]!) / 2);
}

/**
 * @description ミリ秒配列の approximate 95 パーセンタイル
 */
function p95Ms(values: number[]): number {
  if (values.length === 0) return 0;
  const s = [...values].sort((a, b) => a - b);
  const idx = Math.min(s.length - 1, Math.ceil(0.95 * s.length) - 1);
  return s[Math.max(0, idx)]!;
}

/**
 * @description video 要素の状態を 1 行に要約（seek 失敗・タイムアウトの調査用）
 */
function videoDebugSnapshot(video: HTMLVideoElement): string {
  const err = video.error;
  const dur = Number.isFinite(video.duration) ? video.duration.toFixed(2) : "NaN";
  return (
    `rs=${video.readyState} ns=${video.networkState} paused=${video.paused} seeking=${video.seeking}` +
    ` ct=${video.currentTime.toFixed(6)} dur=${dur}` +
    (err ? ` err=${err.code}:${err.message}` : "")
  );
}

/**
 * @description 指定時刻へシークし、デコードゲート（rVFC 優先・タイムアウトで 2×rAF）を通す
 * @param ctx.onTrace レンダラのログへ出す詳細（seeked / rVFC / フォールバック）
 * @param ctx.frameIndex 人間向けフレーム番号（1 始まり）
 */
async function seekVideoToTime(
  video: HTMLVideoElement,
  timeSec: number,
  ctx: {
    onTrace: (line: string) => void;
    frameIndex: number;
    timeoutMs: number;
  },
): Promise<SeekVideoTimingDetail> {
  const { onTrace, frameIndex, timeoutMs } = ctx;
  const t = Math.max(0, timeSec);

  const twoRaf = () =>
    new Promise<void>((r) =>
      requestAnimationFrame(() => requestAnimationFrame(() => r())),
    );

  const runSeekAndGate = async (): Promise<SeekVideoTimingDetail> => {
    const tSeekPhase = performance.now();
    let usedSeek = false;
    let seekWaitMs = 0;

    if (Math.abs(video.currentTime - t) < 1e-4) {
      onTrace(
        `[動画][seek] f=${frameIndex} シーク省略（既に t≈${t.toFixed(6)}）${videoDebugSnapshot(video)}`,
      );
      seekWaitMs = performance.now() - tSeekPhase;
    } else {
      usedSeek = true;
      onTrace(
        `[動画][seek] f=${frameIndex} currentTime 代入 ${video.currentTime.toFixed(6)} → ${t.toFixed(6)}`,
      );
      const tWaitSeek = performance.now();
      await new Promise<void>((resolve, reject) => {
        const onVideoError = () => {
          reject(
            new Error(
              `seekVideoToTime メディアエラー f=${frameIndex} ${videoDebugSnapshot(video)}`,
            ),
          );
        };
        const onSeeked = () => {
          video.removeEventListener("error", onVideoError);
          onTrace(
            `[動画][seek] f=${frameIndex} seeked 発火 (${videoDebugSnapshot(video)})`,
          );
          resolve();
        };
        video.addEventListener("seeked", onSeeked, { once: true });
        video.addEventListener("error", onVideoError, { once: true });
        try {
          video.currentTime = t;
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          reject(
            new Error(
              `seekVideoToTime currentTime 代入失敗 f=${frameIndex} — ${msg}`,
            ),
          );
        }
      });
      seekWaitMs = performance.now() - tWaitSeek;
    }

    const tGate = performance.now();
    let usedRvfc = false;
    let usedRafFallback = false;
    const v = video as VideoWithRvfc;

    try {
      await video.play();
    } catch (e) {
      const m = e instanceof Error ? e.message : String(e);
      onTrace(
        `[動画][seek] f=${frameIndex} decodeGate → play 失敗、2×rAF — ${m}`,
      );
      usedRafFallback = true;
      await twoRaf();
      video.pause();
      return {
        seekWaitMs,
        decodeGateMs: performance.now() - tGate,
        usedSeek,
        usedRvfc: false,
        usedRafFallback: true,
      };
    }

    if (typeof v.requestVideoFrameCallback !== "function") {
      onTrace(
        `[動画][seek] f=${frameIndex} decodeGate → rVFC 未対応、2×rAF/pause`,
      );
      usedRafFallback = true;
      await twoRaf();
      video.pause();
      return {
        seekWaitMs,
        decodeGateMs: performance.now() - tGate,
        usedSeek,
        usedRvfc: false,
        usedRafFallback: true,
      };
    }

    const gotRvfc = await new Promise<boolean>((resolve) => {
      let done = false;
      let handle = 0;
      const timer = window.setTimeout(() => {
        if (done) return;
        done = true;
        if (typeof v.cancelVideoFrameCallback === "function") {
          try {
            v.cancelVideoFrameCallback(handle);
          } catch {
            /* キャンセル失敗は無視 */
          }
        }
        onTrace(
          `[動画][seek] f=${frameIndex} decodeGate → rVFC ${RVFC_TIMEOUT_MS}ms タイムアウト、2×rAF`,
        );
        resolve(false);
      }, RVFC_TIMEOUT_MS);

      handle = v.requestVideoFrameCallback!(() => {
        if (done) return;
        done = true;
        window.clearTimeout(timer);
        video.pause();
        onTrace(
          `[動画][seek] f=${frameIndex} decodeGate → rVFC で完了 (${videoDebugSnapshot(video)})`,
        );
        resolve(true);
      });
    });

    if (!gotRvfc) {
      usedRafFallback = true;
      await twoRaf();
      video.pause();
    } else {
      usedRvfc = true;
    }

    return {
      seekWaitMs,
      decodeGateMs: performance.now() - tGate,
      usedSeek,
      usedRvfc,
      usedRafFallback,
    };
  };

  return new Promise<SeekVideoTimingDetail>((resolve, reject) => {
    let finished = false;
    const to = window.setTimeout(() => {
      if (finished) return;
      finished = true;
      reject(
        new Error(
          `seekVideoToTime タイムアウト (${timeoutMs}ms) f=${frameIndex} targetT=${t.toFixed(6)} ${videoDebugSnapshot(video)}`,
        ),
      );
    }, timeoutMs);
    void runSeekAndGate()
      .then((detail) => {
        if (finished) return;
        finished = true;
        window.clearTimeout(to);
        resolve(detail);
      })
      .catch((e) => {
        if (finished) return;
        finished = true;
        window.clearTimeout(to);
        reject(e instanceof Error ? e : new Error(String(e)));
      });
  });
}

/**
 * @description rVFC メタまたは video の currentTime から表示時刻（秒）を得る
 */
function readRvfcMediaTime(
  video: HTMLVideoElement,
  metadata: unknown,
): number {
  if (
    metadata &&
    typeof metadata === "object" &&
    "mediaTime" in metadata
  ) {
    const mt = (metadata as { mediaTime?: unknown }).mediaTime;
    if (typeof mt === "number" && Number.isFinite(mt)) {
      return mt;
    }
  }
  return video.currentTime;
}

/**
 * @description 書き出しは t が単調増加するので、`currentTime` を飛ばさずデコードだけ進める。キーフレームシークが減り爆速になりやすい。
 * @limitations 巻き戻し・rVFC 非対応・play 失敗時は `seekVideoToTime` にフォールバック。
 */
async function advanceVideoToTimeForward(
  video: HTMLVideoElement,
  targetTimeSec: number,
  ctx: {
    onTrace: (line: string) => void;
    frameIndex: number;
    timeoutMs: number;
  },
): Promise<SeekVideoTimingDetail> {
  const { onTrace, frameIndex, timeoutMs } = ctx;
  const dur = Number.isFinite(video.duration) ? video.duration : targetTimeSec;
  const tGoal = Math.max(0, Math.min(targetTimeSec, dur));

  if (tGoal < video.currentTime - 0.04) {
    onTrace(
      `[動画][fwd] f=${frameIndex} 巻き戻し検出 goal=${tGoal.toFixed(4)} ct=${video.currentTime.toFixed(4)} → シーク`,
    );
    const d = await seekVideoToTime(video, tGoal, ctx);
    return { ...d, usedForwardScan: false };
  }

  const v = video as VideoWithRvfc;
  if (typeof v.requestVideoFrameCallback !== "function") {
    onTrace(`[動画][fwd] f=${frameIndex} rVFC なし → シーク`);
    const d = await seekVideoToTime(video, tGoal, ctx);
    return { ...d, usedForwardScan: false };
  }

  const runForward = async (): Promise<SeekVideoTimingDetail> => {
    const tGate0 = performance.now();
    let rvfcSteps = 0;
    const timeSlopSec = 1 / VIDEO_EXPORT_FPS / 64;

    try {
      await video.play();
    } catch (e) {
      const m = e instanceof Error ? e.message : String(e);
      onTrace(`[動画][fwd] f=${frameIndex} play 失敗 → シーク — ${m}`);
      const d = await seekVideoToTime(video, tGoal, ctx);
      return { ...d, usedForwardScan: false };
    }

    while (!video.ended && rvfcSteps < 65536) {
      const mt = await new Promise<number>((resolve, reject) => {
        const stepTo = window.setTimeout(() => {
          reject(
            new Error(
              `advanceVideoToTimeForward rVFC 待ちタイムアウト f=${frameIndex}`,
            ),
          );
        }, 60_000);
        try {
          v.requestVideoFrameCallback!((_now, meta) => {
            window.clearTimeout(stepTo);
            resolve(readRvfcMediaTime(video, meta));
          });
        } catch (err) {
          window.clearTimeout(stepTo);
          reject(err);
        }
      });
      rvfcSteps++;

      if (mt + timeSlopSec >= tGoal) {
        video.pause();
        onTrace(
          `[動画][fwd] f=${frameIndex} goal=${tGoal.toFixed(4)} mediaT≈${mt.toFixed(4)} steps=${rvfcSteps} (${videoDebugSnapshot(video)})`,
        );
        return {
          seekWaitMs: 0,
          decodeGateMs: performance.now() - tGate0,
          usedSeek: false,
          usedRvfc: true,
          usedRafFallback: false,
          usedForwardScan: true,
        };
      }
    }

    video.pause();
    onTrace(
      `[動画][fwd] f=${frameIndex} EOS 手前 goal=${tGoal.toFixed(4)} steps=${rvfcSteps} (${videoDebugSnapshot(video)})`,
    );
    return {
      seekWaitMs: 0,
      decodeGateMs: performance.now() - tGate0,
      usedSeek: false,
      usedRvfc: rvfcSteps > 0,
      usedRafFallback: false,
      usedForwardScan: true,
    };
  };

  return new Promise<SeekVideoTimingDetail>((resolve, reject) => {
    let done = false;
    const to = window.setTimeout(() => {
      if (done) return;
      done = true;
      video.pause();
      reject(
        new Error(
          `advanceVideoToTimeForward タイムアウト (${timeoutMs}ms) f=${frameIndex} goal=${tGoal.toFixed(4)} ${videoDebugSnapshot(video)}`,
        ),
      );
    }, timeoutMs);

    void runForward()
      .then((detail) => {
        if (done) return;
        done = true;
        window.clearTimeout(to);
        resolve(detail);
      })
      .catch(async (e) => {
        if (done) return;
        onTrace(
          `[動画][fwd] f=${frameIndex} 失敗 → シークへ: ${e instanceof Error ? e.message : String(e)}`,
        );
        try {
          video.pause();
          const d = await seekVideoToTime(video, tGoal, ctx);
          done = true;
          window.clearTimeout(to);
          resolve({ ...d, usedForwardScan: false });
        } catch (err) {
          done = true;
          window.clearTimeout(to);
          video.pause();
          reject(err instanceof Error ? err : new Error(String(err)));
        }
      });
  });
}

/**
 * @description rVFC / play / pause のリアルタイム制約を排除した純粋 seek。
 * seeked 発火後に videoTexture.needsUpdate = true で Three.js にフレームアップロードを委ねる。
 * createImageBitmap は廃止（SRGB8_ALPHA8 vs RGBA の internalformat 不一致でカラースペースが壊れるため）。
 */
async function seekToFrame(
  video: HTMLVideoElement,
  timeSec: number,
  ctx: {
    onTrace: (line: string) => void;
    frameIndex: number;
    timeoutMs: number;
  },
): Promise<{ seekWaitMs: number }> {
  const { onTrace, frameIndex, timeoutMs } = ctx;
  const t = Math.max(0, timeSec);

  const tSeek0 = performance.now();

  // Already at target time — skip seek
  if (Math.abs(video.currentTime - t) >= 1e-4) {
    await new Promise<void>((resolve, reject) => {
      const timer = window.setTimeout(() => {
        cleanup();
        reject(new Error(`seekToFrame タイムアウト (${timeoutMs}ms) f=${frameIndex} target=${t.toFixed(6)} ${videoDebugSnapshot(video)}`));
      }, timeoutMs);
      const cleanup = () => {
        window.clearTimeout(timer);
        video.removeEventListener("seeked", onSeeked);
        video.removeEventListener("error", onError);
      };
      const onSeeked = () => { cleanup(); resolve(); };
      const onError = () => {
        cleanup();
        reject(new Error(`seekToFrame メディアエラー f=${frameIndex} ${videoDebugSnapshot(video)}`));
      };
      video.addEventListener("seeked", onSeeked, { once: true });
      video.addEventListener("error", onError, { once: true });
      try {
        video.currentTime = t;
      } catch (e) {
        cleanup();
        reject(e instanceof Error ? e : new Error(String(e)));
      }
    });
  }

  const seekWaitMs = performance.now() - tSeek0;
  return { seekWaitMs };
}

function basename(filePath: string): string {
  const norm = filePath.replace(/\\/g, "/");
  const i = norm.lastIndexOf("/");
  return i >= 0 ? norm.slice(i + 1) : norm;
}

/**
 * @description Chromium の video 要素で metadata まで読む。失敗時は tmp へコピーして再試行（フォトの一時パス等）
 */
async function openVideoForExport(
  api: FilmLabBatchBridge,
  inputVideoPath: string,
  onLog: (line: string) => void,
): Promise<{
  video: HTMLVideoElement;
  /** @description ffmpeg の 2nd input（音声コピー）に渡す実体パス */
  pathForFfmpeg: string;
  /** @description 削除が必要な tmp パス。無ければ null */
  stagedPath: string | null;
}> {
  const waitLoadedMetadata = (v: HTMLVideoElement): Promise<void> => {
    return new Promise((resolve, reject) => {
      const to = window.setTimeout(() => {
        cleanup();
        reject(new Error("動画 metadata 読み込みタイムアウト（30s）"));
      }, 30000);
      const cleanup = () => {
        window.clearTimeout(to);
        v.removeEventListener("loadedmetadata", onMeta);
        v.removeEventListener("error", onErr);
      };
      const onMeta = () => {
        cleanup();
        resolve();
      };
      const onErr = () => {
        cleanup();
        const code = v.error?.code;
        const detail = v.error?.message ?? "";
        reject(
          new Error(
            `メディアエラー (code=${code ?? "?"}${detail ? ` — ${detail}` : ""})`,
          ),
        );
      };
      v.addEventListener("loadedmetadata", onMeta);
      v.addEventListener("error", onErr);
    });
  };

  const loadFromAbsolutePath = async (
    absPath: string,
  ): Promise<HTMLVideoElement> => {
    const v = document.createElement("video");
    v.muted = true;
    v.playsInline = true;
    v.preload = "auto";
    v.crossOrigin = "anonymous";
    const fileUrl = await api.pathToFileURL(absPath);

    const pageIsHttp =
      typeof window !== "undefined" &&
      (window.location.protocol === "http:" ||
        window.location.protocol === "https:");
    if (pageIsHttp && fileUrl.startsWith("file:")) {
      throw new Error(
        "MAIN_PROCESS_STALE: いまの Electron メインプロセスが古く、file:// を返しています。`apps/desktop-film-lab-batch` で `bun run build:electron` を実行し、ウィンドウを完全に閉じてから `bun run desktop` で起動し直してください（Vite だけ再起動しても直りません）。",
      );
    }

    try {
      const scheme = new URL(fileUrl).protocol;
      if (scheme === "file:") {
        onLog(
          "[動画] 警告: video.src が file: — main 未ビルドの可能性（bun run build:electron を実行してください）",
        );
      }
    } catch {
      // URL 解析不能は無視
    }
    v.src = fileUrl;
    await waitLoadedMetadata(v);
    return v;
  };

  try {
    const video = await loadFromAbsolutePath(inputVideoPath);
    return { video, pathForFfmpeg: inputVideoPath, stagedPath: null };
  } catch (first) {
    if (
      first instanceof Error &&
      first.message.startsWith("MAIN_PROCESS_STALE:")
    ) {
      const msg = first.message.replace(/^MAIN_PROCESS_STALE:\s*/, "");
      throw new Error(msg);
    }
    onLog(
      `[動画] ブラウザでの読込に失敗: ${first instanceof Error ? first.message : String(first)}`,
    );
    onLog(
      "[動画] 写真アプリ等の一時ファイルの可能性があるため、作業用コピーを作って再試行します（映画が長いと複写に時間がかかります）。",
    );
    let stagedPath: string;
    try {
      stagedPath = (await api.videoExportStageSource(inputVideoPath)).stagedPath;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new Error(`作業用コピー作成失敗: ${msg}`);
    }
    try {
      const video = await loadFromAbsolutePath(stagedPath);
      return { video, pathForFfmpeg: stagedPath, stagedPath };
    } catch (e) {
      await api.videoExportUnlinkStaged(stagedPath).catch(() => {});
      const msg = e instanceof Error ? e.message : String(e);
      throw new Error(
        `コピー後も開けません。デスクトップ等に動画を書き出してから選び直すか、H.264 の MP4 を試してください。詳細: ${msg}`,
      );
    }
  }
}

/**
 * @description UI に見せる日本語／英語メッセージ（レンダラの next-intl から渡す）
 */
export type VideoExportPipelineUserMessages = {
  webglUnavailable: string;
  metadataFailed: (detail: string) => string;
  ffmpegStartFailed: (detail: string) => string;
  userAborted: string;
  ffmpegFailed: (code: number) => string;
};

/**
 * @description WebCodecs 実行中の失敗だけを既存 seek 経路で 1 回だけやり直すための判定。
 *   ffmpeg や IPC の失敗はここで飲まず、そのまま FATAL にする。
 */
export function shouldRetryWithSeekAfterWebCodecsRuntimeFailure(
  message: string,
): boolean {
  const lower = message.toLowerCase();
  return (
    lower.includes("webcodecsmp4exportsession") ||
    lower.includes("videodecoder") ||
    lower.includes("drawholdertocanvas")
  );
}

/**
 * @description WebCodecs で高速デコードできないコーデックを判定する。
 *   該当時は ProRes 422 mezzanine に事前変換して seek 速度を改善する。
 */
export function needsMezzanineTranscode(opts: {
  videoCodec: string;
  fileSizeBytes: number;
  absPath: string;
}): boolean {
  const c = opts.videoCodec.toLowerCase();
  // H.264: WebCodecs or HTMLVideoElement で十分速い → 不要
  if (c === "h264" || c === "avc") return false;
  // ProRes: Chromium <video> は macOS でもデコード不可 → mezzanine 必要
  if (c === "prores") return true;
  // HEVC, VP9, AV1, DNxHD 等: mezzanine 必要
  return true;
}

/**
 * @description `<video>` を停止して `src` を外す。seek 経路への再試行時に古いデコーダを残しにくくする。
 */
function disposeVideoElement(video: HTMLVideoElement | null): void {
  if (!video) return;
  try {
    video.pause();
  } catch {
    /* ignore */
  }
  try {
    video.removeAttribute("src");
    video.load();
  } catch {
    /* ignore */
  }
}

/**
 * @description 1 本の動画をグレードして mp4 へ書き出す
 * @param options.api — preload ブリッジ（ffmpeg IPC を含む）
 * @param options.inputVideoPath — ソースの絶対パス
 * @param options.outputDir — 出力ディレクトリ
 * @param options.outputFileName — ファイル名のみ（例: clip-graded.mp4）
 * @param options.grade — バッチと同じ BatchGradeState
 * @param options.signal — 中断用 AbortSignal
 * @param options.onProgress — フレーム進捗
 * @param options.onLog — ログ 1 行
 * @param options.userMessages — 返却する message 文言の上書き（未指定時は従来の日本語固定）
 */
export async function runVideoExportPipeline(options: {
  api: FilmLabBatchBridge;
  inputVideoPath: string;
  outputDir: string;
  outputFileName: string;
  grade: BatchGradeState;
  cameraOptics?: CameraOptics | null;
  signal?: AbortSignal;
  onProgress?: (p: VideoExportProgress) => void;
  onLog: (line: string) => void;
  userMessages?: VideoExportPipelineUserMessages;
  /**
   * @description Progressive loading で既に生成済みの mezzanine パス。
   * 指定時は mezzanine 再生成をスキップしてこのパスを使います。
   * エクスポート完了後の削除はこのパイプラインでは行いません（呼び出し側が管理）。
   */
  precomputedMezzaninePath?: string | null;
}): Promise<{ ok: true } | { ok: false; message: string }> {
  const {
    api,
    inputVideoPath,
    outputDir,
    outputFileName,
    grade,
    cameraOptics,
    signal,
    onProgress,
    onLog,
    userMessages,
    precomputedMezzaninePath,
  } = options;

  const u =
    userMessages ??
    ({
      webglUnavailable: "WebGPU が利用できません",
      metadataFailed: (detail: string) => `メタデータ取得失敗: ${detail}`,
      ffmpegStartFailed: (detail: string) => `ffmpeg 開始失敗: ${detail}`,
      userAborted: "中断されました",
      ffmpegFailed: (code: number) => `ffmpeg 失敗 code=${code}`,
    } satisfies VideoExportPipelineUserMessages);

  if (!(await isWebGPUSupported())) {
    return { ok: false, message: u.webglUnavailable };
  }

  let probe: Awaited<ReturnType<FilmLabBatchBridge["videoExportProbe"]>>;
  try {
    probe = await api.videoExportProbe(inputVideoPath);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, message: u.metadataFailed(msg) };
  }

  const sourceDisplayGeometry = probe.sourceVideoMetadata?.display;
  const sourceWidthForExport = sourceDisplayGeometry?.displayWidth ?? probe.width;
  const sourceHeightForExport = sourceDisplayGeometry?.displayHeight ?? probe.height;
  const sourceRawWidth = sourceDisplayGeometry?.rawWidth ?? probe.width;
  const sourceRawHeight = sourceDisplayGeometry?.rawHeight ?? probe.height;
  const sourceRotationDeg = sourceDisplayGeometry?.rotationDeg ?? null;
  const sourceColorMetadata = probe.sourceVideoMetadata?.color;
  const sourceColorClass = probe.sourceVideoMetadata?.colorClass ?? null;
  const sourceHdrPreparationPolicy =
    probe.sourceVideoMetadata?.hdrPreparationPolicy ?? null;
  const hdrFilterSelection = sourceHdrPreparationPolicy?.filterSelection ?? null;
  const shouldToneMapHdrToSdr =
    sourceHdrPreparationPolicy?.strategy === "prepare-sdr-mezzanine" &&
    hdrFilterSelection != null;
  const sourceTimingMetadata = probe.sourceVideoMetadata?.timing;

  try {
    assertVideoImportWithinCaps(
      sourceWidthForExport,
      sourceHeightForExport,
      probe.durationSec,
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, message: msg };
  }

  const { outW, outH } = computeVideoExportDimensions(
    sourceWidthForExport,
    sourceHeightForExport,
  );
  const totalFrames = computeExportFrameCount(probe.durationSec);
  const safeOutName =
    outputFileName.replace(/[/\\]/g, "_").replace(/[<>:"|?*\u0000-\u001f]/g, "_") ||
    "film-lab-export.mp4";

  onLog(
    `[動画] ${basename(inputVideoPath)} → ${outW}×${outH} @ ${VIDEO_EXPORT_FPS}fps, ${totalFrames} フレーム`,
  );
  onLog(
    `[動画] ソース ${sourceWidthForExport}×${sourceHeightForExport}` +
      (sourceDisplayGeometry &&
      (sourceRawWidth !== sourceWidthForExport ||
        sourceRawHeight !== sourceHeightForExport ||
        sourceRotationDeg !== null)
        ? `（raw ${sourceRawWidth}×${sourceRawHeight}, rotation ${sourceRotationDeg ?? "none"}）`
        : "") +
      `, ${probe.durationSec.toFixed(2)}s, 音声: ${probe.hasAudio ? "あり" : "なし"}, codec: ${probe.videoCodec || "unknown"}` +
      (probe.sourceFrameRateTrusted === true && probe.sourceFrameRate !== null
        ? `, ソースFPS信頼 ~${probe.sourceFrameRate.toFixed(4)}（同一ソースフレームはシーク省略）`
        : `, ソースFPS不信任（ソースフレーム索引の再利用なし）`),
  );
  if (sourceColorMetadata && sourceColorClass) {
    onLog(
      `[動画] 色メタデータ ${sourceColorClass}: range=${sourceColorMetadata.colorRange ?? "unknown"}, space=${sourceColorMetadata.colorSpace ?? "unknown"}, transfer=${sourceColorMetadata.colorTransfer ?? "unknown"}, primaries=${sourceColorMetadata.colorPrimaries ?? "unknown"}` +
        (sourceColorMetadata.hasMasteringDisplayMetadata
          ? ", mastering-display"
          : "") +
        (sourceColorMetadata.hasContentLightMetadata ? ", content-light" : ""),
    );
  }
  if (sourceHdrPreparationPolicy) {
    onLog(
      `[動画] HDR準備ポリシー ${sourceHdrPreparationPolicy.strategy}: reason=${sourceHdrPreparationPolicy.reason}, fixtureValidation=${sourceHdrPreparationPolicy.requiresFixtureValidation ? "required" : "not-required"}` +
        (sourceHdrPreparationPolicy.filterSelection
          ? `, filterSelection=${JSON.stringify(sourceHdrPreparationPolicy.filterSelection)}`
          : "") +
        (sourceHdrPreparationPolicy.warning
          ? `, warning=${sourceHdrPreparationPolicy.warning}`
          : ""),
    );
  }
  if (sourceTimingMetadata) {
    onLog(
      `[動画] フレームレート判定 avg=${sourceTimingMetadata.avgFrameRate ?? "unknown"} (${sourceTimingMetadata.avgFrameRateParsed?.toFixed(4) ?? "invalid"}), r=${sourceTimingMetadata.rFrameRate ?? "unknown"} (${sourceTimingMetadata.rFrameRateParsed?.toFixed(4) ?? "invalid"}), reason=${sourceTimingMetadata.trustReason}`,
    );
  }

  // --- Mezzanine transcode (ProRes 422) for heavy codecs ---
  let mezzaninePath: string | null = null;
  /** @description true のとき mezzanine はこのパイプラインが作ったもの → 完了後に削除する */
  let mezzanineOwnedByExport = false;
  const needsCodecMezzanine = needsMezzanineTranscode({
    videoCodec: probe.videoCodec,
    fileSizeBytes: probe.fileSizeBytes,
    absPath: inputVideoPath,
  });
  if (shouldToneMapHdrToSdr || needsCodecMezzanine) {
    if (
      !shouldToneMapHdrToSdr &&
      typeof precomputedMezzaninePath === "string" &&
      precomputedMezzaninePath.length > 0
    ) {
      mezzaninePath = precomputedMezzaninePath;
      mezzanineOwnedByExport = false;
      onLog(
        `[動画][mezzanine] progressive loading の mezzanine を再利用します`,
      );
    } else {
      onLog(
        shouldToneMapHdrToSdr
          ? `[動画][mezzanine] HDR→SDR tone-map ${hdrFilterSelection.kind} (${hdrFilterSelection.chainId}) → H.264 all-I-frame mezzanine を生成します...`
          : `[動画][mezzanine] codec=${probe.videoCodec} → H.264 all-I-frame mezzanine を生成します...`,
      );
      const unsubscribeMezzanineProgress = onProgress
        ? api.subscribeMezzanineProgress((payload) => {
            onProgress({
              currentFrame: payload.current,
              totalFrames: payload.total,
              phase: "mezzanine",
            });
          })
        : null;
      try {
        const t0 = performance.now();
        const result = await api.videoExportTranscodeMezzanine({
          filePath: inputVideoPath,
          durationSec: probe.durationSec,
          outW,
          outH,
          sourceVideoMetadata: probe.sourceVideoMetadata,
        });
        const elapsedSec = ((performance.now() - t0) / 1000).toFixed(1);
        mezzaninePath = result.mezzaninePath;
        mezzanineOwnedByExport = true;
        onLog(
          `[動画][mezzanine] 完了 size=${(result.mezzanineSizeBytes / 1024 / 1024).toFixed(0)}MB elapsed=${elapsedSec}s`,
        );
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        onLog(
          `[動画][mezzanine] 生成失敗、オリジナルソースで続行 — ${msg}`,
        );
        mezzaninePath = null;
      } finally {
        unsubscribeMezzanineProgress?.();
      }
    }
  }
  const effectiveInputPath = mezzaninePath ?? inputVideoPath;

  let stagedPath: string | null = null;
  const hasDisplayRotation =
    sourceRotationDeg !== null && sourceRotationDeg !== 0;
  const tryWebCodecs = !hasDisplayRotation && shouldAttemptWebCodecsAccurateExport({
    videoCodec: probe.videoCodec,
    fileSizeBytes: probe.fileSizeBytes,
    absPath: inputVideoPath,
  });
  if (hasDisplayRotation) {
    onLog(
      `[動画][WebCodecs] display rotation ${sourceRotationDeg}° のため HTMLVideoElement シーク経路を使います`,
    );
  }
  const epsilon = 1 / VIDEO_EXPORT_FPS / 1000;
  const maxT = Math.max(0, probe.durationSec - epsilon);
  const sourceFpsTrusted = probe.sourceFrameRateTrusted === true;
  const sourceFpsValue = probe.sourceFrameRate;
  const cpuBuf = new Uint8Array(outW * outH * 4);
  const maxAttempts = tryWebCodecs ? 2 : 1;

  try {
    for (let attemptIndex = 0; attemptIndex < maxAttempts; attemptIndex++) {
      const allowWebCodecs = tryWebCodecs && attemptIndex === 0;
      let video: HTMLVideoElement | null = null;
      let pathForFfmpeg = stagedPath ?? effectiveInputPath;
      let webCodecsSession: WebCodecsMp4ExportSession | null = null;
      let srcTexture: THREE.Texture | null = null;
      let renderSession: Awaited<
        ReturnType<typeof createOffscreenRenderSession>
      > | null = null;
      let retryWithSeek = false;
      let retryReason = "";
      let exportSessionId: string | null = null;

      const abortActiveVideoExport = async (): Promise<void> => {
        const currentSessionId = exportSessionId;
        exportSessionId = null;
        await api.videoExportAbort(currentSessionId).catch(() => {});
      };

      try {
        if (allowWebCodecs) {
          try {
            let fileBytes: Uint8Array;
            const readSourcePath = stagedPath ?? effectiveInputPath;
            try {
              fileBytes = await api.readFileBuffer(readSourcePath);
              pathForFfmpeg = readSourcePath;
            } catch (readErr) {
              onLog(
                `[動画][WebCodecs] ソース直接 read 失敗 → ステージング（${readErr instanceof Error ? readErr.message : String(readErr)}）`,
              );
              const st = await api.videoExportStageSource(effectiveInputPath);
              stagedPath = st.stagedPath;
              pathForFfmpeg = st.stagedPath;
              fileBytes = await api.readFileBuffer(st.stagedPath);
            }
            const ab = fileBytes.buffer.slice(
              fileBytes.byteOffset,
              fileBytes.byteOffset + fileBytes.byteLength,
            );
            webCodecsSession = await WebCodecsMp4ExportSession.create(
              ab,
              {
                width: sourceRawWidth,
                height: sourceRawHeight,
                durationSec: probe.durationSec,
              },
              onLog,
            );
            onLog(
              "[動画][WebCodecs] デコード: VideoDecoder + CanvasTexture（HTMLVideoElement シークなし）",
            );
          } catch (wcErr) {
            const detail =
              wcErr instanceof Error ? wcErr.message : String(wcErr);
            onLog(`[動画][WebCodecs] 失敗、従来経路へ — ${detail}`);
            webCodecsSession = null;
            pathForFfmpeg = stagedPath ?? effectiveInputPath;
          }
        } else if (attemptIndex > 0) {
          onLog(
            "[動画][WebCodecs] runtime fallback: HTMLVideoElement シーク経路で最初から再試行します",
          );
        }

        if (!webCodecsSession) {
          try {
            const opened = await openVideoForExport(
              api,
              stagedPath ?? effectiveInputPath,
              onLog,
            );
            video = opened.video;
            pathForFfmpeg = opened.pathForFfmpeg;
            if (opened.stagedPath && opened.stagedPath !== stagedPath) {
              if (stagedPath) {
                await api.videoExportUnlinkStaged(stagedPath).catch(() => {});
              }
              stagedPath = opened.stagedPath;
            }
          } catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            return { ok: false, message: msg };
          }
          video.pause();
        }

        srcTexture = webCodecsSession
          ? (() => {
              const ct = webCodecsSession.texture;
              // Canvas 2D drawImage(videoFrame) は macOS で既に linear 化された値を返す。
              // SRGBColorSpace を指定すると Three.js が二重に sRGB→linear 変換し暗化する。
              // LinearSRGBColorSpace でバイパスして HTMLVideoElement 経路と色を一致させる。
              ct.colorSpace = THREE.LinearSRGBColorSpace;
              return ct;
            })()
          : (() => {
              const vt = new THREE.VideoTexture(video!);
              vt.colorSpace = THREE.SRGBColorSpace;
              vt.minFilter = THREE.LinearFilter;
              vt.magFilter = THREE.LinearFilter;
              return vt;
            })();

        renderSession = await createOffscreenRenderSession({
          width: outW,
          height: outH,
          prefer: "webgpu",
          powerPreference: "high-performance",
        });
        onLog(`[動画] offscreen backend: ${renderSession.backendKind}`);
        renderSession.setGrade(grade);
        renderSession.setCameraOptics(cameraOptics ?? probe.cameraOptics ?? null);
        await renderSession.setDepthTrack(grade.depthTrack);
        await renderSession.setSource({
          texture: srcTexture,
          imageWidth: sourceWidthForExport,
          imageHeight: sourceHeightForExport,
        });

        // Reset motion blur accumulation so export starts from a clean state
        renderSession.resetMotionBlurHistory();

        const gl =
          renderSession.backendKind === "webgl"
            ? (renderSession as WebGLOffscreenRenderSession).getWebGLContext()
            : null;

        // --- PBO readback (WebGL2 PIXEL_PACK_BUFFER) ---
        // WebGL backend keeps the existing async-overlapped path. WebGPU
        // uses the session's backend-neutral RGBA readback instead.
        const pboSize = outW * outH * 4;
        let usePbo = renderSession.backendKind === "webgl";
        let useFence = false;
        const pbos: [WebGLBuffer | null, WebGLBuffer | null] = [null, null];
        if (gl) {
          try {
            pbos[0] = gl.createBuffer();
            if (!pbos[0]) throw new Error("createBuffer returned null");
            gl.bindBuffer(gl.PIXEL_PACK_BUFFER, pbos[0]);
            gl.bufferData(gl.PIXEL_PACK_BUFFER, pboSize, gl.STREAM_READ);
            gl.bindBuffer(gl.PIXEL_PACK_BUFFER, null);

            // Probe fenceSync: some ANGLE/Metal backends return WAIT_FAILED
            const probeSync = gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0);
            if (probeSync) {
              gl.flush();
              const probeResult = gl.clientWaitSync(
                probeSync,
                gl.SYNC_FLUSH_COMMANDS_BIT,
                1_000_000_000,
              );
              gl.deleteSync(probeSync);
              if (
                probeResult === gl.ALREADY_SIGNALED ||
                probeResult === gl.CONDITION_SATISFIED
              ) {
                useFence = true;
                // Create second PBO for double-buffer
                pbos[1] = gl.createBuffer();
                if (!pbos[1]) throw new Error("createBuffer[1] returned null");
                gl.bindBuffer(gl.PIXEL_PACK_BUFFER, pbos[1]);
                gl.bufferData(gl.PIXEL_PACK_BUFFER, pboSize, gl.STREAM_READ);
                gl.bindBuffer(gl.PIXEL_PACK_BUFFER, null);
              }
            }
            const mode = useFence ? "PBO double-buffer + fenceSync" : "PBO + finish";
            onLog(
              `[動画][PBO] ${mode} (${(pboSize / 1024 / 1024).toFixed(1)}MB${useFence ? " × 2" : ""})`,
            );
          } catch (pboErr) {
            usePbo = false;
            for (const p of pbos) if (p) gl.deleteBuffer(p);
            pbos[0] = null;
            pbos[1] = null;
            onLog(
              `[動画][PBO] 作成失敗、sync readPixels にフォールバック — ${pboErr instanceof Error ? pboErr.message : String(pboErr)}`,
            );
          }
        } else {
          onLog("[動画][readback] WebGPU session readback を使用します");
        }
        let pboIdx = 0;
        let prevFence: WebGLSync | null = null;

        const invokeVideoExportWriteFrame = (
          frameBytes: Uint8Array,
        ): Promise<void> => {
          const currentSessionId = exportSessionId;
          if (!currentSessionId) {
            return Promise.reject(
              new Error("video-export-write-frame: セッションが初期化されていません"),
            );
          }
          return api.videoExportWriteFrame({
            sessionId: currentSessionId,
            data: frameBytes,
          });
        };

        let resolvedOutPath: string;
        try {
          await api.videoExportAbort(null).catch(() => {});
          const startRes = await api.videoExportStart({
            inputVideoPath: pathForFfmpeg,
            outputDir,
            outputFileName: safeOutName,
            width: outW,
            height: outH,
            fps: VIDEO_EXPORT_FPS,
            hasAudio: probe.hasAudio,
            dropFirstFrame: renderSession.backendKind === "webgl",
            cameraOptics: cameraOptics ?? probe.cameraOptics,
          });
          resolvedOutPath = startRes.outputVideoPath;
          exportSessionId = startRes.sessionId;
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          return { ok: false, message: `ffmpeg 開始失敗: ${msg}` };
        }

        const wallStart = performance.now();
        const arrSeekWait: number[] = [];
        const arrDecode: number[] = [];
        const arrRender: number[] = [];
        const arrRead: number[] = [];
        const arrIpc: number[] = [];
        const arrTotal: number[] = [];
        const arrSeekWaitBySegment = Array.from(
          { length: VIDEO_EXPORT_PROFILE_SEGMENT_COUNT },
          () => [] as number[],
        );
        const arrIpcBySegment = Array.from(
          { length: VIDEO_EXPORT_PROFILE_SEGMENT_COUNT },
          () => [] as number[],
        );
        const arrTotalBySegment = Array.from(
          { length: VIDEO_EXPORT_PROFILE_SEGMENT_COUNT },
          () => [] as number[],
        );
        let countSeekedPaths = 0;
        let countReusedFrames = 0;
        let countRvfcFrames = 0;
        let countRafFallbackFrames = 0;
        let countForwardScans = 0;
        let lastDecodedSourceFrameIndex: number | null = null;

        let pendingIpc: Promise<void> | null = null;
        let pendingIpcError: string | null = null;

        /**
         * @description 直前フレームの非同期 IPC 書込を吸い切り、保持していたエラー文字列を返す。
         */
        const drainPendingIpc = async (): Promise<string | null> => {
          if (pendingIpc) {
            await pendingIpc.catch(() => {});
            pendingIpc = null;
          }
          const msg = pendingIpcError;
          pendingIpcError = null;
          return msg;
        };

        for (let i = 0; i < totalFrames; i++) {
          if (signal?.aborted) {
            onLog("[動画] ユーザー中断");
            await drainPendingIpc();
            await abortActiveVideoExport();
            return { ok: false, message: u.userAborted };
          }

          const t = Math.min(i / VIDEO_EXPORT_FPS, maxT);
          const tFrame0 = performance.now();
          const profileSegment = profileSegmentIndex(i, totalFrames);

          renderSession.setTime(t);

          const targetSourceIdx = computeTargetSourceFrameIndex(
            t,
            sourceFpsValue,
            sourceFpsTrusted,
          );
          const reuseFrame = shouldReuseDecodedSourceFrame(
            lastDecodedSourceFrameIndex,
            targetSourceIdx,
          );

          let seekWaitMs = 0;
          let decodeGateMs = 0;

          if (reuseFrame) {
            countReusedFrames++;
            const ipcErr = await drainPendingIpc();
            if (ipcErr) {
              onLog(`[動画] フレーム書込エラー: ${ipcErr}`);
              await abortActiveVideoExport();
              return { ok: false, message: ipcErr };
            }
          } else {
            countSeekedPaths++;
            // WebCodecs: presentAtMediaTimeSec / 従来: seekToFrame。いずれも前フレーム IPC と Promise.all で重畳。
            const syncMediaPromise = webCodecsSession
              ? (async () => {
                  const tracePipe =
                    VIDEO_EXPORT_VERBOSE_TRACE &&
                    (i < 6 || i % 200 === 0 || i + 1 === totalFrames);
                  if (tracePipe) {
                    onLog(
                      `[動画][WebCodecs][trace] pipeline f=${i + 1}/${totalFrames} BEFORE presentAtMediaTimeSec t=${t.toFixed(6)}s ipcWait=${pendingIpc ? "yes" : "no"}`,
                    );
                  }
                  const r = await webCodecsSession.presentAtMediaTimeSec(t);
                  if (tracePipe) {
                    onLog(
                      `[動画][WebCodecs][trace] pipeline f=${i + 1} AFTER presentAtMediaTimeSec advanceMs=${r.advanceMs.toFixed(1)}`,
                    );
                  }
                  return { seekWaitMs: r.advanceMs };
                })()
              : seekToFrame(video!, t, {
                  onTrace: onLog,
                  frameIndex: i + 1,
                  timeoutMs: SEEK_TIMEOUT_MS,
                });

            try {
              const [seekResult] = await Promise.all([
                syncMediaPromise,
                pendingIpc
                  ? pendingIpc.then(() => {
                      pendingIpc = null;
                      if (pendingIpcError) {
                        const msg = pendingIpcError;
                        pendingIpcError = null;
                        throw new Error(msg);
                      }
                    })
                  : Promise.resolve(),
              ]);
              seekWaitMs = seekResult.seekWaitMs;
              decodeGateMs = 0;
            } catch (e) {
              const msg = e instanceof Error ? e.message : String(e);
              onLog(`[動画][trace] f=${i + 1}/${totalFrames} 失敗: ${msg}`);
              const ipcErr = await drainPendingIpc();
              if (ipcErr) {
                onLog(`[動画] フレーム書込エラー: ${ipcErr}`);
                await abortActiveVideoExport();
                return { ok: false, message: ipcErr };
              }
              if (
                allowWebCodecs &&
                webCodecsSession &&
                shouldRetryWithSeekAfterWebCodecsRuntimeFailure(msg)
              ) {
                retryWithSeek = true;
                retryReason = msg;
                await abortActiveVideoExport();
                break;
              }
              await abortActiveVideoExport();
              return { ok: false, message: msg };
            }
            if (targetSourceIdx !== null) {
              lastDecodedSourceFrameIndex = targetSourceIdx;
            }
          }

          if (retryWithSeek) {
            break;
          }

          arrSeekWait.push(seekWaitMs);
          arrSeekWaitBySegment[profileSegment]!.push(seekWaitMs);
          arrDecode.push(decodeGateMs);

          if (webCodecsSession && !reuseFrame) {
            srcTexture.needsUpdate = true;
          } else if (!webCodecsSession) {
            // VideoTexture: Three.js が colorSpace + UNPACK_FLIP_Y でアップロード
            srcTexture.needsUpdate = true;
          }

          if (
            webCodecsSession &&
            !reuseFrame &&
            renderSession.backendKind === "webgpu"
          ) {
            // WebCodecs + WebGPU は advancing frame ごとに bitmap upload を更新する。
            await renderSession.setSource({
              texture: srcTexture,
              imageWidth: sourceWidthForExport,
              imageHeight: sourceHeightForExport,
            });
          }

          const tR0 = performance.now();
          renderSession.render();
          const renderMs = performance.now() - tR0;
          arrRender.push(renderMs);

          /**
           * @description エクスポート 1 枚目だけ `gl.finish()` してから readback する。
           *   Metal / ANGLE 系で、初回テクスチャ upload とシェーダの結果が FBO に乗る前に
           *   `readPixels` が走ると RGBA がゼロのまま拾われ、h264 の先頭フレームだけが真っ黒になる
           *   （Finder サムネが黒・qlmanage は別フレームを採るため非黒、などの落差）。全フレーム
           *   `finish` は重いので先頭のみ。
           */
          if (i === 0 && gl) {
            gl.finish();
          }

          // --- GPU→CPU pixel transfer (no Y-flip — ffmpeg vflip handles row order) ---
          let readPxMs = 0;

          if (!gl) {
            const tP0 = performance.now();
            const rgba = await renderSession.readbackRgba8();
            readPxMs = performance.now() - tP0;
            arrRead.push(readPxMs);

            const tW0 = performance.now();
            const ipcSegment = profileSegment;
            pendingIpc = invokeVideoExportWriteFrame(rgba).then(
              () => {
                const ipcMs = performance.now() - tW0;
                arrIpc.push(ipcMs);
                arrIpcBySegment[ipcSegment]!.push(ipcMs);
              },
              (e: unknown) => {
                const ipcMs = performance.now() - tW0;
                arrIpc.push(ipcMs);
                arrIpcBySegment[ipcSegment]!.push(ipcMs);
                pendingIpcError = e instanceof Error ? e.message : String(e);
              },
            );
          } else if (usePbo && useFence) {
            // === Path A: PBO double-buffer + fenceSync (best: async overlap) ===
            const tP0 = performance.now();
            gl.bindBuffer(gl.PIXEL_PACK_BUFFER, pbos[pboIdx]!);
            gl.readPixels(0, 0, outW, outH, gl.RGBA, gl.UNSIGNED_BYTE, 0);
            gl.bindBuffer(gl.PIXEL_PACK_BUFFER, null);
            const newFence = gl.fenceSync(
              gl.SYNC_GPU_COMMANDS_COMPLETE,
              0,
            );
            gl.flush();

            if (prevFence) {
              gl.clientWaitSync(
                prevFence,
                gl.SYNC_FLUSH_COMMANDS_BIT,
                5_000_000_000,
              );
              gl.deleteSync(prevFence);
              gl.bindBuffer(gl.PIXEL_PACK_BUFFER, pbos[1 - pboIdx]!);
              gl.getBufferSubData(gl.PIXEL_PACK_BUFFER, 0, cpuBuf);
              gl.bindBuffer(gl.PIXEL_PACK_BUFFER, null);

              readPxMs = performance.now() - tP0;
              arrRead.push(readPxMs);

              const tW0 = performance.now();
              const ipcSegment = profileSegment;
              pendingIpc = invokeVideoExportWriteFrame(cpuBuf).then(
                () => {
                  const ipcMs = performance.now() - tW0;
                  arrIpc.push(ipcMs);
                  arrIpcBySegment[ipcSegment]!.push(ipcMs);
                },
                (e: unknown) => {
                  const ipcMs = performance.now() - tW0;
                  arrIpc.push(ipcMs);
                  arrIpcBySegment[ipcSegment]!.push(ipcMs);
                  pendingIpcError = e instanceof Error ? e.message : String(e);
                },
              );
            }

            prevFence = newFence;
            pboIdx = 1 - pboIdx;
          } else if (usePbo) {
            // === Path B: single PBO + gl.finish() (pinned-memory memcpy) ===
            const tP0 = performance.now();
            gl.bindBuffer(gl.PIXEL_PACK_BUFFER, pbos[0]!);
            gl.readPixels(0, 0, outW, outH, gl.RGBA, gl.UNSIGNED_BYTE, 0);
            gl.finish();
            gl.getBufferSubData(gl.PIXEL_PACK_BUFFER, 0, cpuBuf);
            gl.bindBuffer(gl.PIXEL_PACK_BUFFER, null);
            readPxMs = performance.now() - tP0;
            arrRead.push(readPxMs);

            const tW0 = performance.now();
            const ipcSegment = profileSegment;
            pendingIpc = invokeVideoExportWriteFrame(cpuBuf).then(
              () => {
                const ipcMs = performance.now() - tW0;
                arrIpc.push(ipcMs);
                arrIpcBySegment[ipcSegment]!.push(ipcMs);
              },
              (e: unknown) => {
                const ipcMs = performance.now() - tW0;
                arrIpc.push(ipcMs);
                arrIpcBySegment[ipcSegment]!.push(ipcMs);
                pendingIpcError = e instanceof Error ? e.message : String(e);
              },
            );
          } else {
            // === Path C: sync readPixels fallback ===
            const tP0 = performance.now();
            gl.readPixels(0, 0, outW, outH, gl.RGBA, gl.UNSIGNED_BYTE, cpuBuf);
            readPxMs = performance.now() - tP0;
            arrRead.push(readPxMs);

            const tW0 = performance.now();
            const ipcSegment = profileSegment;
            pendingIpc = invokeVideoExportWriteFrame(cpuBuf).then(
              () => {
                const ipcMs = performance.now() - tW0;
                arrIpc.push(ipcMs);
                arrIpcBySegment[ipcSegment]!.push(ipcMs);
              },
              (e: unknown) => {
                const ipcMs = performance.now() - tW0;
                arrIpc.push(ipcMs);
                arrIpcBySegment[ipcSegment]!.push(ipcMs);
                pendingIpcError = e instanceof Error ? e.message : String(e);
              },
            );
          }

          const totalMs = performance.now() - tFrame0;
          arrTotal.push(totalMs);
          arrTotalBySegment[profileSegment]!.push(totalMs);
          if (VIDEO_EXPORT_VERBOSE_TRACE) {
            const summary =
              `[動画][trace] f=${i + 1}/${totalFrames} t=${t.toFixed(4)}s ` +
              `reuse=${reuseFrame ? "Y" : "N"} mediaSync=${seekWaitMs.toFixed(0)}ms decode=${decodeGateMs.toFixed(0)}ms ` +
              `render=${renderMs.toFixed(0)}ms readPx=${readPxMs.toFixed(0)}ms ` +
              `ipc=async total=${totalMs.toFixed(0)}ms`;
            onLog(summary);
          }

          if (
            i === 0 ||
            i === totalFrames - 1 ||
            (i + 1) % VIDEO_EXPORT_PROGRESS_CALLBACK_INTERVAL_FRAMES === 0
          ) {
            onProgress?.({ currentFrame: i + 1, totalFrames, phase: "frames" });
          }
        }

        if (retryWithSeek) {
          onLog(
            `[動画][WebCodecs] 実行中に失敗したため、従来のシーク経路で最初から再試行します — ${retryReason}`,
          );
          continue;
        }

        // PBO double-buffer: flush the last buffered frame (1-frame pipeline delay)
        if (gl && usePbo && useFence && prevFence) {
          const prevIpcErr = await drainPendingIpc();
          if (prevIpcErr) {
            onLog(`[動画] フレーム書込エラー: ${prevIpcErr}`);
            await abortActiveVideoExport();
            return { ok: false, message: prevIpcErr };
          }
          const tR0 = performance.now();
          gl.clientWaitSync(
            prevFence,
            gl.SYNC_FLUSH_COMMANDS_BIT,
            5_000_000_000,
          );
          gl.deleteSync(prevFence);
          prevFence = null;
          gl.bindBuffer(gl.PIXEL_PACK_BUFFER, pbos[1 - pboIdx]!);
          gl.getBufferSubData(gl.PIXEL_PACK_BUFFER, 0, cpuBuf);
          gl.bindBuffer(gl.PIXEL_PACK_BUFFER, null);
          arrRead.push(performance.now() - tR0);

          const tW0 = performance.now();
          pendingIpc = invokeVideoExportWriteFrame(cpuBuf).then(
            () => {
              arrIpc.push(performance.now() - tW0);
            },
            (e: unknown) => {
              arrIpc.push(performance.now() - tW0);
              pendingIpcError = e instanceof Error ? e.message : String(e);
            },
          );
        }

        const finalIpcError = await drainPendingIpc();
        if (finalIpcError) {
          onLog(`[動画] フレーム書込エラー: ${finalIpcError}`);
          await abortActiveVideoExport();
          return { ok: false, message: finalIpcError };
        }

        webCodecsSession?.flushExportDebugBuckets("export-end-tail");

        const wallMs = performance.now() - wallStart;
        const wallSec = (wallMs / 1000).toFixed(1);
        onLog(`[動画] ${totalFrames} フレーム / ${wallSec}s`);
        if (VIDEO_EXPORT_VERBOSE_TRACE || VIDEO_EXPORT_DEBUG_PROFILE) {
          const profileDebugDetail = VIDEO_EXPORT_DEBUG_PROFILE
            ? `\n  mediaSync segMean ${formatProfileSegmentMeans(arrSeekWaitBySegment)}\n` +
              `  ipcWrite segMean ${formatProfileSegmentMeans(arrIpcBySegment)}\n` +
              `  frameTotal segMean ${formatProfileSegmentMeans(arrTotalBySegment)}`
            : "";
          onLog(
            `[動画][profile] wall=${wallMs.toFixed(0)}ms frames=${totalFrames} ` +
              `seekedFrames=${countSeekedPaths} reusedFrames=${countReusedFrames} forwardScans=${countForwardScans} rvfcFrames=${countRvfcFrames} rafFallbackFrames=${countRafFallbackFrames}\n` +
              `  mediaSync ms mean=${meanMs(arrSeekWait).toFixed(1)} median=${medianMs(arrSeekWait).toFixed(1)} p95=${p95Ms(arrSeekWait).toFixed(1)}\n` +
              `  decodeGate ms mean=${meanMs(arrDecode).toFixed(1)} median=${medianMs(arrDecode).toFixed(1)} p95=${p95Ms(arrDecode).toFixed(1)}\n` +
              `  render ms mean=${meanMs(arrRender).toFixed(1)} median=${medianMs(arrRender).toFixed(1)} p95=${p95Ms(arrRender).toFixed(1)}\n` +
              `  readPixels ms mean=${meanMs(arrRead).toFixed(1)} median=${medianMs(arrRead).toFixed(1)} p95=${p95Ms(arrRead).toFixed(1)} (${gl ? (usePbo ? (useFence ? "PBO+fence" : "PBO+finish") : "sync") : "webgpu-readback"})\n` +
              `  ipcWrite ms mean=${meanMs(arrIpc).toFixed(1)} median=${medianMs(arrIpc).toFixed(1)} p95=${p95Ms(arrIpc).toFixed(1)}\n` +
              `  frameTotal ms mean=${meanMs(arrTotal).toFixed(1)} median=${medianMs(arrTotal).toFixed(1)} p95=${p95Ms(arrTotal).toFixed(1)}` +
              profileDebugDetail,
          );
        }

        if (!exportSessionId) {
          throw new Error("video-export-finish: セッションが初期化されていません");
        }
        const fin = await api.videoExportFinish(exportSessionId);
        exportSessionId = null;
        if (fin.code !== 0) {
          onLog(`[動画] ffmpeg 終了コード ${fin.code}`);
          if (fin.stderrTail) onLog(fin.stderrTail);
          return {
            ok: false,
            message: `ffmpeg 失敗 code=${fin.code}`,
          };
        }
        onLog(`[動画] 完了 → ${resolvedOutPath}`);
        return { ok: true };
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        onLog(`[動画] FATAL: ${msg}`);
        await abortActiveVideoExport();
        return { ok: false, message: msg };
      } finally {
        webCodecsSession?.dispose();
        srcTexture?.dispose();
        renderSession?.dispose();
        disposeVideoElement(video);
      }
    }

    return {
      ok: false,
      message: "WebCodecs の実行時フォールバック後も書き出しを完了できませんでした",
    };
  } finally {
    if (stagedPath) {
      await api.videoExportUnlinkStaged(stagedPath).catch(() => {});
    }
    if (mezzaninePath && mezzanineOwnedByExport) {
      await api.videoExportUnlinkStaged(mezzaninePath).catch(() => {});
    }
  }
}
