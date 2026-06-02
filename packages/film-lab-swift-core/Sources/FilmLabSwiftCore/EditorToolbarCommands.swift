//
//  EditorToolbarCommands.swift
//  FilmLabSwiftCore
//
//  Shared editor toolbar vocabulary for native Desktop and iPad.
//

import Foundation

/// Canonical editor toolbar commands shared by native Desktop and iPad.
///
/// The enum owns stable command identity, display label, icon, and platform
/// surface identifiers. Dispatch stays in each platform adapter because Desktop
/// routes through AppKit (`NSOpenPanel`, export coordinator, window toolbar
/// keyboard shortcuts) while iPad routes through SwiftUI touch affordances and
/// Photos / Files pickers.
public enum FilmtoneEditorToolbarCommand: String, CaseIterable, Identifiable, Sendable {
    case openSource
    case compare
    case export
    case inspector

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .openSource: return "Open"
        case .compare:    return "Compare"
        case .export:     return "Export"
        case .inspector:  return "Inspector"
        }
    }

    public var systemImage: String {
        switch self {
        case .openSource: return "folder"
        case .compare:    return "rectangle.split.2x1"
        case .export:     return "square.and.arrow.up"
        case .inspector:  return "sidebar.right"
        }
    }

    /// Stable cross-platform command identifier for analytics / future command
    /// routing. UI tests may still use platform-surface identifiers below.
    public var commandIdentifier: String {
        "filmtone.editor.toolbar.\(rawValue)"
    }

    /// Desktop `ToolbarItem(id:)` value. Keeps the existing macOS IDs stable
    /// while moving their ownership into the shared command vocabulary.
    public var desktopToolbarItemID: String {
        switch self {
        case .openSource: return "filmtone.toolbar.open"
        case .compare:    return "filmtone.toolbar.compare"
        case .export:     return "filmtone.toolbar.export"
        case .inspector:  return "filmtone.toolbar.sidebar"
        }
    }

    /// Existing iPad accessibility ID for the concrete toolbar surface.
    /// `openSource` intentionally returns the legacy `.source` suffix because
    /// the button replaces the current source.
    public var iPadAccessibilityIdentifier: String {
        switch self {
        case .openSource: return "filmtone.pad.toolbar.source"
        case .compare:    return "filmtone.pad.toolbar.compare"
        case .export:     return "filmtone.pad.toolbar.export"
        case .inspector:  return "filmtone.pad.toolbar.inspector"
        }
    }

}
