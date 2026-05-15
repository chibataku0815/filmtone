import Foundation

public struct FilmtoneFilmBreathOffsets: Equatable, Hashable, Sendable {
    public let exposure: Double
    public let contrast: Double
    public let temperature: Double
    public let tint: Double

    public static let zero = FilmtoneFilmBreathOffsets(
        exposure: 0,
        contrast: 0,
        temperature: 0,
        tint: 0
    )

    public var isIdentity: Bool {
        exposure == 0 && contrast == 0 && temperature == 0 && tint == 0
    }
}

public enum FilmtoneFilmBreath {
    private static let exposureLimit = 0.16
    private static let contrastLimit = 0.055
    private static let temperatureLimit = 0.09
    private static let tintLimit = 0.04

    public static func deriveOffsets(
        amount: Double,
        timeSeconds: Double,
        sourceSeed: Double
    ) -> FilmtoneFilmBreathOffsets {
        let clampedAmount = clamp(amount, min: 0, max: 1)
        guard clampedAmount > 0, timeSeconds.isFinite, timeSeconds > 0 else {
            return .zero
        }

        let drive = pow(clampedAmount, 1.35)
        let envelope = smoothstep(timeSeconds / 1.25)
        let scale = drive * envelope
        guard scale > 0 else {
            return .zero
        }

        let seed = normalizeSeed(sourceSeed)
        return FilmtoneFilmBreathOffsets(
            exposure: breathNoise(timeSeconds: timeSeconds, seed: seed, salt: 0x4f1bbcdc) * exposureLimit * scale,
            contrast: breathNoise(timeSeconds: timeSeconds, seed: seed, salt: 0x9e2c6b6f) * contrastLimit * scale,
            temperature: breathNoise(timeSeconds: timeSeconds, seed: seed, salt: 0x27d4eb2f) * temperatureLimit * scale,
            tint: breathNoise(timeSeconds: timeSeconds, seed: seed, salt: 0x165667b1) * tintLimit * scale
        )
    }

    public static func applying(
        to params: FilmtonePhase0Params,
        timeSeconds: Double,
        sourceSeed: Double
    ) -> FilmtonePhase0Params {
        let offsets = deriveOffsets(
            amount: params.filmBreathAmount,
            timeSeconds: timeSeconds,
            sourceSeed: sourceSeed
        )
        guard !offsets.isIdentity else {
            return params
        }

        var next = params
        next.exposure = clamp(params.exposure + offsets.exposure, min: -2, max: 2)
        next.contrast = clamp(params.contrast + offsets.contrast, min: 0, max: 2)
        next.temperature = clamp(params.temperature + offsets.temperature, min: -1, max: 1)
        next.tint = clamp(params.tint + offsets.tint, min: -1, max: 1)
        return next
    }

    private static func breathNoise(timeSeconds: Double, seed: UInt32, salt: UInt32) -> Double {
        let slow = valueNoise(timeSeconds: timeSeconds, seed: seed, salt: salt, periodSeconds: 4.8)
        let medium = valueNoise(timeSeconds: timeSeconds, seed: seed, salt: salt ^ 0x6d2b79f5, periodSeconds: 8.6)
        let long = valueNoise(timeSeconds: timeSeconds, seed: seed, salt: salt ^ 0x1b873593, periodSeconds: 15.5)
        return clamp(slow * 0.56 + medium * 0.30 + long * 0.14, min: -1, max: 1)
    }

    private static func valueNoise(
        timeSeconds: Double,
        seed: UInt32,
        salt: UInt32,
        periodSeconds: Double
    ) -> Double {
        let phase = hashUnit(seed: seed, lattice: 0, salt: salt ^ 0xa511e9b3) * 8
        let position = timeSeconds / periodSeconds + phase
        let lattice = Int32(floor(position))
        let fraction = position - Double(lattice)
        let a = hashUnit(seed: seed, lattice: lattice, salt: salt) * 2 - 1
        let b = hashUnit(seed: seed, lattice: lattice &+ 1, salt: salt) * 2 - 1
        return a + (b - a) * smoothstep(fraction)
    }

    private static func hashUnit(seed: UInt32, lattice: Int32, salt: UInt32) -> Double {
        var x = seed
        x ^= UInt32(bitPattern: lattice) &* 0x9e3779b1
        x ^= salt &* 0x85ebca6b
        x ^= x >> 16
        x = x &* 0x7feb352d
        x ^= x >> 15
        x = x &* 0x846ca68b
        x ^= x >> 16
        return Double(x) / Double(UInt32.max)
    }

    private static func normalizeSeed(_ sourceSeed: Double) -> UInt32 {
        guard sourceSeed.isFinite else {
            return 0
        }
        return UInt32(clamping: Int(sourceSeed.magnitude.rounded(.towardZero)))
    }

    private static func smoothstep(_ t: Double) -> Double {
        let x = clamp(t, min: 0, max: 1)
        return x * x * (3 - 2 * x)
    }

    private static func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.min(maxValue, Swift.max(minValue, value))
    }
}
