/**
 * Lut3DTexture — 3D texture upload for LUT1 (Log→Linear) and LUT2 (Creative).
 *
 * Phase 1 T1-2. DIRECTION §2:
 *   - format = `rgba16float`
 *   - `writeTexture` requires `bytesPerRow` 256-byte aligned
 *   - `rowsPerImage = size` so depth slices line up
 *
 * `data` is interpreted as interleaved RGBA float16 or float32 depending on
 * `inputKind`. Internally we normalize to `Float16Array`-equivalent (Uint16
 * holding IEEE 754 binary16 bits). An identity LUT helper is provided for
 * pipeline smoke tests before real `.cube` data arrives.
 */

const BYTES_PER_TEXEL_RGBA16F = 8;
const ALIGN_BYTES_PER_ROW = 256;

export interface LutUploadOptions {
  /** Debug label passed to `createTexture` / `writeTexture`. */
  label?: string;
}

function alignUp(value: number, multiple: number): number {
  return Math.ceil(value / multiple) * multiple;
}

function floatToHalf(f: number): number {
  // IEEE 754 float32 → binary16 via DataView round-trip is the simplest safe
  // path. Pre-baked LUTs are small (≤ 64³) so the one-time cost is negligible.
  const f32 = new Float32Array(1);
  const u32 = new Uint32Array(f32.buffer);
  f32[0] = f;
  const x = u32[0];
  const sign = (x >>> 16) & 0x8000;
  let mantissa = x & 0x7fffff;
  let exponent = (x >>> 23) & 0xff;
  if (exponent === 0xff) {
    return sign | 0x7c00 | (mantissa ? 0x200 : 0);
  }
  exponent -= 127 - 15;
  if (exponent >= 0x1f) return sign | 0x7c00;
  if (exponent <= 0) {
    if (exponent < -10) return sign;
    mantissa = (mantissa | 0x800000) >> (1 - exponent);
    if (mantissa & 0x1000) mantissa += 0x2000;
    return sign | (mantissa >> 13);
  }
  if (mantissa & 0x1000) {
    mantissa += 0x2000;
    if (mantissa & 0x800000) {
      mantissa = 0;
      exponent += 1;
      if (exponent >= 0x1f) return sign | 0x7c00;
    }
  }
  return sign | (exponent << 10) | (mantissa >> 13);
}

function float32ArrayToFloat16(data: Float32Array): Uint16Array {
  const out = new Uint16Array(data.length);
  for (let i = 0; i < data.length; i++) out[i] = floatToHalf(data[i]);
  return out;
}

export class Lut3DTexture {
  /**
   * Upload a 3D LUT. `data` must be `size³ × 4` floats (RGBA, row-major:
   * R at x=0, then x=1…, then y, then z). Identity inputs should hit the
   * `[0..1]` range; clamping is left to the caller — LUT1 accepts bounded
   * Log-encoded input, LUT2 is Reinhard-soft-shaped upstream (DIRECTION §3).
   */
  static upload(
    device: GPUDevice,
    data: Float32Array,
    size: number,
    opts: LutUploadOptions = {},
  ): GPUTexture {
    const expected = size * size * size * 4;
    if (data.length !== expected) {
      throw new Error(
        `Lut3DTexture.upload: data length ${data.length} !== ${expected} for size ${size}`,
      );
    }
    const rowBytes = size * BYTES_PER_TEXEL_RGBA16F;
    const bytesPerRow = Math.max(ALIGN_BYTES_PER_ROW, alignUp(rowBytes, ALIGN_BYTES_PER_ROW));
    const rowsPerImage = size;

    const texture = device.createTexture({
      label: opts.label ?? "lut3d",
      dimension: "3d",
      size: { width: size, height: size, depthOrArrayLayers: size },
      format: "rgba16float",
      usage:
        GPUTextureUsage.TEXTURE_BINDING |
        GPUTextureUsage.COPY_DST,
    });

    const half = float32ArrayToFloat16(data);
    // writeTexture requires contiguous rows at `bytesPerRow`; when padded we
    // repack into an aligned buffer.
    const needsPad = bytesPerRow !== rowBytes;
    let payload: Uint8Array;
    if (!needsPad) {
      payload = new Uint8Array(half.buffer, half.byteOffset, half.byteLength);
    } else {
      payload = new Uint8Array(bytesPerRow * rowsPerImage * size);
      const srcRowBytes = rowBytes;
      const srcStride = srcRowBytes; // rgba16f is 8B per texel
      for (let z = 0; z < size; z++) {
        for (let y = 0; y < size; y++) {
          const srcOffset = (z * size + y) * srcStride;
          const dstOffset = (z * size + y) * bytesPerRow;
          payload.set(
            new Uint8Array(half.buffer, half.byteOffset + srcOffset, srcRowBytes),
            dstOffset,
          );
        }
      }
    }

    device.queue.writeTexture(
      { texture },
      payload as unknown as BufferSource,
      { bytesPerRow, rowsPerImage },
      { width: size, height: size, depthOrArrayLayers: size },
    );
    return texture;
  }

  /**
   * Identity LUT (linear ramp) — each texel holds its own normalized coord.
   * Used as a no-op placeholder to verify the pipeline end-to-end before
   * plugging in real `.cube` data.
   */
  static identity(size: number): Float32Array {
    const out = new Float32Array(size * size * size * 4);
    const denom = Math.max(1, size - 1);
    for (let z = 0; z < size; z++) {
      for (let y = 0; y < size; y++) {
        for (let x = 0; x < size; x++) {
          const i = ((z * size + y) * size + x) * 4;
          out[i + 0] = x / denom;
          out[i + 1] = y / denom;
          out[i + 2] = z / denom;
          out[i + 3] = 1;
        }
      }
    }
    return out;
  }
}
