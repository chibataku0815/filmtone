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
}
