import type { FilmLabBatchBridge } from "./desktop-api";

export type BatchDepthTrackSource = {
  kind: "frameSequence";
  fps: number;
  frameRelPaths: string[];
};

export type BatchDepthTrack = {
  source: BatchDepthTrackSource;
  absolutePaths: string[];
  frameUrls: string[];
};

function filePathToUrl(filePath: string): URL {
  const normalized = filePath.replace(/\\/g, "/");
  const prefixed = normalized.startsWith("/") ? normalized : `/${normalized}`;
  const encoded = prefixed
    .split("/")
    .map((segment, index) => (index === 0 ? segment : encodeURIComponent(segment)))
    .join("/");
  return new URL(`file://${encoded}`);
}

function resolveAbsolutePathRelativeToFile(
  baseFilePath: string,
  relPath: string,
): string {
  const resolved = new URL(relPath, filePathToUrl(baseFilePath));
  const decodedPath = decodeURIComponent(resolved.pathname);
  return /^\/[A-Za-z]:\//.test(decodedPath)
    ? decodedPath.slice(1)
    : decodedPath;
}

function mimeTypeForDepthFrame(filePath: string): string {
  const lower = filePath.toLowerCase();
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
  if (lower.endsWith(".webp")) return "image/webp";
  return "image/png";
}

async function createObjectUrlFromFile(
  api: FilmLabBatchBridge,
  filePath: string,
): Promise<string> {
  const bytes = await api.readFileBuffer(filePath);
  const blob = new Blob([Uint8Array.from(bytes).buffer], {
    type: mimeTypeForDepthFrame(filePath),
  });
  return URL.createObjectURL(blob);
}

async function loadFrameUrls(
  api: FilmLabBatchBridge,
  absolutePaths: string[],
): Promise<string[]> {
  return Promise.all(
    absolutePaths.map((filePath) => createObjectUrlFromFile(api, filePath)),
  );
}

export function releaseBatchDepthTrack(
  track: BatchDepthTrack | null | undefined,
): void {
  for (const url of track?.frameUrls ?? []) {
    URL.revokeObjectURL(url);
  }
}

export async function loadBatchDepthTrackFromGrade(
  api: FilmLabBatchBridge,
  gradeJsonPath: string,
  source: BatchDepthTrackSource,
): Promise<BatchDepthTrack> {
  const absolutePaths = source.frameRelPaths.map((relPath: string) =>
    resolveAbsolutePathRelativeToFile(gradeJsonPath, relPath),
  );
  return {
    source,
    absolutePaths,
    frameUrls: await loadFrameUrls(api, absolutePaths),
  };
}

export async function loadBatchDepthTrackFromAbsolutePaths(
  api: FilmLabBatchBridge,
  absolutePaths: string[],
  fps: number,
): Promise<BatchDepthTrack> {
  return {
    source: {
      kind: "frameSequence",
      fps,
      frameRelPaths: [...absolutePaths],
    },
    absolutePaths: [...absolutePaths],
    frameUrls: await loadFrameUrls(api, absolutePaths),
  };
}
