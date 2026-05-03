import Foundation

enum FilmtoneSourceKind: String, Codable {
    case image
    case video
}

struct SourceInfoDTO: Codable {
    let uri: String
    let filename: String
    let kind: FilmtoneSourceKind
    let mimeType: String?
}

struct CameraOpticsDTO: Codable {
    let source: String
    let fxPx: Double?
    let fyPx: Double?
    let cxPx: Double?
    let cyPx: Double?
    let fovXDeg: Double?
    let fovYDeg: Double?
    let focalLength35mm: Double?
    let lensModel: String?
    let cameraMake: String?
    let cameraModel: String?
}

// MARK: - Source video metadata (T1 HDR + T4 display/timing)

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

enum SourceCodecFamilyDTO: String, Codable {
    case h264
    case hevc
    case prores422 = "prores-422"
    case prores4444 = "prores-4444"
    case proresRaw = "prores-raw"
    case other
}

enum SourceLogTransferFunctionDTO: String, Codable {
    case appleLog = "apple-log"
    case appleLog2 = "apple-log2"
}

enum HdrPreparationStrategyDTO: String, Codable {
    case none                = "none"
    case coreImageToneMapSdr = "core-image-tone-map-sdr"
    case deferVisibleWarning = "defer-visible-warning"
}

struct HdrPreparationPolicyDTO: Codable {
    let strategy: HdrPreparationStrategyDTO
    let reason: String
    let requiresFixtureValidation: Bool
    let warning: String?
}

enum SourceInputTransformStrategyDTO: String, Codable {
    case none = "none"
    case appleLogToRec709 = "apple-log-to-rec709"
    case appleLog2ToRec709 = "apple-log2-to-rec709"
    case coreImageToneMapSdr = "core-image-tone-map-sdr"
    case deferVisibleWarning = "defer-visible-warning"
    case unsupported = "unsupported"
}

struct SourceInputTransformPolicyDTO: Codable {
    let strategy: SourceInputTransformStrategyDTO
    let reason: String
    let requiresFixtureValidation: Bool
    let warning: String?
}

struct SourceColorMetadataDTO: Codable {
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

struct SourceDisplayGeometryDTO: Codable {
    let rawWidth: Int
    let rawHeight: Int
    let displayWidth: Int
    let displayHeight: Int
    let rotationDeg: Int?
    let source: String
}

struct SourceVideoTimingMetadataDTO: Codable {
    let nominalFrameRate: Double?
    let estimatedFrameRate: Double?
    let sourceFrameRateTrusted: Bool
    let trustReason: String
}

struct SourceVideoMetadataDTO: Codable {
    let display: SourceDisplayGeometryDTO
    let color: SourceColorMetadataDTO
    let colorClass: SourceColorClassDTO
    let hdrPreparationPolicy: HdrPreparationPolicyDTO?
    let timing: SourceVideoTimingMetadataDTO?
    let codecFamily: SourceCodecFamilyDTO?
    let logTransferFunction: SourceLogTransferFunctionDTO?
    let inputTransformPolicy: SourceInputTransformPolicyDTO?

    init(
        display: SourceDisplayGeometryDTO,
        color: SourceColorMetadataDTO,
        colorClass: SourceColorClassDTO,
        hdrPreparationPolicy: HdrPreparationPolicyDTO?,
        timing: SourceVideoTimingMetadataDTO?,
        codecFamily: SourceCodecFamilyDTO? = nil,
        logTransferFunction: SourceLogTransferFunctionDTO? = nil,
        inputTransformPolicy: SourceInputTransformPolicyDTO? = nil
    ) {
        self.display = display
        self.color = color
        self.colorClass = colorClass
        self.hdrPreparationPolicy = hdrPreparationPolicy
        self.timing = timing
        self.codecFamily = codecFamily
        self.logTransferFunction = logTransferFunction
        self.inputTransformPolicy = inputTransformPolicy
    }
}

struct SourceProbeDTO: Codable {
    let uri: String
    let filename: String
    let kind: FilmtoneSourceKind
    let mimeType: String?
    let width: Int?
    let height: Int?
    let durationSec: Double?
    let fileSizeBytes: Int?
    let codec: String?
    let codecFamily: SourceCodecFamilyDTO?
    let frameRate: Double?
    let logTransferFunction: SourceLogTransferFunctionDTO?
    let inputTransformPolicy: SourceInputTransformPolicyDTO?
    let cameraOptics: CameraOpticsDTO?
    let sourceVideoMetadata: SourceVideoMetadataDTO?
}

struct Phase0OutputProfileDTO: Codable, Equatable {
    let longEdge: Int
    let fps: Int
    let codec: String
    let container: String
    let preserveAudio: Bool
}

struct Phase0QuickStateDTO: Codable {
    let filmCharacter: Double
    let era: Double
    let dynamics: Double
}

struct Phase0ParamsDTO: Codable {
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let temperature: Double
    let tint: Double
    let rgbShift: Double
    let lensSoftness: Double
    let grainRadialMix: Double
    let grainSize: Double
    let bloomThreshold: Double
    let bloomStrength: Double
    let bloomRadius: Double
    let diffusion: Double
    let halationIntensity: Double
    let halationSpread: Double
    let halationHue: Double
    let halationThreshold: Double
    let halationRadius: Double
    let bloomSoftKnee: Double
    let halationSoftKnee: Double
    let compressionAmount: Double
    let compressionRange: Double
    let printContrast: Double
    let cyan: Double
    let magenta: Double
    let yellow: Double
    let shutterAngle: Double
    let trailIntensity: Double
    let fade: Double
    let shadowTone: Double
    let highlightTone: Double
    let shadowHue: Double
    let highlightHue: Double
    let vignette: Double
    let grainIntensity: Double
}

struct ParsedCubeLutDTO: Codable, Equatable {
    let title: String
    let size: Int
    let data: [Double]
    let intensity: Double
    /// v1.4 Creative LUT Pack 01 provenance — additive, defaults nil.
    let bundledSlug: String?
    let bundledPackId: String?

    init(
        title: String,
        size: Int,
        data: [Double],
        intensity: Double,
        bundledSlug: String? = nil,
        bundledPackId: String? = nil
    ) {
        self.title = title
        self.size = size
        self.data = data
        self.intensity = intensity
        self.bundledSlug = bundledSlug
        self.bundledPackId = bundledPackId
    }
}

struct SerializableLutDTO: Codable, Equatable {
    let size: Int
    let data: [Double]
    let intensity: Double
    /// v1.4 Creative LUT Pack 01 provenance — mirrored from `ParsedCubeLutDTO`.
    let bundledSlug: String?
    let bundledPackId: String?

    init(
        size: Int,
        data: [Double],
        intensity: Double,
        bundledSlug: String? = nil,
        bundledPackId: String? = nil
    ) {
        self.size = size
        self.data = data
        self.intensity = intensity
        self.bundledSlug = bundledSlug
        self.bundledPackId = bundledPackId
    }
}

struct Phase0GradeDTO: Codable {
    let presetName: String
    let presetVersion: String
    let quickState: Phase0QuickStateDTO
    let params: Phase0ParamsDTO
}

struct SidecarDepthInfo: Codable, Equatable {
    let used: Bool
    let source: String?
    let resolutionWidth: Int?
    let resolutionHeight: Int?
    let renderer: String?
    let framesWithDepth: Int?
    let videoDepthSource: String?

    init(
        used: Bool,
        source: String? = nil,
        resolutionWidth: Int? = nil,
        resolutionHeight: Int? = nil,
        renderer: String? = nil,
        framesWithDepth: Int? = nil,
        videoDepthSource: String? = nil
    ) {
        self.used = used
        self.source = source
        self.resolutionWidth = resolutionWidth
        self.resolutionHeight = resolutionHeight
        self.renderer = renderer
        self.framesWithDepth = framesWithDepth
        self.videoDepthSource = videoDepthSource
    }
}

struct Phase0ExportRequestDTO: Codable {
    let sourceUri: String
    let sourceKind: FilmtoneSourceKind
    let sourceProbe: SourceProbeDTO?
    let output: Phase0OutputProfileDTO
    let grade: Phase0GradeDTO
    let lut: ParsedCubeLutDTO?
    let inputLut: SerializableLutDTO?
    let creativeLut: SerializableLutDTO?
    let renderMode: String?
    let depthEnabled: Bool?
    let depthRenderer: String?
    var connectPackage: Bool? = nil
}
