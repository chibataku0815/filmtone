/**
 * Shared mip-weight formula for the bloom / halation / diffusion / central
 * bloom pyramids — extracted verbatim from `WebGLBackend.computeMipWeights`
 * (static method).
 *
 * Behavior-preserving relocation only.
 */

/**
 * Compute per-mip-level weights for the upsample accumulation.
 * radius=0 → tight bloom (only first mips). radius=1 → diffuse wide haze.
 */
export function computeMipWeights(radius: number, levels: number): number[] {
  const weights: number[] = [];
  for (let i = 0; i < levels; i++) {
    const t = i / Math.max(levels - 1, 1);
    const base = Math.exp(-3.0 * (1.0 - radius) * t);
    const wide = Math.exp(-0.5 * radius * (1.0 - t));
    weights.push(base * (1 - radius) + wide * radius);
  }
  return weights;
}
