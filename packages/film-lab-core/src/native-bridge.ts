import { LOOK_RECIPE_VERSION } from "./look-ids";
import type { BaseLookName } from "./presets";
import type { CubeLUT } from "./cube-parser";
import {
  PHASE0_APPROX_SOURCE_LONG_EDGE_MAX,
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
  /**
   * True if asset has a depth source (HEIC aux depth OR AVDepthDataTrack on
   * video). Phase A (v1.3) covered HEIC stills; Phase B (v1.3, Stream D)
   * extended detection to video AVAssets carrying an AVDepthDataTrack.
   */
  hasDepth?: boolean;
}

export type SourceCodecFamily =
  | "h264"
  | "hevc"
  | "prores-422"
  | "prores-4444"
  | "prores-raw"
  | "other"
  | "unknown";

export type SourceLogTransferFunction =
  | "apple-log"
  | "apple-log2";

export type SourceInputTransformStrategy =
  | "none"
  | "apple-log-to-rec709"
  | "apple-log2-to-rec709"
  | "core-image-tone-map-sdr"
  | "defer-visible-warning"
  | "unsupported";

export interface SourceInputTransformPolicy {
  strategy: SourceInputTransformStrategy;
  reason: string;
  requiresFixtureValidation: boolean;
  warning: string | null;
}

export type CameraOpticsSource = "metadata" | "assumed" | "manual";

export interface CameraOptics {
  source: CameraOpticsSource;
  fxPx?: number;
  fyPx?: number;
  cxPx?: number;
  cyPx?: number;
  fovXDeg?: number;
  fovYDeg?: number;
  focalLength35mm?: number;
  lensModel?: string;
  cameraMake?: string;
  cameraModel?: string;
}

export interface SourceProbe extends SourceInfo {
  width?: number;
  height?: number;
  durationSec?: number;
  fileSizeBytes?: number;
  codec?: string;
  codecFamily?: SourceCodecFamily;
  logTransferFunction?: SourceLogTransferFunction;
  inputTransformPolicy?: SourceInputTransformPolicy;
  frameRate?: number;
  cameraOptics?: CameraOptics;
  sourceVideoMetadata?: SourceVideoMetadata;
  sourceToneDescriptor?: SourceToneDescriptor;
}

export interface SourceToneDescriptor {
  lumaP05: number;
  lumaP50: number;
  lumaP95: number;
  lumaRangeP05P95: number;
  shadowCoverage: number;
  highlightCoverage: number;
  lowMidCoverage: number;
  saturationMean: number;
}

// --- iOS v1.1 source video metadata (T1 HDR policy + T4 display/timing) ---
//
// The iOS probe builds this DTO in SourceProbeService. Desktop's own
// HdrPreparationPolicy (apps/desktop-film-lab-batch/electron/
// video-export-source-metadata.ts) is ffmpeg-oriented; iOS reports what its
// Core Image pipeline does through `IosHdrPreparationStrategy`. The bridge
// carries both via the shared `SourceVideoMetadata` envelope.

export type SourceColorClass =
  | "sdr-bt709"
  | "hdr-pq"
  | "hdr-hlg"
  | "apple-log"
  | "apple-log2"
  | "wide-gamut-unknown"
  | "unsupported"
  | "unknown";

export type IosHdrPreparationStrategy =
  | "none"
  | "core-image-tone-map-sdr"
  | "defer-visible-warning";

export interface IosHdrPreparationPolicy {
  strategy: IosHdrPreparationStrategy;
  // Reason vocab overlaps with Desktop where possible:
  //   "source-is-sdr-bt709" | "source-is-hdr-pq" | "source-is-hdr-hlg"
  //   | "wide-gamut-transfer-unknown" | "source-color-unknown"
  reason: string;
  requiresFixtureValidation: boolean;
  warning: string | null;
}

export interface SourceColorMetadata {
  colorRange: string | null;
  colorSpace: string | null;
  colorTransfer: string | null;
  colorPrimaries: string | null;
  logTransferFunction?: SourceLogTransferFunction | null;
  hasMasteringDisplayMetadata: boolean;
  hasContentLightMetadata: boolean;
}

export interface SourceDisplayGeometry {
  rawWidth: number;
  rawHeight: number;
  displayWidth: number;
  displayHeight: number;
  rotationDeg: 0 | 90 | 180 | 270 | null;
  source: "preferred-transform" | "raw";
}

export interface SourceVideoTimingMetadata {
  nominalFrameRate: number | null;
  estimatedFrameRate: number | null;
  sourceFrameRateTrusted: boolean;
  // v1.1 vocab: "nominal-only" | "missing-or-invalid-rate"
  // v1.2 extension: "within-absolute-tolerance" | "rates-diverged"
  trustReason: string;
}

export interface SourceVideoMetadata {
  display: SourceDisplayGeometry;
  color: SourceColorMetadata;
  colorClass: SourceColorClass;
  hdrPreparationPolicy?: IosHdrPreparationPolicy;
  timing?: SourceVideoTimingMetadata;
  codecFamily?: SourceCodecFamily;
  logTransferFunction?: SourceLogTransferFunction | null;
  inputTransformPolicy?: SourceInputTransformPolicy;
}

export interface ParsedCubeLut {
  title: string;
  size: number;
  data: number[];
  intensity: number;
  /**
   * v1.4 Creative LUT Pack: stable namespace slug for built-in cubes shipped
   * with the app bundle (e.g. `"filmtone-creative-pack-01-warm-print"`). nil
   * for user-imported / library-resolved cubes. Sidecar emits this so
   * downstream readers (Filmtone Connect for DaVinci) can recognize bundled
   * Looks across renames and app updates.
   */
  bundledSlug?: string;
  /**
   * v1.4 Creative LUT Pack: pack identifier for the bundled cube (e.g.
   * `"creative-pack-01"`). Companions `bundledSlug` so a single pack rev
   * is identifiable end-to-end.
   */
  bundledPackId?: string;
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

export type Phase0RenderMode = "quality" | "speed";

export type Phase0MezzanineProfileVariant =
  | "sdr"
  | "hdr"
  | "qualitySDR"
  | "qualityHDR";

/**
 * v1.3 (iOS, D3.1): depth prefilter renderer selector. Encoded as a plain
 * string on the wire for forward-compat — Phase B may add `metal` only on a
 * subset of devices. Native side defaults to `"ci"` when nil/absent.
 */
export type Phase0DepthRenderer = "ci" | "metal";

export interface Phase0ExportRequest {
  sourceUri: string;
  sourceKind: SourceKind;
  sourceProbe?: SourceProbe;
  output: Phase0OutputProfile;
  grade: {
    presetName: BaseLookName | string;
    presetVersion: typeof LOOK_RECIPE_VERSION;
    quickState: QuickState;
    params: Phase0Params;
  };
  inputLut: ParsedCubeLut | null;
  creativeLut: ParsedCubeLut | null;
  /** v1.2 (iOS): opt-in to Speed mode. Absent or "quality" behaves as Quality default. */
  renderMode?: Phase0RenderMode;
  /**
   * v1.3 (iOS, D3.1): opt-in flag for the AVDepthData × ray-angle prefilter on
   * the glow trio (mist/bloom/halation). Absent / false → byte-identical to
   * v1.2 output. Only honored for still HEIC sources with depth aux data;
   * video sources are rejected on the native side
   * (`feedback_no_fallback_bug_hotbed`).
   */
  depthEnabled?: boolean;
  /**
   * v1.3 (iOS, D3.1): depth prefilter renderer selector. Phase A ships only
   * `"ci"` (Core Image multi-image kernel); `"metal"` is reserved for Phase B.
   */
  depthRenderer?: Phase0DepthRenderer;
  /**
   * v1.4 (iOS): opt-in to writing the Filmtone Connect package companions
   * (sidecar + cubes + DCTL + reference-after.jpg + a copy of the source
   * media) next to the rendered output. Absent / false → only the rendered
   * mp4 + sidecar are emitted, avoiding the multi-GB source-media copy on
   * normal save-to-Photos / share-sheet flows. The user-facing
   * "Share as Connect package" entry point is the only caller that should
   * pass `true`.
   */
  connectPackage?: boolean;
}

export interface Phase0PreviewRenderResult {
  originalUri: string;
  gradedUri: string;
  width: number;
  height: number;
  posterTimeSec?: number;
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
  // v1.1: filmtone-ios-export-session-v1 sidecar JSON URI (app container temp URL).
  //       Absent when sidecar write failed or the caller disabled sidecar output.
  sidecarUri?: string;
  // Filmtone Connect package companions ordered for sharing:
  // media, sidecar, combined-color.cube, reference-after.jpg.
  packageFileUris?: string[];
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
  /** v1.1: whether this export consumed an existing mezzanine instead of decoding from source. */
  exportUsedMezzanine?: boolean;
  /** v1.1: ms spent generating a fresh mezzanine ahead of this export, if any. */
  mezzanineGenerationMs?: number;
  /** v1.2: render mode actually used ("quality" | "speed"). */
  renderMode?: Phase0RenderMode;
  /** v1.2+: mezzanine variant the export consumed, absent if no mezzanine used. */
  mezzanineProfileVariant?: Phase0MezzanineProfileVariant;
  /** v1.3 (D3.4): whether the depth × ray-angle prefilter ran for this export. */
  depthUsed?: boolean;
  /** v1.3 (D3.4): depth aux source ("avDepthData"), absent when depth not used. */
  depthSource?: string;
  /** v1.3 (D3.4): renderer that executed the prefilter ("ci" | "metal"), absent when depth not used. */
  depthRenderer?: Phase0DepthRenderer;
  /** v1.3 (D3.4): wall-clock ms across the three depth prefilter stages, absent when depth not used. */
  depthPrefilterMs?: number;
}

export function serializeCubeLut(
  lut: CubeLUT,
  options?: {
    title?: string;
    intensity?: number;
    bundledSlug?: string;
    bundledPackId?: string;
  },
): ParsedCubeLut {
  const out: ParsedCubeLut = {
    title: options?.title ?? lut.title ?? "Custom LUT",
    size: lut.size,
    data: Array.from(lut.data),
    intensity: options?.intensity ?? 1,
  };
  if (options?.bundledSlug !== undefined) {
    out.bundledSlug = options.bundledSlug;
  }
  if (options?.bundledPackId !== undefined) {
    out.bundledPackId = options.bundledPackId;
  }
  return out;
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
  project: Pick<
    Phase0ProjectState,
    "presetName" | "quickState" | "params" | "inputLut" | "creativeLut"
  >;
  output?: Partial<Phase0OutputProfile>;
}): Phase0ExportRequest {
  const probe = options.probe ?? undefined;
  if (probe) {
    assertPhase0SourceProbeWithinCaps(probe);
  }

  const toTransportLut = (
    lut: Phase0ProjectState["inputLut"] | null,
  ): ParsedCubeLut | null => {
    if (!lut) return null;
    const out: ParsedCubeLut = {
      title: lut.title,
      size: lut.size,
      data: lut.data,
      intensity: lut.intensity,
    };
    if ((lut as ParsedCubeLut).bundledSlug !== undefined) {
      out.bundledSlug = (lut as ParsedCubeLut).bundledSlug;
    }
    if ((lut as ParsedCubeLut).bundledPackId !== undefined) {
      out.bundledPackId = (lut as ParsedCubeLut).bundledPackId;
    }
    return out;
  };

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
      presetVersion: LOOK_RECIPE_VERSION,
      quickState: options.project.quickState as QuickState,
      params: options.project.params,
    },
    inputLut: toTransportLut(options.project.inputLut),
    creativeLut: toTransportLut(options.project.creativeLut),
  };
}
