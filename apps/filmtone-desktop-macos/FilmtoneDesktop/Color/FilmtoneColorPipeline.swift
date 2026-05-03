import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

// Phase 2 C1: lift the factory from
// `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneColorPipeline.swift`
// (lines 1-82). Produces a Rec.709 SDR `FilmtoneColorPipelineContract` with
// a sourceInterpretationID + sourceFallbackColorSpace derived from probed
// source metadata. Display P3 SDR sources get a P3 fallback CIImage option;
// strict bt709 SDR sources get an sRGB/Rec.709 fallback; HDR / log /
// wide-gamut / unknown sources get nil (the per-frame `toneMapHDRToSDR`
// option handles tone mapping).
//
// HDR output is a future Phase 4 lane — this factory always returns an
// `outputProfileID = "rec709-sdr-mp4"` contract.
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
