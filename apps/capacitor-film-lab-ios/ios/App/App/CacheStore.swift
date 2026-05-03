import CryptoKit
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

    init(fileManager: FileManager = .default, rootURL: URL? = nil) throws {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let cachesDirectory = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.rootURL = cachesDirectory.appendingPathComponent("FilmtonePhase0", isDirectory: true)
        }
        try ensureDirectory(at: self.rootURL)
        for bucket in Bucket.allCases {
            try ensureDirectory(at: self.rootURL.appendingPathComponent(bucket.rawValue, isDirectory: true))
        }
    }

    func directory(for bucket: Bucket) throws -> URL {
        let directoryURL = rootURL.appendingPathComponent(bucket.rawValue, isDirectory: true)
        try ensureDirectory(at: directoryURL)
        return directoryURL
    }

    func importItem(
        from sourceURL: URL,
        suggestedName: String?,
        bucket: Bucket,
        reusableSourceIdentity: String? = nil
    ) throws -> URL {
        let destinationURL: URL
        if bucket == .sources, let reusableSourceIdentity {
            if let existingURL = try existingReusableSourceURL(
                identity: reusableSourceIdentity,
                suggestedName: suggestedName ?? sourceURL.lastPathComponent,
                fallbackExtension: sourceURL.pathExtension
            ) {
                return existingURL
            }
            destinationURL = try reusableSourceURL(
                identity: reusableSourceIdentity,
                suggestedName: suggestedName ?? sourceURL.lastPathComponent,
                fallbackExtension: sourceURL.pathExtension
            )
        } else {
            destinationURL = try stagedItemURL(
                suggestedName: suggestedName ?? sourceURL.lastPathComponent,
                fallbackExtension: sourceURL.pathExtension,
                bucket: bucket
            )
        }
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        try touch(destinationURL)
        return destinationURL
    }

    func importExternalItem(
        from sourceURL: URL,
        suggestedName: String?,
        bucket: Bucket,
        reusableSourceIdentity: String? = nil
    ) throws -> URL {
        let destinationURL: URL
        if bucket == .sources, let reusableSourceIdentity {
            if let existingURL = try existingReusableSourceURL(
                identity: reusableSourceIdentity,
                suggestedName: suggestedName ?? sourceURL.lastPathComponent,
                fallbackExtension: sourceURL.pathExtension
            ) {
                return existingURL
            }
            destinationURL = try reusableSourceURL(
                identity: reusableSourceIdentity,
                suggestedName: suggestedName ?? sourceURL.lastPathComponent,
                fallbackExtension: sourceURL.pathExtension
            )
        } else {
            destinationURL = try stagedItemURL(
                suggestedName: suggestedName ?? sourceURL.lastPathComponent,
                fallbackExtension: sourceURL.pathExtension,
                bucket: bucket
            )
        }
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var copyError: Error?
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { readableURL in
            do {
                try fileManager.copyItem(at: readableURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            try? fileManager.removeItem(at: destinationURL)
            throw coordinationError
        }
        if let copyError {
            try? fileManager.removeItem(at: destinationURL)
            throw copyError
        }

        try touch(destinationURL)
        return destinationURL
    }

    func reusableSourceURL(
        identity: String,
        suggestedName: String?,
        fallbackExtension: String
    ) throws -> URL {
        let filename = sanitizedFilename(
            suggestedName ?? "filmtone-source",
            fallbackExtension: fallbackExtension
        )
        let ext = safePathExtension(filename.pathExtension)
        let digest = SHA256.hash(data: Data(identity.utf8))
        let hexDigest = digest.map { String(format: "%02x", $0) }.joined()
        let directoryURL = try directory(for: .sources)
        return directoryURL.appendingPathComponent("filmtone-source-\(hexDigest.prefix(20)).\(ext)")
    }

    func existingReusableSourceURL(
        identity: String,
        suggestedName: String?,
        fallbackExtension: String
    ) throws -> URL? {
        let url = try reusableSourceURL(
            identity: identity,
            suggestedName: suggestedName,
            fallbackExtension: fallbackExtension
        )
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        guard try isReusableCachedFile(at: url) else {
            try? fileManager.removeItem(at: url)
            return nil
        }
        try touch(url)
        return url
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
        _ = try removeGeneratedFiles(in: .exports)
    }

    func mezzanineFileURL(signature: String) throws -> URL {
        let directoryURL = try directory(for: .mezzanine)
        return directoryURL.appendingPathComponent("\(signature).mp4")
    }

    @discardableResult
    func pruneMezzanine(maxBytes: Int64, maxEntries: Int) throws -> (removedCount: Int, retainedBytes: Int64) {
        let result = try prune(
            policy: CacheRetentionPolicy(
                bucketRules: [
                    .mezzanine: .init(maxBytes: maxBytes, maxEntries: maxEntries)
                ]
            )
        )
        let retainedBytes = try inventory().totalBytes(in: .mezzanine)
        return (removedCount: result.removedCount, retainedBytes: retainedBytes)
    }

    func inventory() throws -> CacheInventory {
        var entriesByBucket: [Bucket: [CacheInventory.Entry]] = [:]
        for bucket in Bucket.allCases {
            entriesByBucket[bucket] = try entries(in: bucket)
        }
        return CacheInventory(entriesByBucket: entriesByBucket)
    }

    @discardableResult
    func prune(policy: CacheRetentionPolicy) throws -> CachePruneResult {
        var removedCount = 0
        var removedBytes: Int64 = 0
        var retainedBytes: Int64 = 0
        var removedURLs: [URL] = []

        for bucket in Bucket.allCases {
            guard let rule = policy.bucketRules[bucket] else {
                continue
            }

            var candidates: [CacheInventory.Entry] = []
            for entry in try entries(in: bucket) {
                let isProtected = policy.protects(entry.url)
                if entry.isPartial && !isProtected {
                    remove(entry, removedCount: &removedCount, removedBytes: &removedBytes, removedURLs: &removedURLs)
                    continue
                }

                if rule.keepOnlyProtected && !isProtected {
                    remove(entry, removedCount: &removedCount, removedBytes: &removedBytes, removedURLs: &removedURLs)
                    continue
                }

                if let maxAge = rule.maxAge,
                   !isProtected,
                   policy.now.timeIntervalSince(entry.modifiedAt) > maxAge {
                    remove(entry, removedCount: &removedCount, removedBytes: &removedBytes, removedURLs: &removedURLs)
                    continue
                }

                candidates.append(entry)
            }

            let protected = candidates.filter { policy.protects($0.url) }
            let unprotected = candidates
                .filter { !policy.protects($0.url) }
                .sorted { lhs, rhs in
                    if lhs.modifiedAt == rhs.modifiedAt {
                        return lhs.url.lastPathComponent > rhs.url.lastPathComponent
                    }
                    return lhs.modifiedAt > rhs.modifiedAt
                }

            retainedBytes += protected.reduce(Int64(0)) { $0 + $1.sizeBytes }

            var retainedUnprotectedBytes: Int64 = 0
            var retainedUnprotectedCount = 0
            for entry in unprotected {
                let exceedsEntries = rule.maxEntries.map { retainedUnprotectedCount + 1 > $0 } ?? false
                let exceedsBytes = rule.maxBytes.map { retainedUnprotectedBytes + entry.sizeBytes > $0 } ?? false
                if exceedsEntries || exceedsBytes {
                    remove(entry, removedCount: &removedCount, removedBytes: &removedBytes, removedURLs: &removedURLs)
                    continue
                }
                retainedUnprotectedBytes += entry.sizeBytes
                retainedUnprotectedCount += 1
            }

            retainedBytes += retainedUnprotectedBytes
        }

        return CachePruneResult(
            removedCount: removedCount,
            removedBytes: removedBytes,
            retainedBytes: retainedBytes,
            removedURLs: removedURLs
        )
    }

    @discardableResult
    func pruneStandard(protecting protectedURLs: [URL] = [], now: Date = Date()) throws -> CachePruneResult {
        try prune(policy: .standard(protecting: protectedURLs, now: now))
    }

    @discardableResult
    func pruneBeforeSourceImport(
        protecting protectedURLs: [URL] = [],
        now: Date = Date()
    ) throws -> CachePruneResult {
        try prune(policy: .beforeSourceImport(protecting: protectedURLs, now: now))
    }

    @discardableResult
    func removeGeneratedFiles(_ urls: [URL]) throws -> CachePruneResult {
        var removedCount = 0
        var removedBytes: Int64 = 0
        var removedURLs: [URL] = []

        for url in urls {
            guard isManagedCacheURL(url) else {
                continue
            }
            guard fileManager.fileExists(atPath: url.path) else {
                continue
            }
            let sizeBytes = sizeOfItem(at: url)
            do {
                try fileManager.removeItem(at: url)
                removedCount += 1
                removedBytes += sizeBytes
                removedURLs.append(url)
            } catch {
                continue
            }
        }

        let retainedBytes = (try? inventory().totalBytes) ?? 0
        return CachePruneResult(
            removedCount: removedCount,
            removedBytes: removedBytes,
            retainedBytes: retainedBytes,
            removedURLs: removedURLs
        )
    }

    @discardableResult
    func removeGeneratedFiles(in bucket: Bucket) throws -> CachePruneResult {
        let urls = try entries(in: bucket).map(\.url)
        return try removeGeneratedFiles(urls)
    }

    func touch(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
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

    private func safePathExtension(_ pathExtension: String) -> String {
        let trimmed = pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: ":", with: "")
        return trimmed.isEmpty ? "dat" : trimmed
    }

    private func isReusableCachedFile(at url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .isRegularFileKey,
        ])
        let sizeBytes = values.fileSize ?? 0
        return values.isRegularFile == true && sizeBytes > 0
    }

    private func entries(in bucket: Bucket) throws -> [CacheInventory.Entry] {
        let directoryURL = try directory(for: bucket)
        let resourceKeys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
        ]
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )

        var entries: [CacheInventory.Entry] = []
        entries.reserveCapacity(urls.count)

        for url in urls {
            guard let entry = entry(for: url, bucket: bucket, resourceKeys: resourceKeys) else {
                continue
            }
            entries.append(entry)
        }

        return entries
    }

    private func entry(
        for url: URL,
        bucket: Bucket,
        resourceKeys: Set<URLResourceKey>
    ) -> CacheInventory.Entry? {
        guard let values = try? url.resourceValues(forKeys: resourceKeys),
              values.isRegularFile == true else {
            return nil
        }

        let sizeBytes = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        let modifiedAt = values.contentModificationDate ?? .distantPast
        return CacheInventory.Entry(
            bucket: bucket,
            url: url,
            sizeBytes: max(0, sizeBytes),
            modifiedAt: modifiedAt,
            isPartial: url.pathExtension == "partial"
        )
    }

    private func remove(
        _ entry: CacheInventory.Entry,
        removedCount: inout Int,
        removedBytes: inout Int64,
        removedURLs: inout [URL]
    ) {
        guard isManagedCacheURL(entry.url) else {
            return
        }
        do {
            try fileManager.removeItem(at: entry.url)
            removedCount += 1
            removedBytes += entry.sizeBytes
            removedURLs.append(entry.url)
        } catch {
            return
        }
    }

    private func sizeOfItem(at url: URL) -> Int64 {
        let values = try? url.resourceValues(
            forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]
        )
        return Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
    }

    private func isManagedCacheURL(_ url: URL) -> Bool {
        let rootPath = canonicalPath(for: rootURL)
        let targetPath = canonicalPath(for: url)
        return targetPath == rootPath || targetPath.hasPrefix(rootPath + "/")
    }

    static func canonicalPath(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func canonicalPath(for url: URL) -> String {
        Self.canonicalPath(for: url)
    }
}

extension CacheStore.Bucket: CaseIterable {}

struct CacheRetentionPolicy {
    struct BucketRule {
        var keepOnlyProtected = false
        var maxBytes: Int64?
        var maxEntries: Int?
        var maxAge: TimeInterval?

        init(
            keepOnlyProtected: Bool = false,
            maxBytes: Int64? = nil,
            maxEntries: Int? = nil,
            maxAge: TimeInterval? = nil
        ) {
            self.keepOnlyProtected = keepOnlyProtected
            self.maxBytes = maxBytes
            self.maxEntries = maxEntries
            self.maxAge = maxAge
        }
    }

    var bucketRules: [CacheStore.Bucket: BucketRule]
    var protectedPaths: Set<String>
    var now: Date

    private static let sourceReuseMaxBytes: Int64 = 8 * 1024 * 1024 * 1024
    private static let sourceReuseMaxEntries = 2
    private static let sourceReuseMaxAge: TimeInterval = 7 * 24 * 60 * 60

    init(
        bucketRules: [CacheStore.Bucket: BucketRule],
        protectedURLs: [URL] = [],
        now: Date = Date()
    ) {
        self.bucketRules = bucketRules
        self.protectedPaths = Set(protectedURLs.map(CacheStore.canonicalPath(for:)))
        self.now = now
    }

    static func standard(
        protecting protectedURLs: [URL] = [],
        now: Date = Date()
    ) -> CacheRetentionPolicy {
        CacheRetentionPolicy(
            bucketRules: [
                .sources: .init(
                    maxBytes: sourceReuseMaxBytes,
                    maxEntries: sourceReuseMaxEntries,
                    maxAge: sourceReuseMaxAge
                ),
                .exports: .init(keepOnlyProtected: true),
                .previews: .init(maxBytes: 64 * 1024 * 1024, maxAge: 24 * 60 * 60),
                .mezzanine: .init(maxBytes: 1_073_741_824, maxEntries: 4),
                .luts: .init(maxBytes: 20 * 1024 * 1024, maxAge: 30 * 24 * 60 * 60),
            ],
            protectedURLs: protectedURLs,
            now: now
        )
    }

    static func beforeSourceImport(
        protecting protectedURLs: [URL] = [],
        now: Date = Date()
    ) -> CacheRetentionPolicy {
        CacheRetentionPolicy(
            bucketRules: [
                .sources: .init(keepOnlyProtected: true),
                .exports: .init(keepOnlyProtected: true),
                .previews: .init(maxBytes: 64 * 1024 * 1024, maxAge: 24 * 60 * 60),
                .mezzanine: .init(maxBytes: 1_073_741_824, maxEntries: 4),
                .luts: .init(maxBytes: 20 * 1024 * 1024, maxAge: 30 * 24 * 60 * 60),
            ],
            protectedURLs: protectedURLs,
            now: now
        )
    }

    func protects(_ url: URL) -> Bool {
        protectedPaths.contains(CacheStore.canonicalPath(for: url))
    }
}

struct CacheInventory {
    struct Entry {
        let bucket: CacheStore.Bucket
        let url: URL
        let sizeBytes: Int64
        let modifiedAt: Date
        let isPartial: Bool
    }

    let entriesByBucket: [CacheStore.Bucket: [Entry]]

    var totalBytes: Int64 {
        entriesByBucket.values.flatMap { $0 }.reduce(Int64(0)) { $0 + $1.sizeBytes }
    }

    func entries(in bucket: CacheStore.Bucket) -> [Entry] {
        entriesByBucket[bucket] ?? []
    }

    func totalBytes(in bucket: CacheStore.Bucket) -> Int64 {
        entries(in: bucket).reduce(Int64(0)) { $0 + $1.sizeBytes }
    }
}

struct CachePruneResult {
    let removedCount: Int
    let removedBytes: Int64
    let retainedBytes: Int64
    let removedURLs: [URL]
}

private extension String {
    var deletingPathExtension: String {
        (self as NSString).deletingPathExtension
    }

    var pathExtension: String {
        let ext = (self as NSString).pathExtension
        return ext.isEmpty ? "dat" : ext
    }
}
