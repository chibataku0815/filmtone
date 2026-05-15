import Foundation
import FilmLabSwiftCore

// M5-C.4: persisted result snapshot for the Export Inspector finished
// state. Stored on `EditorState.lastExportResult` and reset by either
// `resetExportResult()` (Export Again) or the next `setSource(...)`.
//
// `processedFrames` is `nil` for stills; videos populate it from
// `FilmtoneVideoExportResult.processedFrames`. `fileSizeBytes` is read
// post-export via `FileManager.attributesOfItem(atPath:)` so the
// inspector can show the actual on-disk size (which may differ from
// pixel count × bpp once codecs are involved).

struct ExportResultSnapshot: Equatable {
    let outputURL: URL
    let sidecarURL: URL?
    let pixelWidth: Int
    let pixelHeight: Int
    let processedFrames: Int?
    let fileSizeBytes: Int64
    let elapsedSeconds: Double
    let sourceKind: FilmtoneSourceKind
    let videoTimingMode: FilmtoneVideoTimingMode?
    let outputFrameRate: Int?
}

enum FilmtoneFormatters {
    /// Human-readable file size (B / KB / MB / GB) using 1024-base units.
    /// Matches the convention `FileManager.attributesOfItem` returns
    /// (binary bytes). 0 → "0 B"; 1024 → "1.0 KB"; 1.5 MB → "1.5 MB".
    static func formattedFileSize(_ bytes: Int64) -> String {
        let absBytes = bytes < 0 ? 0 : bytes
        let units: [(label: String, divisor: Double)] = [
            ("GB", 1024 * 1024 * 1024),
            ("MB", 1024 * 1024),
            ("KB", 1024),
        ]
        for unit in units where Double(absBytes) >= unit.divisor {
            let value = Double(absBytes) / unit.divisor
            return String(format: "%.1f %@", value, unit.label)
        }
        return "\(absBytes) B"
    }

    /// Human-readable elapsed seconds.
    /// 0 → "0.0s"; 12.4 → "12.4s"; 90 → "1m 30s"; 3661 → "1h 01m 01s".
    static func formattedElapsed(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }
        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, secs)
        }
        return String(format: "%dm %02ds", minutes, secs)
    }

    /// JPEG quality clamp. Mirrors `EditorState.jpegQuality`'s didSet so
    /// pure callers can clamp without an EditorState instance.
    static func clampedJpegQuality(_ value: Double) -> Double {
        min(1.0, max(0.5, value))
    }
}
