import Foundation

public struct FilmtonePhase0ParamsPatch: Codable, Equatable, Hashable, Sendable {
    public var values: [String: Double]

    public static let empty = FilmtonePhase0ParamsPatch(values: [:])

    public init(values: [String: Double] = [:]) {
        self.values = values
    }

    public var isEmpty: Bool {
        values.isEmpty
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FilmtoneDynamicCodingKey.self)
        var values: [String: Double] = [:]

        for key in FilmtonePhase0Generated.paramKeys {
            guard let codingKey = FilmtoneDynamicCodingKey(stringValue: key) else {
                continue
            }
            if let value = try container.decodeIfPresent(Double.self, forKey: codingKey) {
                values[key] = value
            }
        }

        self.values = values
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: FilmtoneDynamicCodingKey.self)
        for key in FilmtonePhase0Generated.paramKeys {
            guard let value = values[key], let codingKey = FilmtoneDynamicCodingKey(stringValue: key) else {
                continue
            }
            try container.encode(value, forKey: codingKey)
        }
    }

    public func removingValue(for key: String) -> FilmtonePhase0ParamsPatch {
        var next = values
        next.removeValue(forKey: key)
        return .init(values: next)
    }

    /// Optical + glow parameter keys that every Look should carry as part of
    /// its identity. Built-in Looks (Stone / Urban) hardcode these; user-saved
    /// Looks pin them via `densifyingOpticsGlow(from:)` at save time so the
    /// Look's optical signature is preserved regardless of which preset it
    /// later lands on.
    public static let opticsGlowKeys: [String] = [
        "rgbShift", "lensSoftness", "detailSoftness", "vignette",
        "bloomThreshold", "bloomStrength", "bloomRadius", "bloomSoftKnee",
        "halationIntensity", "halationSpread", "halationHue",
        "halationThreshold", "halationRadius", "halationSoftKnee",
        "diffusion",
    ]

    /// Returns a patch with every optics + glow key explicitly pinned. Existing
    /// patch entries win; missing keys are filled from `resolved`. Used at Look
    /// save time so a Look stamps its optical signature into `paramOverrides`,
    /// not relying on the apply-time preset baseline to supply those values.
    public func densifyingOpticsGlow(from resolved: FilmtonePhase0Params) -> FilmtonePhase0ParamsPatch {
        var next = values
        for key in Self.opticsGlowKeys where next[key] == nil {
            next[key] = resolved.value(for: key)
        }
        return .init(values: next)
    }
}

private struct FilmtoneDynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
