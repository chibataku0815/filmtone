/**
 * Pure helpers for cross-filter runtime state transitions.
 *
 * Extracted so Hard-mode gating and temporal-history reset semantics can
 * be verified in a non-GPU test environment. Do not depend on any WebGPU
 * types here — this module stays side-effect free so unit tests under the
 * desktop-app's vitest setup can import it directly.
 */

/**
 * Minimum |Δ| on `crossFilterMinSpacing` that counts as a "material"
 * change, matching WebGL (`1e-4`). Values closer than this are treated
 * as the same setting and do NOT force a temporal-history reset.
 */
export const CROSS_FILTER_MIN_SPACING_EPSILON = 1e-4;

/**
 * Hard Mode is "active" only when the user has both:
 *   - engaged the cross filter (`crossFilterStrength > 0`), and
 *   - selected Hard Mode (`crossFilterHardMode >= 0.5`).
 *
 * This predicate drives both diffusion suppression (composite input is
 * zeroed) and the post-chain's temporal + central-bloom stages.
 */
export function isCrossFilterHardModeActive(
  crossFilterStrength: number,
  crossFilterHardMode: number,
): boolean {
  return crossFilterStrength > 0 && crossFilterHardMode >= 0.5;
}

/**
 * Effective diffusion contribution fed to the composite uniform and used
 * to gate the diffusion pyramid build. Hard Mode forces 0; otherwise the
 * user's value passes through clamped to [0, 1].
 *
 * The user's `diffusion` field is NEVER mutated — this function only
 * computes the frame-local effective value.
 */
export function effectiveDiffusionAmount(
  userDiffusion: number,
  hardModeActive: boolean,
): number {
  if (hardModeActive) return 0;
  if (!Number.isFinite(userDiffusion)) return 0;
  return Math.min(1, Math.max(0, userDiffusion));
}

export interface CrossFilterHistorySnapshot {
  /** Clamped `crossFilterStrength` ∈ [0, 1]. */
  readonly strength: number;
  /** Quantized Hard Mode — 0 or 1. */
  readonly hardMode: 0 | 1;
  /** Clamped `crossFilterMinSpacing` ∈ [0, 1]. */
  readonly minSpacing: number;
}

/**
 * Decide whether the cross-filter temporal history ring should be reset
 * given the prior-frame and current-frame snapshots.
 *
 * WebGL parity — the history is reset when:
 *   1. Hard Mode flips between Soft (0) and Hard (1).
 *   2. `crossFilterStrength` transitions from nonzero to 0.
 *   3. `crossFilterMinSpacing` crosses the epsilon.
 *
 * Resolution changes are handled separately in `setResolution`.
 */
export function shouldResetCrossFilterHistory(
  prev: CrossFilterHistorySnapshot,
  next: CrossFilterHistorySnapshot,
): boolean {
  if (next.hardMode !== prev.hardMode) return true;
  if (next.strength === 0 && prev.strength !== 0) return true;
  if (
    Math.abs(next.minSpacing - prev.minSpacing) >= CROSS_FILTER_MIN_SPACING_EPSILON
  ) {
    return true;
  }
  return false;
}
