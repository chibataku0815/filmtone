//
//  EditorExportStateModel.swift
//  FilmLabSwiftCore
//
//  Shared resolution rule for the export inspector's display phase. iOS
//  `FilmtoneExportPanel` and macOS `ExportInspectorPanel` previously each
//  encoded the canonical precedence
//      blocked > in-progress > finished > ready
//  in a parallel `if !violations.isEmpty / else if isExporting / else if
//  lastResult != nil / else` cascade with platform-specific field names.
//  M2.5 (Shared Editor Contract) lifts the precedence into one
//  resolver so both surfaces agree on the same rule and a future
//  precedence change (e.g. a fifth "queued" phase) lives in one place.
//
//  The resolver intentionally avoids carrying snapshot data because the
//  finished snapshot type differs between iOS (`EditorExportResult`) and
//  macOS (`ExportResultSnapshot`). The phase is a *display decision*; the
//  view layer fetches the matching snapshot from its own store.
//

import Foundation

/// Display phase of the export inspector. Resolved from a small set of
/// platform-neutral inputs by `FilmtoneExportStateResolver`. Order of
/// declaration matches precedence (highest priority first).
public enum FilmtoneExportPhase: Hashable, Sendable {
    /// One or more source-cap violations block the export entirely.
    case blocked(reasons: [String])
    /// An export is currently running.
    case inProgress
    /// The most recent export has finished and a result snapshot is
    /// available in the store.
    case finished
    /// No export is running and no recent result is pinned.
    case ready
}

public enum FilmtoneExportStateResolver {
    /// Resolve the current export phase using the canonical precedence:
    /// `blocked` > `inProgress` > `finished` > `ready`.
    ///
    /// - Parameters:
    ///   - sourceCapViolations: human-readable strings explaining why
    ///     export is blocked (empty when allowed).
    ///   - isExporting: `true` when an export task is currently running.
    ///   - hasFinishedResult: `true` when the store still holds a recent
    ///     export result the inspector should surface.
    public static func resolve(
        sourceCapViolations: [String],
        isExporting: Bool,
        hasFinishedResult: Bool
    ) -> FilmtoneExportPhase {
        if !sourceCapViolations.isEmpty {
            return .blocked(reasons: sourceCapViolations)
        }
        if isExporting {
            return .inProgress
        }
        if hasFinishedResult {
            return .finished
        }
        return .ready
    }
}
