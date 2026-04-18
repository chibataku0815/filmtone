import { PRESET_VERSION } from "./look-ids";
import type { PresetName } from "./presets";
import type { CubeLUT } from "./cube-parser";
import {
  PHASE0_APPROX_SOURCE_LONG_EDGE_MAX,
  PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES,
  PHASE0_MAX_SOURCE_DURATION_SEC,
  PHASE0_OUTPUT_PROFILE,
  type Phase0OutputProfile,
  type Phase0Params,
  type Phase0ProjectState,
} from "./phase0-schema";
import type { QuickState } from "./quick-semantics";

export type SourceKind = "image" | "video";

export interface SourceInfo {
  uri: string;
  filename: string;
  kind: SourceKind;
  mimeType?: string;
}

export interface SourceProbe extends SourceInfo {
  width?: number;
  height?: number;
  durationSec?: number;
  fileSizeBytes?: number;
  codec?: string;
  frameRate?: number;
}

export interface ParsedCubeLut {
  title: string;
  size: number;
  data: number[];
  intensity: number;
}

export interface PickedLutFile {
  filename: string;
  text: string;
  uri?: string;
}

export type Phase0ExportStage =
  | "preflight"
  | "reading"
  | "rendering"
  | "writing"
  | "completed";

export interface Phase0ExportRequest {
  sourceUri: string;
  sourceKind: SourceKind;
  sourceProbe?: SourceProbe;
  output: Phase0OutputProfile;
  grade: {
    presetName: PresetName | string;
    presetVersion: typeof PRESET_VERSION;
    quickState: QuickState;
    params: Phase0Params;
  };
  lut: {
    inputLut: ParsedCubeLut | null;
    creativeLut: ParsedCubeLut | null;
  };
}

export interface Phase0ExportProgress {
  stage: Phase0ExportStage;
  progress: number;
  currentFrame?: number;
  totalFrames?: number;
  message?: string;
}

export interface Phase0ExportResult {
  outputUri: string;
  elapsedMs: number;
  outputWidth: number;
  outputHeight: number;
  outputFps: number;
  fileSizeBytes?: number;
  realtimeRatio?: number;
  audioPreserved?: boolean;
  benchmarkRecord?: Phase0ExportBenchmarkRecord;
}

export interface Phase0ExportBenchmarkRecord {
  appVersion: string;
  buildNumber: string;
  deviceModel: string;
  iosVersion: string;
  sourceCodec?: string;
  sourceResolution?: string;
  sourceDurationSec?: number;
  outputFileSizeBytes?: number;
  elapsedMs: number;
  realtimeRatio?: number;
  thermalState?: string;
  memoryWarningCount?: number;
  permissionResult?: string;
  saveToPhotosOk?: boolean;
  errorDomain?: string;
  errorCode?: string;
}

export function serializeCubeLut(
  lut: CubeLUT,
  options?: {
    title?: string;
    intensity?: number;
  },
): ParsedCubeLut {
  return {
    title: options?.title ?? lut.title ?? "Custom LUT",
    size: lut.size,
    data: Array.from(lut.data),
    intensity: options?.intensity ?? 1,
  };
}

export function deserializeCubeLutData(lut: ParsedCubeLut): Float32Array {
  return Float32Array.from(lut.data);
}

export function getPhase0SourceCapViolations(probe: SourceProbe): string[] {
  const violations: string[] = [];
  const longEdge =
    typeof probe.width === "number" && typeof probe.height === "number"
      ? Math.max(probe.width, probe.height)
      : undefined;

  if (
    probe.kind === "video" &&
    typeof probe.durationSec === "number" &&
    probe.durationSec > PHASE0_MAX_SOURCE_DURATION_SEC
  ) {
    violations.push(
      `Source duration ${probe.durationSec.toFixed(1)}s exceeds ${PHASE0_MAX_SOURCE_DURATION_SEC}s`,
    );
  }

  if (
    typeof longEdge === "number" &&
    longEdge > PHASE0_APPROX_SOURCE_LONG_EDGE_MAX
  ) {
    violations.push(
      `Source long edge ${longEdge}px exceeds ${PHASE0_APPROX_SOURCE_LONG_EDGE_MAX}px`,
    );
  }

  if (
    typeof probe.fileSizeBytes === "number" &&
    probe.fileSizeBytes > PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES
  ) {
    violations.push(
      `Source size ${probe.fileSizeBytes} bytes exceeds ${PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES} bytes`,
    );
  }

  return violations;
}

export function assertPhase0SourceProbeWithinCaps(probe: SourceProbe): void {
  const violations = getPhase0SourceCapViolations(probe);
  if (violations.length > 0) {
    throw new RangeError(violations.join("; "));
  }
}

export function buildPhase0ExportRequest(options: {
  source: SourceInfo;
  probe?: SourceProbe | null;
  project: Pick<Phase0ProjectState, "presetName" | "quickState" | "params" | "lut">;
  output?: Partial<Phase0OutputProfile>;
}): Phase0ExportRequest {
  const probe = options.probe ?? undefined;
  if (probe) {
    assertPhase0SourceProbeWithinCaps(probe);
  }

  return {
    sourceUri: options.source.uri,
    sourceKind: options.source.kind,
    sourceProbe: probe,
    output: {
      ...PHASE0_OUTPUT_PROFILE,
      ...options.output,
    },
    grade: {
      presetName: options.project.presetName,
      presetVersion: PRESET_VERSION,
      quickState: options.project.quickState as QuickState,
      params: options.project.params,
    },
    lut: {
      inputLut: null,
      creativeLut: options.project.lut
        ? {
            title: options.project.lut.title,
            size: options.project.lut.size,
            data: options.project.lut.data,
            intensity: options.project.lut.intensity,
          }
        : null,
    },
  };
}
