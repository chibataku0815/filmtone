import Foundation

enum FilmtoneDrxImportError: LocalizedError, Equatable {
    case unreadable(URL)
    case xmlBodyMissing
    case malformedHex
    case bodyTooShort
    case bodyNotZstdFramed
    case zstdUnavailable(reason: String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let url): return "Could not read DRX file: \(url.lastPathComponent)"
        case .xmlBodyMissing: return "DRX Body payload was not found."
        case .malformedHex: return "DRX Body payload is not valid hex."
        case .bodyTooShort: return "DRX Body payload is too short."
        case .bodyNotZstdFramed: return "DRX Body payload is not zstd framed."
        case .zstdUnavailable(let reason): return "zstd is required to decode this DRX: \(reason)"
        }
    }
}

struct FilmtoneDrxXmlEnvelope: Sendable, Equatable {
    let bodyHex: String
    let dbAppVersion: String?

    static func read(url: URL) throws -> FilmtoneDrxXmlEnvelope {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw FilmtoneDrxImportError.unreadable(url)
        }
        guard let body = extractTag("Body", from: text) else {
            throw FilmtoneDrxImportError.xmlBodyMissing
        }
        return FilmtoneDrxXmlEnvelope(
            bodyHex: body.trimmingCharacters(in: .whitespacesAndNewlines),
            dbAppVersion: extractTag("DbAppVer", from: text)
        )
    }

    private static func extractTag(_ tag: String, from text: String) -> String? {
        guard let start = text.range(of: "<\(tag)>"),
              let end = text.range(of: "</\(tag)>", range: start.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[start.upperBound..<end.lowerBound])
    }
}

struct FilmtoneDrxDecodedBody: Sendable, Equatable {
    let bodyVersionFlag: UInt8
    let compressedBody: Data
}

enum FilmtoneDrxHexDecoder {
    static func decodeBody(hex: String) throws -> FilmtoneDrxDecodedBody {
        let compact = hex.filter { !$0.isWhitespace }
        guard compact.count % 2 == 0 else { throw FilmtoneDrxImportError.malformedHex }
        var bytes = Data()
        bytes.reserveCapacity(compact.count / 2)
        var index = compact.startIndex
        while index < compact.endIndex {
            let next = compact.index(index, offsetBy: 2)
            guard let byte = UInt8(compact[index..<next], radix: 16) else {
                throw FilmtoneDrxImportError.malformedHex
            }
            bytes.append(byte)
            index = next
        }
        guard let version = bytes.first, bytes.count > 1 else {
            throw FilmtoneDrxImportError.bodyTooShort
        }
        let compressed = bytes.dropFirst()
        guard compressed.starts(with: Data([0x28, 0xb5, 0x2f, 0xfd])) else {
            throw FilmtoneDrxImportError.bodyNotZstdFramed
        }
        return FilmtoneDrxDecodedBody(
            bodyVersionFlag: version,
            compressedBody: Data(compressed)
        )
    }
}

struct FilmtoneDrxProtobufField: Sendable, Equatable {
    let number: Int
    let wireType: Int
    let path: [Int]
    let varintValue: UInt64?
    let fixed32Value: Float?
    let payload: Data?
    let nested: [FilmtoneDrxProtobufField]?
}

enum FilmtoneDrxProtobuf {
    static func decodeMessage(_ data: Data) -> [FilmtoneDrxProtobufField] {
        (try? decodeMessageStrict(data)) ?? []
    }

    static func decodeMessageStrict(_ data: Data) throws -> [FilmtoneDrxProtobufField] {
        var index = 0
        return try decodeFields(data, index: &index, path: [])
    }

    private static func decodeFields(
        _ data: Data,
        index: inout Int,
        path: [Int]
    ) throws -> [FilmtoneDrxProtobufField] {
        var fields: [FilmtoneDrxProtobufField] = []
        while index < data.count {
            let key = try readVarint(data, index: &index)
            let number = Int(key >> 3)
            let wireType = Int(key & 0x7)
            let fieldPath = path + [number]
            switch wireType {
            case 0:
                let value = try readVarint(data, index: &index)
                fields.append(FilmtoneDrxProtobufField(
                    number: number,
                    wireType: wireType,
                    path: fieldPath,
                    varintValue: value,
                    fixed32Value: nil,
                    payload: nil,
                    nested: nil
                ))
            case 2:
                let length = Int(try readVarint(data, index: &index))
                guard length >= 0, index + length <= data.count else {
                    throw FilmtoneDrxImportError.bodyTooShort
                }
                let payload = Data(data[index..<(index + length)])
                index += length
                let nested = try? decodeMessageStrict(payload)
                fields.append(FilmtoneDrxProtobufField(
                    number: number,
                    wireType: wireType,
                    path: fieldPath,
                    varintValue: nil,
                    fixed32Value: nil,
                    payload: payload,
                    nested: nested?.isEmpty == false ? nested : nil
                ))
            case 5:
                guard index + 4 <= data.count else { throw FilmtoneDrxImportError.bodyTooShort }
                let slice = data[index..<(index + 4)]
                let bits = slice.enumerated().reduce(UInt32(0)) { acc, item in
                    acc | (UInt32(item.element) << UInt32(item.offset * 8))
                }
                index += 4
                fields.append(FilmtoneDrxProtobufField(
                    number: number,
                    wireType: wireType,
                    path: fieldPath,
                    varintValue: nil,
                    fixed32Value: Float(bitPattern: bits),
                    payload: nil,
                    nested: nil
                ))
            default:
                throw FilmtoneDrxImportError.bodyTooShort
            }
        }
        return fields
    }

    private static func readVarint(_ data: Data, index: inout Int) throws -> UInt64 {
        var shift: UInt64 = 0
        var result: UInt64 = 0
        while index < data.count, shift < 64 {
            let byte = data[index]
            index += 1
            result |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
        }
        throw FilmtoneDrxImportError.bodyTooShort
    }
}

struct FilmtoneDrxImportResult: Sendable, Equatable {
    let look: FilmtoneImportedGradeLook
    let sourceGraph: FilmtoneImportedGradeSourceGraph
}

enum FilmtoneDrxImporter {
    static func importDrxFile(at url: URL) throws -> FilmtoneDrxImportResult {
        let envelope = try FilmtoneDrxXmlEnvelope.read(url: url)
        let decoded = try FilmtoneDrxHexDecoder.decodeBody(hex: envelope.bodyHex)
        let decompressed = try decompressZstd(decoded.compressedBody)
        let graph = buildGraph(body: decompressed, bodyVersionFlag: Int(decoded.bodyVersionFlag))
        let look = buildLook(url: url, graph: graph)
        return FilmtoneDrxImportResult(look: look, sourceGraph: graph)
    }

    static func importDrxFileGraphOnly(at url: URL) throws -> FilmtoneDrxImportResult {
        let envelope = try FilmtoneDrxXmlEnvelope.read(url: url)
        let decoded = try FilmtoneDrxHexDecoder.decodeBody(hex: envelope.bodyHex)
        let graph = FilmtoneImportedGradeSourceGraph(
            decoded: false,
            bodyVersionFlag: Int(decoded.bodyVersionFlag),
            approximateNodeCount: 0,
            unsupportedNotes: ["zstd decode skipped; graph-only debug import"]
        )
        return FilmtoneDrxImportResult(look: buildLook(url: url, graph: graph), sourceGraph: graph)
    }

    static func buildGraph(body: Data, bodyVersionFlag: Int) -> FilmtoneImportedGradeSourceGraph {
        let fields = FilmtoneDrxProtobuf.decodeMessage(body)
        let nodes = fields.enumerated().map { index, field in
            FilmtoneImportedGradeSourceGraph.Node(
                index: index,
                protobufPath: field.path,
                recognizedOps: field.nested == nil ? [] : ["protobufMessage:\(field.path.map(String.init).joined(separator: "."))"],
                unsupportedPayloadBase64: field.payload?.base64EncodedString(),
                approximateInnerFieldCount: field.nested?.count ?? 0
            )
        }
        return FilmtoneImportedGradeSourceGraph(
            decoded: true,
            bodyVersionFlag: bodyVersionFlag,
            nodes: nodes,
            approximateNodeCount: nodes.count,
            unsupportedNotes: nodes.isEmpty ? ["no recognized renderable controls"] : ["graph-only; no Resolve parity claimed"]
        )
    }

    private static func buildLook(url: URL, graph: FilmtoneImportedGradeSourceGraph) -> FilmtoneImportedGradeLook {
        FilmtoneImportedGradeLook(
            id: UUID(),
            title: url.deletingPathExtension().lastPathComponent,
            source: .davinciDrx(drxPath: url.path),
            baseLook: .none,
            preLutControls: [],
            postLutControls: [],
            sourceGraph: graph,
            unsupportedMetadata: graph.unsupportedNotes
        )
    }

    private static func decompressZstd(_ data: Data) throws -> Data {
        let executableCandidates = [
            "/opt/homebrew/bin/zstd",
            "/usr/local/bin/zstd",
            "/usr/bin/zstd",
        ]
        guard let executable = executableCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw FilmtoneDrxImportError.zstdUnavailable(reason: "zstd executable not found")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-q", "-d", "-c"]
        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error
        do {
            try process.run()
            input.fileHandleForWriting.write(data)
            try input.fileHandleForWriting.close()
            let out = output.fileHandleForReading.readDataToEndOfFile()
            let err = error.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let reason = String(data: err, encoding: .utf8) ?? "zstd failed"
                throw FilmtoneDrxImportError.zstdUnavailable(reason: reason)
            }
            return out
        } catch let error as FilmtoneDrxImportError {
            throw error
        } catch {
            throw FilmtoneDrxImportError.zstdUnavailable(reason: error.localizedDescription)
        }
    }
}
