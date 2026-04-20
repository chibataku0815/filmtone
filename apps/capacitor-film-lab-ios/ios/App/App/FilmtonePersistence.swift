import Foundation

struct FilmtonePersistenceSnapshot: Codable {
    var schemaVersion: Int
    var project: FilmtoneProjectState
    var source: SourceInfoDTO?
    var probe: SourceProbeDTO?
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
        probe: SourceProbeDTO?
    ) {
        let snapshot = FilmtonePersistenceSnapshot(
            schemaVersion: FilmtonePhase0Math.projectSchemaVersion,
            project: project,
            source: source,
            probe: probe
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
