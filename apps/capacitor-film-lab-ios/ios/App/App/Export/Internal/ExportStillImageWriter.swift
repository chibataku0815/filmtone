import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import FilmLabSwiftCore
import Foundation

/// Phase 2B-9A: still-image writer / adaptor / render-append loop lifted
/// out of `FilmtoneExportSession.exportStillImage(progress:)`. Owns the
/// `AVAssetWriterInputPixelBufferAdaptor` setup, the 3-second frame loop,
/// per-frame pixel-buffer-pool allocation, CI render, output color
/// metadata application, the adaptor append, rendering / writing progress
/// updates, finish handoff to the media writer, and the
/// `CompletedExport` value for still-image output.
///
/// Source image loading, HEIC depth payload loading, `loadedDepthMap` /
/// `depthResolution` mutation, output size calculation, and
/// `renderableStillImage(...)` remain on `FilmtoneExportSession`. The
/// session computes `filteredImage` exactly where it does today and then
/// delegates the writer loop here. Cancellation is forwarded as a closure
/// (`checkCancelled`) so the session keeps ownership of the `cancelled`
/// flag.
final class ExportStillImageWriter {
    private let ciContext: CIContext
    private let outputColorSpace: CGColorSpace
    private let colorPipeline: FilmtoneColorPipelineContract
    private let mediaWriter: ExportMediaWriter
    private let outputFPS: Int

    init(
        ciContext: CIContext,
        outputColorSpace: CGColorSpace,
        colorPipeline: FilmtoneColorPipelineContract,
        mediaWriter: ExportMediaWriter,
        outputFPS: Int
    ) {
        self.ciContext = ciContext
        self.outputColorSpace = outputColorSpace
        self.colorPipeline = colorPipeline
        self.mediaWriter = mediaWriter
        self.outputFPS = outputFPS
    }

    func write(
        filteredImage: CIImage,
        outputSize: CGSize,
        progress: (Phase0ExportProgressDTO) -> Void,
        checkCancelled: () throws -> Void
    ) throws -> CompletedExport {
        let writer = try mediaWriter.makeWriter(outputSize: outputSize)
        let videoInput = mediaWriter.makeVideoInput(outputSize: outputSize)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(outputSize.width.rounded()),
                kCVPixelBufferHeightKey as String: Int(outputSize.height.rounded()),
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw FilmtoneMediaError.exportFailed("Still-image writer input could not be added.")
        }
        writer.add(videoInput)

        guard writer.startWriting() else {
            throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The writer failed to start.")
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(outputFPS * 3, 1)
        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw FilmtoneMediaError.exportFailed("Pixel buffer pool is unavailable.")
        }

        for frameIndex in 0..<frameCount {
            try checkCancelled()
            try autoreleasepool {
                try mediaWriter.waitUntilReadyForMoreMediaData(videoInput, writer: writer, label: "video", checkCancelled: checkCancelled)

                var renderedBuffer: CVPixelBuffer?
                let creationStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &renderedBuffer)
                guard creationStatus == kCVReturnSuccess, let renderedBuffer else {
                    throw FilmtoneMediaError.exportFailed("A render pixel buffer could not be created.")
                }

                ciContext.render(
                    filteredImage,
                    to: renderedBuffer,
                    bounds: CGRect(origin: .zero, size: outputSize),
                    colorSpace: outputColorSpace
                )
                colorPipeline.applyOutputMetadata(to: renderedBuffer)

                let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(outputFPS))
                if !adaptor.append(renderedBuffer, withPresentationTime: presentationTime) {
                    throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The still frame could not be appended.")
                }
            }

            if frameIndex == 0 || frameIndex % 12 == 0 {
                let normalizedProgress = 0.12 + (Double(frameIndex + 1) / Double(frameCount)) * 0.74
                progress(.init(
                    stage: .rendering,
                    progress: min(0.9, normalizedProgress),
                    currentFrame: frameIndex + 1,
                    totalFrames: frameCount,
                    message: "Rendering still image"
                ))
            }
        }

        videoInput.markAsFinished()
        progress(.init(stage: .writing, progress: 0.92, currentFrame: frameCount, totalFrames: frameCount, message: "Writing output"))
        try mediaWriter.finish(writer: writer, checkCancelled: checkCancelled)

        return CompletedExport(
            outputSize: outputSize,
            frameCount: frameCount,
            sourceDurationSec: nil,
            outputDurationSec: Double(frameCount) / Double(outputFPS),
            audioPreserved: false
        )
    }
}
