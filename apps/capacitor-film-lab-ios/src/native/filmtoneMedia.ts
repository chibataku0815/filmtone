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
