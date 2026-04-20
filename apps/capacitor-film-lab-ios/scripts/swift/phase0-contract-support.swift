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
