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
 * change. The current product floor fixes spacing at 1.0, but keep the
 * legacy epsilon contract so older snapshots remain well-defined if this
 * parameter becomes variable again.
 */
export const CROSS_FILTER_MIN_SPACING_EPSILON = 1e-4;
/**
 * Hard-mode temporal hold was authored as "0.82 per frame" in WebGL.
 * Preview, however, renders on RAF cadence while export renders at the
 * fixed video-export cadence. Treat 24 fps as the reference contract so
 * both paths can derive the same real-time decay.
 */
export const CROSS_FILTER_TEMPORAL_REFERENCE_FPS = 24;
export const CROSS_FILTER_TEMPORAL_REFERENCE_DECAY = 0.82;

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

/**
 * Convert the legacy "0.82 per 24 fps frame" temporal hold into an
 * elapsed-time-based decay factor. This keeps preview (RAF cadence) and
 * fixed-fps export aligned in real time instead of render-count space.
 */
export function computeCrossFilterTemporalDecay(
  deltaSeconds: number,
  referenceFps: number = CROSS_FILTER_TEMPORAL_REFERENCE_FPS,
  referenceDecay: number = CROSS_FILTER_TEMPORAL_REFERENCE_DECAY,
): number {
  if (!Number.isFinite(deltaSeconds)) return referenceDecay;
  if (!Number.isFinite(referenceFps) || referenceFps <= 0) return referenceDecay;
  if (!Number.isFinite(referenceDecay) || referenceDecay < 0 || referenceDecay > 1) {
    return CROSS_FILTER_TEMPORAL_REFERENCE_DECAY;
  }
  const clampedDelta = Math.max(0, deltaSeconds);
  if (clampedDelta === 0) return 1;
  return Math.pow(referenceDecay, clampedDelta * referenceFps);
}

export interface CrossFilterHistorySnapshot {
  /** Clamped `crossFilterStrength` ∈ [0, 1]. */
  readonly strength: number;
  /** Quantized Hard Mode — 0 or 1. */
  readonly hardMode: 0 | 1;
  /** Current public `crossFilterMinSpacing` snapshot (1–10 in current UI). */
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
