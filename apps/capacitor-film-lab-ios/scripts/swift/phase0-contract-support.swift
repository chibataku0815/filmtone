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
    case wideGamutUnknown = "wide-gamut-unknown"
    case unknown          = "unknown"
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

struct SourceColorMetadataDTO: Codable {
    let colorRange: String?
    let colorSpace: String?
    let colorTransfer: String?
    let colorPrimaries: String?
    let hasMasteringDisplayMetadata: Bool
    let hasContentLightMetadata: Bool
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
    let frameRate: Double?
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
    let fade: Double
    let vignette: Double
    let grainIntensity: Double
}

struct ParsedCubeLutDTO: Codable, Equatable {
    let title: String
    let size: Int
    let data: [Double]
    let intensity: Double
}

struct SerializableLutDTO: Codable, Equatable {
    let size: Int
    let data: [Double]
    let intensity: Double
}

struct Phase0GradeDTO: Codable {
    let presetName: String
    let presetVersion: String
    let quickState: Phase0QuickStateDTO
    let params: Phase0ParamsDTO
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
}
