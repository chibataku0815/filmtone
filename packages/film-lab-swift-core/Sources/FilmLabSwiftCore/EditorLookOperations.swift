//
//  EditorLookOperations.swift
//  FilmLabSwiftCore
//
//  Shared vocabulary for the saved-Look operations every editor surface
//  supports. iPad inspector and Desktop right rail dispatch the same
//  conceptual operations (apply / clear / toggleFavorite / rename /
//  delete / saveCurrent) but route them through platform-appropriate
//  affordances — iOS uses sheets and context menus; macOS uses
//  `NSAlert` / `NSTextField`. M2.5 (Shared Editor Contract) lifts the
//  *set* of operations into one place so adding a new Look operation
//  means appending a case here and handling it on both platforms,
//  rather than reasoning about two parallel UI files.
//
//  Implementation note: this file is intentionally a value-type
//  vocabulary, not a state-bridging protocol. iOS' `FilmtoneEditorStore`
//  and macOS' `EditorState`/`LibraryViewModel` continue to expose their
//  own typed methods. UI surfaces consume the enum for accessibility
//  identifiers and analytics labels so the operation set is enumerable
//  in one place; the actual dispatch stays platform-typed.
//

import Foundation

/// Canonical set of saved-Look operations the editor inspector exposes.
public enum FilmtoneLookOperation: String, CaseIterable, Hashable, Sendable, Identifiable {
    case apply
    case clear
    case toggleFavorite
    case rename
    case delete
    case saveCurrent

    public var id: String { rawValue }

    /// Stable accessibility / analytics identifier. Platform UI uses
    /// this so the iPad chip context menu and the Desktop library action
    /// row tag the same operation with the same string.
    public var accessibilityIdentifier: String {
        "filmtone.editor.look.\(rawValue)"
    }

    /// Whether the operation targets a specific saved Look. UI uses this
    /// to decide whether a context-menu entry / row button is enabled
    /// when no Look is selected.
    public var requiresTargetEntry: Bool {
        switch self {
        case .apply, .toggleFavorite, .rename, .delete:
            return true
        case .clear, .saveCurrent:
            return false
        }
    }

    /// Whether the operation mutates the saved-Look library on disk.
    /// Used for telemetry and confirmation copy.
    public var mutatesLibrary: Bool {
        switch self {
        case .rename, .delete, .saveCurrent, .toggleFavorite:
            return true
        case .apply, .clear:
            return false
        }
    }

    /// Whether the operation is allowed on bundled / immutable entries
    /// (Stone / Urban / Noir). Bundled entries refuse rename and delete
    /// at the actor layer; UI greys them out using this flag.
    public var allowedOnImmutable: Bool {
        switch self {
        case .apply, .toggleFavorite, .clear, .saveCurrent:
            return true
        case .rename, .delete:
            return false
        }
    }

    /// SF Symbol name used across iPad and macOS surfaces for this
    /// operation. Lifting the icon vocabulary into the shared enum
    /// means a new operation lands in one place and both surfaces pick
    /// up a consistent visual (M7 Drift Guard rule: "shared Core
    /// symbol is consumed by both Desktop and iPad in the same
    /// milestone").
    public var systemImage: String {
        switch self {
        case .apply:          return "checkmark.circle"
        case .clear:          return "circle.dashed"
        case .toggleFavorite: return "star"
        case .rename:         return "pencil"
        case .delete:         return "trash"
        case .saveCurrent:    return "square.and.arrow.down"
        }
    }

    /// SF Symbol variant used when the operation's current state is the
    /// "active" face. For `toggleFavorite` this is the filled star;
    /// other operations have no active face and return `systemImage`.
    public func systemImage(isActive: Bool) -> String {
        switch self {
        case .toggleFavorite: return isActive ? "star.fill" : "star"
        default:              return systemImage
        }
    }

    /// Whether the operation belongs in a per-entry context menu
    /// (vs a global library action row that targets the currently
    /// selected entry). Today the only operations *not* in an
    /// entry-context menu are `clear` (no entry to act on) and
    /// `saveCurrent` (acts on editor state, not a library row).
    public var isEntryContextOperation: Bool {
        switch self {
        case .apply, .toggleFavorite, .rename, .delete:
            return true
        case .clear, .saveCurrent:
            return false
        }
    }

    /// Whether the operation is selectable given the target context.
    ///
    /// - Parameters:
    ///   - hasTargetEntry: `true` when a saved-Look row is selected /
    ///     under the cursor.
    ///   - entryImmutable: `true` when the target is a bundled /
    ///     immutable Look (Stone / Urban / Noir).
    ///
    /// Returns `false` for operations that require a target when
    /// `hasTargetEntry == false`, and `false` for operations that are
    /// not `allowedOnImmutable` when the target is immutable.
    public func isAvailable(
        hasTargetEntry: Bool,
        entryImmutable: Bool
    ) -> Bool {
        if requiresTargetEntry && !hasTargetEntry {
            return false
        }
        if !allowedOnImmutable && entryImmutable {
            return false
        }
        return true
    }

    /// Subset of operations that appear in a per-entry context menu in
    /// canonical order (`apply` → `toggleFavorite` → `rename` →
    /// `delete`). Surfaces iterate this so adding a new context-menu
    /// operation means appending here once.
    public static let contextMenuOperations: [FilmtoneLookOperation] = [
        .apply,
        .toggleFavorite,
        .rename,
        .delete,
    ]

    /// Subset of operations that appear in the Desktop library-action
    /// row (per-selected-entry buttons without `apply`, which is
    /// expressed via the picker selection itself). Canonical order is
    /// favorite → rename → delete.
    public static let libraryActionRowOperations: [FilmtoneLookOperation] = [
        .toggleFavorite,
        .rename,
        .delete,
    ]
}

/// Canonical Look-panel continuous controls shared by Desktop and iPad.
///
/// Desktop currently exposes `strength` in the Look library rail; iPad exposes
/// `strength` plus `creativeLutIntensity` because imported creative LUTs are an
/// iPad output/input adapter. The control identity, range, and stable surface
/// identifiers live here so the panel does not drift into hand-owned iPad or
/// Desktop vocabulary.
public enum FilmtoneLookControlID: String, CaseIterable, Hashable, Sendable, Identifiable {
    case strength
    case creativeLutIntensity

    public var id: String { rawValue }

    public var defaultLabel: String {
        switch self {
        case .strength:             return "Strength"
        case .creativeLutIntensity: return "Look Intensity"
        }
    }

    public var range: ClosedRange<Double> {
        0...1
    }

    public var commandIdentifier: String {
        "filmtone.editor.look.control.\(rawValue)"
    }

    public var desktopAccessibilityIdentifier: String {
        switch self {
        case .strength:             return "filmtone.desktop.look.strength"
        case .creativeLutIntensity: return "filmtone.desktop.look.intensity"
        }
    }

    public var iPadValueAccessibilityIdentifier: String {
        switch self {
        case .strength:             return "filmtone.pad.inspector.look.strength.value"
        case .creativeLutIntensity: return "filmtone.pad.inspector.look.intensity.value"
        }
    }

    public var iPadSliderAccessibilityIdentifier: String {
        switch self {
        case .strength:             return "filmtone.pad.inspector.look.strength.slider"
        case .creativeLutIntensity: return "filmtone.pad.inspector.look.intensity.slider"
        }
    }

    public static let desktopInlineControls: [FilmtoneLookControlID] = [
        .strength,
    ]

    public static let iPadInlineControls: [FilmtoneLookControlID] = [
        .creativeLutIntensity,
        .strength,
    ]
}
