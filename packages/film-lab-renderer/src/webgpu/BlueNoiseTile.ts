/**
 * BlueNoiseTile — 256×256 `r8unorm` texture built from a pre-baked tile.
 *
 * Phase 1 T1-2. DIRECTION §2: grain uses a blue-noise tile, not a per-frame
 * hash. The underlying bytes are void-and-cluster-generated at build time
 * (see `scripts/generate-blue-noise.mjs`).
 */

import { BLUE_NOISE_256_BYTES, BLUE_NOISE_256_SIZE } from "./assets/blue-noise-256";

export class BlueNoiseTile {
  /**
   * Upload the pre-baked tile as a single-channel `r8unorm` texture.
   * Cheaper than rgba8 since grain only needs one scalar value per texel;
   * the shader samples `.r` and reuses it for all channels (or dithered
   * chroma coefficients).
   */
  static load(device: GPUDevice): GPUTexture {
    const size = BLUE_NOISE_256_SIZE;
    const texture = device.createTexture({
      label: "blue-noise.256",
      size: { width: size, height: size, depthOrArrayLayers: 1 },
      format: "r8unorm",
      usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
    });
    // bytesPerRow = 256 ( = size × 1B), already 256-byte aligned.
    device.queue.writeTexture(
      { texture },
      BLUE_NOISE_256_BYTES as unknown as BufferSource,
      { bytesPerRow: size, rowsPerImage: size },
      { width: size, height: size, depthOrArrayLayers: 1 },
    );
    return texture;
  }
}
