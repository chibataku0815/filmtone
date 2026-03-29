/**
 * Film Lab デスクトップ — 動画グレード書き出し（WebGL Viewport + ffmpeg）
 *
 * @overview 1 本のソース動画をフレーム刻みでシークし、画像バッチと同じ Viewport でグレードして raw RGBA を ffmpeg に流す。
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

/** @description development のとき各フレーム 1 行トレース。production では遅いフレームと間引きのみ。 */
const VIDEO_EXPORT_LOG_EVERY_FRAME = import.meta.env.DEV === true;

/** @description seek がこの時間（ms）無応答なら打ち切り（どこで固まったかログに出す） */
const SEEK_TIMEOUT_MS = 90_000;

export type VideoExportProgress = {
  currentFrame: number;
  totalFrames: number;
};

/**
 * @description Y 反転（WebGL readPixels は左下原点、動画は左上原点想定）
 */
function flipRgbaVertical(
  src: Uint8Array,
  width: number,
  height: number,
): Uint8Array {
  const rowBytes = width * 4;
  const out = new Uint8Array(src.length);
  for (let y = 0; y < height; y++) {
    const srcRow = (height - 1 - y) * rowBytes;
    const dstRow = y * rowBytes;
    out.set(src.subarray(srcRow, srcRow + rowBytes), dstRow);
  }
  return out;
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
 * @description 指定時刻へシークし、可能なら requestVideoFrameCallback でデコード完了を待つ
 * @param ctx.onTrace レンダラのログへ出す詳細（seeked / rVFC のどちらで進んだか）
 * @param ctx.frameIndex 人間向けフレーム番号（1 始まり）
 */
function seekVideoToTime(
  video: HTMLVideoElement,
  timeSec: number,
  ctx: {
    onTrace: (line: string) => void;
    frameIndex: number;
    timeoutMs: number;
  },
): Promise<void> {
  const { onTrace, frameIndex, timeoutMs } = ctx;
  return new Promise((resolve, reject) => {
    const t = Math.max(0, timeSec);
    let settled = false;

    const cleanup = () => {
      window.clearTimeout(timeoutId);
      video.removeEventListener("seeked", onSeeked);
      video.removeEventListener("error", onVideoError);
    };

    const succeed = () => {
      if (settled) return;
      settled = true;
      cleanup();
      resolve();
    };

    const fail = (err: Error) => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(err);
    };

    const timeoutId = window.setTimeout(() => {
      fail(
        new Error(
          `seekVideoToTime タイムアウト (${timeoutMs}ms) f=${frameIndex} targetT=${t.toFixed(6)} ${videoDebugSnapshot(video)}`,
        ),
      );
    }, timeoutMs);

    /**
     * @description seeked 後にデコードを進める。pause 中の要素では requestVideoFrameCallback が永遠に来ないことがあるため、muted + play → 2 回 rAF → pause の経路を正とする。
     */
    const runDecodeGate = (phase: string) => {
      const t0 = performance.now();
      void (async () => {
        try {
          onTrace(
            `[動画][seek] f=${frameIndex} ${phase} → play/2×rAF/pause（rVFC は使わない）`,
          );
          await video.play();
          await new Promise<void>((r) =>
            requestAnimationFrame(() => requestAnimationFrame(() => r())),
          );
          video.pause();
        } catch (e) {
          const m = e instanceof Error ? e.message : String(e);
          onTrace(
            `[動画][seek] f=${frameIndex} ${phase} → play 失敗、2×rAF のみで続行 — ${m}`,
          );
          await new Promise<void>((r) =>
            requestAnimationFrame(() => requestAnimationFrame(() => r())),
          );
        }
        onTrace(
          `[動画][seek] f=${frameIndex} ${phase} → ゲート完了 +${(performance.now() - t0).toFixed(1)}ms (${videoDebugSnapshot(video)})`,
        );
        succeed();
      })().catch((e) => {
        const m = e instanceof Error ? e.message : String(e);
        fail(new Error(`runDecodeGate 内例外 f=${frameIndex}: ${m}`));
      });
    };

    const onVideoError = () => {
      fail(
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
      runDecodeGate("seeked後");
    };

    if (Math.abs(video.currentTime - t) < 1e-4) {
      onTrace(
        `[動画][seek] f=${frameIndex} シーク省略（既に t≈${t.toFixed(6)}）${videoDebugSnapshot(video)}`,
      );
      runDecodeGate("同一時刻");
      return;
    }

    onTrace(
      `[動画][seek] f=${frameIndex} currentTime 代入 ${video.currentTime.toFixed(6)} → ${t.toFixed(6)}`,
    );
    video.addEventListener("seeked", onSeeked, { once: true });
    video.addEventListener("error", onVideoError, { once: true });
    try {
      video.currentTime = t;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      fail(new Error(`seekVideoToTime currentTime 代入失敗 f=${frameIndex} — ${msg}`));
    }
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
 * @description 1 本の動画をグレードして mp4 へ書き出す
 * @param options.api — preload ブリッジ（ffmpeg IPC を含む）
 * @param options.inputVideoPath — ソースの絶対パス
 * @param options.outputDir — 出力ディレクトリ
 * @param options.outputFileName — ファイル名のみ（例: clip-graded.mp4）
 * @param options.grade — バッチと同じ BatchGradeState
 * @param options.signal — 中断用 AbortSignal
 * @param options.onProgress — フレーム進捗
 * @param options.onLog — ログ 1 行
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
  } = options;

  if (!isWebGL2Supported()) {
    return { ok: false, message: "WebGL2 が利用できません" };
  }

  let probe: Awaited<ReturnType<FilmLabBatchBridge["videoExportProbe"]>>;
  try {
    probe = await api.videoExportProbe(inputVideoPath);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, message: `メタデータ取得失敗: ${msg}` };
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
    `[動画] ソース ${probe.width}×${probe.height}, ${probe.durationSec.toFixed(2)}s, 音声: ${probe.hasAudio ? "あり" : "なし"}, codec: ${probe.videoCodec || "unknown"}`,
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
  const epsilon = 1 / VIDEO_EXPORT_FPS / 1000;
  const maxT = Math.max(0, probe.durationSec - epsilon);

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

    for (let i = 0; i < totalFrames; i++) {
      if (signal?.aborted) {
        onLog("[動画] ユーザー中断");
        await api.videoExportAbort();
        return { ok: false, message: "中断されました" };
      }

      const t = Math.min(i / VIDEO_EXPORT_FPS, maxT);
      const tFrame0 = performance.now();

      viewport.setTime(t);

      const tSeek0 = performance.now();
      try {
        await seekVideoToTime(video, t, {
          onTrace: onLog,
          frameIndex: i + 1,
          timeoutMs: SEEK_TIMEOUT_MS,
        });
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        onLog(`[動画][trace] f=${i + 1}/${totalFrames} seek 失敗: ${msg}`);
        await api.videoExportAbort().catch(() => {});
        return { ok: false, message: msg };
      }
      const seekMs = performance.now() - tSeek0;

      videoTexture.needsUpdate = true;

      const tR0 = performance.now();
      viewport.render(renderer, scene, camera);
      const renderMs = performance.now() - tR0;

      const tP0 = performance.now();
      gl.readPixels(0, 0, outW, outH, gl.RGBA, gl.UNSIGNED_BYTE, readBuf);
      const readPxMs = performance.now() - tP0;

      const tF0 = performance.now();
      const flipped = flipRgbaVertical(readBuf, outW, outH);
      const flipMs = performance.now() - tF0;

      let ipcMs = 0;
      try {
        const tW0 = performance.now();
        await api.videoExportWriteFrame(flipped);
        ipcMs = performance.now() - tW0;
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        onLog(`[動画] フレーム書込エラー f=${i + 1}: ${msg}`);
        await api.videoExportAbort();
        return { ok: false, message: msg };
      }

      const totalMs = performance.now() - tFrame0;
      const summary =
        `[動画][trace] f=${i + 1}/${totalFrames} t=${t.toFixed(4)}s ` +
        `seek=${seekMs.toFixed(0)}ms render=${renderMs.toFixed(0)}ms readPx=${readPxMs.toFixed(0)}ms ` +
        `flip=${flipMs.toFixed(0)}ms ipc=${ipcMs.toFixed(0)}ms total=${totalMs.toFixed(0)}ms ` +
        `| ${videoDebugSnapshot(video)}`;

      if (VIDEO_EXPORT_LOG_EVERY_FRAME) {
        onLog(summary);
      } else if (totalMs > 1500 || i % 30 === 0 || i === 0 || i === totalFrames - 1) {
        onLog(summary);
      }

      onProgress?.({ currentFrame: i + 1, totalFrames });
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
    videoTexture.dispose();
    viewport.dispose();
    renderer.dispose();
    if (stagedPath) {
      await api.videoExportUnlinkStaged(stagedPath).catch(() => {});
    }
  }
}
