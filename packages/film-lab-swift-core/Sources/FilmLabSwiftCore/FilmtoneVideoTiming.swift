import Foundation

public enum FilmtoneVideoTimingMode: String, Codable, CaseIterable, Sendable {
    case normal
    case slow24
}

public struct FilmtoneVideoTimingPolicy: Equatable, Sendable {
    public static let slowTargetFPS: Double = 24.0
    public static let slowEligibilityThresholdFPS: Double = 24.01

    public let requestedMode: FilmtoneVideoTimingMode
    public let sourceFPS: Double?

    public init(
        mode: FilmtoneVideoTimingMode,
        sourceFPS: Double?
    ) {
        self.requestedMode = mode
        self.sourceFPS = Self.validFPS(sourceFPS)
    }

    public var resolvedMode: FilmtoneVideoTimingMode {
        guard requestedMode == .slow24,
              Self.isSlow24Eligible(sourceFPS: sourceFPS) else {
            return .normal
        }
        return .slow24
    }

    public var isSlow24: Bool {
        resolvedMode == .slow24
    }

    public var targetFPS: Int {
        isSlow24 ? Int(Self.slowTargetFPS) : Int((sourceFPS ?? Self.slowTargetFPS).rounded())
    }

    public var speedMultiplier: Double {
        guard isSlow24, let sourceFPS, sourceFPS > 0 else {
            return 1.0
        }
        return Self.slowTargetFPS / sourceFPS
    }

    public static func isSlow24Eligible(sourceFPS: Double?) -> Bool {
        guard let fps = validFPS(sourceFPS) else {
            return false
        }
        return fps > slowEligibilityThresholdFPS
    }

    public static func validFPS(_ fps: Double?) -> Double? {
        guard let fps, fps.isFinite, fps > 0 else {
            return nil
        }
        return fps
    }

    public func displayDuration(sourceDuration: Double?) -> Double? {
        guard let sourceDuration, sourceDuration.isFinite, sourceDuration > 0 else {
            return sourceDuration
        }
        guard isSlow24 else {
            return sourceDuration
        }
        return sourceDuration / speedMultiplier
    }

    public func sourceTime(forDisplayTime displayTime: Double) -> Double {
        guard isSlow24 else {
            return displayTime
        }
        return max(0, displayTime) * speedMultiplier
    }

    public func displayTime(forSourceTime sourceTime: Double) -> Double {
        guard isSlow24 else {
            return sourceTime
        }
        return max(0, sourceTime) / speedMultiplier
    }

    public func outputDuration(
        sourceDuration: Double?,
        sourceFrameCount: Int? = nil
    ) -> Double? {
        guard isSlow24 else {
            return sourceDuration
        }
        if let sourceFrameCount, sourceFrameCount > 0 {
            return Double(sourceFrameCount) / Self.slowTargetFPS
        }
        return displayDuration(sourceDuration: sourceDuration)
    }
}

public struct FilmtoneVideoTimingMetadataDTO: Codable, Equatable, Sendable {
    public let videoTimingMode: String
    public let sourceFps: Double?
    public let targetFps: Int
    public let speedMultiplier: Double
    public let sourceDurationSec: Double?
    public let outputDurationSec: Double?
    public let audioPolicy: String

    public init(
        videoTimingMode: String,
        sourceFps: Double?,
        targetFps: Int,
        speedMultiplier: Double,
        sourceDurationSec: Double?,
        outputDurationSec: Double?,
        audioPolicy: String
    ) {
        self.videoTimingMode = videoTimingMode
        self.sourceFps = sourceFps
        self.targetFps = targetFps
        self.speedMultiplier = speedMultiplier
        self.sourceDurationSec = sourceDurationSec
        self.outputDurationSec = outputDurationSec
        self.audioPolicy = audioPolicy
    }

    public static func make(
        policy: FilmtoneVideoTimingPolicy,
        sourceDurationSec: Double?,
        sourceFrameCount: Int? = nil
    ) -> FilmtoneVideoTimingMetadataDTO {
        FilmtoneVideoTimingMetadataDTO(
            videoTimingMode: policy.resolvedMode.rawValue,
            sourceFps: policy.sourceFPS,
            targetFps: policy.targetFPS,
            speedMultiplier: policy.speedMultiplier,
            sourceDurationSec: sourceDurationSec,
            outputDurationSec: policy.outputDuration(
                sourceDuration: sourceDurationSec,
                sourceFrameCount: sourceFrameCount
            ),
            audioPolicy: policy.isSlow24 ? "none" : "preserve-source"
        )
    }
}
