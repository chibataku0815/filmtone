import Foundation
import UIKit
import UserNotifications

/// Wave 2 / Stream B — completion Local Notification + success haptic.
///
/// Plan §6.6 SSoT. The controller is intentionally small: it only fires on
/// the success path of `FilmtoneMediaRuntime.runExport` (cancel and error
/// paths intentionally do *not* schedule a notification — the Live Activity
/// `.immediate` dismissal already conveys failure, and a notification on
/// cancel would feel like a buggy double-confirm).
///
/// Permission policy:
///   - Requested lazily on the first export attempt (`requestPermissionIfNeeded`).
///   - Options: `[.alert, .badge]` only — `sound = nil` per plan, the haptic
///     is the audible-equivalent feedback. Adding `.sound` would risk an
///     unwanted audible notification while the user is still inside the app.
///   - We never `throw` on denial: the export pipeline must keep working
///     even when notifications are off; the user simply will not get the
///     post-completion ping.
///
/// String policy:
///   - `export_complete_title` / `export_complete_body` are added to
///     `Localizable.xcstrings` by the concurrent Stream A. Until that lands,
///     `NSLocalizedString(value:)` falls back to the `defaultValue` we pass
///     here, so this file compiles and runs in isolation.
///
/// Identifier policy:
///   - `filmtone.export.{exportID}.completed` per plan §6.6, ensuring each
///     export gets a unique notification — repeat exports never coalesce
///     into a single notification on the lock screen.
@MainActor
final class FilmtoneExportNotification {
    static let shared = FilmtoneExportNotification()

    /// Tracks whether we have already prompted the user this app launch.
    /// Authorization status is the source of truth at runtime; this flag
    /// just avoids redundant `requestAuthorization` round-trips per session.
    private var permissionRequested = false

    private init() {}

    /// Request `[.alert, .badge]` permissions if we have not already asked
    /// this session. Safe to call from every export — short-circuits when
    /// already requested. Never throws to caller; logs and continues on error.
    func requestPermissionIfNeeded() async {
        guard !permissionRequested else { return }
        permissionRequested = true
        let center = UNUserNotificationCenter.current()
        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge])
        } catch {
            // Authorization failures are non-fatal — export must succeed
            // regardless of notification permission state.
        }
    }

    /// Schedule an immediate completion notification for the given export.
    /// `sound = nil` (haptic is the user-facing feedback); `interruptionLevel
    /// = .active` so the banner appears but does not break Focus modes
    /// the user has set up.
    func scheduleCompletionNotification(exportID: String) async {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString(
            "export_complete_title",
            value: "プリント完了",
            comment: "Title of the local notification posted when an export finishes."
        )
        content.body = NSLocalizedString(
            "export_complete_body",
            value: "Photos に納品しました",
            comment: "Body of the local notification posted when an export finishes."
        )
        content.sound = nil
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .active
        }

        let request = UNNotificationRequest(
            identifier: "filmtone.export.\(exportID).completed",
            content: content,
            trigger: nil
        )

        let center = UNUserNotificationCenter.current()
        do {
            try await center.add(request)
        } catch {
            // Posting failures are non-fatal — silent skip.
        }
    }

    /// Fire `.success` haptic feedback. Must be on the main actor because
    /// `UINotificationFeedbackGenerator` requires the main thread.
    func triggerSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
