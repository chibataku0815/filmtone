/**
 * Film Lab デスクトップ — 動画の高速書き出し（ffmpeg のみ）
 *
 * @overview WebGL・逐次 seek は使わず、1 回の ffmpeg で scale / fps /（任意）LUT3D / エンコードする。公開品質の正ではなく、internal approximation として扱う。
 * @limitations WebGL 非互換。Params は ffmpeg（eq 等）への近似のみ。bloom / halation / スプリットトーン細部は未再現。JSON .cube は lut3d。lutIntensity は未反映。
 */
import { filmLookGradeInputSchema, type Params } from "film-lab-core";
import type { FilmLabBatchBridge } from "./desktop-api";
import {
  assertVideoImportWithinCaps,
  computeVideoExportDimensions,
  VIDEO_EXPORT_FPS,
} from "./video-export-constants";

/**
 * @description Grade JSON の親ディレクトリと相対パスを結合して .cube の絶対パス風文字列を返す（区切りは / と \ に対応）
 * @param gradeJsonAbsPath インポートした JSON の絶対パス
 * @param lutRel lutCubeRelPath
 */
function joinGradeDirAndRel(
  gradeJsonAbsPath: string,
  lutRel: string,
): string {
  const cleanRel = lutRel.replace(/^\//, "").replace(/\\/g, "/");
  const norm = gradeJsonAbsPath.replace(/\\/g, "/");
  const i = norm.lastIndexOf("/");
  const dir = i >= 0 ? norm.slice(0, i) : "";
  if (dir.length === 0) {
    return cleanRel;
  }
  return `${dir}/${cleanRel}`;
}

/**
 * @description 高速書き出し用に、LUT .cube の絶対パスを返す（filmLookGradeInput で lut がオンのときのみ）
 * @returns パス文字列。該当なければ null
 */
export async function resolveLutCubeAbsPathForFastExport(
  api: FilmLabBatchBridge,
  importedGradeJsonPath: string | null,
): Promise<string | null> {
  if (importedGradeJsonPath == null || importedGradeJsonPath.trim() === "") {
    return null;
  }
  let raw: unknown;
  try {
    raw = JSON.parse(await api.readFileUtf8(importedGradeJsonPath)) as unknown;
  } catch {
    return null;
  }
  const parsed = filmLookGradeInputSchema.safeParse(raw);
  if (!parsed.success) {
    return null;
  }
  const g = parsed.data;
  if (g.lutEnabled === false) {
    return null;
  }
  const intensity = g.lutIntensity ?? 1;
  if (intensity <= 0) {
    return null;
  }
  const rel = g.lutCubeRelPath;
  if (typeof rel !== "string" || rel.trim() === "") {
    return null;
  }
  return joinGradeDirAndRel(importedGradeJsonPath, rel.trim());
}

/**
 * @description ffmpeg 1 パスで MP4 を書き出す（メインの IPC）
 */
export async function runVideoExportFfmpegFast(options: {
  api: FilmLabBatchBridge;
  inputVideoPath: string;
  outputDir: string;
  outputFileName: string;
  /** @description resolveLutCubeAbsPathForFastExport の戻り。無ければ LUT でない */
  lutCubeAbsPath: string | null;
  /** @description バッチ用プリセット／スライダー数値（ffmpeg 近似に渡す。公開品質の正は WebGL accurate） */
  gradeParams: Params;
  onLog: (line: string) => void;
}): Promise<{ ok: true } | { ok: false; message: string }> {
  const {
    api,
    inputVideoPath,
    outputDir,
    outputFileName,
    lutCubeAbsPath,
    gradeParams,
    onLog,
  } = options;

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
  const safeOutName =
    outputFileName.replace(/[/\\]/g, "_").replace(/[<>:"|?*\u0000-\u001f]/g, "_") ||
    "film-lab-export.mp4";

  onLog(
    `[動画・高速] ffmpeg 1 パス（${outW}×${outH} @ ${VIDEO_EXPORT_FPS}fps）。LUT-first / Params は ffmpeg 近似。プレビューとは一致しません。LUT ファイル: ${lutCubeAbsPath ? "あり" : "なし"}`,
  );

  try {
    const r = await api.videoExportTranscodeFast({
      inputVideoPath,
      outputDir,
      outputFileName: safeOutName,
      width: outW,
      height: outH,
      fps: VIDEO_EXPORT_FPS,
      hasAudio: probe.hasAudio,
      lutCubeAbsPath: lutCubeAbsPath ?? "",
      gradeParams,
    });
    if (r.code !== 0) {
      onLog(`[動画・高速] ffmpeg 終了コード ${r.code}`);
      if (r.stderrTail) {
        onLog(r.stderrTail);
      }
      return { ok: false, message: `ffmpeg 失敗 code=${r.code}` };
    }
    onLog(`[動画・高速] 完了 → ${r.outputVideoPath}`);
    return { ok: true };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, message: msg };
  }
}
