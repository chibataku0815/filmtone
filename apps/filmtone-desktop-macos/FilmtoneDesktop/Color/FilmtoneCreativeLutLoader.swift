import CryptoKit
import Foundation

/// Bundle-resolved cube ready for `CIColorCubeWithColorSpace` consumption.
/// `cubeData` is interleaved Float32 RGBA in iOS canonical b-major order;
/// `intensity` is pinned at 1.0 for v1.4 Pack 01 entries.
struct PreparedCreativeLut {
    let slug: String
    let size: Int
    let intensity: Double
    let cubeData: Data
    let sourceHash: String
}

/// Resolves a `BuiltInLook` to a `PreparedCreativeLut` by reading the
/// bundled `.cube` from `Resources/CreativeLuts/`, verifying its pinned
/// SHA-256 (fail-closed), parsing the triples, and packing them into the
/// Float32 RGBA Data buffer that Core Image expects.
///
/// The result is cached per slug in an `NSCache` so video export's frame
/// loop does not re-parse the ~7 MB cube on every frame. The cache also
/// survives Look picker toggles during a still preview session.
enum FilmtoneCreativeLutLoader {
    // NSCache is internally thread-safe; opt out of Swift 6 isolation
    // checking so preview / still / video pipelines can hit the same
    // cache from any actor.
    nonisolated(unsafe) private static let cache = NSCache<NSString, CachedEntry>()

    private final class CachedEntry {
        let prepared: PreparedCreativeLut
        init(_ prepared: PreparedCreativeLut) {
            self.prepared = prepared
        }
    }

    /// Returns the prepared cube, or `nil` if the resource is missing,
    /// the SHA-256 does not match the pinned hash, or the parse fails.
    /// Pipeline integration treats nil as a silent skip (cube stage is
    /// gated off, the rest of the grade still runs).
    static func load(look: FilmtoneCreativePackCatalog.BuiltInLook) -> PreparedCreativeLut? {
        if let cached = cache.object(forKey: look.slug as NSString) {
            return cached.prepared
        }

        // Pbxproj uses a yellow-folder PBXGroup for `Resources/CreativeLuts/`
        // (per project CLAUDE.md / active.md design decision), which causes
        // Xcode to flatten the bundled .cube files into `Contents/Resources/`
        // at build time. Resolve by name + extension only — `subdirectory:`
        // would return nil because the folder structure is not preserved
        // inside the .app bundle.
        guard let url = Bundle.main.url(
            forResource: (look.bundledFilename as NSString).deletingPathExtension,
            withExtension: "cube"
        ) else {
            print("[FilmtoneCreativeLutLoader] missing bundle resource for slug=\(look.slug)")
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            print("[FilmtoneCreativeLutLoader] failed to read cube data for slug=\(look.slug)")
            return nil
        }

        let actualHash = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        guard actualHash == look.pinnedSha256 else {
            print(
                "[FilmtoneCreativeLutLoader] sha256 mismatch for slug=\(look.slug) "
                + "expected=\(look.pinnedSha256) actual=\(actualHash) — fail-closed"
            )
            return nil
        }

        guard let text = String(data: data, encoding: .utf8) else {
            print("[FilmtoneCreativeLutLoader] cube is not UTF-8 for slug=\(look.slug)")
            return nil
        }

        let parsed: ParsedCubeLut
        do {
            parsed = try FilmtoneCubeParser.parse(text: text, defaultTitle: look.englishName)
        } catch {
            print("[FilmtoneCreativeLutLoader] parse failed for slug=\(look.slug): \(error)")
            return nil
        }

        let rgba = packRGBToRGBA(parsed.data, size: parsed.size)
        let cubeData = rgba.withUnsafeBufferPointer { Data(buffer: $0) }

        let prepared = PreparedCreativeLut(
            slug: look.slug,
            size: parsed.size,
            intensity: look.intensity,
            cubeData: cubeData,
            sourceHash: look.pinnedSha256
        )
        cache.setObject(CachedEntry(prepared), forKey: look.slug as NSString)
        return prepared
    }

    /// Verbatim port of iOS `rgbaCubeData(from:size:)` — promotes the
    /// Float64 RGB triples to interleaved Float32 RGBA with alpha = 1,
    /// padding to the full RGBA count if the input is short.
    private static func packRGBToRGBA(_ data: [Double], size: Int) -> [Float] {
        let expectedRGBCount = size * size * size * 3
        let expectedRGBACount = size * size * size * 4
        if data.count == expectedRGBACount {
            return data.map(Float.init)
        }

        var rgba: [Float] = []
        rgba.reserveCapacity(expectedRGBACount)
        let count = min(data.count, expectedRGBCount)
        var index = 0
        while index < count {
            rgba.append(Float(data[index]))
            rgba.append(Float(index + 1 < count ? data[index + 1] : 0))
            rgba.append(Float(index + 2 < count ? data[index + 2] : 0))
            rgba.append(1)
            index += 3
        }

        while rgba.count < expectedRGBACount {
            rgba.append(0)
            rgba.append(0)
            rgba.append(0)
            rgba.append(1)
        }
        return rgba
    }
}
