import Foundation

func registerDBM13DrxImportTests() {
    let sampleBodyHex = "8128b52ffd04582900000a0308960164f6d07d"

    func makeDrxFixture(bodyHex: String = sampleBodyHex) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmtone-drx-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("verify.drx")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Still>
          <DbAppVer>19.1</DbAppVer>
          <Body>
            \(bodyHex)
          </Body>
        </Still>
        """
        try Data(xml.utf8).write(to: url)
        return url
    }

    func zstdAvailable() -> Bool {
        [
            "/opt/homebrew/bin/zstd",
            "/usr/local/bin/zstd",
            "/usr/bin/zstd",
        ].contains { FileManager.default.isExecutableFile(atPath: $0) }
    }

    runner.test("DB-M13 DRX XML envelope extracts Body and DbAppVer") {
        let url = try makeDrxFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let envelope = try FilmtoneDrxXmlEnvelope.read(url: url)
        try assertEqual(envelope.bodyHex.filter { !$0.isWhitespace }, sampleBodyHex, "Body hex")
        try assertEqual(envelope.dbAppVersion, "19.1", "DbAppVer")
    }

    runner.test("DB-M13 DRX body decoder validates version byte and zstd frame") {
        let decoded = try FilmtoneDrxHexDecoder.decodeBody(hex: sampleBodyHex)
        try assertEqual(decoded.bodyVersionFlag, 129, "version flag")
        try assertEqual(decoded.compressedBody.starts(with: Data([0x28, 0xb5, 0x2f, 0xfd])), true, "zstd magic")
    }

    runner.test("DB-M13 DRX graph-only import remains a valid approximate grade") {
        let url = try makeDrxFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let imported = try FilmtoneDrxImporter.importDrxFileGraphOnly(at: url)
        try assertEqual(imported.look.title, "verify", "title")
        try assertEqual(imported.sourceGraph.decoded, false, "graph-only decode flag")
        try assertEqual(imported.look.sourceGraph?.unsupportedNotes.first, "zstd decode skipped; graph-only debug import")
    }

    runner.test("DB-M13 DRX strict import decodes protobuf graph when zstd is available") {
        guard zstdAvailable() else {
            return
        }
        let url = try makeDrxFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let imported = try FilmtoneDrxImporter.importDrxFile(at: url)
        try assertEqual(imported.sourceGraph.decoded, true, "decoded graph")
        try assertEqual(imported.sourceGraph.bodyVersionFlag, 129, "version flag")
        guard imported.sourceGraph.approximateNodeCount > 0 else {
            throw AssertionError(description: "strict import should expose at least one protobuf node")
        }
        guard imported.look.unsupportedMetadata.contains("graph-only; no Resolve parity claimed") else {
            throw AssertionError(description: "strict import must preserve approximate/parity warning")
        }
    }
}
