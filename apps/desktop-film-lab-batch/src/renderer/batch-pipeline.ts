/**
 * Film Lab バッチ — WebGL パイプライン（1 枚ずつ直列処理）
 *
 * @overview Web Film Lab の Viewport / MediaLoader をそのまま用い、同一 grade を複数ファイルに適用する。
 * @limitations GPU は 1 コンテキスト直列。巨大解像度は maxTextureSize で縮小読込（Web と同様）。
 */
import {
  isWebGPUSupported,
  MediaLoader,
} from "film-lab-renderer";
import type { FilmLabBatchBridge } from "./desktop-api";
import {
  filmLabParamsSchema,
  filmLookGradeInputSchema,
  normalizeFilmLookGradeInputIdentity,
  createFilmtoneDefaultParams,
  PRESETS,
  LOOK_ID_BY_PRESET,
  parseCube,
  type CameraOptics,
  type Params,
  type PresetName,
} from "film-lab-core";
import { createOffscreenRenderSession } from "./offscreen/create-offscreen-render-session";
import {
  loadBatchDepthTrackFromGrade,
  type BatchDepthTrackSource,
  type BatchDepthTrack,
} from "./depth-track";

export type BatchFormat = "png" | "jpeg";

/**
 * @description バッチ 1 枚分の進捗（UI のプログレスバー用。current は 1 始まり）
 */
export type BatchPipelineProgressPayload = {
  current: number;
  total: number;
  fileName: string;
};

/**
 * @description 処理終了時の枚数集計（ログ・画面サマリー用）
 */
export type BatchPipelineSummary = {
  ok: number;
  loadFail: number;
  writeFail: number;
  /** @description 読込または書込に失敗した入力ファイルの絶対パス（順不同・重複なし） */
  failedPaths: string[];
  /** @description ユーザーが中断したとき true（未処理分は failedPaths に含めない） */
  aborted?: boolean;
};

/**
 * バッチが参照するルック状態（メモリ上の単一の真実。JSON はこれへの Import に過ぎない）
 */
export type BatchGradeState = {
  params: Params;
  /** Optional depth track for depth-aware Mist / Glow. */
  depthTrack: BatchDepthTrack | null;
  /** Input Transform LUT (before grading — Log→Rec709) */
  lut1Intensity: number;
  lut1Data: Float32Array | null;
  lut1Size: number;
  /**
   * Built-in source-profile catalog id when lut1 was generated from a
   * Camera Profile (e.g. `built-in:source-profile.panasonic-vlog`). null
   * when lut1 came from a custom `.cube` or no input transform is set.
   */
  lut1SourceProfileId: string | null;
  /** Creative LUT (after grading — film look) */
  lutIntensity: number;
  lutData: Float32Array | null;
  lutSize: number;
};

/**
 * プリセット名から LUT なしのグレード状態を作る（P1 の既定ルック）
 */
export function batchGradeStateFromPreset(preset: PresetName): BatchGradeState {
  return {
    params: PRESETS[preset],
    depthTrack: null,
    lut1Intensity: 1,
    lut1Data: null,
    lut1Size: 0,
    lut1SourceProfileId: null,
    lutIntensity: 1,
    lutData: null,
    lutSize: 0,
  };
}

export function createDefaultBatchGradeState(): BatchGradeState {
  return {
    params: createFilmtoneDefaultParams(),
    depthTrack: null,
    lut1Intensity: 1,
    lut1Data: null,
    lut1Size: 0,
    lut1SourceProfileId: null,
    lutIntensity: 1,
    lutData: null,
    lutSize: 0,
  };
}

function basename(filePath: string): string {
  const norm = filePath.replace(/\\/g, "/");
  const i = norm.lastIndexOf("/");
  return i >= 0 ? norm.slice(i + 1) : norm;
}

function baseNameWithoutExt(filePath: string): string {
  const base = basename(filePath);
  const dot = base.lastIndexOf(".");
  return dot > 0 ? base.slice(0, dot) : base;
}

/**
 * @description 出力ファイル名に付ける接尾辞を安全な形に直す（パス区切り・Windows 禁則文字を除去。
 * 空文字は「接尾辞なし＝ベース名のみ」を意味する。
 */
export function sanitizeBatchFilenameSuffix(raw: string): string {
  return raw
    .trim()
    .replace(/[/\\]/g, "")
    .replace(/[<>:"|?*\u0000-\u001f]/g, "_")
    .slice(0, 128);
}

function mimeForImagePath(filePath: string): string {
  const lower = filePath.toLowerCase();
  if (lower.endsWith(".png")) return "image/png";
  return "image/jpeg";
}

function presetFromLookId(lookId: string): PresetName | null {
  for (const [name, id] of Object.entries(LOOK_ID_BY_PRESET) as [
    PresetName,
    string,
  ][]) {
    if (id === lookId) return name;
  }
  return null;
}

/**
 * JSON テキストから Params と LUT 指定を復元する（3 形態を許容）。
 */
export async function resolveGradeFromJsonText(
  api: FilmLabBatchBridge,
  gradeJsonPath: string,
  jsonText: string,
): Promise<{
  params: Params;
  depthTrack: BatchDepthTrack | null;
  lut1Intensity: number;
  lut1Data: Float32Array | null;
  lut1Size: number;
  lut1SourceProfileId: string | null;
  lutIntensity: number;
  lutData: Float32Array | null;
  lutSize: number;
  cameraOptics: CameraOptics | null;
}> {
  let raw: unknown;
  try {
    raw = JSON.parse(jsonText) as unknown;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(`resolveGradeFromJsonText: JSON 解析失敗 — ${msg}`);
  }

  if (typeof raw !== "object" || raw === null) {
    throw new Error("resolveGradeFromJsonText: ルートがオブジェクトではありません");
  }

  const o = raw as Record<string, unknown>;

  // Look Unification: legacy / dual / Look-first wrapper をすべて認識する。
  // 当面 schema は `lookPresetId` / `presetVersion` を required のまま残すため
  // Look-first only payload は schema 緩和後に到達する path だが、discriminator
  // 側で先に弾くのは設計意図に反するので含めておく。
  const looksLikeWrapper =
    "grade" in o && ("lookPresetId" in o || "lookId" in o);
  if (looksLikeWrapper) {
    const parsed = filmLookGradeInputSchema.safeParse(raw);
    if (!parsed.success) {
      throw new Error(
        `filmLookGradeInputSchema: ${parsed.error.message}`,
      );
    }
    const g = normalizeFilmLookGradeInputIdentity(parsed.data);
    const depthTrackSource = (g as { depthTrack?: BatchDepthTrackSource }).depthTrack;
    const depthTrack = depthTrackSource
      ? await loadBatchDepthTrackFromGrade(api, gradeJsonPath, depthTrackSource)
      : null;

    // LUT1: Input Transform
    let lut1Data: Float32Array | null = null;
    let lut1Size = 0;
    const lut1On = g.lut1Enabled !== false;
    if (lut1On && g.lut1CubeRelPath) {
      const cube1Text = await api.readCubeRelativeToGrade(
        gradeJsonPath,
        g.lut1CubeRelPath,
      );
      const cube1 = parseCube(cube1Text);
      lut1Data = cube1.data;
      lut1Size = cube1.size;
    }

    // LUT2: Creative
    let lutData: Float32Array | null = null;
    let lutSize = 0;
    const lutOn = g.lutEnabled !== false;
    if (lutOn && g.lutCubeRelPath) {
      const cubeText = await api.readCubeRelativeToGrade(
        gradeJsonPath,
        g.lutCubeRelPath,
      );
      const cube = parseCube(cubeText);
      lutData = cube.data;
      lutSize = cube.size;
    }

    /**
     * @description wrapper 形式の grade は古い JSON 由来で一部キーが欠ける場合があるため、
     * ここで shared schema を通して既定値を補完する。
     */
    const normalizedGrade = filmLabParamsSchema.safeParse(g.grade);
    if (!normalizedGrade.success) {
      throw new Error(
        `resolveGradeFromJsonText(wrapper): grade の検証失敗 — ${normalizedGrade.error.message}`,
      );
    }

    return {
      params: normalizedGrade.data,
      depthTrack,
      lut1Intensity: g.lut1Intensity ?? 1,
      lut1Data,
      lut1Size,
      lut1SourceProfileId: null,
      lutIntensity: g.lutIntensity ?? 1,
      lutData,
      lutSize,
      cameraOptics: g.cameraOptics ?? null,
    };
  }

  const flat = filmLabParamsSchema.safeParse(raw);
  if (flat.success) {
    return {
      params: flat.data,
      depthTrack: null,
      lut1Intensity: 1,
      lut1Data: null,
      lut1Size: 0,
      lut1SourceProfileId: null,
      lutIntensity: 1,
      lutData: null,
      lutSize: 0,
      cameraOptics: null,
    };
  }

  if (typeof o.preset === "string" && o.preset in PRESETS) {
    return {
      params: PRESETS[o.preset as PresetName],
      depthTrack: null,
      lut1Intensity: 1,
      lut1Data: null,
      lut1Size: 0,
      lut1SourceProfileId: null,
      lutIntensity: 1,
      lutData: null,
      lutSize: 0,
      cameraOptics: null,
    };
  }

  if (typeof o.lookPresetId === "string") {
    const preset = presetFromLookId(o.lookPresetId);
    if (preset) {
    return {
      params: PRESETS[preset],
      depthTrack: null,
      lut1Intensity: 1,
        lut1Data: null,
        lut1Size: 0,
        lut1SourceProfileId: null,
        lutIntensity: 1,
        lutData: null,
        lutSize: 0,
        cameraOptics: null,
      };
    }
  }

  throw new Error(
    "grade JSON が認識できません（Params 全体 / filmLookGradeInput / preset / lookPresetId を想定）",
  );
}

/**
 * 画像パスの列を順に処理し、出力フォルダへ書き出す。
 * @param options.grade — メモリ上のルック（主導線）。JSON Import 後はこの形に詰め替える。
 * @param options.signal — 渡すと枚の境界で中断チェックし、打ち切り時は aborted: true で返す。
 * @param options.onProgress — 各ファイル処理の開始時に 1 回（current は 1 始まり）。
 * @param options.onFileOutcome — 各ファイルの成否が決まった直後に 1 回（永続化フック用）。
 * @param options.outputFilenameSuffix — ベース名と拡張子の間。省略時は "-graded"。空でベース名のみ。
 */
export async function runBatchPipeline(options: {
  api: FilmLabBatchBridge;
  grade: BatchGradeState;
  imagePaths: string[];
  outputDir: string;
  format: BatchFormat;
  onLog: (line: string) => void;
  signal?: AbortSignal;
  onProgress?: (payload: BatchPipelineProgressPayload) => void;
  onFileOutcome?: (payload: {
    absolutePath: string;
    outcome: "ok" | "loadFail" | "writeFail";
  }) => void;
  outputFilenameSuffix?: string;
}): Promise<BatchPipelineSummary> {
  const {
    api,
    grade,
    imagePaths,
    outputDir,
    format,
    signal,
    onProgress,
    outputFilenameSuffix,
  } = options;

  const suffixForFiles =
    outputFilenameSuffix === undefined
      ? sanitizeBatchFilenameSuffix("-graded")
      : sanitizeBatchFilenameSuffix(outputFilenameSuffix);

  if (!(await isWebGPUSupported())) {
    throw new Error("runBatchPipeline: WebGPU が利用できません");
  }

  const failedPathSet = new Set<string>();
  const pushFailed = (absolutePath: string) => {
    failedPathSet.add(absolutePath);
  };

  const stats: BatchPipelineSummary = {
    ok: 0,
    loadFail: 0,
    writeFail: 0,
    failedPaths: [],
  };

  /**
   * @description メイン側が中断したとき、ここまでの集計をログに出して結果を返す。
   */
  const finishIfAborted = (): BatchPipelineSummary | null => {
    if (!signal?.aborted) return null;
    options.onLog(
      `中断: 成功 ${stats.ok} / ${imagePaths.length}（読込失敗 ${stats.loadFail}, 書込失敗 ${stats.writeFail}）`,
    );
    return {
      ...stats,
      failedPaths: [...failedPathSet],
      aborted: true,
    };
  };

  const renderSession = await createOffscreenRenderSession({
    width: 1,
    height: 1,
    prefer: "webgpu",
  });
  options.onLog(`[batch] offscreen backend: ${renderSession.backendKind}`);
  renderSession.setGrade(grade);
  await renderSession.setDepthTrack(grade.depthTrack);

  const mediaLoader = new MediaLoader();
  const maxTextureSize = renderSession.maxTextureSize;

  try {
    for (let i = 0; i < imagePaths.length; i++) {
      const earlyAbort = finishIfAborted();
      if (earlyAbort) return earlyAbort;
      const src = imagePaths[i]!;
      const shortName = basename(src);
      const current = i + 1;
      options.onLog(`[${current}/${imagePaths.length}] ${shortName}`);
      onProgress?.({ current, total: imagePaths.length, fileName: shortName });

      let buf: Uint8Array;
      try {
        buf = await api.readFileBuffer(src);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        options.onLog(`  ERROR read: ${msg}`);
        stats.loadFail += 1;
        pushFailed(src);
        options.onFileOutcome?.({
          absolutePath: src,
          outcome: "loadFail",
        });
        continue;
      }

      const afterReadAbort = finishIfAborted();
      if (afterReadAbort) return afterReadAbort;

      const mime = mimeForImagePath(src);
      const file = new File([buf as BlobPart], shortName, { type: mime });

      let loadResult;
      try {
        loadResult = await mediaLoader.loadFile(file, { maxTextureSize });
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        options.onLog(`  ERROR load: ${msg}`);
        stats.loadFail += 1;
        pushFailed(src);
        options.onFileOutcome?.({
          absolutePath: src,
          outcome: "loadFail",
        });
        continue;
      }

      const afterLoaderAbort = finishIfAborted();
      if (afterLoaderAbort) return afterLoaderAbort;

      const { width, height, texture } = loadResult;

      renderSession.setRenderSize(width, height);
      await renderSession.setSource({
        texture,
        imageWidth: width,
        imageHeight: height,
      });
      renderSession.setTime(0);
      renderSession.render();

      const mimeOut = format === "png" ? "image/png" : "image/jpeg";
      const quality = format === "jpeg" ? 0.92 : undefined;
      const dataUrl = renderSession.toDataURL(
        mimeOut,
        quality,
      );
      const res = await fetch(dataUrl);
      const outBuf = new Uint8Array(await res.arrayBuffer());

      const ext = format === "jpeg" ? "jpg" : "png";
      const outName = `${baseNameWithoutExt(src)}${suffixForFiles}.${ext}`;

      try {
        const written = await api.writeOutputFile({
          outputDir,
          fileName: outName,
          data: outBuf,
        });
        options.onLog(`  OK → ${written}`);
        stats.ok += 1;
        options.onFileOutcome?.({ absolutePath: src, outcome: "ok" });
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        options.onLog(`  ERROR write: ${msg}`);
        stats.writeFail += 1;
        pushFailed(src);
        options.onFileOutcome?.({
          absolutePath: src,
          outcome: "writeFail",
        });
      }

      texture.dispose();
    }

    options.onLog(
      `集計: 成功 ${stats.ok} / ${imagePaths.length}（読込エラー ${stats.loadFail}, 書込エラー ${stats.writeFail}）`,
    );
  } finally {
    renderSession.dispose();
  }

  return {
    ...stats,
    failedPaths: [...failedPathSet],
    aborted: false,
  };
}
