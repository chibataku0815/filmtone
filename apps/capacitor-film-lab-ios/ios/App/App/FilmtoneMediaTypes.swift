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
    /// Whether the source carries usable depth/disparity aux data
    /// (HEIC Portrait / LiDAR). Optional so legacy emit paths default to nil
    /// = "unknown / absent". Plumbed end-to-end in v1.3 (plan §6.1, D1.3).
    let hasDepth: Bool?

    init(
        uri: String,
        filename: String,
        kind: FilmtoneSourceKind,
        mimeType: String?,
        mezzanineStatus: String? = nil,
        hasDepth: Bool? = nil
    ) {
        self.uri = uri
        self.filename = filename
        self.kind = kind
        self.mimeType = mimeType
        self.mezzanineStatus = mezzanineStatus
        self.hasDepth = hasDepth
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

enum Phase0RenderMode: String, Codable {
    case quality
    case speed
}

/// v1.3: depth prefilter renderer selector. Wire stays a `String` on
/// `Phase0ExportRequestDTO.depthRenderer` for forward-compat (Phase B may add
/// `metal` only on a subset of devices); this enum is an internal convenience
/// for native call-sites that prefer compile-time matching.
enum DepthRenderer: String, Codable {
    case ci
    case metal
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
    /// v1.2: optional opt-in to Speed mode. nil / absent / "quality" all behave as Quality default.
    /// Quality auto-routes to HDR mezzanine when source is wide-gamut; Speed reuses any mezzanine.
    let renderMode: Phase0RenderMode?
    /// v1.3 (D3.1): opt-in flag for the AVDepthData × ray-angle prefilter on the
    /// glow trio (mist/bloom/halation). Optional for backwards compatibility —
    /// nil / false → byte-identical to v1.2 output. Only meaningful for still
    /// HEIC sources with depth aux data; video sources MUST be rejected when
    /// this is true (`feedback_no_fallback_bug_hotbed`).
    let depthEnabled: Bool?
    /// v1.3 (D3.1): depth prefilter renderer selector. Encoded as a plain string
    /// ("ci" | "metal") for forward-compat — see `DepthRenderer`. Defaults to
    /// "ci" on the native side when nil/absent.
    let depthRenderer: String?
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
    /// v1.2: render mode actually used for this export ("quality" | "speed").
    let renderMode: String?
    /// v1.2: mezzanine profile variant the export consumed ("sdr" | "hdr"), nil if no mezzanine used.
    let mezzanineProfileVariant: String?
    /// v1.3 (D3.4): whether the depth × ray-angle prefilter ran for this export.
    let depthUsed: Bool?
    /// v1.3 (D3.4): depth aux source ("avDepthData"), nil when depth not used.
    let depthSource: String?
    /// v1.3 (D3.4): renderer that executed the prefilter ("ci" | "metal"),
    /// nil when depth not used.
    let depthRenderer: String?
    /// v1.3 (D3.4): wall-clock ms spent on the depth prefilter pass (sum across
    /// the three glow stages). nil when depth not used.
    let depthPrefilterMs: Double?
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
    /// v1.3 (D3.6): depthEnabled=true was sent with a video source. Phase A only
    /// supports still HEIC + AVDepthData; we throw rather than silently disabling
    /// (`feedback_no_fallback_bug_hotbed`) so callers see the contract violation.
    case depthUnsupportedForVideoSource

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
        case .depthUnsupportedForVideoSource:
            return "DEPTH_UNSUPPORTED_FOR_VIDEO_SOURCE"
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
        case .depthUnsupportedForVideoSource:
            return filmtoneLocalized(
                "filmtone.error.depth_unsupported_for_video",
                defaultValue: "Depth-aware glow is not available for video sources in this version.",
                comment: "Error shown when depthEnabled=true is requested with a video source."
            )
        }
    }
}

// MARK: - v1.3 sidecar depth block (D3.5)

/// Records whether (and how) AVDepthData was consumed for this export.
/// Mirrors the `mezzanine` block convention: `used == false` is meaningful — it
/// signals an explicit "no-depth-prefilter" path rather than an absent field.
/// `source` is "avDepthData" when used; nil when not (Phase B will add CoreML
/// depth-anything-v2 to the vocabulary). `renderer` is "ci" | "metal".
struct SidecarDepthInfo: Codable, Equatable {
    let used: Bool
    let source: String?
    let resolutionWidth: Int?
    let resolutionHeight: Int?
    let renderer: String?
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
