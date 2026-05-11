import AVFoundation
import FilmLabSwiftCore
import Foundation

struct ExportAudioCompletionValidation {
    let sourceAudioTrackCount: Int
    let effectiveVideoAudioTrackCount: Int
    let outputAudioTrackCount: Int
    let audioPreserved: Bool
    let failureReason: String?
}

struct ExportAudioSampleStats {
    let samples: Int
    let firstPTS: Double?
    let lastPTS: Double?
}

final class ExportAudioSampleStatsTracker {
    private let lock = NSLock()
    private var samples = 0
    private var firstPTS: Double?
    private var lastPTS: Double?

    func record(_ sampleBuffer: CMSampleBuffer) {
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let seconds = pts.isValid && pts.isNumeric ? CMTimeGetSeconds(pts) : nil
        lock.lock()
        samples += 1
        if firstPTS == nil, let seconds, seconds.isFinite {
            firstPTS = seconds
        }
        if let seconds, seconds.isFinite {
            lastPTS = seconds
        }
        lock.unlock()
    }

    func snapshot() -> ExportAudioSampleStats {
        lock.lock()
        defer { lock.unlock() }
        return ExportAudioSampleStats(samples: samples, firstPTS: firstPTS, lastPTS: lastPTS)
    }
}

enum ExportAudioCompletionValidator {
    static func validate(
        sourceAsset: AVAsset,
        effectiveVideoAsset: AVAsset,
        outputURL: URL,
        preserveAudioRequested: Bool,
        highlightTimelinePresent: Bool
    ) -> ExportAudioCompletionValidation {
        let sourceAudioTrackCount = sourceAsset.tracks(withMediaType: .audio).count
        let effectiveVideoAudioTrackCount = effectiveVideoAsset.tracks(withMediaType: .audio).count
        let outputAsset = AVURLAsset(url: outputURL)
        let outputAudioTrackCount = outputAsset.tracks(withMediaType: .audio).count

        guard preserveAudioRequested, !highlightTimelinePresent else {
            return .init(
                sourceAudioTrackCount: sourceAudioTrackCount,
                effectiveVideoAudioTrackCount: effectiveVideoAudioTrackCount,
                outputAudioTrackCount: outputAudioTrackCount,
                audioPreserved: false,
                failureReason: nil
            )
        }
        guard sourceAudioTrackCount > 0 else {
            return .init(
                sourceAudioTrackCount: sourceAudioTrackCount,
                effectiveVideoAudioTrackCount: effectiveVideoAudioTrackCount,
                outputAudioTrackCount: outputAudioTrackCount,
                audioPreserved: false,
                failureReason: nil
            )
        }

        let preserved = outputAudioTrackCount > 0
        return .init(
            sourceAudioTrackCount: sourceAudioTrackCount,
            effectiveVideoAudioTrackCount: effectiveVideoAudioTrackCount,
            outputAudioTrackCount: outputAudioTrackCount,
            audioPreserved: preserved,
            failureReason: preserved ? nil : "completed-output-missing-audio-track"
        )
    }
}

struct ExportAudioDiagnostics: Codable {
    let createdAtIso: String
    let sourceURL: String
    let effectiveVideoURL: String
    let outputURL: String
    let preserveAudioRequested: Bool
    let highlightTimelinePresent: Bool
    let mezzanineVariant: String?
    let sourceAudioTrackCount: Int
    let effectiveVideoAudioTrackCount: Int
    let outputAudioTrackCount: Int
    let audioReaderStarted: Bool
    let audioSamplesAppended: Int
    let firstAudioPTS: Double?
    let lastAudioPTS: Double?
    let audioPreserved: Bool
    let failureReason: String?

    init(
        createdAt: Date = Date(),
        sourceURL: URL,
        effectiveVideoURL: URL,
        outputURL: URL,
        preserveAudioRequested: Bool,
        highlightTimelinePresent: Bool,
        mezzanineVariant: ProfileVariant?,
        validation: ExportAudioCompletionValidation,
        audioReaderStarted: Bool,
        sampleStats: ExportAudioSampleStats
    ) {
        self.createdAtIso = ISO8601DateFormatter().string(from: createdAt)
        self.sourceURL = sourceURL.absoluteString
        self.effectiveVideoURL = effectiveVideoURL.absoluteString
        self.outputURL = outputURL.absoluteString
        self.preserveAudioRequested = preserveAudioRequested
        self.highlightTimelinePresent = highlightTimelinePresent
        self.mezzanineVariant = mezzanineVariant?.rawValue
        self.sourceAudioTrackCount = validation.sourceAudioTrackCount
        self.effectiveVideoAudioTrackCount = validation.effectiveVideoAudioTrackCount
        self.outputAudioTrackCount = validation.outputAudioTrackCount
        self.audioReaderStarted = audioReaderStarted
        self.audioSamplesAppended = sampleStats.samples
        self.firstAudioPTS = sampleStats.firstPTS
        self.lastAudioPTS = sampleStats.lastPTS
        self.audioPreserved = validation.audioPreserved
        self.failureReason = validation.failureReason
    }

    var summary: String {
        let status = audioPreserved ? "preserved" : "not-preserved"
        return "src=\(sourceAudioTrackCount) eff=\(effectiveVideoAudioTrackCount) out=\(outputAudioTrackCount) samples=\(audioSamplesAppended) \(status)"
    }

    var sidecarDiagnostics: SidecarAudioDiagnostics {
        SidecarAudioDiagnostics(
            createdAtIso: createdAtIso,
            sourceURL: sourceURL,
            effectiveVideoURL: effectiveVideoURL,
            outputURL: outputURL,
            preserveAudioRequested: preserveAudioRequested,
            highlightTimelinePresent: highlightTimelinePresent,
            mezzanineVariant: mezzanineVariant,
            sourceAudioTrackCount: sourceAudioTrackCount,
            effectiveVideoAudioTrackCount: effectiveVideoAudioTrackCount,
            outputAudioTrackCount: outputAudioTrackCount,
            audioReaderStarted: audioReaderStarted,
            audioSamplesAppended: audioSamplesAppended,
            firstAudioPTS: firstAudioPTS,
            lastAudioPTS: lastAudioPTS,
            audioPreserved: audioPreserved,
            failureReason: failureReason
        )
    }

    func writeLatest() -> URL? {
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let directory = documents.appendingPathComponent("FilmtoneAudioDiagnostics", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("latest-export-audio.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self)
            try data.write(to: url, options: [.atomic])
            NSLog("[FilmtoneAudioDebug] wrote %@ summary=%@", url.path, summary)
            return url
        } catch {
            NSLog("[FilmtoneAudioDebug] diagnostic write failed: %@", error.localizedDescription)
            return nil
        }
    }
}
