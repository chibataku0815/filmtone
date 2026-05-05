import Foundation

public struct FilmtoneMarkerSourceIdentity: Codable, Equatable, Hashable, Sendable {
    public var filename: String?
    public var durationSec: Double?
    public var fps: Double?
    public var fileSizeBytes: Int64?
    public var contentHash: String?

    public init(
        filename: String?,
        durationSec: Double?,
        fps: Double?,
        fileSizeBytes: Int64?,
        contentHash: String? = nil
    ) {
        self.filename = filename
        self.durationSec = durationSec
        self.fps = fps
        self.fileSizeBytes = fileSizeBytes
        self.contentHash = contentHash
    }
}

public struct FilmtoneMarkerDefaults: Codable, Equatable, Hashable, Sendable {
    public static let standard = FilmtoneMarkerDefaults(preRollSec: 2.0, postRollSec: 3.0)

    public var preRollSec: Double
    public var postRollSec: Double

    public init(preRollSec: Double, postRollSec: Double) {
        self.preRollSec = max(0, preRollSec)
        self.postRollSec = max(0, postRollSec)
    }
}

public struct FilmtoneHighlightMarker: Codable, Equatable, Hashable, Sendable {
    public static let defaultColor = "Blue"
    public static let defaultName = "Highlight"
    public static let duplicateToleranceSec = 0.25

    public var id: String
    public var sourceTimeSec: Double
    public var sourceFrame: Int?
    public var sourceFps: Double?
    public var preRollSec: Double
    public var postRollSec: Double
    public var color: String
    public var name: String
    public var note: String
    public var createdOnPlatform: String
    public var createdAtIso: String
    public var updatedAtIso: String?

    public init(
        id: String,
        sourceTimeSec: Double,
        sourceFrame: Int?,
        sourceFps: Double?,
        preRollSec: Double,
        postRollSec: Double,
        color: String = defaultColor,
        name: String = defaultName,
        note: String = "",
        createdOnPlatform: String,
        createdAtIso: String,
        updatedAtIso: String? = nil
    ) {
        self.id = id
        self.sourceTimeSec = max(0, sourceTimeSec)
        self.sourceFrame = sourceFrame.map { max(0, $0) }
        self.sourceFps = Self.validFPS(sourceFps)
        self.preRollSec = max(0, preRollSec)
        self.postRollSec = max(0, postRollSec)
        self.color = color
        self.name = name
        self.note = note
        self.createdOnPlatform = createdOnPlatform
        self.createdAtIso = createdAtIso
        self.updatedAtIso = updatedAtIso
    }

    public init(
        id: String,
        sourceTimeSec: Double,
        sourceFps: Double?,
        defaults: FilmtoneMarkerDefaults = .standard,
        color: String = defaultColor,
        name: String = defaultName,
        note: String = "",
        createdOnPlatform: String,
        createdAtIso: String,
        updatedAtIso: String? = nil
    ) {
        let validFps = Self.validFPS(sourceFps)
        self.init(
            id: id,
            sourceTimeSec: sourceTimeSec,
            sourceFrame: Self.frameIndex(sourceTimeSec: sourceTimeSec, fps: validFps),
            sourceFps: validFps,
            preRollSec: defaults.preRollSec,
            postRollSec: defaults.postRollSec,
            color: color,
            name: name,
            note: note,
            createdOnPlatform: createdOnPlatform,
            createdAtIso: createdAtIso,
            updatedAtIso: updatedAtIso
        )
    }

    public static func frameIndex(sourceTimeSec: Double, fps: Double?) -> Int? {
        guard sourceTimeSec.isFinite,
              sourceTimeSec >= 0,
              let fps = validFPS(fps) else {
            return nil
        }
        return max(0, Int((sourceTimeSec * fps).rounded(.toNearestOrAwayFromZero)))
    }

    public static func validFPS(_ fps: Double?) -> Double? {
        guard let fps, fps.isFinite, fps > 0 else {
            return nil
        }
        return fps
    }
}

public struct FilmtoneHighlightMarkers: Codable, Equatable, Hashable, Sendable {
    public static let schemaID = "filmtone-highlight-markers-v1"

    public var schema: String
    public var sourceIdentity: FilmtoneMarkerSourceIdentity
    public var defaults: FilmtoneMarkerDefaults
    public var markers: [FilmtoneHighlightMarker]

    public init(
        schema: String = schemaID,
        sourceIdentity: FilmtoneMarkerSourceIdentity,
        defaults: FilmtoneMarkerDefaults = .standard,
        markers: [FilmtoneHighlightMarker]
    ) {
        self.schema = schema
        self.sourceIdentity = sourceIdentity
        self.defaults = defaults
        self.markers = markers.sorted { lhs, rhs in
            if lhs.sourceTimeSec == rhs.sourceTimeSec {
                return lhs.id < rhs.id
            }
            return lhs.sourceTimeSec < rhs.sourceTimeSec
        }
    }

    public var isEmpty: Bool {
        markers.isEmpty
    }

    public func marker(near sourceTimeSec: Double, toleranceSec: Double = FilmtoneHighlightMarker.duplicateToleranceSec) -> FilmtoneHighlightMarker? {
        markers.first { abs($0.sourceTimeSec - sourceTimeSec) <= toleranceSec }
    }

    public func replacingOrAppending(_ marker: FilmtoneHighlightMarker) -> FilmtoneHighlightMarkers {
        var next = markers.filter { $0.id != marker.id }
        next.append(marker)
        return FilmtoneHighlightMarkers(
            schema: schema,
            sourceIdentity: sourceIdentity,
            defaults: defaults,
            markers: next
        )
    }
}
