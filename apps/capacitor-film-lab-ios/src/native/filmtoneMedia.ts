import { registerPlugin, type PluginListenerHandle } from "@capacitor/core";
import type {
  Phase0ExportProgress,
  Phase0ExportRequest,
  Phase0ExportResult,
  Phase0PreviewRenderResult,
  SourceInfo,
  SourceProbe,
} from "film-lab-core";

export interface PickedLutFile {
  filename: string;
  text: string;
  uri?: string;
}

export interface CacheBucketInventory {
  bytes: number;
  count: number;
}

export interface CacheInventory {
  totalBytes: number;
  sources: CacheBucketInventory;
  mezzanine: CacheBucketInventory;
  exports: CacheBucketInventory;
  previews: CacheBucketInventory;
  luts: CacheBucketInventory;
}

export interface CacheReleaseResult {
  removedCount: number;
  removedBytes: number;
  retainedBytes: number;
}

export interface CachePrunedNotice {
  removedBytes: number;
  trigger: "lowDisk";
}

/**
 * Hidden / debug-only payload returned by `probeCaptureCapabilities`.
 *
 * The probe enumerates `AVCaptureDevice` formats without starting a session.
 * Apple Log / Apple Log 2 entries appear only when the runtime reports them;
 * unknown enum raw values are surfaced by raw value alone (no inferred names).
 *
 * @internal Used by the V2 capture / Gyroflow lane M1 milestone. Not surfaced
 * from production UI.
 */
export interface CaptureCapabilityProbeResult {
  schemaVersion: number;
  filePath: string;
  fileURI: string;
  json: string;
  payload: CaptureCapabilityProbePayload;
}

export interface CaptureCapabilityProbePayload {
  schemaVersion: number;
  generatedAt: string;
  runtime: {
    iosVersion: string;
    systemName: string;
    deviceModel: string;
    deviceName: string;
  };
  devices: CaptureCapabilityProbeDevice[];
  m2Recommendation: {
    candidate: CaptureCapabilityProbeRecommendation | null;
    reasoning: string;
  };
}

export interface CaptureCapabilityProbeDevice {
  uniqueID: string;
  localizedName: string;
  modelID: string;
  manufacturer: string;
  deviceType: string;
  position: "back" | "front" | "unspecified" | "unknown";
  hasFlash: boolean;
  hasTorch: boolean;
  isVirtualDevice: boolean;
  formats: CaptureCapabilityProbeFormat[];
  constituentDevices?: Array<{
    uniqueID: string;
    deviceType: string;
    position: "back" | "front" | "unspecified" | "unknown";
  }>;
}

export interface CaptureCapabilityProbeFormat {
  index: number;
  mediaType: string;
  mediaSubType: string;
  codecLabel?: string;
  dimensions: { width: number; height: number };
  isVideoBinned: boolean;
  isVideoHDRSupported: boolean;
  videoFieldOfView: number;
  videoMaxZoomFactor: number;
  frameRateRanges: Array<{
    minFPS: number;
    maxFPS: number;
    minDurationSeconds: number;
    maxDurationSeconds: number;
  }>;
  supportedColorSpaces: Array<{ rawValue: number; name?: string }>;
  supportedVideoStabilizationModes: Array<{ rawValue: number; name?: string }>;
  supportedMaxPhotoDimensions?: Array<{ width: number; height: number }>;
  formatDescriptionExtensions?: {
    fullRangeVideoFlag?: unknown;
    transferFunction?: unknown;
    ycbcrMatrix?: unknown;
    colorPrimaries?: unknown;
  };
}

export interface CaptureCapabilityProbeRecommendation {
  deviceUniqueID: string;
  deviceLocalizedName: string;
  deviceType: string;
  formatIndex: number;
  codec: string;
  colorSpace: string;
  dimensions: { width: number; height: number };
  fps: number;
  score: number;
}

export interface FilmtoneMediaPlugin {
  pickSource(): Promise<SourceInfo | null>;
  pickLutFile(options?: { slot?: "inputLut" | "creativeLut" }): Promise<PickedLutFile | null>;
  probeSource(options: { uri: string }): Promise<SourceProbe>;
  renderPreviewFrame(request: Phase0ExportRequest): Promise<Phase0PreviewRenderResult>;
  runExport(request: Phase0ExportRequest): Promise<Phase0ExportResult>;
  saveToPhotos(options: { uri: string }): Promise<void>;
  shareOutput(options: {
    uri: string;
    sidecarUri?: string;
    packageFileUris?: string[];
  }): Promise<void>;
  cancelExport(): Promise<void>;
  cacheInventory(): Promise<CacheInventory>;
  releaseCache(options?: { protectedURIs?: string[] }): Promise<CacheReleaseResult>;
  /**
   * Hidden / debug-only V2 capability probe (M1).
   *
   * Enumerates `AVCaptureDevice` formats without starting a session. iOS only.
   * Web shim throws — there is no browser equivalent.
   */
  probeCaptureCapabilities(): Promise<CaptureCapabilityProbeResult>;
  addListener(
    eventName: "exportProgress",
    listenerFunc: (progress: Phase0ExportProgress) => void,
  ): Promise<PluginListenerHandle>;
  addListener(
    eventName: "cachePrunedNotice",
    listenerFunc: (notice: CachePrunedNotice) => void,
  ): Promise<PluginListenerHandle>;
}

export const filmtoneMedia = registerPlugin<FilmtoneMediaPlugin>(
  "FilmtoneMedia",
  {
    web: () => import("./filmtoneMedia.web").then((mod) => new mod.FilmtoneMediaWeb()),
  },
);
