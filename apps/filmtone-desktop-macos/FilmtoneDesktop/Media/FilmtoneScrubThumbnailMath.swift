import CoreGraphics
import Foundation

// M5-K4 — Foundation-only helpers for the scrub-thumbnail provider.
//
// Kept separate from `FilmtoneVideoScrubThumbnailProvider` so the standalone
// `Verify/run.sh` harness (Foundation + FilmLabSwiftCore only — no
// AVFoundation, no Core Image) can exercise the math. Pure types here also
// keep the provider's hot path obviously side-effect-free.

enum FilmtoneScrubThumbnailMath {

    /// Default hover quantization bucket (seconds). 0.25s gives ~4 unique
    /// thumbnails per second of footage — fine-grained enough to feel
    /// responsive on a typical 600pt-wide scrub bar (one bucket ≈ 2pt at
    /// a 2-minute clip), and coarse enough to land cache hits on adjacent
    /// hover positions.
    static let defaultQuantizeBucketSeconds: Double = 0.25

    /// Quantize a timestamp into a bucket so adjacent hover positions
    /// resolve to the same cache key. `bucket` must be > 0; non-finite or
    /// negative `seconds` clamp to 0.
    static func quantize(
        seconds: Double,
        bucket: Double = defaultQuantizeBucketSeconds
    ) -> Double {
        guard bucket > 0 else { return max(0, seconds) }
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return (seconds / bucket).rounded() * bucket
    }

    /// Clamp a request timestamp into `[0, duration]` so a far-right hover
    /// or quantize-rounding cannot push the request past the asset's end.
    /// AVAssetImageGenerator fails silently for out-of-range times and
    /// the right edge of the scrub bar would lose its thumbnail. Non-
    /// finite or non-positive `duration` clamps to 0.
    static func clampToDuration(seconds: Double, duration: Double) -> Double {
        guard duration.isFinite, duration > 0 else { return 0 }
        guard seconds.isFinite else { return 0 }
        return min(duration, max(0, seconds))
    }

    /// Quantize while honoring the asset's duration. Naive
    /// `clampToDuration → quantize` still lets bucket rounding overshoot:
    /// for a 12.38s clip, a far-right hover clamps to 12.38, then
    /// `quantize(12.38)` rounds 49.52 → 50 → 12.50, which AVAssetImage-
    /// Generator silently rejects. When the rounded bucket would exceed
    /// `duration`, fall back to the last bucket ≤ duration. Non-finite or
    /// non-positive `duration` clamps to 0.
    static func quantizeWithinDuration(
        seconds: Double,
        duration: Double,
        bucket: Double = defaultQuantizeBucketSeconds
    ) -> Double {
        let clamped = clampToDuration(seconds: seconds, duration: duration)
        let q = quantize(seconds: clamped, bucket: bucket)
        if q <= duration { return q }
        guard bucket > 0 else { return clamped }
        let floored = (duration / bucket).rounded(.down) * bucket
        return max(0, floored)
    }

    /// Map a hover X (in slider local space) onto a [0, 1] fraction of
    /// the slider's *usable* track. Mirrors the knob-aware math in
    /// `FilmtoneGlassSlider.updateValue` so hover and drag agree at the
    /// edges. `width` is the slider's full width (knob inclusive),
    /// `knob` is the rendered knob diameter at the current hover/drag
    /// state.
    static func clampHoverFraction(
        x: CGFloat,
        width: CGFloat,
        knob: CGFloat
    ) -> Double {
        let usable = max(width - knob, 1)
        let raw = (x - knob / 2) / usable
        return min(1.0, max(0.0, Double(raw)))
    }

    /// Place the thumbnail center so it follows the cursor but is clamped
    /// inside the scrub bar's window-relative bounds. The thumbnail must
    /// not escape `[scrubBarMinX, scrubBarMaxX]` even when the cursor is
    /// near either end. If the thumbnail is wider than the scrub bar
    /// itself, fall back to centering it on the scrub bar (no escape
    /// possible without overflow).
    static func clampThumbnailCenterX(
        cursorX: CGFloat,
        thumbnailWidth: CGFloat,
        scrubBarMinX: CGFloat,
        scrubBarMaxX: CGFloat
    ) -> CGFloat {
        let half = thumbnailWidth / 2
        let scrubBarWidth = scrubBarMaxX - scrubBarMinX
        guard scrubBarWidth >= thumbnailWidth else {
            return scrubBarMinX + scrubBarWidth / 2
        }
        let lower = scrubBarMinX + half
        let upper = scrubBarMaxX - half
        return min(upper, max(lower, cursorX))
    }
}

/// Cache key for a thumbnail request. Combines the quantized timestamp with
/// the inputs signature so a render-input change automatically invalidates
/// the cache without explicit clearing.
struct FilmtoneScrubThumbnailCacheKey: Hashable {
    let quantizedSeconds: Double
    let signature: UInt64
}
