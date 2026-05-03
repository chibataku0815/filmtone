import Foundation

// Phase 2 C1: lift the static classifier from
// `apps/capacitor-film-lab-ios/ios/App/App/SourceColorClassifier.swift`
// (lines 8-56). Inputs must already be normalized through
// `SourceColorMetadataNormalizer`; raw CoreMedia identifiers will fall to
// `.unknown`.
//
// `FilmtoneMezzanineRoutePolicy` (iOS lines 58-187) is intentionally not
// ported — it's iOS mezzanine routing and irrelevant to the macOS native
// Phase 2 backbone.
enum SourceColorClassifier {
    static func classify(_ metadata: SourceColorMetadataDTO) -> SourceColorClassDTO {
        if metadata.logTransferFunction == .appleLog2 ||
            metadata.colorTransfer == "apple-log2" ||
            metadata.colorTransfer == "apple-log-2"
        {
            return .appleLog2
        }
        if metadata.logTransferFunction == .appleLog || metadata.colorTransfer == "apple-log" {
            return .appleLog
        }

        if metadata.colorTransfer == "smpte2084" {
            return .hdrPq
        }
        if metadata.colorTransfer == "arib-std-b67" {
            return .hdrHlg
        }

        let hasBt2020 =
            metadata.colorPrimaries == "bt2020" ||
            metadata.colorSpace == "bt2020" ||
            metadata.colorSpace == "bt2020nc" ||
            metadata.colorSpace == "bt2020c"
        if hasBt2020
            || metadata.hasMasteringDisplayMetadata
            || metadata.hasContentLightMetadata
        {
            return .wideGamutUnknown
        }

        if isStrictSdrBt709(metadata) {
            return .sdrBt709
        }

        return .unknown
    }

    private static func isStrictSdrBt709(_ metadata: SourceColorMetadataDTO) -> Bool {
        let hasBt709Primaries = metadata.colorPrimaries == "bt709"
        let hasSdrTransfer =
            metadata.colorTransfer == "bt709" ||
            metadata.colorTransfer == nil
        let hasVideoMatrix =
            metadata.colorSpace == "bt709" ||
            metadata.colorSpace == nil
        return hasBt709Primaries && hasSdrTransfer && hasVideoMatrix
    }
}
