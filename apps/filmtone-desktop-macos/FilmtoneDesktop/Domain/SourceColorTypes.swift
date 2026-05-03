import Foundation

// Phase 2 C1: lift the source color DTO graph from
// `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift` (lines
// 67-156). These are platform-neutral, depend only on Foundation, and feed
// `SourceColorClassifier` + `FilmtoneColorPipeline.defaultOutputContract`.
//
// Field order, raw values, and member init signatures must stay bit-identical
// with the iOS canonical so a future SPM consolidation (Phase 2 C6 if/when
// taken) can drop these and re-link to the shared Swift core without API
// drift.

enum SourceColorClassDTO: String, Codable {
    case sdrBt709         = "sdr-bt709"
    case hdrPq            = "hdr-pq"
    case hdrHlg           = "hdr-hlg"
    case appleLog         = "apple-log"
    case appleLog2        = "apple-log2"
    case wideGamutUnknown = "wide-gamut-unknown"
    case unsupported      = "unsupported"
    case unknown          = "unknown"
}

enum SourceLogTransferFunctionDTO: String, Codable {
    case appleLog = "apple-log"
    case appleLog2 = "apple-log2"
}

struct SourceColorMetadataDTO: Codable {
    // Values are normalized to ffprobe vocabulary
    // (see SourceColorMetadataNormalizer):
    //   colorTransfer: "smpte2084" | "arib-std-b67" | "bt709" | "smpte170m" | ...
    //   colorPrimaries: "bt2020" | "bt709" | "smpte170m" | "smpte432" | ...
    //   colorSpace: same vocabulary as primaries, or "bt2020nc" / "bt2020c"
    let colorRange: String?
    let colorSpace: String?
    let colorTransfer: String?
    let colorPrimaries: String?
    let logTransferFunction: SourceLogTransferFunctionDTO?
    let hasMasteringDisplayMetadata: Bool
    let hasContentLightMetadata: Bool

    init(
        colorRange: String?,
        colorSpace: String?,
        colorTransfer: String?,
        colorPrimaries: String?,
        logTransferFunction: SourceLogTransferFunctionDTO? = nil,
        hasMasteringDisplayMetadata: Bool,
        hasContentLightMetadata: Bool
    ) {
        self.colorRange = colorRange
        self.colorSpace = colorSpace
        self.colorTransfer = colorTransfer
        self.colorPrimaries = colorPrimaries
        self.logTransferFunction = logTransferFunction
        self.hasMasteringDisplayMetadata = hasMasteringDisplayMetadata
        self.hasContentLightMetadata = hasContentLightMetadata
    }
}
