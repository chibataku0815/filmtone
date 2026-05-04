import Foundation

// Sparse patch over FilmtonePhase0Params, ported from iOS
// `FilmtonePhase0Math.swift` (struct + applyingPatch + setValue + keyPaths).
// Codable is intentionally omitted — the Desktop usage is in-memory only
// (built-in Look paramOverrides applied at preset-resolve time). Round-trip
// to disk happens through SidecarWriter, not through Patch encoding.

extension FilmtonePhase0Params {
    // WritableKeyPath is not Sendable. The dictionary is initialized once
    // and read-only thereafter, so concurrent reads from the export /
    // preview pipelines are safe — opt out of Swift 6 isolation checking.
    nonisolated(unsafe) static let keyPaths: [String: WritableKeyPath<FilmtonePhase0Params, Double>] = [
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

    func value(for key: String) -> Double {
        guard let keyPath = Self.keyPaths[key] else {
            return 0
        }
        return self[keyPath: keyPath]
    }

    mutating func setValue(_ value: Double, for key: String) {
        guard let keyPath = Self.keyPaths[key] else {
            return
        }
        self[keyPath: keyPath] = value
    }

    func applyingPatch(_ patch: FilmtonePhase0ParamsPatch?) -> FilmtonePhase0Params {
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

struct FilmtonePhase0ParamsPatch: Codable, Equatable, Hashable, Sendable {
    var values: [String: Double]

    static let empty = FilmtonePhase0ParamsPatch(values: [:])

    init(values: [String: Double] = [:]) {
        self.values = values
    }

    var isEmpty: Bool {
        values.isEmpty
    }
}
