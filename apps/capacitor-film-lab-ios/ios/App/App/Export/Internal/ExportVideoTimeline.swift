import AVFoundation
import CoreMedia
import Foundation

/// Phase 2B-10B: pure video timeline / timing helpers lifted out of
/// `FilmtoneExportSession.exportVideo(...)`. Owns the output frame count,
/// output duration, output presentation time, source lookup time, source
/// segment index, source-time-offset normalization, per-sample timeline
/// time, and rendering progress math. The session keeps owning reader /
/// writer setup, dispatch queues, sample decode, lookahead selection,
/// frame append, audio append, completion / failure locks, and
/// `ExportVideoDepthMatcher` ownership.
///
/// `sourceTimeOffset` is set lazily from the first valid raw sample time
/// the session passes through `makeTimedSample(_:)` and exposed so the
/// depth matcher can align its lookup with the same offset. Highlight-reel
/// exports source `outputFrameCount` / `outputDurationSec` /
/// `sourceLookupTime` / `sourceSegmentIndex` from the supplied
/// `FilmtoneHighlightReelFrameTimeline`; full-clip exports fall back to
/// the asset's source duration and a 1:1 output→source timeline.
final class ExportVideoTimeline {
    struct TimedSample {
        let buffer: CMSampleBuffer
        let rawTime: CMTime
        let timelineTime: CMTime
    }

    private let highlightTimeline: FilmtoneHighlightReelFrameTimeline?
    private let outputFPS: Int
    let outputFrameCount: Int
    let outputDurationSec: Double
    private(set) var sourceTimeOffset: CMTime?

    init(
        highlightTimeline: FilmtoneHighlightReelFrameTimeline?,
        outputFPS: Int,
        sourceDurationSec: Double
    ) {
        self.highlightTimeline = highlightTimeline
        self.outputFPS = outputFPS
        self.outputFrameCount = highlightTimeline?.totalFrameCount ?? max(
            1,
            Int(floor((sourceDurationSec.isFinite ? sourceDurationSec : 0) * Double(outputFPS) + 1e-6))
        )
        self.outputDurationSec = highlightTimeline?.durationSec
            ?? (sourceDurationSec.isFinite ? sourceDurationSec : 0)
        self.sourceTimeOffset = nil
    }

    func outputPresentationTime(for frameIndex: Int) -> CMTime {
        CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(max(1, outputFPS)))
    }

    func sourceLookupTime(for frameIndex: Int) -> CMTime {
        guard let highlightTimeline,
              let sourceTimeSec = highlightTimeline.sourceTimeSec(forOutputFrameIndex: frameIndex) else {
            return outputPresentationTime(for: frameIndex)
        }
        return CMTime(seconds: sourceTimeSec, preferredTimescale: 60_000)
    }

    func sourceSegmentIndex(for frameIndex: Int) -> Int? {
        highlightTimeline?.segmentIndex(forOutputFrameIndex: frameIndex)
    }

    func makeTimedSample(_ sampleBuffer: CMSampleBuffer) -> TimedSample {
        let rawTime = ExportMediaWriter.validPresentationTime(for: sampleBuffer)
        if sourceTimeOffset == nil {
            sourceTimeOffset = rawTime
        }
        let timelineTime = ExportMediaWriter.nonNegativeTime(
            CMTimeSubtract(rawTime, sourceTimeOffset ?? .zero)
        )
        return TimedSample(buffer: sampleBuffer, rawTime: rawTime, timelineTime: timelineTime)
    }

    func renderingProgress(presentationTime: CMTime) -> Double {
        guard outputDurationSec.isFinite, outputDurationSec > 0 else {
            return 0.12
        }
        let presentationSec = CMTimeGetSeconds(presentationTime)
        guard presentationSec.isFinite else {
            return 0.12
        }
        let normalized = min(max(presentationSec / outputDurationSec, 0), 1)
        return 0.12 + (normalized * 0.74)
    }
}
