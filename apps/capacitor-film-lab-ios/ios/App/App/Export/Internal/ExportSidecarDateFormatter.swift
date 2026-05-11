import Foundation

extension ISO8601DateFormatter {
    /// Shared formatter used by the export sidecar writer. Configured to emit
    /// millisecond-precision UTC stamps (e.g. `2026-04-24T12:00:00.000Z`).
    static let filmtoneSidecar: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
