import Foundation

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure(description: message)
    }
}

@main
private struct CapturePackagePersistenceTest {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmtone-ios-capture-package-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let lutValues = stride(from: 0, to: 24, by: 1).map { Double($0) / 23.0 }
        let lutBlob = try FilmtoneLutBlobCodec.encode(data: lutValues, size: 2)
        let lutHash = try FilmtoneLutBlobCodec.sourceHash(data: lutValues, size: 2)

        let customLut = FilmtoneCaptureCustomLutRecord(
            libraryId: UUID(uuidString: "11111111-2222-4333-8444-555555555555"),
            title: "Roundtrip LUT",
            size: 2,
            sourceHash: lutHash,
            intensity: 0.6,
            conversionPolicy: FilmtoneCaptureCustomLutRecord.captureConversionPolicy,
            transformWarningReason: nil,
            transformWarningKind: nil,
            transformWarningSignal: nil,
            transformWarningAccepted: true
        )
        let payload = FilmtoneCaptureCustomLutPayload(
            dataRef: FilmtoneCaptureCustomLutPayload.defaultDataRef,
            dataFormat: FilmtoneCaptureCustomLutPayload.dataFormat,
            blob: lutBlob
        )
        let package = FilmtoneCapturePackage(
            captureId: "roundtrip",
            storagePolicy: .internalDocumentsCapped,
            masterURL: root.appendingPathComponent("master.mov"),
            proxyURL: root.appendingPathComponent("proxy.mov"),
            packageDirURL: root,
            durationLimitSeconds: 10,
            recordedDurationSeconds: 3,
            parameters: .baseline,
            lens: nil,
            selectedLook: nil,
            customLut: customLut,
            customLutPayload: payload,
            exposureControl: nil,
            whiteBalance: nil,
            masterBookmark: nil,
            observedStabilization: "cinematicExtendedEnhanced",
            requestedCaptureRotationDegrees: 90,
            observedCaptureRotationDegrees: 90,
            masterAudioTrackCount: 1
        )

        guard let jsonURL = FilmtoneCapturePackagePersistence.write(package: package) else {
            throw TestFailure(description: "write returned nil")
        }
        let writtenLutURL = root.appendingPathComponent(FilmtoneCaptureCustomLutPayload.defaultDataRef)
        try expect(FileManager.default.fileExists(atPath: writtenLutURL.path), "custom LUT blob was not written")

        let jsonObject = try JSONSerialization.jsonObject(with: Data(contentsOf: jsonURL)) as? [String: Any]
        try expect(
            jsonObject?["customLutDataRef"] as? String == FilmtoneCaptureCustomLutPayload.defaultDataRef,
            "customLutDataRef missing"
        )
        try expect(
            jsonObject?["customLutDataFormat"] as? String == FilmtoneCaptureCustomLutPayload.dataFormat,
            "customLutDataFormat missing"
        )

        guard let decoded = FilmtoneCapturePackagePersistence.read(localPackageJSONPath: jsonURL.path) else {
            throw TestFailure(description: "read returned nil")
        }
        try expect(decoded.customLut?.title == "Roundtrip LUT", "custom LUT metadata did not round-trip")
        try expect(
            decoded.customLutPayload?.dataRef == FilmtoneCaptureCustomLutPayload.defaultDataRef,
            "payload ref did not round-trip"
        )
        try expect(decoded.customLutPayload?.blob == lutBlob, "payload blob did not round-trip")

        var legacy = jsonObject ?? [:]
        legacy.removeValue(forKey: "customLutDataRef")
        legacy.removeValue(forKey: "customLutDataFormat")
        let legacyURL = root.appendingPathComponent("legacy-capture-package.json")
        try JSONSerialization.data(withJSONObject: legacy, options: [.prettyPrinted, .sortedKeys])
            .write(to: legacyURL)
        guard let legacyDecoded = FilmtoneCapturePackagePersistence.read(
            localPackageJSONPath: legacyURL.path
        ) else {
            throw TestFailure(description: "legacy read returned nil")
        }
        try expect(legacyDecoded.customLut?.title == "Roundtrip LUT", "legacy metadata did not decode")
        try expect(legacyDecoded.customLutPayload == nil, "legacy package should remain metadata-only")

        print("capture package persistence payload round-trip passed")
    }
}
