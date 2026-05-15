import Foundation

enum FilmtoneImportedGradePackageImportError: LocalizedError {
    case sidecarNotFound(URL)
    case sidecarUnreadable(URL)
    case invalidSidecar(String)
    case drxRequiresDrxImporter

    var errorDescription: String? {
        switch self {
        case .sidecarNotFound(let url):
            return "Imported Grade sidecar not found: \(url.path)"
        case .sidecarUnreadable(let url):
            return "Imported Grade sidecar could not be read: \(url.path)"
        case .invalidSidecar(let detail):
            return "Imported Grade sidecar is invalid: \(detail)"
        case .drxRequiresDrxImporter:
            return "Use the DRX importer for .drx files."
        }
    }
}

struct FilmtoneImportedGradePackage: Sendable, Equatable {
    let look: FilmtoneImportedGradeLook
    let sidecarURL: URL
}

enum FilmtoneImportedGradePackageImporter {
    static let sidecarFilename = "filmtone-imported-grade-v1.json"

    static func isImportedGradeCandidate(_ url: URL) -> Bool {
        if url.pathExtension.lowercased() == "drx" { return true }
        if url.lastPathComponent == sidecarFilename { return true }
        return ((try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true)
            && FileManager.default.fileExists(atPath: url.appendingPathComponent(sidecarFilename).path)
    }

    static func importPackage(from url: URL) throws -> FilmtoneImportedGradePackage {
        if url.pathExtension.lowercased() == "drx" {
            throw FilmtoneImportedGradePackageImportError.drxRequiresDrxImporter
        }
        let sidecarURL: URL
        if url.lastPathComponent == sidecarFilename {
            sidecarURL = url
        } else {
            sidecarURL = url.appendingPathComponent(sidecarFilename)
        }
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            throw FilmtoneImportedGradePackageImportError.sidecarNotFound(sidecarURL)
        }
        guard let data = try? Data(contentsOf: sidecarURL) else {
            throw FilmtoneImportedGradePackageImportError.sidecarUnreadable(sidecarURL)
        }
        do {
            let look = try FilmtoneImportedGradeStore.decoder.decode(FilmtoneImportedGradeLook.self, from: data)
            try look.validate()
            return FilmtoneImportedGradePackage(look: look, sidecarURL: sidecarURL)
        } catch {
            throw FilmtoneImportedGradePackageImportError.invalidSidecar(error.localizedDescription)
        }
    }
}
