/**
 * Film Lab デスクトップ — 動画グレード書き出し（WebGL Viewport + ffmpeg）
 *
 * @overview 1 本のソース動画を時刻単調にデコードし（主に前方向 rVFC・シークはフォールバック）、画像バッチと同じ Viewport でグレードして raw RGBA を ffmpeg に流す。
 * @limitations 単一 GL 直列。ffprobe/ffmpeg は PATH 必須（Homebrew 等）。macOS では VideoToolbox を優先。
 */
import * as THREE from "three";
import { isWebGL2Supported } from "@/shared/gl";
import type { FilmLabBatchBridge } from "./desktop-api";
import { Viewport } from "@film-lab/core/Viewport";
import { filmlabVertexShader } from "@film-lab/shader/filmlab.vert";
import { filmlabFragmentShader } from "@film-lab/shader/filmlab.frag";
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

/** @description development のとき各フレーム 1 行トレース。production では遅いフレームと間引きのみ。 */
const VIDEO_EXPORT_LOG_EVERY_FRAME = import.meta.env.DEV === true;

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
      onLog(
        `[動画] 検証: video.src スキーム=${scheme}（http dev では film-lab-video: であるべき。file: のときは main 未ビルド）`,
      );
    } catch {
      onLog("[動画] 検証: video.src を URL として解析できませんでした");
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
  let video: HTMLVideoElement;
  let pathForFfmpeg: string;
  try {
    const opened = await openVideoForExport(api, inputVideoPath, onLog);
    video = opened.video;
    pathForFfmpeg = opened.pathForFfmpeg;
    stagedPath = opened.stagedPath;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, message: msg };
  }

  video.pause();

  const videoTexture = new THREE.VideoTexture(video);
  videoTexture.colorSpace = THREE.SRGBColorSpace;
  videoTexture.minFilter = THREE.LinearFilter;
  videoTexture.magFilter = THREE.LinearFilter;

  const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
  camera.position.z = 1;
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0a0a0a);

  const renderer = new THREE.WebGLRenderer({
    antialias: false,
    alpha: false,
    preserveDrawingBuffer: true,
  });
  renderer.setPixelRatio(1);
  renderer.setSize(outW, outH, false);
  renderer.outputColorSpace = THREE.SRGBColorSpace;

  const viewport = new Viewport({
    vertexShader: filmlabVertexShader,
    fragmentShader: filmlabFragmentShader,
    width: outW,
    height: outH,
  });
  scene.add(viewport.mesh);

  viewport.setResolution(outW, outH);
  viewport.setTexture(videoTexture);
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
  const readBuf = new Uint8Array(outW * outH * 4);
  const flipBuf = new Uint8Array(outW * outH * 4);
  const epsilon = 1 / VIDEO_EXPORT_FPS / 1000;
  const maxT = Math.max(0, probe.durationSec - epsilon);
  const sourceFpsTrusted = probe.sourceFrameRateTrusted === true;
  const sourceFpsValue = probe.sourceFrameRate;

  try {
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
    let countSeekedPaths = 0;
    let countReusedFrames = 0;
    let countRvfcFrames = 0;
    let countRafFallbackFrames = 0;
    let countForwardScans = 0;
    let lastDecodedSourceFrameIndex: number | null = null;

    for (let i = 0; i < totalFrames; i++) {
      if (signal?.aborted) {
        onLog("[動画] ユーザー中断");
        await api.videoExportAbort();
        return { ok: false, message: "中断されました" };
      }

      const t = Math.min(i / VIDEO_EXPORT_FPS, maxT);
      const tFrame0 = performance.now();

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
        seekWaitMs = 0;
        decodeGateMs = 0;
      } else {
        countSeekedPaths++;
        try {
          const seekDetail = await advanceVideoToTimeForward(video, t, {
            onTrace: onLog,
            frameIndex: i + 1,
            timeoutMs: SEEK_TIMEOUT_MS,
          });
          seekWaitMs = seekDetail.seekWaitMs;
          decodeGateMs = seekDetail.decodeGateMs;
          if (seekDetail.usedForwardScan === true) countForwardScans++;
          if (seekDetail.usedRvfc) countRvfcFrames++;
          if (seekDetail.usedRafFallback) countRafFallbackFrames++;
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          onLog(`[動画][trace] f=${i + 1}/${totalFrames} seek 失敗: ${msg}`);
          await api.videoExportAbort().catch(() => {});
          return { ok: false, message: msg };
        }
        if (targetSourceIdx !== null) {
          lastDecodedSourceFrameIndex = targetSourceIdx;
        }
      }

      arrSeekWait.push(seekWaitMs);
      arrDecode.push(decodeGateMs);

      videoTexture.needsUpdate = true;

      const tR0 = performance.now();
      viewport.render(renderer, scene, camera);
      const renderMs = performance.now() - tR0;
      arrRender.push(renderMs);

      const tP0 = performance.now();
      gl.readPixels(0, 0, outW, outH, gl.RGBA, gl.UNSIGNED_BYTE, readBuf);
      const readPxMs = performance.now() - tP0;
      arrRead.push(readPxMs);

      const tF0 = performance.now();
      flipRgbaVerticalInto(readBuf, outW, outH, flipBuf);
      const flipMs = performance.now() - tF0;
      arrFlip.push(flipMs);

      let ipcMs = 0;
      try {
        const tW0 = performance.now();
        await api.videoExportWriteFrame(flipBuf);
        ipcMs = performance.now() - tW0;
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        onLog(`[動画] フレーム書込エラー f=${i + 1}: ${msg}`);
        await api.videoExportAbort();
        return { ok: false, message: msg };
      }
      arrIpc.push(ipcMs);

      const totalMs = performance.now() - tFrame0;
      arrTotal.push(totalMs);
      const summary =
        `[動画][trace] f=${i + 1}/${totalFrames} t=${t.toFixed(4)}s ` +
        `reuse=${reuseFrame ? "Y" : "N"} seekWait=${seekWaitMs.toFixed(0)}ms decode=${decodeGateMs.toFixed(0)}ms ` +
        `render=${renderMs.toFixed(0)}ms readPx=${readPxMs.toFixed(0)}ms ` +
        `flip=${flipMs.toFixed(0)}ms ipc=${ipcMs.toFixed(0)}ms total=${totalMs.toFixed(0)}ms ` +
        `| ${videoDebugSnapshot(video)}`;

      if (VIDEO_EXPORT_LOG_EVERY_FRAME) {
        onLog(summary);
      } else if (
        totalMs > 1500 ||
        i % VIDEO_EXPORT_FPS === 0 ||
        i === 0 ||
        i === totalFrames - 1
      ) {
        onLog(summary);
      }

      onProgress?.({ currentFrame: i + 1, totalFrames });
    }

    const wallMs = performance.now() - wallStart;
    const mean = (a: number[]) =>
      a.length === 0 ? 0 : a.reduce((x, y) => x + y, 0) / a.length;
    onLog(
      `[動画][profile] wall=${wallMs.toFixed(0)}ms frames=${totalFrames} ` +
        `seekedFrames=${countSeekedPaths} reusedFrames=${countReusedFrames} forwardScans=${countForwardScans} rvfcFrames=${countRvfcFrames} rafFallbackFrames=${countRafFallbackFrames}\n` +
        `  seekWait ms mean=${mean(arrSeekWait).toFixed(1)} median=${medianMs(arrSeekWait).toFixed(1)} p95=${p95Ms(arrSeekWait).toFixed(1)}\n` +
        `  decodeGate ms mean=${mean(arrDecode).toFixed(1)} median=${medianMs(arrDecode).toFixed(1)} p95=${p95Ms(arrDecode).toFixed(1)}\n` +
        `  render ms mean=${mean(arrRender).toFixed(1)} median=${medianMs(arrRender).toFixed(1)} p95=${p95Ms(arrRender).toFixed(1)}\n` +
        `  readPixels ms mean=${mean(arrRead).toFixed(1)} median=${medianMs(arrRead).toFixed(1)} p95=${p95Ms(arrRead).toFixed(1)}\n` +
        `  flip ms mean=${mean(arrFlip).toFixed(1)} median=${medianMs(arrFlip).toFixed(1)} p95=${p95Ms(arrFlip).toFixed(1)}\n` +
        `  ipcWrite ms mean=${mean(arrIpc).toFixed(1)} median=${medianMs(arrIpc).toFixed(1)} p95=${p95Ms(arrIpc).toFixed(1)}\n` +
        `  frameTotal ms mean=${mean(arrTotal).toFixed(1)} median=${medianMs(arrTotal).toFixed(1)} p95=${p95Ms(arrTotal).toFixed(1)}`,
    );

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
    videoTexture.dispose();
    viewport.dispose();
    renderer.dispose();
    if (stagedPath) {
      await api.videoExportUnlinkStaged(stagedPath).catch(() => {});
    }
  }
}
