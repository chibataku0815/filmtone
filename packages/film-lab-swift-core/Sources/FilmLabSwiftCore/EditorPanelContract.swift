//
//  EditorPanelContract.swift
//  FilmLabSwiftCore
//
//  Shared definition of the editor inspector's panel set and the canonical
//  panel order across platforms. iPad workspace and Desktop right rail
//  both mount Source → Look → Adjust → Export in this order; M2.5 (Shared
//  Editor Contract) lifts that fact into FilmLabSwiftCore so the order is
//  no longer encoded twice in parallel UI files.
//
//  Adding a new panel means appending to `canonicalOrder` here and
//  handling the new case in each platform's panel factory.
//

import Foundation

/// Identifies the four canonical editor inspector panels.
public enum FilmtoneEditorPanelID: String, CaseIterable, Hashable, Sendable, Identifiable {
    case source
    case look
    case adjust
    case export

    public var id: String { rawValue }

    /// Stable English title used in accessibility identifiers, debug
    /// logs, and analytics. Localized headings stay platform-specific.
    public var debugTitle: String {
        switch self {
        case .source: return "Source"
        case .look:   return "Look"
        case .adjust: return "Adjust"
        case .export: return "Export"
        }
    }
}

public enum FilmtoneEditorPanelContract {
    /// Canonical panel order used by both Desktop and iPad inspectors.
    public static let canonicalOrder: [FilmtoneEditorPanelID] = [
        .source,
        .look,
        .adjust,
        .export,
    ]
}
