import ActivityKit
import SwiftUI
import WidgetKit

/// Widget Extension entry point. Hosts the Live Activity widget(s).
@main
struct FilmtoneExportActivityBundle: WidgetBundle {
    var body: some Widget {
        FilmtoneExportActivityWidget()
    }
}

/// Live Activity widget configuration.
/// Wave 1 / Stream W1-B fills the lock screen body and the DynamicIsland regions.
@available(iOS 17.0, *)
struct FilmtoneExportActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FilmtoneExportAttributes.self) { context in
            LockScreenView(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandViews.expandedLeading(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DynamicIslandViews.expandedTrailing(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    DynamicIslandViews.expandedCenter(state: context.state, attributes: context.attributes)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandViews.expandedBottom(state: context.state)
                }
            } compactLeading: {
                DynamicIslandViews.compactLeading(state: context.state)
            } compactTrailing: {
                DynamicIslandViews.compactTrailing(state: context.state)
            } minimal: {
                DynamicIslandViews.minimal(state: context.state)
            }
        }
    }
}
