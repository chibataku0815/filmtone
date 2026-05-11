import AVFoundation
import CoreMedia
import Foundation

/// Phase 2B-10A: per-frame video depth-frame matching state machine lifted
/// out of `FilmtoneExportSession.exportVideo(...)`. Owns the depth reader
/// cursor (`lastDepthFrame` / `pendingDepthFrame` / `readerExhausted`) and
/// the pull loop that advances pending frames while
/// `pendingDepthFrame.presentationTime <= lookupTime`. The matcher reports
/// the matched depth map (most recent depth frame whose pts is less than or
/// equal to the lookup time) and the decode wall-clock time per call so the
/// session keeps owning `loadedDepthMap`, `videoDepthDecodeMs`,
/// `videoDepthFramesProcessed`, `depthResolution`, and
/// `videoDepthSourceLabel` telemetry on `FilmtoneExportSession`.
///
/// Mid-stream `ExportDepthPayloadManager.pullNextFrame` failure logs the
/// same debug line as the pre-extraction in-place loop, clears the pending
/// frame, marks the reader exhausted, and keeps `lastDepthFrame` so the
/// remainder of the export degrades gracefully to last-known depth instead
/// of dropping depth entirely. End-of-stream takes the same path without
/// logging.
final class ExportVideoDepthMatcher {
    struct MatchResult {
        let depthMap: FilmtoneDepthMap?
        let decodeMs: Double
    }

    private let reader: VideoDepthFrameReader?
    private var lastDepthFrame: (presentationTime: CMTime, depthMap: FilmtoneDepthMap)?
    private var pendingDepthFrame: (presentationTime: CMTime, depthMap: FilmtoneDepthMap)?
    private var readerExhausted: Bool

    init(reader: VideoDepthFrameReader?) {
        self.reader = reader
        self.lastDepthFrame = nil
        self.pendingDepthFrame = nil
        self.readerExhausted = (reader == nil)
    }

    var hasReader: Bool { reader != nil }

    func cancel() {
        reader?.cancel()
    }

    func matchDepthFrame(
        for sourceLookupTime: CMTime,
        sourceTimeOffset: CMTime?
    ) -> MatchResult {
        guard let reader else {
            return MatchResult(depthMap: nil, decodeMs: 0)
        }
        let lookupTime = CMTimeAdd(sourceLookupTime, sourceTimeOffset ?? .zero)
        let decodeStart = Date()
        // Advance until pendingDepthFrame.pts > current output pts (or EOS).
        // The rendered video sample is resampled to the 24 fps output
        // timeline, so depth follows that same output timeline rather than
        // the original source-frame cadence.
        while !readerExhausted,
              pendingDepthFrame == nil
                || CMTimeCompare(pendingDepthFrame!.presentationTime, lookupTime) <= 0 {
            if let pf = pendingDepthFrame {
                lastDepthFrame = pf
            }
            switch ExportDepthPayloadManager.pullNextFrame(reader: reader) {
            case .frame(let next):
                pendingDepthFrame = next
            case .endOfStream:
                pendingDepthFrame = nil
                readerExhausted = true
            case .failure(let error):
                NSLog("FilmtoneExportSession: video depth frame pull failed: \(error). Continuing without depth for remaining frames.")
                pendingDepthFrame = nil
                readerExhausted = true
            }
        }
        let decodeMs = Date().timeIntervalSince(decodeStart) * 1000.0
        return MatchResult(depthMap: lastDepthFrame?.depthMap, decodeMs: decodeMs)
    }
}
