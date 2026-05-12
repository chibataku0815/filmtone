import CryptoKit
import Foundation

/// Canonical package/local LUT blob codec shared with iOS.
///
/// `.lutbin` is a headerless little-endian Float32 RGB stream:
/// `size^3 * 3 * 4` bytes. Size lives in the adjacent metadata
/// (`capture-package.json` or library JSON).
enum FilmtoneLutBlobCodec {
    static let dataFormat = "f32le-rgb-v1"

    enum CodecError: LocalizedError {
        case invalidSize(Int)
        case dataLengthMismatch(expected: Int, actual: Int)
        case malformedBlob(String)

        var errorDescription: String? {
            switch self {
            case .invalidSize(let size):
                return "Invalid LUT size: \(size)."
            case .dataLengthMismatch(let expected, let actual):
                return "LUT data length mismatch: expected \(expected) values, got \(actual)."
            case .malformedBlob(let detail):
                return "Malformed LUT blob: \(detail)."
            }
        }
    }

    static func encode(data: [Double], size: Int) throws -> Data {
        guard size > 1 else {
            throw CodecError.invalidSize(size)
        }
        let expected = size * size * size * 3
        guard data.count == expected else {
            throw CodecError.dataLengthMismatch(expected: expected, actual: data.count)
        }

        var blob = Data(capacity: expected * MemoryLayout<Float32>.size)
        for value in data {
            let bits = Float32(value).bitPattern.littleEndian
            withUnsafeBytes(of: bits) { rawBytes in
                blob.append(
                    rawBytes.bindMemory(to: UInt8.self).baseAddress!,
                    count: rawBytes.count
                )
            }
        }
        return blob
    }

    static func decode(blob: Data, size: Int) throws -> [Double] {
        guard size > 1 else {
            throw CodecError.invalidSize(size)
        }
        let expected = size * size * size * 3
        let expectedBytes = expected * MemoryLayout<Float32>.size
        guard blob.count == expectedBytes else {
            throw CodecError.malformedBlob(
                "expected \(expectedBytes) bytes, got \(blob.count)"
            )
        }

        var out = [Double](repeating: 0, count: expected)
        blob.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            for index in 0..<expected {
                let offset = index * MemoryLayout<Float32>.size
                let pointer = base.advanced(by: offset).assumingMemoryBound(to: UInt32.self)
                let bits = UInt32(littleEndian: pointer.pointee)
                out[index] = Double(Float32(bitPattern: bits))
            }
        }
        return out
    }

    static func sourceHash(blob: Data) -> String {
        SHA256.hash(data: blob)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func sourceHash(data: [Double], size: Int) throws -> String {
        sourceHash(blob: try encode(data: data, size: size))
    }
}
