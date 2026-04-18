/**
 * OffscreenTargetPool — labeled GPU texture allocation for offscreen passes.
 *
 * Phase 1 T1-2. All offscreen RTs default to `rgba16float` per DIRECTION §2
 * (no clamp, HDR values > 1 are preserved). `label` is reused as an
 * identifier; calling `get` with the same label returns the same texture
 * unless dimensions / format / mipLevels change.
 */

export type OffscreenScale = "full" | "half" | "quarter" | "eighth";

export interface OffscreenTargetDescriptor {
  width: number;
  height: number;
  format?: GPUTextureFormat;
  mipLevelCount?: number;
  sampleCount?: number;
  usage?: GPUTextureUsageFlags;
}

interface Entry {
  texture: GPUTexture;
  descriptor: Required<Pick<OffscreenTargetDescriptor, "width" | "height" | "format" | "mipLevelCount" | "sampleCount">> & {
    usage: GPUTextureUsageFlags;
  };
}

const DEFAULT_OFFSCREEN_USAGE: GPUTextureUsageFlags =
  GPUTextureUsage.RENDER_ATTACHMENT |
  GPUTextureUsage.TEXTURE_BINDING |
  GPUTextureUsage.COPY_SRC;

export class OffscreenTargetPool {
  private readonly entries = new Map<string, Entry>();
  constructor(private readonly device: GPUDevice) {}

  get(label: string, desc: OffscreenTargetDescriptor): GPUTexture {
    const format = desc.format ?? "rgba16float";
    const mipLevelCount = desc.mipLevelCount ?? 1;
    const sampleCount = desc.sampleCount ?? 1;
    const usage = desc.usage ?? DEFAULT_OFFSCREEN_USAGE;

    const existing = this.entries.get(label);
    if (
      existing &&
      existing.descriptor.width === desc.width &&
      existing.descriptor.height === desc.height &&
      existing.descriptor.format === format &&
      existing.descriptor.mipLevelCount === mipLevelCount &&
      existing.descriptor.sampleCount === sampleCount &&
      existing.descriptor.usage === usage
    ) {
      return existing.texture;
    }
    existing?.texture.destroy();

    const texture = this.device.createTexture({
      label,
      size: { width: desc.width, height: desc.height, depthOrArrayLayers: 1 },
      format,
      mipLevelCount,
      sampleCount,
      usage,
    });
    this.entries.set(label, {
      texture,
      descriptor: { width: desc.width, height: desc.height, format, mipLevelCount, sampleCount, usage },
    });
    return texture;
  }

  /**
   * Build a mip-pyramid as N separately-labeled textures. `level=0` is the
   * `fullWidth`/`fullHeight` RT; each subsequent level halves until `minDim`.
   * Designed for bloom (5 levels) and halation (6 levels).
   */
  pyramid(
    labelPrefix: string,
    fullWidth: number,
    fullHeight: number,
    levels: number,
    desc: Omit<OffscreenTargetDescriptor, "width" | "height"> = {},
  ): GPUTexture[] {
    const out: GPUTexture[] = [];
    let w = Math.max(1, Math.floor(fullWidth));
    let h = Math.max(1, Math.floor(fullHeight));
    for (let i = 0; i < levels; i++) {
      out.push(this.get(`${labelPrefix}.${i}`, { ...desc, width: w, height: h }));
      w = Math.max(1, Math.floor(w / 2));
      h = Math.max(1, Math.floor(h / 2));
    }
    return out;
  }

  destroy(): void {
    for (const { texture } of this.entries.values()) texture.destroy();
    this.entries.clear();
  }
}
