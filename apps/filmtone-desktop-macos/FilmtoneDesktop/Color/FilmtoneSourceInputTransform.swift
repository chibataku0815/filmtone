import CoreImage
import Foundation

// M5-C.1: Source-profile input transform for the macOS native pipeline.
//
// Resolves a (selection, probedColorClass) pair to a `CameraProfileCatalogEntry`
// (Auto path → match by detectionHint), builds a Rec.709 cube via
// `FilmtoneSourceProfileMath`, and applies it via
// `CIColorCubeWithColorSpace` before the grade pipeline.
//
// Cubes are cached by curve so repeat exports / preview frames reuse the same
// `Data` blob without rebuilding the cube. The cache is a Sendable-safe
// NSLock-guarded dictionary because the math is deterministic and idempotent;
// duplicating the build under contention is wasted work but never wrong.

struct PreparedSourceProfileCube: Sendable {
    let curve: SourceProfileCurve
    let size: Int
    let cubeData: Data
}

enum FilmtoneSourceInputTransform {

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [SourceProfileCurve: PreparedSourceProfileCube] = [:]

    /// Resolve the catalog entry implied by a selection + a probed color
    /// class. `.auto` defers to the prober; `.builtIn(slug)` is sticky.
    static func resolve(
        selection: CameraProfileSelection,
        probedColorClass: SourceColorClassDTO?
    ) -> CameraProfileCatalogEntry? {
        switch selection {
        case .auto:
            return FilmtoneSourceProfileCatalog.entry(forColorClass: probedColorClass)
        case .builtIn(let id):
            return FilmtoneSourceProfileCatalog.entry(forCatalogId: id)
        }
    }

    /// Prepare (or fetch from cache) a Rec.709 cube for `curve`. Returns
    /// `nil` for `nil` curve (Rec.709 passthrough — no transform needed).
    static func prepareCube(for curve: SourceProfileCurve?, size: Int = 33) -> PreparedSourceProfileCube? {
        guard let curve else { return nil }

        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let hit = cache[curve], hit.size == size {
            return hit
        }

        let rgb = makeCube(for: curve, size: size)
        let rgba = packRGBA(from: rgb, size: size)
        let prepared = PreparedSourceProfileCube(curve: curve, size: size, cubeData: rgba)
        cache[curve] = prepared
        return prepared
    }

    /// Apply the input transform for `entry` to `image`. Passthrough when
    /// `entry` is nil or the entry's curve is nil (Rec.709 passthrough).
    static func apply(to image: CIImage, entry: CameraProfileCatalogEntry?) -> CIImage {
        guard let entry, let prepared = prepareCube(for: entry.curve) else {
            return image
        }
        return image.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": prepared.size,
            "inputCubeData": prepared.cubeData,
            "inputColorSpace": FilmtoneCIContext.outputColorSpace,
        ])
    }

    /// True when the probed source color class lies outside the Rec.709 SDR
    /// envelope the Desktop pipeline can faithfully render (HDR PQ / HLG, or
    /// wide-gamut without a clear log curve), AND no catalog entry covers
    /// it. Drives the source-cap gate: the right rail surfaces a notice and
    /// Export becomes disabled.
    static func sourceExceedsCapacity(
        selection: CameraProfileSelection,
        probedColorClass: SourceColorClassDTO?
    ) -> Bool {
        guard let probedColorClass else { return false }
        switch probedColorClass {
        case .hdrPq, .hdrHlg, .wideGamutUnknown, .unsupported:
            // Manual `.builtIn(...)` lets the user assert "treat this as
            // <profile>" and lifts the gate. Auto cannot recover.
            switch selection {
            case .auto:
                return true
            case .builtIn:
                return false
            }
        case .sdrBt709, .appleLog, .appleLog2, .unknown:
            return false
        }
    }

    /// Human-readable reason for the source-cap gate, suitable for tooltip
    /// or notice copy.
    static func sourceCapReason(probedColorClass: SourceColorClassDTO?) -> String? {
        guard let probedColorClass else { return nil }
        switch probedColorClass {
        case .hdrPq:
            return "HDR PQ source — Desktop currently supports SDR Rec.709 only. Pick a Source Profile manually if you want to force a tone-mapped export."
        case .hdrHlg:
            return "HDR HLG source — Desktop currently supports SDR Rec.709 only. Pick a Source Profile manually if you want to force a tone-mapped export."
        case .wideGamutUnknown:
            return "Wide-gamut source without a recognized log curve — pick a Source Profile manually so Filmtone knows how to interpret it."
        case .unsupported:
            return "Source format is not yet supported on Desktop."
        case .sdrBt709, .appleLog, .appleLog2, .unknown:
            return nil
        }
    }

    // MARK: - Internal

    private static func makeCube(for curve: SourceProfileCurve, size: Int) -> [Float] {
        switch curve {
        case .appleLog:
            return FilmtoneSourceProfileMath.makeAppleLogToRec709Cube(size: size, rec2020GamutMap: true)
        case .appleLog2:
            return FilmtoneSourceProfileMath.makeAppleLogToRec709Cube(size: size, rec2020GamutMap: true)
        case .djiDLog:
            return FilmtoneSourceProfileMath.makeDlogToRec709Cube(size: size)
        case .djiDLogM:
            return FilmtoneSourceProfileMath.makeDlogMToRec709Cube(size: size)
        case .canonCLog:
            return FilmtoneSourceProfileMath.makeCanonClogToRec709Cube(size: size)
        case .canonLog3CinemaGamut:
            return FilmtoneSourceProfileMath.makeCanonLog3CineGamutToRec709Cube(size: size)
        case .panasonicVLog:
            return FilmtoneSourceProfileMath.makeVlogToRec709Cube(size: size)
        case .sonySLog3:
            return FilmtoneSourceProfileMath.makeSlog3ToRec709Cube(size: size)
        }
    }

    /// `CIColorCubeWithColorSpace` consumes RGBA Float32 (4 floats per
    /// voxel, alpha = 1). Math module returns RGB-packed (3 floats per
    /// voxel) to match iOS canonical; this packs to RGBA in one pass.
    private static func packRGBA(from rgb: [Float], size: Int) -> Data {
        let voxelCount = size * size * size
        precondition(rgb.count == voxelCount * 3, "cube data must be RGB Float32 of size³ voxels")
        var rgba = [Float](repeating: 0, count: voxelCount * 4)
        for index in 0..<voxelCount {
            rgba[index * 4]     = rgb[index * 3]
            rgba[index * 4 + 1] = rgb[index * 3 + 1]
            rgba[index * 4 + 2] = rgb[index * 3 + 2]
            rgba[index * 4 + 3] = 1
        }
        return rgba.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
