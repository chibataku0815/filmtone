import CoreGraphics
import FilmLabSwiftCore
import Foundation

struct CompletedExport {
    let outputSize: CGSize
    let frameCount: Int
    let sourceDurationSec: Double?
    let audioPreserved: Bool
}

struct FilmtoneHighlightReelFrameTimeline {
    private struct Entry {
        let segmentIndex: Int
        let outputStartFrame: Int
        let frameCount: Int
        let sourceStartSec: Double
    }

    private let entries: [Entry]
    let totalFrameCount: Int
    let durationSec: Double
    private let outputFps: Int

    init?(segments: [FilmtoneHighlightClipSegment], outputFps: Int) {
        let fps = max(1, outputFps)
        var nextOutputStartFrame = 0
        var builtEntries: [Entry] = []
        for (index, segment) in segments.enumerated() where segment.durationSec > 0 {
            let frameCount = max(1, Int(floor(segment.durationSec * Double(fps) + 1e-6)))
            builtEntries.append(Entry(
                segmentIndex: index,
                outputStartFrame: nextOutputStartFrame,
                frameCount: frameCount,
                sourceStartSec: segment.sourceStartSec
            ))
            nextOutputStartFrame += frameCount
        }
        guard nextOutputStartFrame > 0 else {
            return nil
        }
        self.entries = builtEntries
        self.totalFrameCount = nextOutputStartFrame
        self.durationSec = Double(nextOutputStartFrame) / Double(fps)
        self.outputFps = fps
    }

    func sourceTimeSec(forOutputFrameIndex frameIndex: Int) -> Double? {
        guard let entry = entry(forOutputFrameIndex: frameIndex) else {
            return nil
        }
        let localFrame = max(0, frameIndex - entry.outputStartFrame)
        return entry.sourceStartSec + (Double(localFrame) / Double(outputFps))
    }

    func segmentIndex(forOutputFrameIndex frameIndex: Int) -> Int? {
        entry(forOutputFrameIndex: frameIndex)?.segmentIndex
    }

    private func entry(forOutputFrameIndex frameIndex: Int) -> Entry? {
        entries.first { entry in
            frameIndex >= entry.outputStartFrame
                && frameIndex < entry.outputStartFrame + entry.frameCount
        }
    }
}
