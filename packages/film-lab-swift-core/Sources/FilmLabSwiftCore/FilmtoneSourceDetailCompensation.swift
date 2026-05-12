import Foundation

// Swift mirror of packages/film-lab-core/src/source-detail-compensation.ts.
// Recommended bias values, transfer classes, ids, and cascade order must
// match the TS resolver byte-for-byte so macOS native + iOS export render
// passes resolve `sourceDetailBias` the same way the TS resolver does for
// equivalent metadata bundles.
//
// Inputs are string-typed so the resolver does not depend on iOS / macOS
// DTO types. Callers pass `rawValue` of their `SourceLogTransferFunctionDTO`,
// `SourceCodecFamilyDTO`, `SourceColorClassDTO`,
// `SourceInputTransformStrategyDTO`, plus a `sourceProfileId` like
// `"built-in:source-profile.<slug>"`. Unknown / empty values resolve to
// the conservative `metadata-missing` / `log-unknown` branches just like
// the TS resolver.

public enum FilmtoneSourceDetailConfidence: String, Equatable, Sendable {
    case high
    case medium
    case low
    case none
}

public enum FilmtoneSourceDetailTransferClass: String, Equatable, Sendable {
    case rec709Consumer = "rec709-consumer"
    case rec709Cinema   = "rec709-cinema"
    case logConsumer    = "log-consumer"
    case logCinema      = "log-cinema"
    case unknown
}

public enum FilmtoneSourceDetailProfileId: String, Equatable, Sendable {
    case iphoneSdrHevc   = "iphone-sdr-hevc"
    case appleLog        = "apple-log"
    case djiAction       = "dji-action"
    case goproAction     = "gopro-action"
    case sonySLog3       = "sony-slog3"
    case canonCLog       = "canon-clog"
    case panasonicVLog   = "panasonic-vlog"
    case rec709Unknown   = "rec709-unknown"
    case logUnknown      = "log-unknown"
    case metadataMissing = "metadata-missing"
}

public struct FilmtoneSourceDetailProfile: Equatable, Sendable {
    public let id: FilmtoneSourceDetailProfileId
    public let confidence: FilmtoneSourceDetailConfidence
    public let transferClass: FilmtoneSourceDetailTransferClass
    public let recommendedBias: Double
    public let effectiveMax: Double
    public let reason: String

    public init(
        id: FilmtoneSourceDetailProfileId,
        confidence: FilmtoneSourceDetailConfidence,
        transferClass: FilmtoneSourceDetailTransferClass,
        recommendedBias: Double,
        effectiveMax: Double,
        reason: String
    ) {
        self.id = id
        self.confidence = confidence
        self.transferClass = transferClass
        self.recommendedBias = recommendedBias
        self.effectiveMax = effectiveMax
        self.reason = reason
    }
}

public struct FilmtoneSourceDetailCompensationInput: Equatable, Sendable {
    public var cameraMake: String?
    public var cameraModel: String?
    /// Raw value of `SourceLogTransferFunctionDTO` (`"apple-log"` /
    /// `"apple-log2"`). Anything else is ignored.
    public var logTransferFunction: String?
    /// Raw value of `SourceInputTransformStrategyDTO` (`"none"`,
    /// `"apple-log-to-rec709"`, `"apple-log2-to-rec709"`,
    /// `"core-image-tone-map-sdr"`, …). `"none"` is treated as
    /// no-signal.
    public var inputTransformStrategy: String?
    /// Raw value of `SourceCodecFamilyDTO` (`"hevc"`, `"h264"`,
    /// `"prores-422"`, …).
    public var codecFamily: String?
    /// Raw value of `SourceColorClassDTO` (`"sdr-bt709"`,
    /// `"apple-log"`, …).
    public var colorClass: String?
    /// Source-profile catalog id (`"built-in:source-profile.<slug>"`).
    public var sourceProfileId: String?

    public init(
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        logTransferFunction: String? = nil,
        inputTransformStrategy: String? = nil,
        codecFamily: String? = nil,
        colorClass: String? = nil,
        sourceProfileId: String? = nil
    ) {
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.logTransferFunction = logTransferFunction
        self.inputTransformStrategy = inputTransformStrategy
        self.codecFamily = codecFamily
        self.colorClass = colorClass
        self.sourceProfileId = sourceProfileId
    }
}

public enum FilmtoneSourceDetailCompensation {

    private static let appleLogInputStrategies: Set<String> = [
        "apple-log-to-rec709",
        "apple-log2-to-rec709",
    ]

    private static let appleLogSourceProfileIds: Set<String> = [
        "built-in:source-profile.apple-log",
        "built-in:source-profile.apple-log-2",
    ]

    private static let djiSourceProfileIds: Set<String> = [
        "built-in:source-profile.dji-dlog",
        "built-in:source-profile.dji-dlog-m",
    ]

    private static let canonLogSourceProfileIds: Set<String> = [
        "built-in:source-profile.canon-clog",
        "built-in:source-profile.canon-log3-cinema-gamut",
    ]

    private static let panasonicLogSourceProfileIds: Set<String> = [
        "built-in:source-profile.panasonic-vlog",
    ]

    private static let sonyLogSourceProfileIds: Set<String> = [
        "built-in:source-profile.sony-slog3",
    ]

    private static let appleColorClasses: Set<String> = [
        "apple-log",
        "apple-log2",
    ]

    private static let rec709ColorClasses: Set<String> = [
        "sdr-bt709",
    ]

    private static func clampBias(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return min(value, FilmtoneDetailSoftness.effectiveMax)
    }

    private static func normalizeText(_ text: String?) -> String {
        guard let text else { return "" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func makeProfile(
        id: FilmtoneSourceDetailProfileId,
        confidence: FilmtoneSourceDetailConfidence,
        transferClass: FilmtoneSourceDetailTransferClass,
        bias: Double,
        reason: String
    ) -> FilmtoneSourceDetailProfile {
        FilmtoneSourceDetailProfile(
            id: id,
            confidence: confidence,
            transferClass: transferClass,
            recommendedBias: clampBias(bias),
            effectiveMax: FilmtoneDetailSoftness.effectiveMax,
            reason: reason
        )
    }

    /// Resolve a profile for the supplied metadata bundle. Pure and
    /// deterministic — equivalent metadata always produces the same
    /// profile regardless of caller.
    public static func resolve(
        _ input: FilmtoneSourceDetailCompensationInput = FilmtoneSourceDetailCompensationInput()
    ) -> FilmtoneSourceDetailProfile {
        let make = normalizeText(input.cameraMake)
        let model = normalizeText(input.cameraModel)
        let profileId = input.sourceProfileId ?? ""
        let transferStrategy = input.inputTransformStrategy

        let appleLogTransfer =
            input.logTransferFunction == "apple-log" ||
            input.logTransferFunction == "apple-log2"
        let appleLogColorClass: Bool = {
            guard let colorClass = input.colorClass else { return false }
            return appleColorClasses.contains(colorClass)
        }()
        let appleLogStrategy: Bool = {
            guard let strategy = transferStrategy else { return false }
            return appleLogInputStrategies.contains(strategy)
        }()
        let appleLogProfile = appleLogSourceProfileIds.contains(profileId)

        if appleLogTransfer || appleLogColorClass || appleLogStrategy || appleLogProfile {
            let matched =
                (appleLogTransfer ? 1 : 0) +
                (appleLogColorClass ? 1 : 0) +
                (appleLogStrategy ? 1 : 0) +
                (appleLogProfile ? 1 : 0)
            let confidence: FilmtoneSourceDetailConfidence = matched >= 2 ? .high : .medium
            return makeProfile(
                id: .appleLog,
                confidence: confidence,
                transferClass: .logConsumer,
                bias: 0.06,
                reason: "apple-log-smaller-positive"
            )
        }

        if sonyLogSourceProfileIds.contains(profileId) || make == "sony" {
            return makeProfile(
                id: .sonySLog3,
                confidence: profileId.isEmpty ? .medium : .high,
                transferClass: .logCinema,
                bias: 0.02,
                reason: "sony-log-near-zero"
            )
        }

        if canonLogSourceProfileIds.contains(profileId) || make == "canon" {
            return makeProfile(
                id: .canonCLog,
                confidence: profileId.isEmpty ? .medium : .high,
                transferClass: .logCinema,
                bias: 0.02,
                reason: "canon-log-near-zero"
            )
        }

        if panasonicLogSourceProfileIds.contains(profileId) || make == "panasonic" {
            return makeProfile(
                id: .panasonicVLog,
                confidence: profileId.isEmpty ? .medium : .high,
                transferClass: .logCinema,
                bias: 0.02,
                reason: "panasonic-log-near-zero"
            )
        }

        if djiSourceProfileIds.contains(profileId) || make == "dji" {
            return makeProfile(
                id: .djiAction,
                confidence: profileId.isEmpty ? .medium : .high,
                transferClass: .rec709Consumer,
                bias: 0.08,
                reason: "dji-action-positive"
            )
        }

        if make == "gopro" {
            return makeProfile(
                id: .goproAction,
                confidence: .medium,
                transferClass: .rec709Consumer,
                bias: 0.08,
                reason: "gopro-action-positive"
            )
        }

        if make == "apple" || model.hasPrefix("iphone") {
            let codec = input.codecFamily
            let isProRes = codec == "prores-422" || codec == "prores-4444"
            let isHevc = codec == "hevc"
            let reasonCodec = isProRes ? "iphone-prores" : (isHevc ? "iphone-hevc" : "iphone-sdr")
            return makeProfile(
                id: .iphoneSdrHevc,
                confidence: .high,
                transferClass: .rec709Consumer,
                bias: 0.1,
                reason: "\(reasonCodec)-modest-positive"
            )
        }

        let hasLogTransfer = input.logTransferFunction != nil
        let hasLogStrategy =
            transferStrategy != nil && transferStrategy != "none"
        if hasLogTransfer || hasLogStrategy {
            return makeProfile(
                id: .logUnknown,
                confidence: .low,
                transferClass: .unknown,
                bias: 0,
                reason: "unknown-log-zero"
            )
        }

        let rec709ProfileMatch = profileId == "built-in:source-profile.rec709"
        let rec709ColorMatch: Bool = {
            guard let colorClass = input.colorClass else { return false }
            return rec709ColorClasses.contains(colorClass)
        }()
        if rec709ProfileMatch || rec709ColorMatch || input.codecFamily != nil {
            return makeProfile(
                id: .rec709Unknown,
                confidence: .low,
                transferClass: .rec709Consumer,
                bias: 0.02,
                reason: "unknown-rec709-tiny"
            )
        }

        return makeProfile(
            id: .metadataMissing,
            confidence: .none,
            transferClass: .unknown,
            bias: 0,
            reason: "metadata-missing-zero"
        )
    }
}
