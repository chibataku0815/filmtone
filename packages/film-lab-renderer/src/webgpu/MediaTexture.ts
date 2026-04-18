/**
 * MediaTexture — upload still and video sources as `rgba8unorm-srgb`.
 *
 * Phase 1 T1-2. Hardware EOTF converts the sampled sRGB value to linear on
 * read (DIRECTION §2), so the pipeline sees linear Rec.709 from the first
 * texture fetch.
 *
 * `fromVideoElement` re-uploads on every frame via
 * `copyExternalImageToTexture`; the caller owns RAF scheduling. When
 * `VideoFrame` is unavailable we fall back to the same `HTMLVideoElement`
 * path (DIRECTION §10 common default).
 */

export interface MediaTextureOptions {
  label?: string;
  /** Default: `TEXTURE_BINDING | COPY_DST | RENDER_ATTACHMENT` */
  usage?: GPUTextureUsageFlags;
}

const DEFAULT_MEDIA_USAGE: GPUTextureUsageFlags =
  GPUTextureUsage.TEXTURE_BINDING |
  GPUTextureUsage.COPY_DST |
  GPUTextureUsage.RENDER_ATTACHMENT;

export class MediaTexture {
  static fromImageBitmap(
    device: GPUDevice,
    bitmap: ImageBitmap,
    opts: MediaTextureOptions = {},
  ): GPUTexture {
    const texture = device.createTexture({
      label: opts.label ?? "media.image",
      size: { width: bitmap.width, height: bitmap.height, depthOrArrayLayers: 1 },
      format: "rgba8unorm-srgb",
      usage: opts.usage ?? DEFAULT_MEDIA_USAGE,
    });
    device.queue.copyExternalImageToTexture(
      { source: bitmap, flipY: false },
      { texture },
      { width: bitmap.width, height: bitmap.height },
    );
    return texture;
  }

  /**
   * Upload the current frame of `video` into a reusable texture. If `target`
   * is null or its dimensions no longer match the video, a fresh texture is
   * allocated and returned; otherwise the existing one is updated in place.
   */
  static fromVideoElement(
    device: GPUDevice,
    video: HTMLVideoElement,
    target: GPUTexture | null,
    opts: MediaTextureOptions = {},
  ): GPUTexture {
    const width = video.videoWidth || 1;
    const height = video.videoHeight || 1;
    const needsAlloc =
      !target ||
      target.width !== width ||
      target.height !== height;
    const texture = needsAlloc
      ? device.createTexture({
          label: opts.label ?? "media.video",
          size: { width, height, depthOrArrayLayers: 1 },
          format: "rgba8unorm-srgb",
          usage: opts.usage ?? DEFAULT_MEDIA_USAGE,
        })
      : (target as GPUTexture);
    if (target && needsAlloc) target.destroy();
    device.queue.copyExternalImageToTexture(
      { source: video, flipY: false },
      { texture },
      { width, height },
    );
    return texture;
  }
}
