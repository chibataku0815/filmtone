//
//  FilmtoneOpticalFilterEditorCatalog.swift
//  FilmLabSwiftCore
//
//  Shared editor-side vocabulary for optical filter profiles (currently
//  Backlight Veil 1/8, 1/4, 1/2). Promoted from the Desktop-only
//  `FilmtoneOpticalFilterCatalog` (in
//  `apps/filmtone-desktop-macos/.../Domain/AdvancedAdjustCatalog.swift`) as
//  part of M2.5 (Shared Editor Contract) so the iPad inspector reads from a
//  shared list instead of hardcoding `"backlightVeil-1-*"` IDs.
//
//  The rendering side (paramPatch, optical scatter coefficients, render
//  override resolution, sidecar payload) stays in the Desktop catalog and
//  the iOS render path respectively — those are platform-specific math
//  layers. This file owns only the editor vocabulary: id, family, density,
//  displayName, shortLabel.
//

import Foundation

/// Editor-facing description of an optical filter profile. Drives picker
/// labels, picker tags, sidecar identity, and adjust-panel summaries on
/// both iOS and macOS. Render math layers (Backlight Veil scatter params,
/// param patches) live in platform-specific catalogs that join on `id`.
public struct FilmtoneOpticalFilterEditorEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let family: String
    public let density: String
    public let displayName: String
    public let shortLabel: String

    public init(
        id: String,
        family: String,
        density: String,
        displayName: String,
        shortLabel: String
    ) {
        self.id = id
        self.family = family
        self.density = density
        self.displayName = displayName
        self.shortLabel = shortLabel
    }
}

public enum FilmtoneOpticalFilterEditorCatalog {
    /// Picker tag / sidecar marker for "no filter applied".
    public static let noneIdentifier: String = "none"

    /// Canonical entry list — the editor vocabulary both platforms read.
    /// Order is the picker / chip-row order (least dense first).
    public static let entries: [FilmtoneOpticalFilterEditorEntry] = [
        FilmtoneOpticalFilterEditorEntry(
            id: "backlightVeil-1-8",
            family: "backlightVeil",
            density: "1/8",
            displayName: "Backlight Veil 1/8",
            shortLabel: "1/8"
        ),
        FilmtoneOpticalFilterEditorEntry(
            id: "backlightVeil-1-4",
            family: "backlightVeil",
            density: "1/4",
            displayName: "Backlight Veil 1/4",
            shortLabel: "1/4"
        ),
        FilmtoneOpticalFilterEditorEntry(
            id: "backlightVeil-1-2",
            family: "backlightVeil",
            density: "1/2",
            displayName: "Backlight Veil 1/2",
            shortLabel: "1/2"
        ),
    ]

    /// Lookup an entry by profile id. Returns `nil` for `nil` or the
    /// `noneIdentifier` sentinel so callers can treat both as "no filter".
    public static func entry(for id: String?) -> FilmtoneOpticalFilterEditorEntry? {
        guard let id, id != noneIdentifier else { return nil }
        return entries.first { $0.id == id }
    }
}
