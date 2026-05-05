import Foundation

// M5-K3 pure-Foundation clamp + default for the Before/After compare
// split fraction. Lives in Domain so EditorState (still / video state),
// FilmtoneCompareCompose (still preview), and the AVPlayer composition
// handler all share a single source of truth — and so the verify harness
// can pin the boundary behavior without booting CoreImage.
enum FilmtoneCompareSplitMath {

    /// Mid-frame split. Matches the M5-J.2 fixed 50:50 starting point so
    /// the first toggle of compare on a fresh source feels identical to
    /// the previous MVP before the user drags.
    static let `default`: Double = 0.5

    /// Inclusive [0, 1] range that the still / video preview composition
    /// helpers rely on to keep the split rectangles non-degenerate.
    static let range: ClosedRange<Double> = 0.0...1.0

    /// Clamp a candidate fraction into the valid range. Non-finite values
    /// (NaN / ±Infinity) collapse to `default` so a bad scrub never lands
    /// the renderer in an unrenderable state.
    static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return Self.default }
        return min(range.upperBound, max(range.lowerBound, value))
    }
}
