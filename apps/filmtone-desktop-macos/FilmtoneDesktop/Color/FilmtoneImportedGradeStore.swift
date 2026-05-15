import Foundation

struct FilmtoneImportedGradeLibrarySnapshot: Sendable, Equatable {
    let looks: [FilmtoneImportedGradeLook]

    static let empty = FilmtoneImportedGradeLibrarySnapshot(looks: [])

    func look(id: UUID?) -> FilmtoneImportedGradeLook? {
        guard let id else { return nil }
        return looks.first { $0.id == id }
    }
}

actor FilmtoneImportedGradeStore {
    enum StoreError: LocalizedError {
        case lookNotFound(UUID)
        case duplicateLook(UUID)
        case malformed(String)

        var errorDescription: String? {
            switch self {
            case .lookNotFound(let id): return "Imported Grade not found: \(id.uuidString)."
            case .duplicateLook(let id): return "Imported Grade already exists: \(id.uuidString)."
            case .malformed(let detail): return "Imported Grade library is malformed: \(detail)."
            }
        }
    }

    private let fileManager: FileManager
    private let rootURL: URL
    private let gradesURL: URL
    private var looks: [UUID: FilmtoneImportedGradeLook] = [:]
    private var sidecarURLs: [UUID: URL] = [:]
    private var didLoad = false

    init(fileManager: FileManager = .default, rootURL: URL? = nil) throws {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let supportDir = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.rootURL = supportDir.appendingPathComponent("Filmtone/library", isDirectory: true)
        }
        self.gradesURL = self.rootURL.appendingPathComponent("imported-grades", isDirectory: true)
        try fileManager.createDirectory(at: gradesURL, withIntermediateDirectories: true)
    }

    @discardableResult
    func loadOrRebuild() throws -> FilmtoneImportedGradeLibrarySnapshot {
        if didLoad {
            return snapshot()
        }
        defer { didLoad = true }
        var loaded: [UUID: FilmtoneImportedGradeLook] = [:]
        var urls: [UUID: URL] = [:]
        let children = (try? fileManager.contentsOfDirectory(
            at: gradesURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        for dir in children {
            let sidecarURL = dir.appendingPathComponent("filmtone-imported-grade-v1.json")
            guard fileManager.fileExists(atPath: sidecarURL.path),
                  let data = try? Data(contentsOf: sidecarURL),
                  let look = try? Self.decoder.decode(FilmtoneImportedGradeLook.self, from: data),
                  (try? look.validate()) != nil else {
                continue
            }
            loaded[look.id] = look
            urls[look.id] = sidecarURL
        }
        looks = loaded
        sidecarURLs = urls
        return snapshot()
    }

    func snapshot() -> FilmtoneImportedGradeLibrarySnapshot {
        FilmtoneImportedGradeLibrarySnapshot(
            looks: looks.values.sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        )
    }

    func sidecarURL(id: UUID) -> URL? {
        sidecarURLs[id]
    }

    func loadLook(id: UUID) throws -> FilmtoneImportedGradeLook {
        if !didLoad { _ = try loadOrRebuild() }
        guard let look = looks[id] else { throw StoreError.lookNotFound(id) }
        return look
    }

    @discardableResult
    func register(_ look: FilmtoneImportedGradeLook, sourceSidecarURL: URL? = nil) throws -> FilmtoneImportedGradeLook {
        if !didLoad { _ = try loadOrRebuild() }
        if looks[look.id] != nil {
            throw StoreError.duplicateLook(look.id)
        }
        try look.validate()
        let dir = gradesURL.appendingPathComponent(look.id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let sidecarURL = dir.appendingPathComponent("filmtone-imported-grade-v1.json")
        let data = try Self.encoder.encode(look)
        try data.write(to: sidecarURL, options: [.atomic])
        if let sourceSidecarURL {
            copySiblingAssets(from: sourceSidecarURL, to: dir)
        }
        looks[look.id] = look
        sidecarURLs[look.id] = sidecarURL
        return look
    }

    @discardableResult
    func deleteLook(id: UUID) throws -> FilmtoneImportedGradeLibrarySnapshot {
        if !didLoad { _ = try loadOrRebuild() }
        guard looks[id] != nil else { throw StoreError.lookNotFound(id) }
        let dir = gradesURL.appendingPathComponent(id.uuidString, isDirectory: true)
        try? fileManager.removeItem(at: dir)
        looks.removeValue(forKey: id)
        sidecarURLs.removeValue(forKey: id)
        return snapshot()
    }

    private func copySiblingAssets(from sidecarURL: URL, to dir: URL) {
        let sourceDir = sidecarURL.deletingLastPathComponent()
        guard let children = try? fileManager.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil) else {
            return
        }
        for child in children where child.pathExtension.lowercased() == "cube" {
            let target = dir.appendingPathComponent(child.lastPathComponent)
            if !fileManager.fileExists(atPath: target.path) {
                try? fileManager.copyItem(at: child, to: target)
            }
        }
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
