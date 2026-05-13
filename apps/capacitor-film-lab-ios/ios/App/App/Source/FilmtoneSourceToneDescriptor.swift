import Foundation

/// Lightweight import-time descriptor of a source's tonal character.
/// Lives in its own UIKit-free file so the standalone focused tests can
/// link the resolver without dragging in `FilmtoneMediaTypes` (which
/// imports UIKit).
///
/// M1 Max Quality Look Director — `nightPracticalScore`,
/// `highKeyScore`, `lowSaturationFlatScore`, and `digitalHardnessScore`
/// are additive optional fields. Legacy probes leave them nil and the
/// resolver treats nil as "no signal".
struct FilmtoneSourceToneDescriptor: Codable, Equatable {
    let lumaP05: Double
    let lumaP50: Double
    let lumaP95: Double
    let lumaRangeP05P95: Double
    let shadowCoverage: Double
    let highlightCoverage: Double
    let lowMidCoverage: Double
    let saturationMean: Double
    let nightPracticalScore: Double?
    let highKeyScore: Double?
    let lowSaturationFlatScore: Double?
    let digitalHardnessScore: Double?

    init(
        lumaP05: Double,
        lumaP50: Double,
        lumaP95: Double,
        lumaRangeP05P95: Double,
        shadowCoverage: Double,
        highlightCoverage: Double,
        lowMidCoverage: Double,
        saturationMean: Double,
        nightPracticalScore: Double? = nil,
        highKeyScore: Double? = nil,
        lowSaturationFlatScore: Double? = nil,
        digitalHardnessScore: Double? = nil
    ) {
        self.lumaP05 = lumaP05
        self.lumaP50 = lumaP50
        self.lumaP95 = lumaP95
        self.lumaRangeP05P95 = lumaRangeP05P95
        self.shadowCoverage = shadowCoverage
        self.highlightCoverage = highlightCoverage
        self.lowMidCoverage = lowMidCoverage
        self.saturationMean = saturationMean
        self.nightPracticalScore = nightPracticalScore
        self.highKeyScore = highKeyScore
        self.lowSaturationFlatScore = lowSaturationFlatScore
        self.digitalHardnessScore = digitalHardnessScore
    }

    private enum CodingKeys: String, CodingKey {
        case lumaP05, lumaP50, lumaP95
        case lumaRangeP05P95
        case shadowCoverage, highlightCoverage, lowMidCoverage
        case saturationMean
        case nightPracticalScore
        case highKeyScore
        case lowSaturationFlatScore
        case digitalHardnessScore
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.lumaP05 = try c.decode(Double.self, forKey: .lumaP05)
        self.lumaP50 = try c.decode(Double.self, forKey: .lumaP50)
        self.lumaP95 = try c.decode(Double.self, forKey: .lumaP95)
        self.lumaRangeP05P95 = try c.decode(Double.self, forKey: .lumaRangeP05P95)
        self.shadowCoverage = try c.decode(Double.self, forKey: .shadowCoverage)
        self.highlightCoverage = try c.decode(Double.self, forKey: .highlightCoverage)
        self.lowMidCoverage = try c.decode(Double.self, forKey: .lowMidCoverage)
        self.saturationMean = try c.decode(Double.self, forKey: .saturationMean)
        self.nightPracticalScore = try c.decodeIfPresent(Double.self, forKey: .nightPracticalScore)
        self.highKeyScore = try c.decodeIfPresent(Double.self, forKey: .highKeyScore)
        self.lowSaturationFlatScore = try c.decodeIfPresent(Double.self, forKey: .lowSaturationFlatScore)
        self.digitalHardnessScore = try c.decodeIfPresent(Double.self, forKey: .digitalHardnessScore)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lumaP05, forKey: .lumaP05)
        try c.encode(lumaP50, forKey: .lumaP50)
        try c.encode(lumaP95, forKey: .lumaP95)
        try c.encode(lumaRangeP05P95, forKey: .lumaRangeP05P95)
        try c.encode(shadowCoverage, forKey: .shadowCoverage)
        try c.encode(highlightCoverage, forKey: .highlightCoverage)
        try c.encode(lowMidCoverage, forKey: .lowMidCoverage)
        try c.encode(saturationMean, forKey: .saturationMean)
        try c.encodeIfPresent(nightPracticalScore, forKey: .nightPracticalScore)
        try c.encodeIfPresent(highKeyScore, forKey: .highKeyScore)
        try c.encodeIfPresent(lowSaturationFlatScore, forKey: .lowSaturationFlatScore)
        try c.encodeIfPresent(digitalHardnessScore, forKey: .digitalHardnessScore)
    }
}
