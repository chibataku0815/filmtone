// Filmtone V2 native camera capture — capture package persistence (M10).
//
// `FilmtoneCapturePackage` is in-memory after `adoptCaptureResult(_:)`.
// On its own that means the master/proxy linkage evaporates on the next
// app launch — the editor would still find the proxy via the persisted
// SourceInfoDTO, but the master URL (and therefore "export the master",
// "share to camera roll from master", "reconnect SSD" affordances) would
// be lost.
//
// To survive a relaunch we write `capture-package.json` next to the
// proxy under `Caches/Filmtone/captures/<id>/` and (best-effort) mirror
// it into the security-scoped external folder when one is in use, so
// that re-discovering the SSD later still finds the linkage. The editor
// stores the local JSON path as `currentCapturePackageRef` in the
// persisted snapshot and re-hydrates `lastCapturePackage` from it on
// boot.

import Foundation

#if os(iOS)

/// On-disk shape of a capture package.  Mirrors `FilmtoneCapturePackage`
/// 1:1 with the storage policy flattened to a tag string + folder URL
/// (security-scoped URLs round-trip across launches via path string —
/// the user re-acquires scope by re-picking the folder, which is the
/// product affordance we want for "reconnect SSD" anyway).
struct FilmtoneCapturePackageSnapshotV1: Codable {
    var schemaVersion: Int
    var captureId: String
    var storagePolicyTag: String
    var externalFolderPath: String?
    var masterURLPath: String
    var proxyURLPath: String
    var packageDirURLPath: String
    var durationLimitSeconds: Double
    var recordedDurationSeconds: Double
    var parametersWidthPx: Int
    var parametersHeightPx: Int
    var parametersFrameRate: Double
    var parametersCodec: String
    var parametersColorSpace: String
    var parametersStabilization: String
    /// ISO8601 wall-clock timestamp of the snapshot write.  Useful for
    /// diagnostic banners ("recorded at …") without changing the
    /// capture pipeline.
    var writtenAtISO8601: String

    static let currentSchemaVersion = 1
}

enum FilmtoneCapturePackagePersistence {

    static let snapshotFilename = "capture-package.json"

    /// Write `capture-package.json` to the local package directory and,
    /// best-effort, mirror it into the external security-scoped folder
    /// that holds the master.  The mirror is best-effort because the
    /// user can revoke scope between recording finalize and this write
    /// — failing the mirror does NOT fail the capture.
    @discardableResult
    static func write(package: FilmtoneCapturePackage) -> URL? {
        let snapshot = makeSnapshot(from: package)
        guard let data = encode(snapshot: snapshot) else { return nil }

        let localURL = package.packageDirURL.appendingPathComponent(
            snapshotFilename, isDirectory: false
        )
        do {
            try FileManager.default.createDirectory(
                at: package.packageDirURL,
                withIntermediateDirectories: true
            )
            try data.write(to: localURL, options: .atomic)
        } catch {
            return nil
        }

        if case .externalSecurityScopedFolder(let folderURL) = package.storagePolicy {
            let mirror = folderURL.appendingPathComponent(
                "filmtone-capture-package-\(package.captureId).json",
                isDirectory: false
            )
            try? data.write(to: mirror, options: .atomic)
        }
        return localURL
    }

    /// Try to read a previously-written `capture-package.json`.  Caller
    /// passes the local JSON path persisted in
    /// `FilmtoneEditorStore.currentCapturePackageRef`.  Returns nil if
    /// the file no longer exists or is unreadable.
    static func read(localPackageJSONPath: String) -> FilmtoneCapturePackage? {
        let url = URL(fileURLWithPath: localPackageJSONPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(
            FilmtoneCapturePackageSnapshotV1.self, from: data
        ) else { return nil }
        return makePackage(from: snapshot)
    }

    // MARK: - Codec

    private static func makeSnapshot(
        from package: FilmtoneCapturePackage
    ) -> FilmtoneCapturePackageSnapshotV1 {
        let policyTag: String
        let externalPath: String?
        switch package.storagePolicy {
        case .externalSecurityScopedFolder(let url):
            policyTag = "external"
            externalPath = url.path
        case .internalDocumentsCapped:
            policyTag = "internal"
            externalPath = nil
        }
        return FilmtoneCapturePackageSnapshotV1(
            schemaVersion: FilmtoneCapturePackageSnapshotV1.currentSchemaVersion,
            captureId: package.captureId,
            storagePolicyTag: policyTag,
            externalFolderPath: externalPath,
            masterURLPath: package.masterURL.path,
            proxyURLPath: package.proxyURL.path,
            packageDirURLPath: package.packageDirURL.path,
            durationLimitSeconds: package.durationLimitSeconds,
            recordedDurationSeconds: package.recordedDurationSeconds,
            parametersWidthPx: package.parameters.widthPx,
            parametersHeightPx: package.parameters.heightPx,
            parametersFrameRate: package.parameters.frameRate,
            parametersCodec: package.parameters.codec,
            parametersColorSpace: package.parameters.colorSpace,
            parametersStabilization: package.parameters.stabilization,
            writtenAtISO8601: ISO8601DateFormatter().string(from: Date())
        )
    }

    private static func makePackage(
        from snapshot: FilmtoneCapturePackageSnapshotV1
    ) -> FilmtoneCapturePackage {
        let storagePolicy: FilmtoneCaptureStoragePolicy
        switch snapshot.storagePolicyTag {
        case "external":
            if let path = snapshot.externalFolderPath, !path.isEmpty {
                storagePolicy = .externalSecurityScopedFolder(URL(fileURLWithPath: path))
            } else {
                storagePolicy = .internalDocumentsCapped
            }
        default:
            storagePolicy = .internalDocumentsCapped
        }
        let parameters = FilmtoneCaptureParameters(
            widthPx: snapshot.parametersWidthPx,
            heightPx: snapshot.parametersHeightPx,
            frameRate: snapshot.parametersFrameRate,
            codec: snapshot.parametersCodec,
            colorSpace: snapshot.parametersColorSpace,
            stabilization: snapshot.parametersStabilization
        )
        return FilmtoneCapturePackage(
            captureId: snapshot.captureId,
            storagePolicy: storagePolicy,
            masterURL: URL(fileURLWithPath: snapshot.masterURLPath),
            proxyURL: URL(fileURLWithPath: snapshot.proxyURLPath),
            packageDirURL: URL(fileURLWithPath: snapshot.packageDirURLPath),
            durationLimitSeconds: snapshot.durationLimitSeconds,
            recordedDurationSeconds: snapshot.recordedDurationSeconds,
            parameters: parameters
        )
    }

    private static func encode(
        snapshot: FilmtoneCapturePackageSnapshotV1
    ) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(snapshot)
    }
}

#endif
