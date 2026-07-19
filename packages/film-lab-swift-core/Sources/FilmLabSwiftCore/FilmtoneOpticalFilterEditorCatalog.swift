//
//  FilmtoneOpticalFilterEditorCatalog.swift
//  FilmLabSwiftCore
//
//  Shared editor-side vocabulary for Deep Glow profiles. The legacy
//  Backlight Veil density ids remain the compatibility contract. Promoted
//  from the Desktop-only
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
/// both iOS and macOS. Render math layers (Deep Glow scatter params,
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
    public static let featureName: String = "Deep Glow"

    /// Picker tag / sidecar marker for "no filter applied".
    public static let noneIdentifier: String = "none"

    /// Canonical entry list — the editor vocabulary both platforms read.
    /// Order is the picker / chip-row order (least dense first).
    public static let entries: [FilmtoneOpticalFilterEditorEntry] = [
        FilmtoneOpticalFilterEditorEntry(
            id: "backlightVeil-1-8",
            family: "backlightVeil",
            density: "1/8",
            displayName: "Deep Glow - Subtle",
            shortLabel: "Subtle"
        ),
        FilmtoneOpticalFilterEditorEntry(
            id: "backlightVeil-1-4",
            family: "backlightVeil",
            density: "1/4",
            displayName: "Deep Glow - Balanced",
            shortLabel: "Balanced"
        ),
        FilmtoneOpticalFilterEditorEntry(
            id: "backlightVeil-1-2",
            family: "backlightVeil",
            density: "1/2",
            displayName: "Deep Glow - Strong",
            shortLabel: "Strong"
        ),
    ]

    /// Lookup an entry by profile id. Returns `nil` for `nil` or the
    /// `noneIdentifier` sentinel so callers can treat both as "no filter".
    public static func entry(for id: String?) -> FilmtoneOpticalFilterEditorEntry? {
        guard let id, id != noneIdentifier else { return nil }
        return entries.first { $0.id == id }
    }

    public static func localizedShortLabel(
        for id: String?,
        prefersJapanese: Bool
    ) -> String {
        guard let entry = entry(for: id) else {
            return prefersJapanese ? "オフ" : "Off"
        }
        guard prefersJapanese else { return entry.shortLabel }
        switch entry.id {
        case "backlightVeil-1-8": return "控えめ"
        case "backlightVeil-1-4": return "標準"
        case "backlightVeil-1-2": return "強め"
        default: return entry.shortLabel
        }
    }

    public static func localizedDisplayName(
        for id: String?,
        prefersJapanese: Bool
    ) -> String {
        guard entry(for: id) != nil else { return featureName }
        return "\(featureName) - \(localizedShortLabel(for: id, prefersJapanese: prefersJapanese))"
    }
}
