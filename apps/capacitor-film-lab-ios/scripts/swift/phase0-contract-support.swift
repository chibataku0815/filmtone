import Foundation
import FilmLabSwiftCore

typealias Phase0OutputProfileDTO = FilmLabSwiftCore.Phase0OutputProfileDTO

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
    let detailSoftness: Double
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
    let filmBreathAmount: Double
    let dustAmount: Double
    let scratchAmount: Double
    let fade: Double
    let shadowTone: Double
    let shadowLatitude: Double
    let blackPoint: Double
    let toeContrast: Double
    let highlightTone: Double
    let shadowHue: Double
    let highlightHue: Double
    let vignette: Double
    let grainIntensity: Double

    init(
        exposure: Double,
        contrast: Double,
        saturation: Double,
        temperature: Double,
        tint: Double,
        rgbShift: Double,
        lensSoftness: Double,
        detailSoftness: Double,
        grainRadialMix: Double,
        grainSize: Double,
        bloomThreshold: Double,
        bloomStrength: Double,
        bloomRadius: Double,
        diffusion: Double,
        halationIntensity: Double,
        halationSpread: Double,
        halationHue: Double,
        halationThreshold: Double,
        halationRadius: Double,
        bloomSoftKnee: Double,
        halationSoftKnee: Double,
        compressionAmount: Double,
        compressionRange: Double,
        printContrast: Double,
        cyan: Double,
        magenta: Double,
        yellow: Double,
        shutterAngle: Double,
        trailIntensity: Double,
        filmBreathAmount: Double = 0,
        dustAmount: Double = 0,
        scratchAmount: Double = 0,
        fade: Double,
        shadowTone: Double,
        shadowLatitude: Double,
        blackPoint: Double = 0,
        toeContrast: Double = 0,
        highlightTone: Double,
        shadowHue: Double,
        highlightHue: Double,
        vignette: Double,
        grainIntensity: Double
    ) {
        self.exposure = exposure
        self.contrast = contrast
        self.saturation = saturation
        self.temperature = temperature
        self.tint = tint
        self.rgbShift = rgbShift
        self.lensSoftness = lensSoftness
        self.detailSoftness = detailSoftness
        self.grainRadialMix = grainRadialMix
        self.grainSize = grainSize
        self.bloomThreshold = bloomThreshold
        self.bloomStrength = bloomStrength
        self.bloomRadius = bloomRadius
        self.diffusion = diffusion
        self.halationIntensity = halationIntensity
        self.halationSpread = halationSpread
        self.halationHue = halationHue
        self.halationThreshold = halationThreshold
        self.halationRadius = halationRadius
        self.bloomSoftKnee = bloomSoftKnee
        self.halationSoftKnee = halationSoftKnee
        self.compressionAmount = compressionAmount
        self.compressionRange = compressionRange
        self.printContrast = printContrast
        self.cyan = cyan
        self.magenta = magenta
        self.yellow = yellow
        self.shutterAngle = shutterAngle
        self.trailIntensity = trailIntensity
        self.filmBreathAmount = filmBreathAmount
        self.dustAmount = dustAmount
        self.scratchAmount = scratchAmount
        self.fade = fade
        self.shadowTone = shadowTone
        self.shadowLatitude = shadowLatitude
        self.blackPoint = blackPoint
        self.toeContrast = toeContrast
        self.highlightTone = highlightTone
        self.shadowHue = shadowHue
        self.highlightHue = highlightHue
        self.vignette = vignette
        self.grainIntensity = grainIntensity
    }

    private enum CodingKeys: String, CodingKey {
        case exposure, contrast, saturation, temperature, tint
        case rgbShift, lensSoftness, detailSoftness, grainRadialMix, grainSize
        case bloomThreshold, bloomStrength, bloomRadius, diffusion
        case halationIntensity, halationSpread, halationHue, halationThreshold, halationRadius
        case bloomSoftKnee, halationSoftKnee, compressionAmount, compressionRange
        case printContrast, cyan, magenta, yellow
        case shutterAngle, trailIntensity, filmBreathAmount, dustAmount, scratchAmount
        case fade, shadowTone, shadowLatitude, blackPoint, toeContrast
        case highlightTone, shadowHue, highlightHue
        case vignette, grainIntensity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.exposure = try c.decode(Double.self, forKey: .exposure)
        self.contrast = try c.decode(Double.self, forKey: .contrast)
        self.saturation = try c.decode(Double.self, forKey: .saturation)
        self.temperature = try c.decode(Double.self, forKey: .temperature)
        self.tint = try c.decode(Double.self, forKey: .tint)
        self.rgbShift = try c.decode(Double.self, forKey: .rgbShift)
        self.lensSoftness = try c.decode(Double.self, forKey: .lensSoftness)
        self.detailSoftness = try c.decode(Double.self, forKey: .detailSoftness)
        self.grainRadialMix = try c.decode(Double.self, forKey: .grainRadialMix)
        self.grainSize = try c.decode(Double.self, forKey: .grainSize)
        self.bloomThreshold = try c.decode(Double.self, forKey: .bloomThreshold)
        self.bloomStrength = try c.decode(Double.self, forKey: .bloomStrength)
        self.bloomRadius = try c.decode(Double.self, forKey: .bloomRadius)
        self.diffusion = try c.decode(Double.self, forKey: .diffusion)
        self.halationIntensity = try c.decode(Double.self, forKey: .halationIntensity)
        self.halationSpread = try c.decode(Double.self, forKey: .halationSpread)
        self.halationHue = try c.decode(Double.self, forKey: .halationHue)
        self.halationThreshold = try c.decode(Double.self, forKey: .halationThreshold)
        self.halationRadius = try c.decode(Double.self, forKey: .halationRadius)
        self.bloomSoftKnee = try c.decode(Double.self, forKey: .bloomSoftKnee)
        self.halationSoftKnee = try c.decode(Double.self, forKey: .halationSoftKnee)
        self.compressionAmount = try c.decode(Double.self, forKey: .compressionAmount)
        self.compressionRange = try c.decode(Double.self, forKey: .compressionRange)
        self.printContrast = try c.decode(Double.self, forKey: .printContrast)
        self.cyan = try c.decode(Double.self, forKey: .cyan)
        self.magenta = try c.decode(Double.self, forKey: .magenta)
        self.yellow = try c.decode(Double.self, forKey: .yellow)
        self.shutterAngle = try c.decode(Double.self, forKey: .shutterAngle)
        self.trailIntensity = try c.decode(Double.self, forKey: .trailIntensity)
        self.filmBreathAmount = try c.decodeIfPresent(Double.self, forKey: .filmBreathAmount) ?? 0
        self.dustAmount = try c.decodeIfPresent(Double.self, forKey: .dustAmount) ?? 0
        self.scratchAmount = try c.decodeIfPresent(Double.self, forKey: .scratchAmount) ?? 0
        self.fade = try c.decode(Double.self, forKey: .fade)
        self.shadowTone = try c.decode(Double.self, forKey: .shadowTone)
        self.shadowLatitude = try c.decode(Double.self, forKey: .shadowLatitude)
        self.blackPoint = try c.decodeIfPresent(Double.self, forKey: .blackPoint) ?? 0
        self.toeContrast = try c.decodeIfPresent(Double.self, forKey: .toeContrast) ?? 0
        self.highlightTone = try c.decode(Double.self, forKey: .highlightTone)
        self.shadowHue = try c.decode(Double.self, forKey: .shadowHue)
        self.highlightHue = try c.decode(Double.self, forKey: .highlightHue)
        self.vignette = try c.decode(Double.self, forKey: .vignette)
        self.grainIntensity = try c.decode(Double.self, forKey: .grainIntensity)
    }
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
    var opticalFilterProfileId: String? = nil
    var videoTimingMode: FilmtoneVideoTimingMode? = nil
}

extension Phase0ExportRequestDTO {
    var sourceVideoFPS: Double? {
        FilmtoneVideoTimingPolicy.validFPS(
            sourceProbe?.frameRate ?? sourceProbe?.sourceVideoMetadata?.timing?.nominalFrameRate
        )
    }

    var videoTimingPolicy: FilmtoneVideoTimingPolicy {
        FilmtoneVideoTimingPolicy(
            mode: videoTimingMode ?? .normal,
            sourceFPS: sourceVideoFPS
        )
    }

    var effectiveOutputFPS: Int {
        videoTimingPolicy.isSlow24 ? videoTimingPolicy.targetFPS : output.fps
    }

    var effectivePreserveAudio: Bool {
        output.preserveAudio && !videoTimingPolicy.isSlow24
    }
}
