import Foundation

struct CacheStoreCheckError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CacheStoreCheckError(message: message)
    }
}

@main
struct TestCacheStore {
    static func main() throws {
        try runLRUAndProtectedFileTest()
        try runStandardBucketPolicyTest()
        try runSourceImportPruneTest()
        try runReusableSourceImportTest()
        try runGeneratedExportRemovalTest()
        print("CacheStore tests passed")
    }

    static func runLRUAndProtectedFileTest() throws {
        let fixture = try CacheStoreFixture()
        defer { fixture.cleanup() }

        let old = try fixture.write(
            bucket: .mezzanine,
            name: "old.mp4",
            size: 12,
            modifiedAt: fixture.date(secondsAgo: 300)
        )
        let recent = try fixture.write(
            bucket: .mezzanine,
            name: "recent.mp4",
            size: 12,
            modifiedAt: fixture.date(secondsAgo: 20)
        )
        let protected = try fixture.write(
            bucket: .mezzanine,
            name: "protected.mp4",
            size: 12,
            modifiedAt: fixture.date(secondsAgo: 600)
        )

        let result = try fixture.store.prune(
            policy: CacheRetentionPolicy(
                bucketRules: [.mezzanine: .init(maxEntries: 1)],
                protectedURLs: [protected],
                now: fixture.now
            )
        )

        try expect(result.removedCount == 1, "expected one unprotected mezzanine removal")
        try expect(!FileManager.default.fileExists(atPath: old.path), "old mezzanine should be removed")
        try expect(FileManager.default.fileExists(atPath: recent.path), "newest mezzanine should be retained")
        try expect(FileManager.default.fileExists(atPath: protected.path), "protected mezzanine should be retained")
    }

    static func runStandardBucketPolicyTest() throws {
        let fixture = try CacheStoreFixture()
        defer { fixture.cleanup() }

        let activeSource = try fixture.write(bucket: .sources, name: "active.mov", modifiedAt: fixture.date(secondsAgo: 60))
        let staleSource = try fixture.write(bucket: .sources, name: "stale.mov", modifiedAt: fixture.date(secondsAgo: 30))
        let activePreview = try fixture.write(bucket: .previews, name: "active.jpg", modifiedAt: fixture.date(secondsAgo: 10))
        let oldPreview = try fixture.write(bucket: .previews, name: "old.jpg", modifiedAt: fixture.date(secondsAgo: 25 * 60 * 60))
        let stalePartial = try fixture.write(bucket: .mezzanine, name: "stale.mp4.partial", modifiedAt: fixture.date(secondsAgo: 5))
        let protectedPartial = try fixture.write(bucket: .mezzanine, name: "keep.mp4.partial", modifiedAt: fixture.date(secondsAgo: 5))

        _ = staleSource
        _ = oldPreview
        _ = stalePartial

        let result = try fixture.store.pruneStandard(
            protecting: [activeSource, activePreview, protectedPartial],
            now: fixture.now
        )

        try expect(result.removedCount == 2, "standard policy should remove stale preview and stale partial")
        try expect(FileManager.default.fileExists(atPath: activeSource.path), "active source should be retained")
        try expect(FileManager.default.fileExists(atPath: staleSource.path), "recent inactive source should be retained for reuse")
        try expect(FileManager.default.fileExists(atPath: activePreview.path), "active preview should be retained")
        try expect(!FileManager.default.fileExists(atPath: oldPreview.path), "expired preview should be removed")
        try expect(!FileManager.default.fileExists(atPath: stalePartial.path), "stale partial should be removed")
        try expect(FileManager.default.fileExists(atPath: protectedPartial.path), "protected partial should be retained")
    }

    static func runSourceImportPruneTest() throws {
        let fixture = try CacheStoreFixture()
        defer { fixture.cleanup() }

        let activeSource = try fixture.write(bucket: .sources, name: "active.mov", modifiedAt: fixture.date(secondsAgo: 60))
        let inactiveSource = try fixture.write(bucket: .sources, name: "inactive.mov", modifiedAt: fixture.date(secondsAgo: 30))

        let result = try fixture.store.pruneBeforeSourceImport(
            protecting: [activeSource],
            now: fixture.now
        )

        try expect(result.removedCount == 1, "source import prune should remove inactive sources")
        try expect(FileManager.default.fileExists(atPath: activeSource.path), "active source should be retained")
        try expect(!FileManager.default.fileExists(atPath: inactiveSource.path), "inactive source should be removed before a new copy")
    }

    static func runReusableSourceImportTest() throws {
        let fixture = try CacheStoreFixture()
        defer { fixture.cleanup() }

        let external = fixture.rootURL
            .deletingLastPathComponent()
            .appendingPathComponent("external-source.mov")
        try Data(repeating: 3, count: 32).write(to: external)

        let firstURL = try fixture.store.importExternalItem(
            from: external,
            suggestedName: "Camera Source.mov",
            bucket: .sources,
            reusableSourceIdentity: "source-identity"
        )
        let secondURL = try fixture.store.importExternalItem(
            from: external,
            suggestedName: "Different Display Name.mov",
            bucket: .sources,
            reusableSourceIdentity: "source-identity"
        )

        try expect(firstURL == secondURL, "same reusable source identity should return the same cache URL")
        try expect(firstURL.lastPathComponent.hasPrefix("filmtone-source-"), "reusable source should use a deterministic filename")

        let zeroURL = try fixture.store.reusableSourceURL(
            identity: "zero-byte-source",
            suggestedName: "Zero.mov",
            fallbackExtension: "mov"
        )
        try Data().write(to: zeroURL)
        let zeroExistingURL = try fixture.store.existingReusableSourceURL(
            identity: "zero-byte-source",
            suggestedName: "Zero.mov",
            fallbackExtension: "mov"
        )

        try expect(zeroExistingURL == nil, "zero-byte reusable source should not be reused")
        try expect(!FileManager.default.fileExists(atPath: zeroURL.path), "zero-byte reusable source should be removed")
    }

    static func runGeneratedExportRemovalTest() throws {
        let fixture = try CacheStoreFixture()
        defer { fixture.cleanup() }

        let media = try fixture.write(bucket: .exports, name: "export.mp4", modifiedAt: fixture.date(secondsAgo: 5))
        let sidecar = try fixture.write(
            bucket: .exports,
            name: "export.mp4.filmtone-ios-export-session-v1.json",
            modifiedAt: fixture.date(secondsAgo: 5)
        )
        let outside = fixture.rootURL.deletingLastPathComponent().appendingPathComponent("outside.mp4")
        try Data(repeating: 1, count: 8).write(to: outside)

        let result = try fixture.store.removeGeneratedFiles([media, sidecar, outside])

        try expect(result.removedCount == 2, "only managed export files should be removed")
        try expect(!FileManager.default.fileExists(atPath: media.path), "export media should be removed")
        try expect(!FileManager.default.fileExists(atPath: sidecar.path), "export sidecar should be removed")
        try expect(FileManager.default.fileExists(atPath: outside.path), "outside file should not be removed")
    }
}

final class CacheStoreFixture {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let rootURL: URL
    let store: CacheStore

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmtone-cache-store-test-\(UUID().uuidString)", isDirectory: true)
        store = try CacheStore(rootURL: rootURL)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
        try? FileManager.default.removeItem(at: rootURL.deletingLastPathComponent().appendingPathComponent("outside.mp4"))
        try? FileManager.default.removeItem(at: rootURL.deletingLastPathComponent().appendingPathComponent("external-source.mov"))
    }

    func date(secondsAgo: TimeInterval) -> Date {
        now.addingTimeInterval(-secondsAgo)
    }

    func write(
        bucket: CacheStore.Bucket,
        name: String,
        size: Int = 16,
        modifiedAt: Date
    ) throws -> URL {
        let url = try store.directory(for: bucket).appendingPathComponent(name)
        try Data(repeating: 7, count: size).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: url.path)
        return url
    }
}
