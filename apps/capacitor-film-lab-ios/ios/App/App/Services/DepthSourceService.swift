import AVFoundation
import CoreImage
import CoreVideo
import Foundation
import ImageIO
import simd

/// Loads depth/disparity maps from HEIC sources captured with Portrait mode
/// or LiDAR, then normalizes them into the renderer-friendly grid described
/// by `FilmtoneDepthMap` (v1.3 plan §6.1).
///
/// Behavior contract:
/// - "No depth aux data present" is a normal absent-case → returns `nil`.
/// - Technical failures (allocation, CV write, unsupported conversion) throw
///   `DepthSourceError`. Callers MUST NOT swallow these silently.
/// - All work hops to a detached background task; safe to call from `@MainActor`.
final class DepthSourceService {

    // MARK: - Errors

    enum DepthSourceError: Error {
        case unsupportedConversion
        case allocationFailed
        case readFailed(OSStatus)
    }

    // MARK: - Public API

    /// Quick presence probe (does this URL carry HEIC depth/disparity aux data?).
    /// Synchronous, light: opens the image source and asks for the auxiliary
    /// data dictionary at index 0 without decoding the depth plane.
    /// Non-HEIC paths short-circuit on extension/UTI.
    static func probeHasDepth(url: URL) -> Bool {
        guard isHeicCandidate(url: url) else {
            return false
        }
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return false
        }
        return auxiliaryInfo(from: imageSource, index: 0) != nil
    }

    /// Loads the auxiliary depth/disparity payload from `url`, converts it to
    /// metric depth, normalizes to `[0=near, 1=far]`, and returns the result.
    /// Returns `nil` when no depth aux data is present (expected, not an error).
    func loadDepthMap(from url: URL) async throws -> FilmtoneDepthMap? {
        try await Task.detached(priority: .utility) {
            try Self.loadDepthMapSync(from: url)
        }.value
    }

    // MARK: - Sync core

    private static func loadDepthMapSync(from url: URL) throws -> FilmtoneDepthMap? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        guard let auxInfo = auxiliaryInfo(from: imageSource, index: 0) else {
            // Absent depth aux data is expected for non-Portrait HEICs; return
            // nil so callers treat it as "no depth available" rather than an error.
            return nil
        }

        let avDepthData: AVDepthData
        do {
            avDepthData = try AVDepthData(fromDictionaryRepresentation: auxInfo)
        } catch {
            // Corrupt or unsupported aux dict — surface as a technical failure.
            throw DepthSourceError.unsupportedConversion
        }

        // Convert to float32 metric depth (smaller = nearer in metric space).
        let metricDepth = avDepthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let metricBuffer = metricDepth.depthDataMap

        guard let normalizedBuffer = try normalizeFloat32Depth(metricBuffer) else {
            return nil
        }

        let orientation = sourceOrientation(from: imageSource, index: 0)
        let intrinsics = Self.intrinsicsMatrix(from: metricDepth)

        return FilmtoneDepthMap(
            width: CVPixelBufferGetWidth(normalizedBuffer),
            height: CVPixelBufferGetHeight(normalizedBuffer),
            orientation: orientation,
            pixelBuffer: normalizedBuffer,
            source: .avDepthData,
            intrinsics: intrinsics
        )
    }

    // MARK: - Aux data extraction

    /// Pulls the disparity aux info dict if present, falling back to the depth
    /// aux info dict. Disparity is preferred since modern Portrait captures
    /// store disparity (1/depth) and Apple's `AVDepthData` initializer accepts
    /// either form.
    private static func auxiliaryInfo(from imageSource: CGImageSource, index: Int) -> [String: Any]? {
        let disparityKey = kCGImageAuxiliaryDataTypeDisparity
        if let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(imageSource, index, disparityKey) as? [String: Any] {
            return info
        }
        let depthKey = kCGImageAuxiliaryDataTypeDepth
        if let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(imageSource, index, depthKey) as? [String: Any] {
            return info
        }
        return nil
    }

    // MARK: - Normalization

    /// Rewrites a `kCVPixelFormatType_DepthFloat32` plane into a freshly
    /// allocated `kCVPixelFormatType_OneComponent32Float` plane with values
    /// linearly mapped to `[0=near, 1=far]`.
    ///
    /// Edge cases:
    /// - Non-finite or zero pixels (often "invalid depth" sentinels in
    ///   AVDepthData) are skipped during min/max scan AND clamped to the
    ///   midpoint `0.5` in the output so they don't poison the gradient.
    /// - When `min == max` (degenerate scene), every output pixel is `0.5`.
    private static func normalizeFloat32Depth(_ source: CVPixelBuffer) throws -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        guard width > 0, height > 0 else {
            return nil
        }

        let lockResult = CVPixelBufferLockBaseAddress(source, .readOnly)
        guard lockResult == kCVReturnSuccess else {
            throw DepthSourceError.readFailed(lockResult)
        }
        defer { CVPixelBufferUnlockBaseAddress(source, .readOnly) }

        guard let srcBase = CVPixelBufferGetBaseAddress(source) else {
            throw DepthSourceError.readFailed(kCVReturnError)
        }
        let srcStride = CVPixelBufferGetBytesPerRow(source)
        let srcPtr = srcBase.assumingMemoryBound(to: Float32.self)
        let srcRowFloats = srcStride / MemoryLayout<Float32>.size

        // Pass 1: scan for finite min/max ignoring sentinels.
        var minValue: Float32 = .greatestFiniteMagnitude
        var maxValue: Float32 = -.greatestFiniteMagnitude
        var hasFinite = false
        for y in 0..<height {
            let row = srcPtr.advanced(by: y * srcRowFloats)
            for x in 0..<width {
                let v = row[x]
                if v.isFinite, v > 0 {
                    if v < minValue { minValue = v }
                    if v > maxValue { maxValue = v }
                    hasFinite = true
                }
            }
        }

        // Allocate destination plane.
        var dstBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary,
        ]
        let allocStatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent32Float,
            attrs as CFDictionary,
            &dstBuffer
        )
        guard allocStatus == kCVReturnSuccess, let destination = dstBuffer else {
            throw DepthSourceError.allocationFailed
        }

        let dstLock = CVPixelBufferLockBaseAddress(destination, [])
        guard dstLock == kCVReturnSuccess else {
            throw DepthSourceError.readFailed(dstLock)
        }
        defer { CVPixelBufferUnlockBaseAddress(destination, []) }

        guard let dstBase = CVPixelBufferGetBaseAddress(destination) else {
            throw DepthSourceError.readFailed(kCVReturnError)
        }
        let dstStride = CVPixelBufferGetBytesPerRow(destination)
        let dstPtr = dstBase.assumingMemoryBound(to: Float32.self)
        let dstRowFloats = dstStride / MemoryLayout<Float32>.size

        // Pass 2: write normalized values. Degenerate scenes collapse to 0.5.
        let denom = maxValue - minValue
        let canNormalize = hasFinite && denom > .ulpOfOne

        for y in 0..<height {
            let srcRow = srcPtr.advanced(by: y * srcRowFloats)
            let dstRow = dstPtr.advanced(by: y * dstRowFloats)
            for x in 0..<width {
                let v = srcRow[x]
                let normalized: Float32
                if !v.isFinite || v <= 0 {
                    normalized = 0.5
                } else if canNormalize {
                    normalized = (v - minValue) / denom
                } else {
                    normalized = 0.5
                }
                dstRow[x] = normalized
            }
        }

        return destination
    }

    // MARK: - Orientation

    private static func sourceOrientation(from imageSource: CGImageSource, index: Int) -> CGImagePropertyOrientation {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any],
              let raw = properties[kCGImagePropertyOrientation] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: raw) else {
            return .up
        }
        return orientation
    }

    // MARK: - Intrinsics

    private static func intrinsicsMatrix(from depthData: AVDepthData) -> simd_float3x3? {
        guard let calibration = depthData.cameraCalibrationData else {
            return nil
        }
        return calibration.intrinsicMatrix
    }

    // MARK: - HEIC sniff

    private static func isHeicCandidate(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext == "heic" || ext == "heif" {
            return true
        }
        // Some sources hand us URLs without an extension; fall back to UTI.
        if let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let contentType = resourceValues.contentType {
            if contentType.identifier == "public.heic"
                || contentType.identifier == "public.heif"
                || contentType.identifier == "public.heif-standard" {
                return true
            }
        }
        return false
    }
}
