import AVFoundation
import CoreMedia
import Foundation
import os

/// Phase 2B-10C: video export queue body owner lifted out of
/// `FilmtoneExportSession.exportVideo(...)`. Owns the per-call video
/// sample state (`previousVideoSample`, `lookaheadVideoSample`,
/// `sourceReaderExhausted`), the per-call output frame loop index
/// (`nextOutputFrameIndex`), the rendered-frame counter
/// (`renderedFrames`), and the per-frame progress emission cadence.
/// The session keeps owning `appendOutputFrame(...)`, depth preparation,
/// motion blur reset, render, frame append ordering, and the audio
/// queue (which lives in `ExportVideoAudioPump`).
///
/// Sample-selection rule preserved verbatim from the inline body:
/// 1. decode the first sample into `previousVideoSample`
/// 2. when source is not yet exhausted and lookahead is missing, decode
///    the next sample into `lookaheadVideoSample`
/// 3. compare `previous.timelineTime` and `lookahead.timelineTime` to
///    `timeline.sourceLookupTime(for:)` and choose the nearer sample by
///    `ExportMediaWriter.absoluteSecondsBetween`
/// 4. when the source reader is exhausted, keep using the last
///    `previousVideoSample`
///
/// Progress cadence: emit on the first rendered frame and every 12th
/// rendered frame after, computed from the output presentation time
/// the frame was appended at.
final class ExportVideoFramePump {
    struct AppendRequest {
        let sample: ExportVideoTimeline.TimedSample
        let outputPresentationTime: CMTime
        let sourceLookupTime: CMTime
        let sourceSegmentIndex: Int?
    }

    private let videoInput: AVAssetWriterInput
    private let videoOutput: AVAssetReaderTrackOutput
    private let reader: AVAssetReader
    private let videoQueue: DispatchQueue
    private let timeline: ExportVideoTimeline
    private let completion: ExportVideoCompletionCoordinator
    private let performanceMetrics: FilmtoneExportPerformanceMetrics
    private let signposter: OSSignposter

    private var previousVideoSample: ExportVideoTimeline.TimedSample?
    private var lookaheadVideoSample: ExportVideoTimeline.TimedSample?
    private var sourceReaderExhausted = false
    private var nextOutputFrameIndex = 0
    private(set) var renderedFrames = 0

    init(
        videoInput: AVAssetWriterInput,
        videoOutput: AVAssetReaderTrackOutput,
        reader: AVAssetReader,
        videoQueue: DispatchQueue,
        timeline: ExportVideoTimeline,
        completion: ExportVideoCompletionCoordinator,
        performanceMetrics: FilmtoneExportPerformanceMetrics,
        signposter: OSSignposter
    ) {
        self.videoInput = videoInput
        self.videoOutput = videoOutput
        self.reader = reader
        self.videoQueue = videoQueue
        self.timeline = timeline
        self.completion = completion
        self.performanceMetrics = performanceMetrics
        self.signposter = signposter
    }

    func start(
        progress: @escaping (Phase0ExportProgressDTO) -> Void,
        checkCancelled: @escaping () throws -> Void,
        appendFrame: @escaping (AppendRequest) throws -> Void
    ) {
        videoInput.requestMediaDataWhenReady(on: videoQueue) { [self] in
            while videoInput.isReadyForMoreMediaData {
                if completion.hasCapturedError {
                    completion.finishVideoInput(markAsFinished: true)
                    return
                }

                do {
                    try checkCancelled()
                    guard nextOutputFrameIndex < timeline.outputFrameCount else {
                        completion.finishVideoInput(markAsFinished: true)
                        return
                    }

                    if previousVideoSample == nil {
                        let decodedSample = performanceMetrics.measure(.decode) {
                            signposter.withIntervalSignpost("decode") {
                                videoOutput.copyNextSampleBuffer()
                            }
                        }
                        guard let sampleBuffer = decodedSample else {
                            if reader.status == .failed {
                                throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "Video read failed.")
                            }
                            completion.finishVideoInput(markAsFinished: true)
                            return
                        }
                        previousVideoSample = timeline.makeTimedSample(sampleBuffer)
                        continue
                    }

                    if !sourceReaderExhausted && lookaheadVideoSample == nil {
                        let decodedSample = performanceMetrics.measure(.decode) {
                            signposter.withIntervalSignpost("decode") {
                                videoOutput.copyNextSampleBuffer()
                            }
                        }
                        guard let sampleBuffer = decodedSample else {
                            if reader.status == .failed {
                                throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "Video read failed.")
                            }
                            sourceReaderExhausted = true
                            continue
                        }
                        lookaheadVideoSample = timeline.makeTimedSample(sampleBuffer)
                        continue
                    }

                    if let lookahead = lookaheadVideoSample {
                        let outputTime = timeline.outputPresentationTime(for: nextOutputFrameIndex)
                        let sourceTime = timeline.sourceLookupTime(for: nextOutputFrameIndex)
                        if CMTimeCompare(sourceTime, lookahead.timelineTime) < 0 {
                            guard let previous = previousVideoSample else {
                                throw FilmtoneMediaError.exportFailed("The first decoded video frame was unavailable.")
                            }
                            let previousDelta = ExportMediaWriter.absoluteSecondsBetween(
                                previous.timelineTime,
                                sourceTime
                            )
                            let lookaheadDelta = ExportMediaWriter.absoluteSecondsBetween(
                                lookahead.timelineTime,
                                sourceTime
                            )
                            let selectedSample = previousDelta <= lookaheadDelta ? previous : lookahead
                            try appendFrame(AppendRequest(
                                sample: selectedSample,
                                outputPresentationTime: outputTime,
                                sourceLookupTime: sourceTime,
                                sourceSegmentIndex: timeline.sourceSegmentIndex(for: nextOutputFrameIndex)
                            ))
                            recordAppendedFrame(at: outputTime, progress: progress)
                        } else {
                            previousVideoSample = lookahead
                            lookaheadVideoSample = nil
                        }
                        continue
                    }

                    if sourceReaderExhausted, let previous = previousVideoSample {
                        let outputTime = timeline.outputPresentationTime(for: nextOutputFrameIndex)
                        try appendFrame(AppendRequest(
                            sample: previous,
                            outputPresentationTime: outputTime,
                            sourceLookupTime: timeline.sourceLookupTime(for: nextOutputFrameIndex),
                            sourceSegmentIndex: timeline.sourceSegmentIndex(for: nextOutputFrameIndex)
                        ))
                        recordAppendedFrame(at: outputTime, progress: progress)
                        continue
                    }
                } catch {
                    completion.failExport(error)
                    return
                }
            }
        }
    }

    private func recordAppendedFrame(
        at outputPresentationTime: CMTime,
        progress: (Phase0ExportProgressDTO) -> Void
    ) {
        renderedFrames += 1
        nextOutputFrameIndex += 1
        if renderedFrames == 1 || renderedFrames % 12 == 0 {
            let normalizedProgress = timeline.renderingProgress(presentationTime: outputPresentationTime)
            progress(.init(
                stage: .rendering,
                progress: min(0.9, normalizedProgress),
                currentFrame: renderedFrames,
                totalFrames: timeline.outputFrameCount,
                message: "Rendering frames"
            ))
        }
    }
}
