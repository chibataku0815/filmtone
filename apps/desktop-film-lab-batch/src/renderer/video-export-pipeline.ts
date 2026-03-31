/**
 * Film Lab デスクトップ — 動画グレード書き出し（WebGL Viewport + ffmpeg）
 *
 * @overview 1 本のソース動画を時刻単調にデコードし、画像バッチと同じ Viewport でグレードして raw RGBA を ffmpeg に流す。
 *   MP4/H.264 かつ条件一致時は WebCodecs + CanvasTexture を優先し、それ以外は HTMLVideoElement の seek。
 * @limitations 単一 GL 直列。ffprobe/ffmpeg は PATH 必須（Homebrew 等）。macOS では VideoToolbox を優先。
 */
import * as THREE from "three";
import {
  isWebGL2Supported,
  Viewport,
  filmlabVertexShader,
  filmlabFragmentShader,
} from "film-lab-renderer";
import type { FilmLabBatchBridge } from "./desktop-api";
import { halationHueToHex } from "@film-lab/preset-data";
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
  currentFrame: number;
  totalFrames: number;
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
 * @description Y 反転（WebGL readPixels は左下原点、動画は左上原点想定）。`dst` に上書きし割当を避ける。
 */
function flipRgbaVerticalInto(
  src: Uint8Array,
  width: number,
  height: number,
  dst: Uint8Array,
): void {
  const rowBytes = width * 4;
  for (let y = 0; y < height; y++) {
    const srcRow = (height - 1 - y) * rowBytes;
    const dstRow = y * rowBytes;
    dst.set(src.subarray(srcRow, srcRow + rowBytes), dstRow);
  }
}

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
  signal?: AbortSignal;
  onProgress?: (p: VideoExportProgress) => void;
  onLog: (line: string) => void;
  userMessages?: VideoExportPipelineUserMessages;
}): Promise<{ ok: true } | { ok: false; message: string }> {
  const {
    api,
    inputVideoPath,
    outputDir,
    outputFileName,
    grade,
    signal,
    onProgress,
    onLog,
    userMessages,
  } = options;

  const u =
    userMessages ??
    ({
      webglUnavailable: "WebGL2 が利用できません",
      metadataFailed: (detail: string) => `メタデータ取得失敗: ${detail}`,
      ffmpegStartFailed: (detail: string) => `ffmpeg 開始失敗: ${detail}`,
      userAborted: "中断されました",
      ffmpegFailed: (code: number) => `ffmpeg 失敗 code=${code}`,
    } satisfies VideoExportPipelineUserMessages);

  if (!isWebGL2Supported()) {
    return { ok: false, message: u.webglUnavailable };
  }

  let probe: Awaited<ReturnType<FilmLabBatchBridge["videoExportProbe"]>>;
  try {
    probe = await api.videoExportProbe(inputVideoPath);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, message: u.metadataFailed(msg) };
  }

  try {
    assertVideoImportWithinCaps(
      probe.width,
      probe.height,
      probe.durationSec,
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, message: msg };
  }

  const { outW, outH } = computeVideoExportDimensions(probe.width, probe.height);
  const totalFrames = computeExportFrameCount(probe.durationSec);
  const safeOutName =
    outputFileName.replace(/[/\\]/g, "_").replace(/[<>:"|?*\u0000-\u001f]/g, "_") ||
    "film-lab-export.mp4";

  onLog(
    `[動画] ${basename(inputVideoPath)} → ${outW}×${outH} @ ${VIDEO_EXPORT_FPS}fps, ${totalFrames} フレーム`,
  );
  onLog(
    `[動画] ソース ${probe.width}×${probe.height}, ${probe.durationSec.toFixed(2)}s, 音声: ${probe.hasAudio ? "あり" : "なし"}, codec: ${probe.videoCodec || "unknown"}` +
      (probe.sourceFrameRateTrusted === true && probe.sourceFrameRate !== null
        ? `, ソースFPS信頼 ~${probe.sourceFrameRate.toFixed(4)}（同一ソースフレームはシーク省略）`
        : `, ソースFPS不信任（ソースフレーム索引の再利用なし）`),
  );

  let stagedPath: string | null = null;
  const tryWebCodecs = shouldAttemptWebCodecsAccurateExport({
    videoCodec: probe.videoCodec,
    fileSizeBytes: probe.fileSizeBytes,
    absPath: inputVideoPath,
  });
  const epsilon = 1 / VIDEO_EXPORT_FPS / 1000;
  const maxT = Math.max(0, probe.durationSec - epsilon);
  const sourceFpsTrusted = probe.sourceFrameRateTrusted === true;
  const sourceFpsValue = probe.sourceFrameRate;
  const readBuf = new Uint8Array(outW * outH * 4);
  const flipBuf = new Uint8Array(outW * outH * 4);
  const maxAttempts = tryWebCodecs ? 2 : 1;

  try {
    for (let attemptIndex = 0; attemptIndex < maxAttempts; attemptIndex++) {
      const allowWebCodecs = tryWebCodecs && attemptIndex === 0;
      let video: HTMLVideoElement | null = null;
      let pathForFfmpeg = stagedPath ?? inputVideoPath;
      let webCodecsSession: WebCodecsMp4ExportSession | null = null;
      let srcTexture: THREE.Texture | null = null;
      let viewport: Viewport | null = null;
      let renderer: THREE.WebGLRenderer | null = null;
      let retryWithSeek = false;
      let retryReason = "";

      try {
        // WebCodecs (VideoDecoder → Canvas 2D → CanvasTexture) 経路は
        // CanvasTexture の色空間処理に起因する色ズレ（大幅な暗化）が確認されたため無効化。
        // HTMLVideoElement シーク経路はプレビューと同じテクスチャパスを通るため色が一致する。
        // WebCodecs の色空間問題が解決するまでは HTMLVideoElement のみ使用する。
        // See: life#38
        if (false && allowWebCodecs) {
          // (WebCodecs path disabled — kept for future reference)
          webCodecsSession = null;
        } else if (attemptIndex > 0) {
          onLog(
            "[動画][WebCodecs] runtime fallback: HTMLVideoElement シーク経路で最初から再試行します",
          );
        }

        if (!webCodecsSession) {
          try {
            const opened = await openVideoForExport(
              api,
              stagedPath ?? inputVideoPath,
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
          ? webCodecsSession.texture
          : (() => {
              const vt = new THREE.VideoTexture(video!);
              vt.colorSpace = THREE.SRGBColorSpace;
              vt.minFilter = THREE.LinearFilter;
              vt.magFilter = THREE.LinearFilter;
              return vt;
            })();

        const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
        camera.position.z = 1;
        const scene = new THREE.Scene();
        scene.background = new THREE.Color(0x0a0a0a);

        renderer = new THREE.WebGLRenderer({
          antialias: false,
          alpha: false,
          preserveDrawingBuffer: true,
        });
        renderer.setPixelRatio(1);
        renderer.setSize(outW, outH, false);
        renderer.outputColorSpace = THREE.SRGBColorSpace;

        viewport = new Viewport({
          vertexShader: filmlabVertexShader,
          fragmentShader: filmlabFragmentShader,
          width: outW,
          height: outH,
        });
        scene.add(viewport.mesh);

        viewport.setResolution(outW, outH);
        viewport.setTexture(srcTexture);
        viewport.setImageResolution(probe.width, probe.height);
        viewport.setParams({
          ...grade.params,
          halationColor: halationHueToHex(grade.params.halationHue),
        });
        if (grade.lutData && grade.lutSize > 0) {
          viewport.setLUT(grade.lutData, grade.lutSize);
          viewport.setLUTIntensity(grade.lutIntensity);
        } else {
          viewport.clearLUT();
        }

        const gl = renderer.getContext() as WebGL2RenderingContext;

        let resolvedOutPath: string;
        try {
          await api.videoExportAbort().catch(() => {});
          const startRes = await api.videoExportStart({
            inputVideoPath: pathForFfmpeg,
            outputDir,
            outputFileName: safeOutName,
            width: outW,
            height: outH,
            fps: VIDEO_EXPORT_FPS,
            hasAudio: probe.hasAudio,
          });
          resolvedOutPath = startRes.outputVideoPath;
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          return { ok: false, message: `ffmpeg 開始失敗: ${msg}` };
        }

        const wallStart = performance.now();
        const arrSeekWait: number[] = [];
        const arrDecode: number[] = [];
        const arrRender: number[] = [];
        const arrRead: number[] = [];
        const arrFlip: number[] = [];
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

        // Double-buffer for flip output so we can overlap IPC with next seek
        const flipBufA = flipBuf;
        const flipBufB = new Uint8Array(outW * outH * 4);
        let useFlipA = true;
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
            await api.videoExportAbort();
            return { ok: false, message: u.userAborted };
          }

          const t = Math.min(i / VIDEO_EXPORT_FPS, maxT);
          const tFrame0 = performance.now();
          const profileSegment = profileSegmentIndex(i, totalFrames);

          viewport.setTime(t);

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
              await api.videoExportAbort();
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
                await api.videoExportAbort().catch(() => {});
                return { ok: false, message: ipcErr };
              }
              if (
                allowWebCodecs &&
                webCodecsSession &&
                shouldRetryWithSeekAfterWebCodecsRuntimeFailure(msg)
              ) {
                retryWithSeek = true;
                retryReason = msg;
                await api.videoExportAbort().catch(() => {});
                break;
              }
              await api.videoExportAbort().catch(() => {});
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

          if (webCodecsSession) {
            if (!reuseFrame) {
              srcTexture.needsUpdate = true;
            }
          } else {
            // VideoTexture: Three.js が colorSpace + UNPACK_FLIP_Y でアップロード
            srcTexture.needsUpdate = true;
          }

          const tR0 = performance.now();
          viewport.render(renderer, scene, camera);
          const renderMs = performance.now() - tR0;
          arrRender.push(renderMs);

          const tP0 = performance.now();
          gl.readPixels(0, 0, outW, outH, gl.RGBA, gl.UNSIGNED_BYTE, readBuf);
          const readPxMs = performance.now() - tP0;
          arrRead.push(readPxMs);

          const currentFlipBuf = useFlipA ? flipBufA : flipBufB;
          useFlipA = !useFlipA;

          const tF0 = performance.now();
          flipRgbaVerticalInto(readBuf, outW, outH, currentFlipBuf);
          const flipMs = performance.now() - tF0;
          arrFlip.push(flipMs);

          // Fire IPC write and DON'T await — it runs in parallel with next frame's seek.
          // The pipelined main-side handler returns quickly (no drain wait).
          const tW0 = performance.now();
          const ipcSegment = profileSegment;
          pendingIpc = api.videoExportWriteFrame(currentFlipBuf).then(
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

          const totalMs = performance.now() - tFrame0;
          arrTotal.push(totalMs);
          arrTotalBySegment[profileSegment]!.push(totalMs);
          if (VIDEO_EXPORT_VERBOSE_TRACE) {
            const summary =
              `[動画][trace] f=${i + 1}/${totalFrames} t=${t.toFixed(4)}s ` +
              `reuse=${reuseFrame ? "Y" : "N"} mediaSync=${seekWaitMs.toFixed(0)}ms decode=${decodeGateMs.toFixed(0)}ms ` +
              `render=${renderMs.toFixed(0)}ms readPx=${readPxMs.toFixed(0)}ms ` +
              `flip=${flipMs.toFixed(0)}ms ipc=async total=${totalMs.toFixed(0)}ms`;
            onLog(summary);
          }

          if (
            i === 0 ||
            i === totalFrames - 1 ||
            (i + 1) % VIDEO_EXPORT_PROGRESS_CALLBACK_INTERVAL_FRAMES === 0
          ) {
            onProgress?.({ currentFrame: i + 1, totalFrames });
          }
        }

        if (retryWithSeek) {
          onLog(
            `[動画][WebCodecs] 実行中に失敗したため、従来のシーク経路で最初から再試行します — ${retryReason}`,
          );
          continue;
        }

        const finalIpcError = await drainPendingIpc();
        if (finalIpcError) {
          onLog(`[動画] フレーム書込エラー: ${finalIpcError}`);
          await api.videoExportAbort();
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
              `  readPixels ms mean=${meanMs(arrRead).toFixed(1)} median=${medianMs(arrRead).toFixed(1)} p95=${p95Ms(arrRead).toFixed(1)}\n` +
              `  flip ms mean=${meanMs(arrFlip).toFixed(1)} median=${medianMs(arrFlip).toFixed(1)} p95=${p95Ms(arrFlip).toFixed(1)}\n` +
              `  ipcWrite ms mean=${meanMs(arrIpc).toFixed(1)} median=${medianMs(arrIpc).toFixed(1)} p95=${p95Ms(arrIpc).toFixed(1)}\n` +
              `  frameTotal ms mean=${meanMs(arrTotal).toFixed(1)} median=${medianMs(arrTotal).toFixed(1)} p95=${p95Ms(arrTotal).toFixed(1)}` +
              profileDebugDetail,
          );
        }

        const fin = await api.videoExportFinish();
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
        await api.videoExportAbort().catch(() => {});
        return { ok: false, message: msg };
      } finally {
        webCodecsSession?.dispose();
        srcTexture?.dispose();
        viewport?.dispose();
        renderer?.dispose();
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
  }
}
