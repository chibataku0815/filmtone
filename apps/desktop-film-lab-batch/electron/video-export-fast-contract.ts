import { filmLabParamsSchema, type Params } from "film-lab-core";

import { buildGradeApproximationVF } from "./video-export-grade-approx-vf";

export const FILM_LAB_VIDEO_PROTOCOL = "film-lab-video";

export type FastTranscodeRequest = {
  inputVideoPath: string;
  outputDir: string;
  outputFileName: string;
  width: number;
  height: number;
  fps: number;
  hasAudio: boolean;
  lutCubeAbsPath: string;
  gradeParams: Params | null;
};

/**
 * @description レンダラの video 要素用 URL（クエリに path を載せる）
 */
export function absolutePathToVideoSrcUrl(absPath: string): string {
  return `${FILM_LAB_VIDEO_PROTOCOL}://local/?path=${encodeURIComponent(absPath)}`;
}

/**
 * @description 高速トランスコード IPC の payload を正規化する。
 * Params は schema validate に通ったときだけ採用し、それ以外は null として扱う。
 */
export function parseFastTranscodeRequest(
  payload: unknown,
): FastTranscodeRequest {
  if (!payload || typeof payload !== "object" || payload === null) {
    throw new TypeError("video-export-transcode-fast: payload が不正です");
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
  const lutCubeAbsPath =
    typeof o.lutCubeAbsPath === "string" ? o.lutCubeAbsPath.trim() : "";

  let gradeParams: Params | null = null;
  if (o.gradeParams != null && typeof o.gradeParams === "object") {
    const parsed = filmLabParamsSchema.safeParse(o.gradeParams);
    if (parsed.success) {
      gradeParams = parsed.data;
    }
  }

  if (
    !inputVideoPath ||
    !outputDir ||
    !outputFileName ||
    width <= 0 ||
    height <= 0 ||
    fps <= 0
  ) {
    throw new TypeError(
      "video-export-transcode-fast: inputVideoPath / outputDir / outputFileName / width / height / fps が不正です",
    );
  }

  return {
    inputVideoPath,
    outputDir,
    outputFileName,
    width,
    height,
    fps,
    hasAudio,
    lutCubeAbsPath,
    gradeParams,
  };
}

/**
 * @description ソース 1 本を直接読み、（任意）Params の ffmpeg 近似 + fps + scale +（任意）LUT3D で 1 パス書き出す。
 */
export function buildFfmpegFastTranscodeArgs(opts: {
  inputVideoPath: string;
  outputVideoPath: string;
  width: number;
  height: number;
  fps: number;
  hasAudio: boolean;
  lutCubeAbsPath: string | null;
  gradeParams: Params | null;
  videoCodecArgs: string[];
}): string[] {
  const {
    inputVideoPath,
    outputVideoPath,
    width,
    height,
    fps,
    hasAudio,
    lutCubeAbsPath,
    gradeParams,
    videoCodecArgs,
  } = opts;
  const vfParts: string[] = [];
  if (gradeParams != null) {
    vfParts.push(buildGradeApproximationVF(gradeParams));
  }
  vfParts.push(`fps=${fps}`, `scale=${width}:${height}:flags=lanczos`);
  if (lutCubeAbsPath != null && lutCubeAbsPath.length > 0) {
    const normalized = lutCubeAbsPath.replace(/\\/g, "/");
    const escaped = normalized.replace(/'/g, "'\\''");
    vfParts.push(`lut3d=file='${escaped}':interp=tetrahedral`);
  }
  const vf = vfParts.join(",");
  const args: string[] = [
    "-hide_banner",
    "-loglevel",
    "error",
    "-y",
    "-i",
    inputVideoPath,
    "-vf",
    vf,
    ...videoCodecArgs,
  ];
  return hasAudio
    ? args.concat([
        "-c:a",
        "copy",
        "-map",
        "0:v:0",
        "-map",
        "0:a:0",
        "-shortest",
        outputVideoPath,
      ])
    : args.concat(["-an", outputVideoPath]);
}
