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

    public func highlightReelSegments(
        options: FilmtoneHighlightReelOptions = .standard
    ) -> [FilmtoneHighlightClipSegment] {
        FilmtoneHighlightClipSegment.segments(
            from: markers,
            sourceDurationSec: sourceIdentity.durationSec,
            sourceFps: sourceIdentity.fps,
            options: options
        )
    }
}

public enum FilmtoneHighlightReelOutputMode: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case combined
    case separate
}

public struct FilmtoneHighlightReelOptions: Codable, Equatable, Hashable, Sendable {
    public static let defaultClipDurationSec = 1.0
    public static let supportedClipDurationsSec: [Double] = [1.0, 3.0, 5.0, 10.0]

    public static let standard = FilmtoneHighlightReelOptions(
        clipDurationSec: defaultClipDurationSec,
        mergeOverlaps: true
    )

    public var clipDurationSec: Double
    public var mergeOverlaps: Bool

    public init(clipDurationSec: Double = 1.0, mergeOverlaps: Bool = true) {
        self.clipDurationSec = Self.normalizedClipDurationSec(clipDurationSec)
        self.mergeOverlaps = mergeOverlaps
    }

    public init(
        clipDurationSec: Double = defaultClipDurationSec,
        outputMode: FilmtoneHighlightReelOutputMode
    ) {
        self.init(
            clipDurationSec: clipDurationSec,
            mergeOverlaps: outputMode == .combined
        )
    }

    public static func normalizedClipDurationSec(_ value: Double) -> Double {
        value.isFinite && value > 0 ? value : defaultClipDurationSec
    }
}

public struct FilmtoneHighlightClipSegment: Codable, Equatable, Hashable, Sendable {
    public var markerIds: [String]
    public var sourceStartSec: Double
    public var sourceEndSec: Double
    public var durationSec: Double
    public var sourceStartFrame: Int?
    public var sourceEndFrame: Int?
    public var sourceFps: Double?

    public init(
        markerIds: [String],
        sourceStartSec: Double,
        sourceEndSec: Double,
        sourceFps: Double?
    ) {
        let start = sourceStartSec.isFinite ? max(0, sourceStartSec) : 0
        let end = sourceEndSec.isFinite ? max(start, sourceEndSec) : start
        let validFps = FilmtoneHighlightMarker.validFPS(sourceFps)

        self.markerIds = Self.uniqueMarkerIds(markerIds)
        self.sourceStartSec = start
        self.sourceEndSec = end
        self.durationSec = max(0, end - start)
        self.sourceFps = validFps
        self.sourceStartFrame = Self.frameIndex(seconds: start, fps: validFps)
        self.sourceEndFrame = Self.frameIndex(seconds: end, fps: validFps)
    }

    public static func segments(
        from markers: [FilmtoneHighlightMarker],
        sourceDurationSec: Double?,
        sourceFps: Double?,
        options: FilmtoneHighlightReelOptions = .standard
    ) -> [FilmtoneHighlightClipSegment] {
        let validDuration = sourceDurationSec.flatMap { value in
            value.isFinite && value > 0 ? value : nil
        }
        let validFps = FilmtoneHighlightMarker.validFPS(sourceFps)
        let clipDuration = options.clipDurationSec
        let halfDuration = clipDuration / 2.0

        let rawSegments = markers
            .filter { !$0.id.isEmpty && $0.sourceTimeSec.isFinite && $0.sourceTimeSec >= 0 }
            .sorted { lhs, rhs in
                if lhs.sourceTimeSec == rhs.sourceTimeSec {
                    return lhs.id < rhs.id
                }
                return lhs.sourceTimeSec < rhs.sourceTimeSec
            }
            .map { marker in
                let markerFps = validFps ?? marker.sourceFps
                let bounds = centeredBounds(
                    centerSec: marker.sourceTimeSec,
                    clipDurationSec: clipDuration,
                    halfDurationSec: halfDuration,
                    sourceDurationSec: validDuration
                )
                return FilmtoneHighlightClipSegment(
                    markerIds: [marker.id],
                    sourceStartSec: bounds.start,
                    sourceEndSec: bounds.end,
                    sourceFps: markerFps
                )
            }
            .filter { $0.durationSec > 0 }

        guard options.mergeOverlaps else {
            return rawSegments
        }
        return mergeOverlapping(rawSegments)
    }

    private static func centeredBounds(
        centerSec: Double,
        clipDurationSec: Double,
        halfDurationSec: Double,
        sourceDurationSec: Double?
    ) -> (start: Double, end: Double) {
        guard let sourceDurationSec else {
            let start = max(0, centerSec - halfDurationSec)
            return (start, start + clipDurationSec)
        }
        if sourceDurationSec <= clipDurationSec {
            return (0, sourceDurationSec)
        }

        let unclampedStart = centerSec - halfDurationSec
        let maxStart = sourceDurationSec - clipDurationSec
        let start = min(max(0, unclampedStart), maxStart)
        return (start, start + clipDurationSec)
    }

    private static func mergeOverlapping(
        _ segments: [FilmtoneHighlightClipSegment]
    ) -> [FilmtoneHighlightClipSegment] {
        var merged: [FilmtoneHighlightClipSegment] = []
        for segment in segments {
            guard var current = merged.popLast() else {
                merged.append(segment)
                continue
            }
            if segment.sourceStartSec <= current.sourceEndSec {
                current = FilmtoneHighlightClipSegment(
                    markerIds: current.markerIds + segment.markerIds,
                    sourceStartSec: current.sourceStartSec,
                    sourceEndSec: max(current.sourceEndSec, segment.sourceEndSec),
                    sourceFps: current.sourceFps ?? segment.sourceFps
                )
                merged.append(current)
            } else {
                merged.append(current)
                merged.append(segment)
            }
        }
        return merged
    }

    private static func uniqueMarkerIds(_ markerIds: [String]) -> [String] {
        var seen = Set<String>()
        return markerIds.filter { markerId in
            guard !markerId.isEmpty, !seen.contains(markerId) else {
                return false
            }
            seen.insert(markerId)
            return true
        }
    }

    private static func frameIndex(seconds: Double, fps: Double?) -> Int? {
        FilmtoneHighlightMarker.frameIndex(sourceTimeSec: seconds, fps: fps)
    }
}
