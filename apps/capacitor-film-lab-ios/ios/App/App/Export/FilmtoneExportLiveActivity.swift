import ActivityKit
import Foundation
import UIKit

/// Wave 1 / Stream W1-C — App-side Live Activity controller.
///
/// Owns the `Activity<FilmtoneExportAttributes>` for the lifetime of a single
/// `FilmtoneMediaRuntime.runExport` invocation. The Widget Extension renders
/// the lock-screen / Dynamic Island UI from the `ContentState` updates this
/// controller pushes via `Activity.update`.
///
/// Throttle policy (plan §6.3 SSoT — exact thresholds, do not tune):
///   - emit when `>= 1.0 s` since last update, OR
///   - emit when `|progress - lastProgress| >= 0.05`, OR
///   - emit when `stage` differs from last-emitted stage.
///
/// All three short-circuit; `progress` deltas under 5 % within 1 s are dropped
/// to avoid budget pressure on the Live Activity update channel.
///
/// Naming note: the type lives in this file but is namespaced as a Controller
/// to avoid colliding with the Widget-side `FilmtoneExportActivityWidget`
/// Widget struct (the WidgetKit configuration entry point).
@available(iOS 16.2, *)
final class FilmtoneExportLiveActivityController {
    static let shared = FilmtoneExportLiveActivityController()

    private var activity: Activity<FilmtoneExportAttributes>?
    private var lastUpdateAt: Date = .distantPast
    private var lastUpdateProgress: Double = 0
    private var lastUpdateStage: String = ""

    private init() {}

    func start(
        attributes: FilmtoneExportAttributes,
        initialState: FilmtoneExportAttributes.ContentState
    ) async {
        // Apple eligibility gate. If the user has globally disabled Live
        // Activities (Settings → Face ID & Passcode → Live Activities, or
        // per-app toggle), `areActivitiesEnabled` is false and `request`
        // would throw `.unsupported`. Return silently — export must still
        // succeed without a Live Activity.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Idempotent: repeated start within the same export is a no-op.
        guard activity == nil else { return }
        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            lastUpdateAt = Date()
            lastUpdateProgress = initialState.progress
            lastUpdateStage = initialState.stage
        } catch {
            // ActivityAuthorizationError.denied / .globalMaximumExceeded /
            // .unsupportedTarget — silent fallback. Export pipeline must
            // not surface this; the WebView UI keeps its own progress bar.
            activity = nil
        }
    }

    func receive(progress: FilmtoneExportAttributes.ContentState) async {
        guard let activity = activity else { return }
        let now = Date()
        let progressDelta = abs(progress.progress - lastUpdateProgress)
        let stageChanged = progress.stage != lastUpdateStage
        let timePassed = now.timeIntervalSince(lastUpdateAt) >= 1.0
        guard stageChanged || progressDelta >= 0.05 || timePassed else { return }

        let content = ActivityContent(state: progress, staleDate: nil)
        await activity.update(content)
        lastUpdateAt = now
        lastUpdateProgress = progress.progress
        lastUpdateStage = progress.stage
    }

    func end(
        success: Bool,
        finalState: FilmtoneExportAttributes.ContentState? = nil
    ) async {
        guard let activity = activity else { return }
        let policy: ActivityUIDismissalPolicy = success ? .default : .immediate
        if let finalState = finalState {
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: policy)
        } else {
            await activity.end(nil, dismissalPolicy: policy)
        }
        self.activity = nil
        lastUpdateAt = .distantPast
        lastUpdateProgress = 0
        lastUpdateStage = ""
    }
}
