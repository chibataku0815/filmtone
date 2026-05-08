import Foundation

struct FilmtonePersistenceSnapshot: Codable {
    var schemaVersion: Int
    var project: FilmtoneProjectState
    var source: SourceInfoDTO?
    var probe: SourceProbeDTO?
    /// Local filesystem path to a `capture-package.json` written by the
    /// M10 native capture surface for the **currently-adopted** source.
    /// Decoupled from `SourceInfoDTO` so the source identity stays a
    /// pure media-input concept and the capture provenance / master
    /// linkage rides on its own field.  Decoded as `nil` for snapshots
    /// written before M10 (additive Codable field).
    var currentCapturePackageRef: String?
}

enum FilmtonePersistence {
    private static let snapshotKey = "filmtone-ios-native-phase1/snapshot/v1"

    static func load() -> FilmtonePersistenceSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: snapshotKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(FilmtonePersistenceSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    static func save(
        project: FilmtoneProjectState,
        source: SourceInfoDTO?,
        probe: SourceProbeDTO?,
        currentCapturePackageRef: String?
    ) {
        let snapshot = FilmtonePersistenceSnapshot(
            schemaVersion: FilmtonePhase0Math.projectSchemaVersion,
            project: project,
            source: source,
            probe: probe,
            currentCapturePackageRef: currentCapturePackageRef
        )

        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        UserDefaults.standard.set(data, forKey: snapshotKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: snapshotKey)
    }
}
