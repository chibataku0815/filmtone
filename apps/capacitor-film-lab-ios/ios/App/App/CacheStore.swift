import Foundation

final class CacheStore {
    enum Bucket: String {
        case sources
        case luts
        case exports
        case previews
        case mezzanine
    }

    private let fileManager: FileManager
    let rootURL: URL

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        let cachesDirectory = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.rootURL = cachesDirectory.appendingPathComponent("FilmtonePhase0", isDirectory: true)
        try ensureDirectory(at: rootURL)
        try Bucket.allCases.forEach { bucket in
            try ensureDirectory(at: rootURL.appendingPathComponent(bucket.rawValue, isDirectory: true))
        }
    }

    func directory(for bucket: Bucket) throws -> URL {
        let directoryURL = rootURL.appendingPathComponent(bucket.rawValue, isDirectory: true)
        try ensureDirectory(at: directoryURL)
        return directoryURL
    }

    func importItem(from sourceURL: URL, suggestedName: String?, bucket: Bucket) throws -> URL {
        let destinationURL = try stagedItemURL(
            suggestedName: suggestedName ?? sourceURL.lastPathComponent,
            fallbackExtension: sourceURL.pathExtension,
            bucket: bucket
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    func stagedItemURL(
        suggestedName: String?,
        fallbackExtension: String,
        bucket: Bucket
    ) throws -> URL {
        let filename = sanitizedFilename(
            suggestedName ?? "filmtone-import",
            fallbackExtension: fallbackExtension
        )
        return try uniqueURL(
            in: bucket,
            preferredName: filename.deletingPathExtension,
            pathExtension: filename.pathExtension
        )
    }

    func temporaryExportURL(pathExtension: String = "mp4") throws -> URL {
        try uniqueURL(in: .exports, preferredName: "filmtone-export", pathExtension: pathExtension)
    }

    func temporaryPreviewURL(
        preferredName: String = "filmtone-preview",
        pathExtension: String = "jpg"
    ) throws -> URL {
        try uniqueURL(in: .previews, preferredName: preferredName, pathExtension: pathExtension)
    }

    func purgeExports() throws {
        let exportsDirectory = try directory(for: .exports)
        for entry in try fileManager.contentsOfDirectory(
            at: exportsDirectory,
            includingPropertiesForKeys: nil
        ) {
            try fileManager.removeItem(at: entry)
        }
    }

    func mezzanineFileURL(signature: String) throws -> URL {
        let directoryURL = try directory(for: .mezzanine)
        return directoryURL.appendingPathComponent("\(signature).mp4")
    }

    @discardableResult
    func pruneMezzanine(maxBytes: Int64, maxEntries: Int) throws -> (removedCount: Int, retainedBytes: Int64) {
        let directoryURL = try directory(for: .mezzanine)
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .contentAccessDateKey, .isRegularFileKey]
        let entries = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )

        struct Entry {
            let url: URL
            let sizeBytes: Int64
            let accessDate: Date
        }

        var descriptors: [Entry] = []
        descriptors.reserveCapacity(entries.count)

        for url in entries {
            let values = try url.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true else { continue }
            // Any *.partial is from an interrupted transcode in a prior session.
            // Drop it outright — it's not usable and shouldn't occupy the budget.
            if url.pathExtension == "partial" {
                try? fileManager.removeItem(at: url)
                continue
            }
            let size = Int64(values.fileSize ?? 0)
            let access = values.contentAccessDate ?? .distantPast
            descriptors.append(Entry(url: url, sizeBytes: size, accessDate: access))
        }

        // Newest-first retention. Evict oldest until both caps satisfied.
        descriptors.sort { $0.accessDate > $1.accessDate }

        var retainedBytes: Int64 = 0
        var retainedCount = 0
        var removed: [URL] = []

        for entry in descriptors {
            let wouldExceedEntries = retainedCount + 1 > maxEntries
            let wouldExceedBytes = retainedBytes + entry.sizeBytes > maxBytes
            if wouldExceedEntries || wouldExceedBytes {
                removed.append(entry.url)
            } else {
                retainedBytes += entry.sizeBytes
                retainedCount += 1
            }
        }

        for url in removed {
            try? fileManager.removeItem(at: url)
        }

        return (removedCount: removed.count, retainedBytes: retainedBytes)
    }

    private func ensureDirectory(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func uniqueURL(
        in bucket: Bucket,
        preferredName: String,
        pathExtension: String
    ) throws -> URL {
        let directoryURL = try directory(for: bucket)
        let baseName = preferredName.isEmpty ? "filmtone" : preferredName
        let suffix = UUID().uuidString.lowercased()
        let filename = "\(baseName)-\(suffix).\(pathExtension)"
        return directoryURL.appendingPathComponent(filename)
    }

    private func sanitizedFilename(_ filename: String, fallbackExtension: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = trimmed.isEmpty ? "filmtone-import" : trimmed
        if safeName.contains(".") {
            return safeName
        }
        let ext = fallbackExtension.isEmpty ? "dat" : fallbackExtension
        return "\(safeName).\(ext)"
    }
}

extension CacheStore.Bucket: CaseIterable {}

private extension String {
    var deletingPathExtension: String {
        (self as NSString).deletingPathExtension
    }

    var pathExtension: String {
        let ext = (self as NSString).pathExtension
        return ext.isEmpty ? "dat" : ext
    }
}
