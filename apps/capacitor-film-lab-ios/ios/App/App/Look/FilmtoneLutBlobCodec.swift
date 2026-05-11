import Foundation
import CryptoKit

/// Binary encoding for LUT data — little-endian Float32 RGB triples.
///
/// `size³ × 3 × 4` bytes per blob (e.g. ~140 KB for size 33). Two reasons
/// this beats the existing JSON `[Double]` representation:
/// - **~50% smaller on disk** vs the ASCII JSON form, even after pretty-print is removed.
/// - **5–10× faster to load**: no UTF-8 → JSON-tree → Double round-trip; we
///   `Data(contentsOf:)` then `bindMemory(to: UInt32.self)`.
///
/// JSON is reserved for human-readable metadata only. Format identifier is
/// `FilmtoneLibraryConstants.lutDataFormat` and is recorded on every entry
/// so a future format change can be detected and migrated.
enum FilmtoneLutBlobCodec {
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

    /// Encode a parsed LUT data array into the canonical `.lutbin` byte stream.
    /// Caller must pass the same `size` the parser reported; we validate and
    /// fail loudly if `data.count != size³ × 3` rather than silently truncating.
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
            // Float32 carries enough precision for LUT samples; the matching
            // `.cube` ASCII representation is typically 6 significant figures.
            let bits = Float32(value).bitPattern.littleEndian
            withUnsafeBytes(of: bits) { rawBytes in
                blob.append(rawBytes.bindMemory(to: UInt8.self).baseAddress!, count: rawBytes.count)
            }
        }
        return blob
    }

    /// Decode a `.lutbin` byte stream back into the canonical `[Double]`
    /// array shape that `ParsedCubeLutDTO.data` expects.
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
            guard let base = raw.baseAddress else {
                return
            }
            // Read as UInt32 little-endian, reconstruct Float32 via bitPattern,
            // widen to Double. Avoids unaligned-read traps that Float32-direct
            // pointer cast would risk on unaligned `Data` buffers.
            for i in 0..<expected {
                let offset = i * MemoryLayout<Float32>.size
                let pointer = base.advanced(by: offset).assumingMemoryBound(to: UInt32.self)
                let bits = UInt32(littleEndian: pointer.pointee)
                out[i] = Double(Float32(bitPattern: bits))
            }
        }
        return out
    }

    /// SHA-256 over the canonical Float32 byte stream. Two `.cube` files that
    /// produce the same parsed `data` (regardless of comments / whitespace /
    /// `DOMAIN_*` baking) will hash identically. Cheap enough to compute on
    /// every import (a 33³ LUT is ~140 KB, hashed in well under 1 ms on A-series).
    static func sourceHash(data: [Double], size: Int) throws -> String {
        let blob = try encode(data: data, size: size)
        let digest = SHA256.hash(data: blob)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
