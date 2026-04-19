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
}

struct PickedLutFileDTO: Codable {
    let filename: String
    let text: String
    let uri: String?
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
            return "Bridge view controller is unavailable."
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
            return "An export is already in progress."
        case .exportCancelled:
            return "The export was cancelled."
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
