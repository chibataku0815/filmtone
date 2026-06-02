//
//  EditorCompareSplit.swift
//  FilmLabSwiftCore
//
//  Pure-Foundation clamp + default for the Before/After compare split
//  fraction. Originally introduced in M5-K3 on the macOS Desktop app
//  (`FilmtoneCompareSplitMath` under `Domain/`). M3 (iPad Preview
//  Optimization) promotes the math into FilmLabSwiftCore so iPad's new
//  `FilmtonePadCompareSplitOverlay` shares the same source of truth as
//  Desktop's `CompareSplitOverlay`, `EditorState.compareSplitFraction`,
//  `FilmtoneCompareCompose.makeSplit`, and the AVPlayer composition
//  handler — and so the Verify harness can pin the boundary behavior
//  without booting CoreImage or AVFoundation.
//
//  Symbol name (`FilmtoneCompareSplitMath`) is preserved so existing
//  Desktop call sites and Verify tests remain unchanged after promotion.
//

import Foundation

public enum FilmtoneCompareSplitMath {

    /// Mid-frame split. Matches the M5-J.2 fixed 50:50 starting point so
    /// the first toggle of compare on a fresh source feels identical to
    /// the previous MVP before the user drags.
    public static let `default`: Double = 0.5

    /// Inclusive [0, 1] range that the still / video preview composition
    /// helpers rely on to keep the split rectangles non-degenerate.
    public static let range: ClosedRange<Double> = 0.0...1.0

    /// Clamp a candidate fraction into the valid range. Non-finite values
    /// (NaN / ±Infinity) collapse to `default` so a bad scrub never lands
    /// the renderer in an unrenderable state.
    public static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return Self.default }
        return min(range.upperBound, max(range.lowerBound, value))
    }
}
