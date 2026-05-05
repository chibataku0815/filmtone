import Foundation

public struct FilmtonePhase0Params: Codable, Equatable, Hashable, Sendable {
    public var exposure: Double
    public var contrast: Double
    public var saturation: Double
    public var temperature: Double
    public var tint: Double
    public var rgbShift: Double
    public var lensSoftness: Double
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
    public var fade: Double
    public var shadowTone: Double
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
        fade: Double,
        shadowTone: Double,
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
        self.fade = fade
        self.shadowTone = shadowTone
        self.highlightTone = highlightTone
        self.shadowHue = shadowHue
        self.highlightHue = highlightHue
        self.vignette = vignette
        self.grainIntensity = grainIntensity
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
        "fade": \.fade,
        "shadowTone": \.shadowTone,
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
        crossFilterEdgeStrengthGain: Double
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
    }
}
