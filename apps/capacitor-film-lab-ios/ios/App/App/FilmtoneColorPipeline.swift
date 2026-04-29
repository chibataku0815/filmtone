import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

enum FilmtoneColorPipeline {
    static func defaultOutputContract(
        sourceMetadata: SourceColorMetadataDTO?,
        sourceColorClass: SourceColorClassDTO?
    ) -> FilmtoneColorPipelineContract {
        FilmtoneColorPipelineContract(
            outputProfileID: "rec709-sdr-mp4",
            outputColorPrimariesID: "bt709",
            outputColorTransferID: "bt709",
            outputColorSpaceID: "bt709",
            sourceInterpretationID: sourceInterpretationID(
                metadata: sourceMetadata,
                colorClass: sourceColorClass
            ),
            sourceFallbackColorSpace: sourceFallbackColorSpace(
                metadata: sourceMetadata,
                colorClass: sourceColorClass
            )
        )
    }

    private static func sourceInterpretationID(
        metadata: SourceColorMetadataDTO?,
        colorClass: SourceColorClassDTO?
    ) -> String {
        if isDisplayP3SDR(metadata) {
            return "display-p3-sdr"
        }
        return colorClass?.rawValue ?? "unknown"
    }

    private static func sourceFallbackColorSpace(
        metadata: SourceColorMetadataDTO?,
        colorClass: SourceColorClassDTO?
    ) -> CGColorSpace? {
        if isDisplayP3SDR(metadata) {
            return CGColorSpace(name: CGColorSpace.displayP3)
        }
        if colorClass == .sdrBt709 {
            return outputColorSpace()
        }
        return nil
    }

    private static func isDisplayP3SDR(_ metadata: SourceColorMetadataDTO?) -> Bool {
        guard let metadata else {
            return false
        }
        let hasP3Primaries =
            metadata.colorPrimaries == "smpte432" ||
            metadata.colorPrimaries == "smpte431"
        let isSDRTransfer =
            metadata.colorTransfer == "bt709" ||
            metadata.colorTransfer == "iec61966-2-1" ||
            metadata.colorTransfer == nil
        return hasP3Primaries && isSDRTransfer
    }

    static func workingColorSpace() -> CGColorSpace {
        CGColorSpace(name: CGColorSpace.linearSRGB)
            ?? CGColorSpace(name: CGColorSpace.sRGB)
            ?? CGColorSpaceCreateDeviceRGB()
    }

    static func outputColorSpace() -> CGColorSpace {
        for name in [
            CGColorSpace.itur_709,
            CGColorSpace.sRGB,
        ] {
            if let colorSpace = CGColorSpace(name: name), colorSpace.supportsOutput {
                return colorSpace
            }
        }
        return CGColorSpaceCreateDeviceRGB()
    }
}

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
        [
            .applyOrientationProperty: true,
            .toneMapHDRtoSDR: true,
        ]
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

    #if os(iOS)
    func applyOutputMetadata(to composition: AVMutableVideoComposition) {
        composition.colorPrimaries = videoColorPrimariesTag
        composition.colorTransferFunction = videoTransferFunctionTag
        composition.colorYCbCrMatrix = videoYCbCrMatrixTag
    }
    #endif

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
