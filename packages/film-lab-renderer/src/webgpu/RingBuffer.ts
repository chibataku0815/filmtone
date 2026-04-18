/**
 * RingBuffer — 8-slot motion-blur ring implemented as a single `GPUTexture`
 * with `depthOrArrayLayers: 8` (DIRECTION §4 — never 8 separate textures).
 *
 * Phase 1 T1-2. On resize, the texture is recreated and `validSlots` resets
 * to 0 so the composite pass can skip stale layers via a uniform.
 */

export const MOTION_BLUR_RING_SLOTS = 8;

export interface RingBufferOptions {
  width: number;
  height: number;
  format?: GPUTextureFormat;
  label?: string;
}

const DEFAULT_FORMAT: GPUTextureFormat = "rgba16float";

export class RingBuffer {
  private texture: GPUTexture;
  private writeIndex = 0;
  private _validSlots = 0;
  private _width: number;
  private _height: number;
  private readonly format: GPUTextureFormat;
  private readonly label: string;

  constructor(private readonly device: GPUDevice, opts: RingBufferOptions) {
    this.format = opts.format ?? DEFAULT_FORMAT;
    this.label = opts.label ?? "motion-blur.ring";
    this._width = Math.max(1, Math.floor(opts.width));
    this._height = Math.max(1, Math.floor(opts.height));
    this.texture = this.allocate();
  }

  private allocate(): GPUTexture {
    return this.device.createTexture({
      label: this.label,
      size: {
        width: this._width,
        height: this._height,
        depthOrArrayLayers: MOTION_BLUR_RING_SLOTS,
      },
      dimension: "2d",
      format: this.format,
      usage:
        GPUTextureUsage.RENDER_ATTACHMENT |
        GPUTextureUsage.COPY_SRC |
        GPUTextureUsage.TEXTURE_BINDING,
    });
  }

  resize(width: number, height: number): void {
    const w = Math.max(1, Math.floor(width));
    const h = Math.max(1, Math.floor(height));
    if (w === this._width && h === this._height) return;
    this.texture.destroy();
    this._width = w;
    this._height = h;
    this.texture = this.allocate();
    this.writeIndex = 0;
    this._validSlots = 0;
  }

  /** Advance the write pointer. Returns the layer index to render into. */
  nextSlot(): number {
    const slot = this.writeIndex;
    this.writeIndex = (this.writeIndex + 1) % MOTION_BLUR_RING_SLOTS;
    if (this._validSlots < MOTION_BLUR_RING_SLOTS) this._validSlots += 1;
    return slot;
  }

  /** Target view for the given layer — pass to a render pass color attachment. */
  viewForSlot(slot: number): GPUTextureView {
    return this.texture.createView({
      baseArrayLayer: slot,
      arrayLayerCount: 1,
      dimension: "2d",
    });
  }

  /** 2D-array sampling view for the composite pass. */
  arrayView(): GPUTextureView {
    return this.texture.createView({ dimension: "2d-array" });
  }

  get validSlots(): number {
    return this._validSlots;
  }

  get width(): number {
    return this._width;
  }

  get height(): number {
    return this._height;
  }

  destroy(): void {
    this.texture.destroy();
  }
}
