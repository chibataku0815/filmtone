import Foundation
import Observation

@MainActor
@Observable
final class ImportedGradeLibraryViewModel {
    private(set) var snapshot: FilmtoneImportedGradeLibrarySnapshot = .empty
    var lastError: String?

    @ObservationIgnored
    private let store: FilmtoneImportedGradeStore

    @ObservationIgnored
    private var didBootstrap = false

    init() {
        do {
            self.store = try FilmtoneImportedGradeStore()
        } catch {
            self.lastError = "Imported Grade library unavailable: \(error.localizedDescription)"
            let fallbackURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Filmtone/imported-grades", isDirectory: true)
            do {
                self.store = try FilmtoneImportedGradeStore(rootURL: fallbackURL)
            } catch {
                self.store = try! FilmtoneImportedGradeStore(
                    rootURL: URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent("Filmtone/imported-grades", isDirectory: true)
                )
            }
        }
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await refresh()
    }

    func refresh() async {
        do {
            snapshot = try await store.loadOrRebuild()
        } catch {
            lastError = error.localizedDescription
            snapshot = await store.snapshot()
        }
    }

    func loadLook(id: UUID) async -> FilmtoneImportedGradeLook? {
        do {
            return try await store.loadLook(id: id)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func sidecarURL(id: UUID) async -> URL? {
        await store.sidecarURL(id: id)
    }

    @discardableResult
    func importGrade(from url: URL) async -> FilmtoneImportedGradeLook? {
        do {
            let look: FilmtoneImportedGradeLook
            let sidecarURL: URL?
            if url.pathExtension.lowercased() == "drx" {
                let imported = try FilmtoneDrxImporter.importDrxFile(at: url)
                look = imported.look
                sidecarURL = nil
            } else {
                let imported = try FilmtoneImportedGradePackageImporter.importPackage(from: url)
                look = imported.look
                sidecarURL = imported.sidecarURL
            }
            let registered = try await store.register(look, sourceSidecarURL: sidecarURL)
            await refresh()
            return registered
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func deleteLook(id: UUID) async -> Bool {
        do {
            _ = try await store.deleteLook(id: id)
            await refresh()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
