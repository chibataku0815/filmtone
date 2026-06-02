//
//  FilmtoneQuickAdjustEditorSpec.swift
//  FilmLabSwiftCore
//
//  Shared definition of the Quick Adjust 3-knob subset (Film Character /
//  Era / Dynamics). Both the iPhone fullscreen editor's
//  `FilmtoneStrengthSheet` and the iPad workspace's
//  `FilmtonePadAdjustPanel` previously hardcoded the same keys / center
//  offsets / ranges; M2.5 (Shared Editor Contract) lifts that definition
//  to a single source so adding or changing a Quick control happens once
//  for both iOS surfaces.
//
//  Localized labels stay platform-specific because each platform sources
//  them through its own `Strings` type. Desktop does not currently show
//  a Quick subset — it presents the full Advanced Adjust catalog inline —
//  but the spec lives here so a future Desktop Quick row reads from the
//  same definition.
//

import Foundation

/// One entry in the Quick Adjust subset. `key` is the canonical Phase 0
/// parameter key in `FilmtonePhase0Params`. `centerOffset` is the value
/// the underlying parameter holds when the slider sits at zero — so the
/// slider's `[-1, +1]` range maps to `[centerOffset - 1, centerOffset + 1]`
/// on the underlying param. Exposure's zero is 0; contrast and saturation
/// are 1.0 (multiplicative identity).
public struct FilmtoneQuickAdjustEditorEntry: Identifiable, Hashable, Sendable {
    public let key: String
    public let centerOffset: Double
    public let range: ClosedRange<Double>

    public init(
        key: String,
        centerOffset: Double,
        range: ClosedRange<Double> = -1...1
    ) {
        self.key = key
        self.centerOffset = centerOffset
        self.range = range
    }

    public var id: String { key }
}

public enum FilmtoneQuickAdjustEditorSpec {
    /// Canonical 3-knob Quick Adjust subset, in display order. iPhone
    /// `FilmtoneStrengthSheet` and iPad `FilmtonePadAdjustPanel` read this
    /// list; labels and help copy are resolved per platform.
    public static let entries: [FilmtoneQuickAdjustEditorEntry] = [
        FilmtoneQuickAdjustEditorEntry(key: "exposure", centerOffset: 0),
        FilmtoneQuickAdjustEditorEntry(key: "contrast", centerOffset: 1.0),
        FilmtoneQuickAdjustEditorEntry(key: "saturation", centerOffset: 1.0),
    ]

    /// Lookup by parameter key.
    public static func entry(for key: String) -> FilmtoneQuickAdjustEditorEntry? {
        entries.first { $0.key == key }
    }
}
