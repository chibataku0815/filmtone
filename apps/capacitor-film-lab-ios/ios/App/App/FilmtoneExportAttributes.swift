import ActivityKit
import Foundation

/// Live Activity attributes for Filmtone export progress.
///
/// Compiled into both the App target (for `Activity<FilmtoneExportAttributes>.request`)
/// and the FilmtoneExportActivity Widget Extension (for `ActivityConfiguration`).
///
/// `ContentState` updates flow through the App-side throttle layer
/// (``FilmtoneExportLiveActivityController``) — clients never call `Activity.update`
/// directly with a raw progress DTO.
struct FilmtoneExportAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var stage: String              // "preflight" | "rendering" | "writing" | "completed" | "failed"
        public var progress: Double           // 0.0 - 1.0
        public var currentFrame: Int?
        public var totalFrames: Int?
        public var mode: String               // "Postcard" | "Master"
        public var elapsedSeconds: TimeInterval
        public var estimatedRemainingSeconds: TimeInterval?

        public init(
            stage: String,
            progress: Double,
            currentFrame: Int? = nil,
            totalFrames: Int? = nil,
            mode: String,
            elapsedSeconds: TimeInterval,
            estimatedRemainingSeconds: TimeInterval? = nil
        ) {
            self.stage = stage
            self.progress = progress
            self.currentFrame = currentFrame
            self.totalFrames = totalFrames
            self.mode = mode
            self.elapsedSeconds = elapsedSeconds
            self.estimatedRemainingSeconds = estimatedRemainingSeconds
        }
    }

    public var sourceFileName: String
    public var startedAt: Date

    public init(sourceFileName: String, startedAt: Date) {
        self.sourceFileName = sourceFileName
        self.startedAt = startedAt
    }
}
