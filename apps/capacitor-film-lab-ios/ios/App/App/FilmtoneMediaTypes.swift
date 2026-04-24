import Foundation
import UIKit

enum FilmtoneSourceKind: String, Codable {
    case image
    case video
}

enum Phase0ExportStage: String, Codable {
    case preflight
    case reading
    case rendering
    case writing
    case completed
}

struct SourceInfoDTO: Codable {
    let uri: String
    let filename: String
    let kind: FilmtoneSourceKind
    let mimeType: String?
    let mezzanineStatus: String?

    init(uri: String, filename: String, kind: FilmtoneSourceKind, mimeType: String?, mezzanineStatus: String? = nil) {
        self.uri = uri
        self.filename = filename
        self.kind = kind
        self.mimeType = mimeType
        self.mezzanineStatus = mezzanineStatus
    }
}

struct PickedLutFileDTO: Codable {
    let filename: String
    let text: String
    let uri: String?
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

// MARK: - Source video metadata (T1 HDR policy + T4 display/timing)

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
    // reason vocab: "source-is-sdr-bt709" | "source-is-hdr-pq" | "source-is-hdr-hlg"
    //             | "wide-gamut-transfer-unknown" | "source-color-unknown"
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
    // reason vocab: "source-is-sdr-bt709" | "source-is-hdr-pq" | "source-is-hdr-hlg"
    //             | "source-is-apple-log" | "source-is-apple-log2"
    //             | "wide-gamut-transfer-unknown" | "source-is-prores-raw"
    //             | "source-color-unknown"
    let reason: String
    let requiresFixtureValidation: Bool
    let warning: String?
}

struct SourceColorMetadataDTO: Codable {
    // Values are normalized to ffprobe vocabulary (see SourceColorMetadataNormalizer):
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

struct SourceDisplayGeometryDTO: Codable {
    let rawWidth: Int
    let rawHeight: Int
    let displayWidth: Int
    let displayHeight: Int
    let rotationDeg: Int?       // 0 | 90 | 180 | 270 | nil
    let source: String          // "preferred-transform" | "raw"
}

struct SourceVideoTimingMetadataDTO: Codable {
    let nominalFrameRate: Double?
    let estimatedFrameRate: Double?   // v1.1 は常に nil (VFR 判定は v1.2)
    let sourceFrameRateTrusted: Bool
    // trustReason (v1.1): "nominal-only" | "missing-or-invalid-rate"
    //   v1.2 extension: "within-absolute-tolerance" | "rates-diverged"
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

    init(
        uri: String,
        filename: String,
        kind: FilmtoneSourceKind,
        mimeType: String?,
        width: Int?,
        height: Int?,
        durationSec: Double?,
        fileSizeBytes: Int?,
        codec: String?,
        codecFamily: SourceCodecFamilyDTO? = nil,
        frameRate: Double?,
        logTransferFunction: SourceLogTransferFunctionDTO? = nil,
        inputTransformPolicy: SourceInputTransformPolicyDTO? = nil,
        cameraOptics: CameraOpticsDTO? = nil,
        sourceVideoMetadata: SourceVideoMetadataDTO? = nil
    ) {
        self.uri = uri
        self.filename = filename
        self.kind = kind
        self.mimeType = mimeType
        self.width = width
        self.height = height
        self.durationSec = durationSec
        self.fileSizeBytes = fileSizeBytes
        self.codec = codec
        self.codecFamily = codecFamily
        self.frameRate = frameRate
        self.logTransferFunction = logTransferFunction
        self.inputTransformPolicy = inputTransformPolicy
        self.cameraOptics = cameraOptics
        self.sourceVideoMetadata = sourceVideoMetadata
    }
}

struct Phase0OutputProfileDTO: Codable {
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

struct ParsedCubeLutDTO: Codable {
    let title: String
    let size: Int
    let data: [Double]
    let intensity: Double
}

struct SerializableLutDTO: Codable {
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

struct Phase0ExportProgressDTO: Encodable {
    let stage: Phase0ExportStage
    let progress: Double
    let currentFrame: Int?
    let totalFrames: Int?
    let message: String?
}

struct Phase0ExportBenchmarkRecordDTO: Encodable {
    let appVersion: String
    let buildNumber: String
    let deviceModel: String
    let iosVersion: String
    let sourceCodec: String?
    let sourceResolution: String?
    let sourceDurationSec: Double?
    let outputFileSizeBytes: Int?
    let elapsedMs: Int
    let realtimeRatio: Double?
    let thermalState: String?
    let memoryWarningCount: Int?
    let permissionResult: String?
    let saveToPhotosOk: Bool?
    let errorDomain: String?
    let errorCode: String?
    let exportUsedMezzanine: Bool?
    let mezzanineGenerationMs: Int?
}

struct Phase0ExportResultDTO: Encodable {
    let outputUri: String
    let elapsedMs: Int
    let outputWidth: Int
    let outputHeight: Int
    let outputFps: Int
    let fileSizeBytes: Int?
    let realtimeRatio: Double?
    let audioPreserved: Bool?
    let benchmarkRecord: Phase0ExportBenchmarkRecordDTO?
    // v1.1: filmtone-ios-export-session-v1 sidecar JSON URI (app container temp URL).
    //       nil when sidecar write failed or disabled.
    let sidecarUri: String?

    init(
        outputUri: String,
        elapsedMs: Int,
        outputWidth: Int,
        outputHeight: Int,
        outputFps: Int,
        fileSizeBytes: Int?,
        realtimeRatio: Double?,
        audioPreserved: Bool?,
        benchmarkRecord: Phase0ExportBenchmarkRecordDTO?,
        sidecarUri: String? = nil
    ) {
        self.outputUri = outputUri
        self.elapsedMs = elapsedMs
        self.outputWidth = outputWidth
        self.outputHeight = outputHeight
        self.outputFps = outputFps
        self.fileSizeBytes = fileSizeBytes
        self.realtimeRatio = realtimeRatio
        self.audioPreserved = audioPreserved
        self.benchmarkRecord = benchmarkRecord
        self.sidecarUri = sidecarUri
    }
}

struct Phase0PreviewRenderResultDTO: Encodable {
    let originalUri: String
    let gradedUri: String
    let width: Int
    let height: Int
    let posterTimeSec: Double?
}

enum FilmtoneMediaError: LocalizedError {
    case bridgeUnavailable
    case invalidURL(String)
    case missingSource(String)
    case unsupportedSource(String)
    case permissionDenied(String)
    case pickerUnavailable(String)
    case exportBusy
    case exportCancelled
    case exportFailed(String)
    case saveFailed(String)
    case shareFailed(String)
    case cacheFailed(String)

    var code: String {
        switch self {
        case .bridgeUnavailable:
            return "BRIDGE_UNAVAILABLE"
        case .invalidURL:
            return "INVALID_URL"
        case .missingSource:
            return "MISSING_SOURCE"
        case .unsupportedSource:
            return "UNSUPPORTED_SOURCE"
        case .permissionDenied:
            return "PERMISSION_DENIED"
        case .pickerUnavailable:
            return "PICKER_UNAVAILABLE"
        case .exportBusy:
            return "EXPORT_BUSY"
        case .exportCancelled:
            return "EXPORT_CANCELLED"
        case .exportFailed:
            return "EXPORT_FAILED"
        case .saveFailed:
            return "SAVE_FAILED"
        case .shareFailed:
            return "SHARE_FAILED"
        case .cacheFailed:
            return "CACHE_FAILED"
        }
    }

    var errorDescription: String? {
        switch self {
        case .bridgeUnavailable:
            return filmtoneLocalized(
                "filmtone.error.bridge_unavailable",
                defaultValue: "The Filmtone view is unavailable right now.",
                comment: "Error shown when the native presenter is unavailable."
            )
        case .invalidURL(let message),
             .missingSource(let message),
             .unsupportedSource(let message),
             .permissionDenied(let message),
             .pickerUnavailable(let message),
             .exportFailed(let message),
             .saveFailed(let message),
             .shareFailed(let message),
             .cacheFailed(let message):
            return message
        case .exportBusy:
            return filmtoneLocalized(
                "filmtone.error.export_busy",
                defaultValue: "An export is already in progress.",
                comment: "Error shown when a second export starts while one is already running."
            )
        case .exportCancelled:
            return filmtoneLocalized(
                "filmtone.error.export_cancelled",
                defaultValue: "The export was cancelled.",
                comment: "Error shown when export is cancelled."
            )
        }
    }
}

extension ProcessInfo.ThermalState {
    var filmtoneLabel: String {
        switch self {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }
}

extension UIDevice {
    var filmtoneModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
