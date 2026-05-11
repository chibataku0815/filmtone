import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import FilmLabSwiftCore
import Foundation
import os

/// Phase 2B-7B: per-frame video sample append / rasterize collaborator
/// lifted out of `FilmtoneExportSession`. Owns the writer readiness wait,
/// pixel-buffer-pool allocation, CI render, output color metadata
/// application, the adaptor append, and the wait/build-graph/render/append
/// signpost intervals plus their matching performance-metric phases.
///
/// `exportVideo`, `exportStillImage`, `renderableImage`, `applyGrade`, and
/// the source/depth/motion render order remain on `FilmtoneExportSession`
/// during 2B-7B. The appender receives a render closure
/// (`renderFrameImage`) so the session keeps ownership of the grade /
/// motion / depth pipeline order. Cancellation is forwarded as a closure
/// (`checkCancelled`) so the session keeps ownership of the `cancelled`
/// flag.
final class ExportFrameAppender {
    private let ciContext: CIContext
    private let outputColorSpace: CGColorSpace
    private let colorPipeline: FilmtoneColorPipelineContract
    private let performanceMetrics: FilmtoneExportPerformanceMetrics
    private let signposter: OSSignposter
    private let mediaWriter: ExportMediaWriter

    init(
        ciContext: CIContext,
        outputColorSpace: CGColorSpace,
        colorPipeline: FilmtoneColorPipelineContract,
        performanceMetrics: FilmtoneExportPerformanceMetrics,
        signposter: OSSignposter,
        mediaWriter: ExportMediaWriter
    ) {
        self.ciContext = ciContext
        self.outputColorSpace = outputColorSpace
        self.colorPipeline = colorPipeline
        self.performanceMetrics = performanceMetrics
        self.signposter = signposter
        self.mediaWriter = mediaWriter
    }

    func appendVideoSample(
        _ sampleBuffer: CMSampleBuffer,
        videoInput: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        videoTrack: AVAssetTrack,
        outputSize: CGSize,
        outputPresentationTime: CMTime? = nil,
        renderTimeSeconds: Double? = nil,
        waitForReady: Bool = true,
        checkCancelled: () throws -> Void,
        renderFrameImage: (CVPixelBuffer, CGAffineTransform, CGSize, Double) -> CIImage
    ) throws -> Bool {
        try autoreleasepool { () throws -> Bool in
            if waitForReady {
                try performanceMetrics.measure(.waitEncoder) {
                    try signposter.withIntervalSignpost("wait-encoder") {
                        try mediaWriter.waitUntilReadyForMoreMediaData(videoInput, writer: writer, reader: reader, label: "video", checkCancelled: checkCancelled)
                    }
                }
            }

            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return false
            }
            guard let pixelBufferPool = adaptor.pixelBufferPool else {
                throw FilmtoneMediaError.exportFailed("Pixel buffer pool is unavailable.")
            }

            let sourcePresentationTime = ExportMediaWriter.validPresentationTime(for: sampleBuffer)
            let outputTime = outputPresentationTime ?? sourcePresentationTime
            let presentationTimeSec = renderTimeSeconds ?? CMTimeGetSeconds(sourcePresentationTime)
            let frameImage = performanceMetrics.measure(.buildGraph) {
                signposter.withIntervalSignpost("build-graph") {
                    renderFrameImage(
                        imageBuffer,
                        videoTrack.preferredTransform,
                        outputSize,
                        presentationTimeSec.isFinite ? presentationTimeSec : 0
                    )
                }
            }

            var renderedBuffer: CVPixelBuffer?
            let creationStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &renderedBuffer)
            guard creationStatus == kCVReturnSuccess, let renderedBuffer else {
                throw FilmtoneMediaError.exportFailed("A render pixel buffer could not be created.")
            }

            performanceMetrics.measure(.render) {
                signposter.withIntervalSignpost("render") {
                    ciContext.render(
                        frameImage,
                        to: renderedBuffer,
                        bounds: CGRect(origin: .zero, size: outputSize),
                        colorSpace: outputColorSpace
                    )
                }
            }
            colorPipeline.applyOutputMetadata(to: renderedBuffer)

            let appended = performanceMetrics.measure(.append) {
                signposter.withIntervalSignpost("append") {
                    adaptor.append(renderedBuffer, withPresentationTime: outputTime)
                }
            }
            if !appended {
                throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The frame could not be appended.")
            }
            performanceMetrics.recordRenderedFrame()

            return true
        }
    }
}
