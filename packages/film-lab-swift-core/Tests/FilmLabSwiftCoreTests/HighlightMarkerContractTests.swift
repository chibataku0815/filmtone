import XCTest
import FilmLabSwiftCore

final class HighlightMarkerContractTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private func fixtureData(_ name: String) throws -> Data {
        let testFile = URL(fileURLWithPath: #filePath)
        let fixtures = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/highlight-markers")
        return try Data(contentsOf: fixtures.appendingPathComponent(name))
    }

    func testHighlightMarkersRoundTripWithDaVinciFriendlyKeys() throws {
        let payload = FilmtoneHighlightMarkers(
            sourceIdentity: FilmtoneMarkerSourceIdentity(
                filename: "C0061.mov",
                durationSec: 123.45,
                fps: 29.97,
                fileSizeBytes: 123_456_789
            ),
            markers: [
                FilmtoneHighlightMarker(
                    id: "filmtone-marker-001",
                    sourceTimeSec: 42.13,
                    sourceFps: 29.97,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-05-05T00:00:00.000Z"
                )
            ]
        )

        let data = try encoder.encode(payload)
        let decoded = try decoder.decode(FilmtoneHighlightMarkers.self, from: data)
        XCTAssertEqual(decoded, payload)
        XCTAssertEqual(decoded.schema, FilmtoneHighlightMarkers.schemaID)
        XCTAssertEqual(decoded.defaults.preRollSec, 2.0)
        XCTAssertEqual(decoded.defaults.postRollSec, 3.0)
        XCTAssertEqual(decoded.markers.first?.sourceFrame, 1263)

        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"sourceTimeSec\""))
        XCTAssertTrue(json.contains("\"sourceFrame\""))
        XCTAssertTrue(json.contains("\"createdOnPlatform\""))
    }

    func testSharedSidecarFixtureDecodesHighlightMarkers() throws {
        struct SidecarProbe: Decodable {
            let kind: String
            let schema: String
            let highlightMarkers: FilmtoneHighlightMarkers?
        }

        let data = try fixtureData("C0061.filmtone-ios-export-session-v1.json")
        let decoded = try decoder.decode(SidecarProbe.self, from: data)
        XCTAssertEqual(decoded.kind, "filmtone-export-session")
        XCTAssertEqual(decoded.schema, "filmtone-ios-export-session-v1")
        XCTAssertEqual(decoded.highlightMarkers?.schema, FilmtoneHighlightMarkers.schemaID)
        XCTAssertEqual(decoded.highlightMarkers?.sourceIdentity.filename, "C0061.mov")
        XCTAssertEqual(decoded.highlightMarkers?.markers.first?.id, "filmtone-marker-001")
        XCTAssertEqual(decoded.highlightMarkers?.markers.first?.sourceFrame, 1263)
    }

    func testMissingHighlightMarkersBlockIsValidForOldSidecars() throws {
        struct SidecarProbe: Decodable {
            let schema: String
            let highlightMarkers: FilmtoneHighlightMarkers?
        }

        let data = Data(#"{"schema":"filmtone-ios-export-session-v1"}"#.utf8)
        let decoded = try decoder.decode(SidecarProbe.self, from: data)
        XCTAssertEqual(decoded.schema, "filmtone-ios-export-session-v1")
        XCTAssertNil(decoded.highlightMarkers)
    }

    func testMarkerHelpersClampAndPreserveSourceRelativeTruth() {
        let defaults = FilmtoneMarkerDefaults(preRollSec: -1, postRollSec: 3)
        XCTAssertEqual(defaults.preRollSec, 0)
        XCTAssertEqual(defaults.postRollSec, 3)

        let marker = FilmtoneHighlightMarker(
            id: "m1",
            sourceTimeSec: 10.4,
            sourceFps: 24,
            defaults: defaults,
            createdOnPlatform: "macos",
            createdAtIso: "2026-05-05T01:00:00.000Z"
        )
        XCTAssertEqual(marker.sourceFrame, 250)
        XCTAssertEqual(marker.preRollSec, 0)
        XCTAssertEqual(marker.postRollSec, 3)

        let markers = FilmtoneHighlightMarkers(
            sourceIdentity: FilmtoneMarkerSourceIdentity(
                filename: "clip.mov",
                durationSec: 20,
                fps: 24,
                fileSizeBytes: 1000
            ),
            markers: [marker]
        )
        XCTAssertEqual(markers.marker(near: 10.5)?.id, "m1")
        XCTAssertNil(markers.marker(near: 10.8))
    }

    func testPublicMarkerAPIIsReachableFromPlainImport() {
        let identity = FilmtoneMarkerSourceIdentity(
            filename: "source.mov",
            durationSec: 8,
            fps: 30,
            fileSizeBytes: 256
        )
        let markers = FilmtoneHighlightMarkers(sourceIdentity: identity, markers: [])
        XCTAssertEqual(markers.schema, FilmtoneHighlightMarkers.schemaID)
        XCTAssertTrue(markers.isEmpty)
        XCTAssertEqual(FilmtoneHighlightMarker.frameIndex(sourceTimeSec: 1.5, fps: 30), 45)
    }

    func testHighlightReelSegmentsCenterMarkersAtOneSecond() {
        let markers = FilmtoneHighlightMarkers(
            sourceIdentity: FilmtoneMarkerSourceIdentity(
                filename: "source.mov",
                durationSec: 20,
                fps: 24,
                fileSizeBytes: 256
            ),
            markers: [
                FilmtoneHighlightMarker(
                    id: "m1",
                    sourceTimeSec: 10,
                    sourceFps: 24,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-05-05T01:00:00.000Z"
                )
            ]
        )

        let segments = markers.highlightReelSegments()

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].markerIds, ["m1"])
        XCTAssertEqual(segments[0].sourceStartSec, 9.5)
        XCTAssertEqual(segments[0].sourceEndSec, 10.5)
        XCTAssertEqual(segments[0].durationSec, 1.0)
        XCTAssertEqual(segments[0].sourceStartFrame, 228)
        XCTAssertEqual(segments[0].sourceEndFrame, 252)
    }

    func testHighlightReelSegmentsClampToSourceEdgesWhileKeepingOneSecondWhenPossible() {
        let identity = FilmtoneMarkerSourceIdentity(
            filename: "source.mov",
            durationSec: 10,
            fps: 30,
            fileSizeBytes: 256
        )
        let markers = FilmtoneHighlightMarkers(
            sourceIdentity: identity,
            markers: [
                FilmtoneHighlightMarker(
                    id: "start",
                    sourceTimeSec: 0.1,
                    sourceFps: 30,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-05-05T01:00:00.000Z"
                ),
                FilmtoneHighlightMarker(
                    id: "end",
                    sourceTimeSec: 9.9,
                    sourceFps: 30,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-05-05T01:00:01.000Z"
                )
            ]
        )

        let segments = markers.highlightReelSegments()

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].markerIds, ["start"])
        XCTAssertEqual(segments[0].sourceStartSec, 0)
        XCTAssertEqual(segments[0].sourceEndSec, 1)
        XCTAssertEqual(segments[1].markerIds, ["end"])
        XCTAssertEqual(segments[1].sourceStartSec, 9)
        XCTAssertEqual(segments[1].sourceEndSec, 10)
    }

    func testHighlightReelSegmentsUseWholeSourceWhenSourceIsShorterThanClip() {
        let markers = FilmtoneHighlightMarkers(
            sourceIdentity: FilmtoneMarkerSourceIdentity(
                filename: "short.mov",
                durationSec: 0.6,
                fps: 24,
                fileSizeBytes: 128
            ),
            markers: [
                FilmtoneHighlightMarker(
                    id: "m1",
                    sourceTimeSec: 0.3,
                    sourceFps: 24,
                    createdOnPlatform: "macos",
                    createdAtIso: "2026-05-05T01:00:00.000Z"
                )
            ]
        )

        let segments = markers.highlightReelSegments()

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].sourceStartSec, 0)
        XCTAssertEqual(segments[0].sourceEndSec, 0.6)
        XCTAssertEqual(segments[0].durationSec, 0.6)
    }

    func testHighlightReelSegmentsMergeOverlapsAndPreserveMarkerIds() {
        let markers = FilmtoneHighlightMarkers(
            sourceIdentity: FilmtoneMarkerSourceIdentity(
                filename: "source.mov",
                durationSec: 20,
                fps: 30,
                fileSizeBytes: 256
            ),
            markers: [
                FilmtoneHighlightMarker(
                    id: "m1",
                    sourceTimeSec: 5.0,
                    sourceFps: 30,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-05-05T01:00:00.000Z"
                ),
                FilmtoneHighlightMarker(
                    id: "m2",
                    sourceTimeSec: 5.8,
                    sourceFps: 30,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-05-05T01:00:01.000Z"
                )
            ]
        )

        let merged = markers.highlightReelSegments()
        let unmerged = markers.highlightReelSegments(
            options: FilmtoneHighlightReelOptions(clipDurationSec: 1.0, mergeOverlaps: false)
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].markerIds, ["m1", "m2"])
        XCTAssertEqual(merged[0].sourceStartSec, 4.5)
        XCTAssertEqual(merged[0].sourceEndSec, 6.3)
        XCTAssertEqual(unmerged.count, 2)
    }

    func testHighlightReelOptionsSupportLongerDurationsAndSeparateOutput() {
        let markers = FilmtoneHighlightMarkers(
            sourceIdentity: FilmtoneMarkerSourceIdentity(
                filename: "source.mov",
                durationSec: 20,
                fps: 30,
                fileSizeBytes: 256
            ),
            markers: [
                FilmtoneHighlightMarker(
                    id: "m1",
                    sourceTimeSec: 5.0,
                    sourceFps: 30,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-06-02T01:00:00.000Z"
                ),
                FilmtoneHighlightMarker(
                    id: "m2",
                    sourceTimeSec: 7.0,
                    sourceFps: 30,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-06-02T01:00:01.000Z"
                )
            ]
        )

        XCTAssertEqual(FilmtoneHighlightReelOptions.supportedClipDurationsSec, [1.0, 3.0, 5.0, 10.0])
        XCTAssertEqual(FilmtoneHighlightReelOptions(clipDurationSec: -1).clipDurationSec, 1.0)

        let combined = markers.highlightReelSegments(
            options: FilmtoneHighlightReelOptions(
                clipDurationSec: 5.0,
                outputMode: .combined
            )
        )
        let separate = markers.highlightReelSegments(
            options: FilmtoneHighlightReelOptions(
                clipDurationSec: 5.0,
                outputMode: .separate
            )
        )

        XCTAssertEqual(combined.count, 1)
        XCTAssertEqual(combined[0].markerIds, ["m1", "m2"])
        XCTAssertEqual(combined[0].sourceStartSec, 2.5)
        XCTAssertEqual(combined[0].sourceEndSec, 9.5)
        XCTAssertEqual(separate.count, 2)
        XCTAssertEqual(separate[0].markerIds, ["m1"])
        XCTAssertEqual(separate[0].durationSec, 5.0)
        XCTAssertEqual(separate[1].markerIds, ["m2"])
        XCTAssertEqual(separate[1].durationSec, 5.0)
    }

    func testHighlightReelSegmentsSkipInvalidMarkers() {
        let segments = FilmtoneHighlightClipSegment.segments(
            from: [
                FilmtoneHighlightMarker(
                    id: "",
                    sourceTimeSec: 1,
                    sourceFrame: nil,
                    sourceFps: 24,
                    preRollSec: 2,
                    postRollSec: 3,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-05-05T01:00:00.000Z"
                ),
                FilmtoneHighlightMarker(
                    id: "valid",
                    sourceTimeSec: 2,
                    sourceFps: 24,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-05-05T01:00:01.000Z"
                )
            ],
            sourceDurationSec: 10,
            sourceFps: 24
        )

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].markerIds, ["valid"])
    }
}
