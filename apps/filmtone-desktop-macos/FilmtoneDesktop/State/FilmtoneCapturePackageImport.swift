import Foundation

enum FilmtoneCapturePackageImportError: LocalizedError {
    case packageJSONNotFound(URL)
    case packageUnreadable(URL)
    case packageHasNoReachableMedia(captureId: String)

    var errorDescription: String? {
        switch self {
        case .packageJSONNotFound(let url):
            return "No capture-package.json found at \(url.lastPathComponent)"
        case .packageUnreadable(let url):
            return "Could not read capture package: \(url.lastPathComponent)"
        case .packageHasNoReachableMedia(let captureId):
            return "Capture package \(captureId) has no reachable master or proxy media."
        }
    }
}

enum FilmtoneCapturePackageSourceMode: String, Sendable, Equatable {
    case master
    case proxy
}

struct FilmtoneCapturePackageProvenance: Sendable, Equatable {
    let captureId: String
    let packageJSONPath: String
    let sourceMode: FilmtoneCapturePackageSourceMode
    let fallbackReason: String?
    let masterURLPath: String
    let proxyURLPath: String
    let selectedLookSlug: String?
    let selectedLookEnglishName: String?
    let customLutTitle: String?
    let customLutLibraryId: String?
    let customLutSourceHash: String?
    let customLutSize: Int?
    let customLutIntensity: Double?
    let customLutConversionPolicy: String?
    let customLutPayloadState: String?
    let customLutDataRef: String?
    let customLutDataFormat: String?
    let requestedStabilization: String?
    let observedStabilization: String?
    let requestedCaptureRotationDegrees: Double?
    let observedCaptureRotationDegrees: Double?
    let masterAudioTrackCount: Int?
}

struct FilmtoneImportedCapturePackage: Sendable, Equatable {
    let sourceURL: URL
    let packageJSONURL: URL
    let sourceProfileSelection: CameraProfileSelection
    let selectedLookSlug: String?
    let selectedLookId: UUID?
    let packageCreativeLut: PreparedCreativeLut?
    let customLutMissingReason: String?
    let provenance: FilmtoneCapturePackageProvenance
}

enum FilmtoneCapturePackageImporter {
    static let snapshotFilename = "capture-package.json"

    static func isCapturePackageCandidate(_ url: URL) -> Bool {
        if url.lastPathComponent == snapshotFilename {
            return true
        }
        if isDirectory(url) {
            return FileManager.default.fileExists(
                atPath: url.appendingPathComponent(snapshotFilename).path
            )
        }
        return false
    }

    static func importPackage(from url: URL) throws -> FilmtoneImportedCapturePackage {
        let jsonURL = try packageJSONURL(from: url)
        guard let data = try? Data(contentsOf: jsonURL),
              let snapshot = try? JSONDecoder().decode(CapturePackageSnapshot.self, from: data) else {
            throw FilmtoneCapturePackageImportError.packageUnreadable(jsonURL)
        }

        let source = try resolveSource(snapshot: snapshot, jsonURL: jsonURL)
        let selectedLook = resolveSelectedLook(snapshot: snapshot)
        let customLut = resolveCustomLut(snapshot: snapshot, jsonURL: jsonURL)
        let sourceProfileSelection = resolveSourceProfile(
            snapshot: snapshot,
            sourceMode: source.mode
        )
        let payloadState = customLut.payloadState
        let provenance = FilmtoneCapturePackageProvenance(
            captureId: snapshot.captureId,
            packageJSONPath: jsonURL.path,
            sourceMode: source.mode,
            fallbackReason: source.fallbackReason,
            masterURLPath: snapshot.masterURLPath,
            proxyURLPath: snapshot.proxyURLPath,
            selectedLookSlug: selectedLook?.slug ?? snapshot.selectedLookSlug,
            selectedLookEnglishName: snapshot.selectedLookEnglishName,
            customLutTitle: snapshot.customLutTitle,
            customLutLibraryId: snapshot.customLutLibraryId,
            customLutSourceHash: snapshot.customLutSourceHash,
            customLutSize: snapshot.customLutSize,
            customLutIntensity: snapshot.customLutIntensity,
            customLutConversionPolicy: snapshot.customLutConversionPolicy,
            customLutPayloadState: payloadState,
            customLutDataRef: snapshot.customLutDataRef,
            customLutDataFormat: snapshot.customLutDataFormat,
            requestedStabilization: snapshot.parametersRequestedStabilization,
            observedStabilization: snapshot.observedStabilization,
            requestedCaptureRotationDegrees: snapshot.requestedCaptureRotationDegrees,
            observedCaptureRotationDegrees: snapshot.observedCaptureRotationDegrees,
            masterAudioTrackCount: snapshot.masterAudioTrackCount
        )

        return FilmtoneImportedCapturePackage(
            sourceURL: source.url,
            packageJSONURL: jsonURL,
            sourceProfileSelection: sourceProfileSelection,
            selectedLookSlug: selectedLook?.slug,
            selectedLookId: selectedLook?.canonicalUUID,
            packageCreativeLut: customLut.prepared,
            customLutMissingReason: customLut.missingReason,
            provenance: provenance
        )
    }

    private static func packageJSONURL(from url: URL) throws -> URL {
        if isDirectory(url) {
            let candidate = url.appendingPathComponent(snapshotFilename, isDirectory: false)
            guard FileManager.default.fileExists(atPath: candidate.path) else {
                throw FilmtoneCapturePackageImportError.packageJSONNotFound(url)
            }
            return candidate
        }
        guard url.lastPathComponent == snapshotFilename else {
            throw FilmtoneCapturePackageImportError.packageJSONNotFound(url)
        }
        return url
    }

    private static func resolveSource(
        snapshot: CapturePackageSnapshot,
        jsonURL: URL
    ) throws -> (url: URL, mode: FilmtoneCapturePackageSourceMode, fallbackReason: String?) {
        if let master = existingURL(
            snapshotPath: snapshot.masterURLPath,
            jsonURL: jsonURL,
            packageDirPath: snapshot.packageDirURLPath
        ) {
            return (master, .master, nil)
        }
        if let proxy = existingURL(
            snapshotPath: snapshot.proxyURLPath,
            jsonURL: jsonURL,
            packageDirPath: snapshot.packageDirURLPath
        ) {
            return (proxy, .proxy, "master-unreachable")
        }
        throw FilmtoneCapturePackageImportError.packageHasNoReachableMedia(
            captureId: snapshot.captureId
        )
    }

    private static func existingURL(
        snapshotPath: String,
        jsonURL: URL,
        packageDirPath: String
    ) -> URL? {
        let absolute = URL(fileURLWithPath: snapshotPath)
        let candidates = [
            absolute,
            jsonURL.deletingLastPathComponent().appendingPathComponent(absolute.lastPathComponent),
            URL(fileURLWithPath: packageDirPath).appendingPathComponent(absolute.lastPathComponent),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func resolveSelectedLook(
        snapshot: CapturePackageSnapshot
    ) -> FilmtoneCreativePackCatalog.BuiltInLook? {
        if let uuidString = snapshot.selectedLookCanonicalUUID,
           let uuid = UUID(uuidString: uuidString),
           let look = FilmtoneCreativePackCatalog.find(canonicalUUID: uuid) {
            return look
        }
        if let slug = snapshot.selectedLookSlug {
            return FilmtoneCreativePackCatalog.find(slug: slug)
        }
        return nil
    }

    private static func resolveCustomLut(
        snapshot: CapturePackageSnapshot,
        jsonURL: URL
    ) -> (prepared: PreparedCreativeLut?, missingReason: String?, payloadState: String?) {
        guard let title = snapshot.customLutTitle,
              let size = snapshot.customLutSize,
              let intensity = snapshot.customLutIntensity else {
            return (nil, nil, nil)
        }

        guard let dataRef = snapshot.customLutDataRef,
              let dataFormat = snapshot.customLutDataFormat else {
            return (
                nil,
                "Custom LUT payload is missing for \(title).",
                "metadata-only"
            )
        }
        guard dataFormat == FilmtoneLutBlobCodec.dataFormat else {
            return (
                nil,
                "Custom LUT payload format is unsupported for \(title).",
                "unsupported-format"
            )
        }
        let candidates = [
            jsonURL.deletingLastPathComponent().appendingPathComponent(dataRef),
            URL(fileURLWithPath: snapshot.packageDirURLPath).appendingPathComponent(dataRef),
        ]
        guard let payloadURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let blob = try? Data(contentsOf: payloadURL) else {
            return (
                nil,
                "Custom LUT payload is missing for \(title).",
                "missing-file"
            )
        }
        let slug = "filmtone-package-custom-lut:\(snapshot.customLutSourceHash ?? title)"
        guard let prepared = FilmtoneCreativeLutLoader.preparePackageLocal(
            slug: slug,
            title: title,
            size: size,
            intensity: intensity,
            blob: blob,
            sourceHash: snapshot.customLutSourceHash
        ) else {
            return (
                nil,
                "Custom LUT payload could not be decoded for \(title).",
                "decode-failed"
            )
        }
        return (prepared, nil, "ready")
    }

    private static func resolveSourceProfile(
        snapshot: CapturePackageSnapshot,
        sourceMode: FilmtoneCapturePackageSourceMode
    ) -> CameraProfileSelection {
        guard sourceMode == .master else { return .auto }
        let colorSpace = snapshot.parametersColorSpace.lowercased()
        if colorSpace.contains("apple log 2") {
            return .builtIn(catalogId: "built-in:source-profile.apple-log-2")
        }
        if colorSpace.contains("apple log") {
            return .builtIn(catalogId: "built-in:source-profile.apple-log")
        }
        return .auto
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private struct CapturePackageSnapshot: Decodable {
        let schemaVersion: Int
        let captureId: String
        let storagePolicyTag: String
        let externalFolderPath: String?
        let masterURLPath: String
        let proxyURLPath: String
        let packageDirURLPath: String
        let durationLimitSeconds: Double
        let recordedDurationSeconds: Double
        let parametersWidthPx: Int
        let parametersHeightPx: Int
        let parametersFrameRate: Double
        let parametersCodec: String
        let parametersColorSpace: String
        let parametersStabilization: String
        let selectedLookCanonicalUUID: String?
        let selectedLookSlug: String?
        let selectedLookEnglishName: String?
        let selectedLookIntensity: Double?
        let customLutLibraryId: String?
        let customLutTitle: String?
        let customLutSize: Int?
        let customLutSourceHash: String?
        let customLutIntensity: Double?
        let customLutConversionPolicy: String?
        let customLutTransformWarningReason: String?
        let customLutTransformWarningKind: String?
        let customLutTransformWarningSignal: String?
        let customLutTransformWarningAccepted: Bool?
        let customLutDataRef: String?
        let customLutDataFormat: String?
        let parametersRequestedStabilization: String?
        let observedStabilization: String?
        let requestedCaptureRotationDegrees: Double?
        let observedCaptureRotationDegrees: Double?
        let masterAudioTrackCount: Int?
    }
}
