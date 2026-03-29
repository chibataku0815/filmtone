/**
 * Film Lab バッチ — WebGL パイプライン（1 枚ずつ直列処理）
 *
 * @overview Web Film Lab の Viewport / MediaLoader をそのまま用い、同一 grade を複数ファイルに適用する。
 * @limitations GPU は 1 コンテキスト直列。巨大解像度は maxTextureSize で縮小読込（Web と同様）。
 */
import * as THREE from "three";
import { isWebGL2Supported } from "@/shared/gl";
import type { FilmLabBatchBridge } from "./desktop-api";
import { Viewport } from "@film-lab/core/Viewport";
import { MediaLoader } from "@film-lab/core/MediaLoader";
import { filmlabVertexShader } from "@film-lab/shader/filmlab.vert";
import { filmlabFragmentShader } from "@film-lab/shader/filmlab.frag";
import { halationHueToHex } from "@film-lab/preset-data";
import {
  filmLabParamsSchema,
  filmLookGradeInputSchema,
  PRESETS,
  LOOK_ID_BY_PRESET,
  parseCube,
  type Params,
  type PresetName,
} from "film-lab-core";

export type BatchFormat = "png" | "jpeg";

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
  lutIntensity: number;
  lutData: Float32Array | null;
  lutSize: number;
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

  const looksLikeWrapper =
    "grade" in o && "lookPresetId" in o && "presetVersion" in o;
  if (looksLikeWrapper) {
    const parsed = filmLookGradeInputSchema.safeParse(raw);
    if (!parsed.success) {
      throw new Error(
        `filmLookGradeInputSchema: ${parsed.error.message}`,
      );
    }
    const g = parsed.data;
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
    return {
      params: g.grade,
      lutIntensity: g.lutIntensity ?? 1,
      lutData,
      lutSize,
    };
  }

  const flat = filmLabParamsSchema.safeParse(raw);
  if (flat.success) {
    return {
      params: flat.data,
      lutIntensity: 1,
      lutData: null,
      lutSize: 0,
    };
  }

  if (typeof o.preset === "string" && o.preset in PRESETS) {
    return {
      params: PRESETS[o.preset as PresetName],
      lutIntensity: 1,
      lutData: null,
      lutSize: 0,
    };
  }

  if (typeof o.lookPresetId === "string") {
    const preset = presetFromLookId(o.lookPresetId);
    if (preset) {
      return {
        params: PRESETS[preset],
        lutIntensity: 1,
        lutData: null,
        lutSize: 0,
      };
    }
  }

  throw new Error(
    "grade JSON が認識できません（Params 全体 / filmLookGradeInput / preset / lookPresetId を想定）",
  );
}

/**
 * 画像パスの列を順に処理し、出力フォルダへ書き出す。
 */
export async function runBatchPipeline(options: {
  api: FilmLabBatchBridge;
  gradeJsonPath: string;
  gradeJsonText: string;
  imagePaths: string[];
  outputDir: string;
  format: BatchFormat;
  onLog: (line: string) => void;
}): Promise<void> {
  const { api, gradeJsonPath, gradeJsonText, imagePaths, outputDir, format } =
    options;

  if (!isWebGL2Supported()) {
    throw new Error("runBatchPipeline: WebGL2 が利用できません");
  }

  const grade = await resolveGradeFromJsonText(
    api,
    gradeJsonPath,
    gradeJsonText,
  );

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
  renderer.outputColorSpace = THREE.SRGBColorSpace;

  let viewport: Viewport | null = null;
  const mediaLoader = new MediaLoader();
  const maxTextureSize = renderer.capabilities.maxTextureSize;

  try {
    for (let i = 0; i < imagePaths.length; i++) {
      const src = imagePaths[i]!;
      const shortName = basename(src);
      options.onLog(`[${i + 1}/${imagePaths.length}] ${shortName}`);

      const buf = await api.readFileBuffer(src);
      const mime = mimeForImagePath(src);
      const file = new File([buf as BlobPart], shortName, { type: mime });

      let loadResult;
      try {
        loadResult = await mediaLoader.loadFile(file, { maxTextureSize });
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        options.onLog(`  ERROR load: ${msg}`);
        continue;
      }

      const { width, height, texture } = loadResult;

      if (!viewport) {
        viewport = new Viewport({
          vertexShader: filmlabVertexShader,
          fragmentShader: filmlabFragmentShader,
          width,
          height,
        });
        scene.add(viewport.mesh);
      }

      renderer.setSize(width, height, false);
      viewport.setResolution(width, height);
      viewport.setTexture(texture);
      viewport.setImageResolution(width, height);

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

      viewport.setTime(0);
      viewport.render(renderer, scene, camera);

      const mimeOut = format === "png" ? "image/png" : "image/jpeg";
      const quality = format === "jpeg" ? 0.92 : undefined;
      const dataUrl = renderer.domElement.toDataURL(
        mimeOut,
        quality as never,
      );
      const res = await fetch(dataUrl);
      const outBuf = new Uint8Array(await res.arrayBuffer());

      const ext = format === "jpeg" ? "jpg" : "png";
      const outName = `${baseNameWithoutExt(src)}-graded.${ext}`;

      try {
        const written = await api.writeOutputFile({
          outputDir,
          fileName: outName,
          data: outBuf,
        });
        options.onLog(`  OK → ${written}`);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        options.onLog(`  ERROR write: ${msg}`);
      }

      texture.dispose();
    }
  } finally {
    viewport?.dispose();
    renderer.dispose();
  }
}
