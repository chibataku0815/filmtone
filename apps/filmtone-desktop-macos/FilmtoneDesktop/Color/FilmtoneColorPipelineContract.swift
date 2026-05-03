import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

// Phase 2 C1: aligns with iOS canonical contract struct
// (`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneColorPipeline.swift`
// lines 84-206). Construct via
// `FilmtoneColorPipeline.defaultOutputContract(sourceMetadata:sourceColorClass:)`
// — the previous `phase1cMP4Default()` shortcut is gone now that the factory
// has landed.
//
// The iOS-only `applyOutputMetadata(to: AVMutableVideoComposition)` overload
// is omitted: the macOS exporter writes via
// `AVAssetWriterInputPixelBufferAdaptor`, not video composition. Reintroduce
// when (if) we add an AVPlayer-backed scrubber that needs composition color
// metadata.
struct FilmtoneColorPipelineContract {
    let outputProfileID: String
    let outputColorPrimariesID: String
    let outputColorTransferID: String
    let outputColorSpaceID: String
    let sourceInterpretationID: String
    let sourceFallbackColorSpace: CGColorSpace?

    var workingColorSpace: CGColorSpace {
        FilmtoneColorPipeline.workingColorSpace()
    }

    var destinationColorSpace: CGColorSpace {
        FilmtoneColorPipeline.outputColorSpace()
    }

    var writerColorProperties: [String: Any] {
        [
            AVVideoColorPrimariesKey: videoColorPrimariesTag,
            AVVideoTransferFunctionKey: videoTransferFunctionTag,
            AVVideoYCbCrMatrixKey: videoYCbCrMatrixTag,
        ]
    }

    var videoColorPrimariesTag: String {
        AVVideoColorPrimaries_ITU_R_709_2
    }

    var videoTransferFunctionTag: String {
        AVVideoTransferFunction_ITU_R_709_2
    }

    var videoYCbCrMatrixTag: String {
        AVVideoYCbCrMatrix_ITU_R_709_2
    }

    var pixelBufferColorPrimariesTag: CFString {
        kCVImageBufferColorPrimaries_ITU_R_709_2
    }

    var pixelBufferTransferFunctionTag: CFString {
        kCVImageBufferTransferFunction_ITU_R_709_2
    }

    var pixelBufferYCbCrMatrixTag: CFString {
        kCVImageBufferYCbCrMatrix_ITU_R_709_2
    }

    func videoReaderOutputSettings(pixelFormat: OSType) -> [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: Int(pixelFormat),
            AVVideoAllowWideColorKey: true,
        ]
    }

    func sourceImageOptions(
        for imageBuffer: CVPixelBuffer,
        toneMapHDRToSDR: Bool
    ) -> [CIImageOption: Any] {
        var options: [CIImageOption: Any] = toneMapHDRToSDR
            ? [.toneMapHDRtoSDR: true]
            : [:]
        if sourceColorAttachmentsMissing(from: imageBuffer),
           let sourceFallbackColorSpace {
            options[.colorSpace] = sourceFallbackColorSpace
        }
        return options
    }

    func stillImageOptions() -> [CIImageOption: Any] {
        var options: [CIImageOption: Any] = [
            .applyOrientationProperty: true,
            .toneMapHDRtoSDR: true,
        ]
        if let sourceFallbackColorSpace {
            options[.colorSpace] = sourceFallbackColorSpace
        }
        return options
    }

    func applyOutputMetadata(to imageBuffer: CVPixelBuffer) {
        CVBufferSetAttachment(
            imageBuffer,
            kCVImageBufferColorPrimariesKey,
            pixelBufferColorPrimariesTag,
            .shouldPropagate
        )
        CVBufferSetAttachment(
            imageBuffer,
            kCVImageBufferTransferFunctionKey,
            pixelBufferTransferFunctionTag,
            .shouldPropagate
        )
        CVBufferSetAttachment(
            imageBuffer,
            kCVImageBufferYCbCrMatrixKey,
            pixelBufferYCbCrMatrixTag,
            .shouldPropagate
        )
    }

    private func sourceColorAttachmentsMissing(from imageBuffer: CVPixelBuffer) -> Bool {
        CVBufferCopyAttachment(
            imageBuffer,
            kCVImageBufferColorPrimariesKey,
            nil
        ) == nil &&
            CVBufferCopyAttachment(
                imageBuffer,
                kCVImageBufferTransferFunctionKey,
                nil
            ) == nil &&
            CVBufferCopyAttachment(
                imageBuffer,
                kCVImageBufferYCbCrMatrixKey,
                nil
            ) == nil
    }
}
