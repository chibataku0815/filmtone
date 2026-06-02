import Foundation

public struct FilmtonePhase0Params: Codable, Equatable, Hashable, Sendable {
    public var exposure: Double
    public var contrast: Double
    public var saturation: Double
    public var temperature: Double
    public var tint: Double
    public var rgbShift: Double
    public var lensSoftness: Double
    public var detailSoftness: Double
    public var grainRadialMix: Double
    public var grainSize: Double
    public var bloomThreshold: Double
    public var bloomStrength: Double
    public var bloomRadius: Double
    public var diffusion: Double
    public var halationIntensity: Double
    public var halationSpread: Double
    public var halationHue: Double
    public var halationThreshold: Double
    public var halationRadius: Double
    public var bloomSoftKnee: Double
    public var halationSoftKnee: Double
    public var compressionAmount: Double
    public var compressionRange: Double
    public var printContrast: Double
    public var cyan: Double
    public var magenta: Double
    public var yellow: Double
    public var shutterAngle: Double
    public var trailIntensity: Double
    public var filmBreathAmount: Double
    public var dustAmount: Double
    public var scratchAmount: Double
    public var fade: Double
    public var shadowTone: Double
    public var shadowLatitude: Double
    public var blackPoint: Double
    public var toeContrast: Double
    public var highlightTone: Double
    public var shadowHue: Double
    public var highlightHue: Double
    public var vignette: Double
    public var grainIntensity: Double

    public init(
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
        filmBreathAmount: Double,
        dustAmount: Double = 0,
        scratchAmount: Double = 0,
        fade: Double,
        shadowTone: Double,
        shadowLatitude: Double,
        blackPoint: Double,
        toeContrast: Double,
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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ParamCodingKey.self)

        func decode(_ key: String) throws -> Double {
            try c.decode(Double.self, forKey: ParamCodingKey(key))
        }

        func decodeDefaultingZero(_ key: String) throws -> Double {
            try c.decodeIfPresent(Double.self, forKey: ParamCodingKey(key)) ?? 0
        }

        self.exposure = try decode("exposure")
        self.contrast = try decode("contrast")
        self.saturation = try decode("saturation")
        self.temperature = try decode("temperature")
        self.tint = try decode("tint")
        self.rgbShift = try decode("rgbShift")
        self.lensSoftness = try decode("lensSoftness")
        self.detailSoftness = try decodeDefaultingZero("detailSoftness")
        self.grainRadialMix = try decode("grainRadialMix")
        self.grainSize = try decode("grainSize")
        self.bloomThreshold = try decode("bloomThreshold")
        self.bloomStrength = try decode("bloomStrength")
        self.bloomRadius = try decode("bloomRadius")
        self.diffusion = try decode("diffusion")
        self.halationIntensity = try decode("halationIntensity")
        self.halationSpread = try decode("halationSpread")
        self.halationHue = try decode("halationHue")
        self.halationThreshold = try decode("halationThreshold")
        self.halationRadius = try decode("halationRadius")
        self.bloomSoftKnee = try decode("bloomSoftKnee")
        self.halationSoftKnee = try decode("halationSoftKnee")
        self.compressionAmount = try decode("compressionAmount")
        self.compressionRange = try decode("compressionRange")
        self.printContrast = try decode("printContrast")
        self.cyan = try decode("cyan")
        self.magenta = try decode("magenta")
        self.yellow = try decode("yellow")
        self.shutterAngle = try decode("shutterAngle")
        self.trailIntensity = try decode("trailIntensity")
        self.filmBreathAmount = try decodeDefaultingZero("filmBreathAmount")
        self.dustAmount = try decodeDefaultingZero("dustAmount")
        self.scratchAmount = try decodeDefaultingZero("scratchAmount")
        self.fade = try decode("fade")
        self.shadowTone = try decode("shadowTone")
        self.shadowLatitude = try decode("shadowLatitude")
        self.blackPoint = try decodeDefaultingZero("blackPoint")
        self.toeContrast = try decodeDefaultingZero("toeContrast")
        self.highlightTone = try decode("highlightTone")
        self.shadowHue = try decode("shadowHue")
        self.highlightHue = try decode("highlightHue")
        self.vignette = try decode("vignette")
        self.grainIntensity = try decode("grainIntensity")
    }

    public static let reset = FilmtonePhase0Generated.resetParams

    // WritableKeyPath is not Sendable. The dictionary is initialized once and
    // read-only thereafter, so concurrent reads from any consumer are safe.
    public nonisolated(unsafe) static let keyPaths: [String: WritableKeyPath<FilmtonePhase0Params, Double>] = [
        "exposure": \.exposure,
        "contrast": \.contrast,
        "saturation": \.saturation,
        "temperature": \.temperature,
        "tint": \.tint,
        "rgbShift": \.rgbShift,
        "lensSoftness": \.lensSoftness,
        "detailSoftness": \.detailSoftness,
        "grainRadialMix": \.grainRadialMix,
        "grainSize": \.grainSize,
        "bloomThreshold": \.bloomThreshold,
        "bloomStrength": \.bloomStrength,
        "bloomRadius": \.bloomRadius,
        "diffusion": \.diffusion,
        "halationIntensity": \.halationIntensity,
        "halationSpread": \.halationSpread,
        "halationHue": \.halationHue,
        "halationThreshold": \.halationThreshold,
        "halationRadius": \.halationRadius,
        "bloomSoftKnee": \.bloomSoftKnee,
        "halationSoftKnee": \.halationSoftKnee,
        "compressionAmount": \.compressionAmount,
        "compressionRange": \.compressionRange,
        "printContrast": \.printContrast,
        "cyan": \.cyan,
        "magenta": \.magenta,
        "yellow": \.yellow,
        "shutterAngle": \.shutterAngle,
        "trailIntensity": \.trailIntensity,
        "filmBreathAmount": \.filmBreathAmount,
        "dustAmount": \.dustAmount,
        "scratchAmount": \.scratchAmount,
        "fade": \.fade,
        "shadowTone": \.shadowTone,
        "shadowLatitude": \.shadowLatitude,
        "blackPoint": \.blackPoint,
        "toeContrast": \.toeContrast,
        "highlightTone": \.highlightTone,
        "shadowHue": \.shadowHue,
        "highlightHue": \.highlightHue,
        "vignette": \.vignette,
        "grainIntensity": \.grainIntensity,
    ]

    public func value(for key: String) -> Double {
        guard let keyPath = Self.keyPaths[key] else {
            return 0
        }
        return self[keyPath: keyPath]
    }

    public mutating func setValue(_ value: Double, for key: String) {
        guard let keyPath = Self.keyPaths[key] else {
            return
        }
        self[keyPath: keyPath] = value
    }

    public func applyingPatch(_ patch: FilmtonePhase0ParamsPatch?) -> FilmtonePhase0Params {
        guard let patch else {
            return self
        }
        var next = self
        for (key, value) in patch.values {
            next.setValue(value, for: key)
        }
        return next
    }

    private struct ParamCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init(_ stringValue: String) {
            self.stringValue = stringValue
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }
}

public struct FilmtonePhase0HiddenDefaults: Equatable, Hashable, Sendable {
    public let depthMistGain: Double
    public let depthGlowGain: Double
    public let depthRayAngleGamma: Double
    public let depthRayAngleInnerThreshold: Double
    public let depthMistRayAngleGain: Double
    public let depthBloomRayAngleGain: Double
    public let depthHalationRayAngleGain: Double
    public let depthMistFieldPsfGain: Double
    public let depthBloomFieldPsfGain: Double
    public let depthHalationFieldPsfGain: Double
    public let depthMistFieldPsfRadiusPx: Double
    public let depthBloomFieldPsfRadiusPx: Double
    public let depthHalationFieldPsfRadiusPx: Double
    public let crossFilterDepthGain: Double
    public let crossFilterAngleGain: Double
    public let crossFilterAngleGamma: Double
    public let crossFilterAngleInnerThreshold: Double
    public let crossFilterEdgeLengthGain: Double
    public let crossFilterEdgeStrengthGain: Double
    public let haloPrismStrength: Double
    public let haloPrismRadius: Double
    public let haloPrismWidth: Double
    public let haloPrismChromatic: Double
    public let haloPrismThreshold: Double
    public let haloPrismSplit: Double
    public let haloPrismAngle: Double
    public let haloPrismSourceReactivity: Double
    public let opticalDirectTransmission: Double
    public let opticalBlackRetention: Double
    public let opticalScatterStrength: Double
    public let opticalHighlightReactivity: Double
    public let opticalWarmScatter: Double
    public let opticalSpectralTail: Double

    public init(
        depthMistGain: Double,
        depthGlowGain: Double,
        depthRayAngleGamma: Double,
        depthRayAngleInnerThreshold: Double,
        depthMistRayAngleGain: Double,
        depthBloomRayAngleGain: Double,
        depthHalationRayAngleGain: Double,
        depthMistFieldPsfGain: Double,
        depthBloomFieldPsfGain: Double,
        depthHalationFieldPsfGain: Double,
        depthMistFieldPsfRadiusPx: Double,
        depthBloomFieldPsfRadiusPx: Double,
        depthHalationFieldPsfRadiusPx: Double,
        crossFilterDepthGain: Double,
        crossFilterAngleGain: Double,
        crossFilterAngleGamma: Double,
        crossFilterAngleInnerThreshold: Double,
        crossFilterEdgeLengthGain: Double,
        crossFilterEdgeStrengthGain: Double,
        haloPrismStrength: Double,
        haloPrismRadius: Double,
        haloPrismWidth: Double,
        haloPrismChromatic: Double,
        haloPrismThreshold: Double,
        haloPrismSplit: Double,
        haloPrismAngle: Double,
        haloPrismSourceReactivity: Double,
        opticalDirectTransmission: Double,
        opticalBlackRetention: Double,
        opticalScatterStrength: Double,
        opticalHighlightReactivity: Double,
        opticalWarmScatter: Double,
        opticalSpectralTail: Double
    ) {
        self.depthMistGain = depthMistGain
        self.depthGlowGain = depthGlowGain
        self.depthRayAngleGamma = depthRayAngleGamma
        self.depthRayAngleInnerThreshold = depthRayAngleInnerThreshold
        self.depthMistRayAngleGain = depthMistRayAngleGain
        self.depthBloomRayAngleGain = depthBloomRayAngleGain
        self.depthHalationRayAngleGain = depthHalationRayAngleGain
        self.depthMistFieldPsfGain = depthMistFieldPsfGain
        self.depthBloomFieldPsfGain = depthBloomFieldPsfGain
        self.depthHalationFieldPsfGain = depthHalationFieldPsfGain
        self.depthMistFieldPsfRadiusPx = depthMistFieldPsfRadiusPx
        self.depthBloomFieldPsfRadiusPx = depthBloomFieldPsfRadiusPx
        self.depthHalationFieldPsfRadiusPx = depthHalationFieldPsfRadiusPx
        self.crossFilterDepthGain = crossFilterDepthGain
        self.crossFilterAngleGain = crossFilterAngleGain
        self.crossFilterAngleGamma = crossFilterAngleGamma
        self.crossFilterAngleInnerThreshold = crossFilterAngleInnerThreshold
        self.crossFilterEdgeLengthGain = crossFilterEdgeLengthGain
        self.crossFilterEdgeStrengthGain = crossFilterEdgeStrengthGain
        self.haloPrismStrength = haloPrismStrength
        self.haloPrismRadius = haloPrismRadius
        self.haloPrismWidth = haloPrismWidth
        self.haloPrismChromatic = haloPrismChromatic
        self.haloPrismThreshold = haloPrismThreshold
        self.haloPrismSplit = haloPrismSplit
        self.haloPrismAngle = haloPrismAngle
        self.haloPrismSourceReactivity = haloPrismSourceReactivity
        self.opticalDirectTransmission = opticalDirectTransmission
        self.opticalBlackRetention = opticalBlackRetention
        self.opticalScatterStrength = opticalScatterStrength
        self.opticalHighlightReactivity = opticalHighlightReactivity
        self.opticalWarmScatter = opticalWarmScatter
        self.opticalSpectralTail = opticalSpectralTail
    }
}
