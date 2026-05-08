import Foundation

/// Reasons an export can be cancelled. Recorded for telemetry / debugging.
///
/// Entry points (v1.3 = 3, v1.4 candidate adds BGContinuedProcessingTask):
///   - `userViaUI`: SwiftUI UI → `FilmtoneEditorStore.cancelExport()`
///   - `userViaLiveActivity`: Live Activity Cancel button → `CancelExportIntent.perform`
///   - `backgroundTaskExpiration`: `UIApplication.beginBackgroundTask` expirationHandler
///     (writing-tail protection)
public enum ExportCancelReason: String {
    case userViaUI
    case userViaLiveActivity
    case backgroundTaskExpiration
}

/// Abstract handle the actor cancels through. Allows ``ExportCancelController``
/// to compile in both the App target and the FilmtoneExportActivity Widget Extension
/// without dragging the App-only ``FilmtoneExportSession`` symbol into Widget binary.
/// The concrete conformance lives in `FilmtoneExportSession+Cancelable.swift` (App only).
public protocol ExportCancelable: AnyObject {
    func cancel()
}

/// Single source of truth for export cancellation across all entry points.
///
/// The actor guarantees:
///   - ``cancel(reason:)`` is idempotent — only the first invocation propagates
///     to the attached session; later invocations are no-ops.
///   - ``attach(_:)`` / ``detach()`` / ``cancel(reason:)`` are serialized, so
///     the three-way race (WebView UI / Live Activity intent / background-task
///     expiration) cannot double-cancel or write to a stale session reference.
///
/// The reference to the session is `weak` to avoid extending its lifetime
/// beyond the runtime's local export-session handle. ``detach()`` is called
/// from the runtime in success/error paths for predictability; the weak ref
/// would clear on its own otherwise.
public actor ExportCancelController {
    public static let shared = ExportCancelController()

    private weak var currentSession: ExportCancelable?
    private(set) public var isCancelled = false
    private(set) public var lastCancelReason: ExportCancelReason?

    public func attach(_ session: ExportCancelable) {
        currentSession = session
        isCancelled = false
        lastCancelReason = nil
    }

    public func detach() {
        currentSession = nil
    }

    public func cancel(reason: ExportCancelReason) {
        guard !isCancelled else { return }
        isCancelled = true
        lastCancelReason = reason
        currentSession?.cancel()
    }
}
