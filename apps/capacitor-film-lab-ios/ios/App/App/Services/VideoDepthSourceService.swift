import AVFoundation
import CoreImage
import CoreVideo
import Foundation
import ImageIO
import simd

/// Streams per-frame depth/disparity from an `AVAsset`'s depth track and
/// normalizes each frame into the renderer-friendly grid described by
/// `FilmtoneDepthMap` (v1.3 Phase B, plan §6.2).
///
/// Behavior contract:
/// - "No depth track present" is a normal absent-case: `hasDepthTrack` returns
///   `false` and `makeReader` returns `nil`. Callers MUST treat this as
///   "depth-off path" and not as an error.
/// - Unrecognized depth pixel format (neither DisparityFloat16 nor
///   DepthFloat32 readable) → throws `FilmtoneMediaError.depthUnsupportedFormat`.
///   We do NOT silently degrade because the caller (export session) requested
///   depth explicitly (`feedback_no_fallback_bug_hotbed`).
/// - Mid-stream reader failure surfaces from `nextFrame()` so the integration
///   layer can decide whether to abort the export or continue depth-off.
final class VideoDepthSourceService {

    init() {}

    /// Quick presence probe. Returns `true` when the asset contains at least
    /// one track with `mediaType == .depthData`. Does not open a reader.
    func hasDepthTrack(in asset: AVAsset) async -> Bool {
        do {
            let tracks = try await asset.loadTracks(withMediaType: .depthData)
            return !tracks.isEmpty
        } catch {
            return false
        }
    }

    /// Opens a streaming reader for the asset's first depth track. Returns
    /// `nil` when the asset carries no depth track (expected, not an error).
    /// Throws when a depth track exists but cannot be wired to an output
    /// (unsupported pixel format, reader init failure).
    func makeReader(for asset: AVAsset) async throws -> VideoDepthFrameReader? {
        let depthTracks = try await asset.loadTracks(withMediaType: .depthData)
        guard let track = depthTracks.first else {
            return nil
        }

        let preferredTransform = try await track.load(.preferredTransform)
        let orientation = Self.orientation(from: preferredTransform)

        return try VideoDepthFrameReader(
            asset: asset,
            track: track,
            orientation: orientation
        )
    }

    // MARK: - Orientation

    /// Decodes the track's `preferredTransform` into the same
    /// `CGImagePropertyOrientation` vocabulary that `FilmtoneDepthMap` already
    /// stores for stills, so downstream renderer code is source-agnostic.
    /// Falls back to `.up` for affine combinations we don't recognize (e.g.
    /// non-orthogonal mirrors).
    private static func orientation(from transform: CGAffineTransform) -> CGImagePropertyOrientation {
        let a = transform.a
        let b = transform.b
        let c = transform.c
        let d = transform.d

        if a == 1, b == 0, c == 0, d == 1 {
            return .up
        }
        if a == 0, b == 1, c == -1, d == 0 {
            return .right
        }
        if a == -1, b == 0, c == 0, d == -1 {
            return .down
        }
        if a == 0, b == -1, c == 1, d == 0 {
            return .left
        }
        return .up
    }
}

/// Pull-style reader over an `AVAssetReaderTrackOutput` for a depth track.
/// Single-consumer: callers serialize their own `nextFrame()` calls.
final class VideoDepthFrameReader {

    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    private let orientation: CGImagePropertyOrientation
    private var didStart = false
    private var isCancelled = false

    fileprivate init(
        asset: AVAsset,
        track: AVAssetTrack,
        orientation: CGImagePropertyOrientation
    ) throws {
        // DisparityFloat16 is the modern Portrait/LiDAR video format; the
        // DepthFloat32 alternative covers older or transcoded clips. Asking
        // the reader to convert handles both without us probing first.
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: [
                kCVPixelFormatType_DisparityFloat16,
                kCVPixelFormatType_DepthFloat32,
            ],
        ]

        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        trackOutput.alwaysCopiesSampleData = false

        let assetReader: AVAssetReader
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            NSLog("[VideoDepthSourceService] AVAssetReader init failed: \(error)")
            throw FilmtoneMediaError.depthUnsupportedFormat
        }

        guard assetReader.canAdd(trackOutput) else {
            NSLog("[VideoDepthSourceService] depth track output rejected by reader")
            throw FilmtoneMediaError.depthUnsupportedFormat
        }
        assetReader.add(trackOutput)

        self.reader = assetReader
        self.output = trackOutput
        self.orientation = orientation
    }

    /// Pulls the next frame from the depth track. Returns `nil` at EOF or
    /// after `cancel()`. Throws when the underlying reader transitions to
    /// `.failed` or when normalization cannot allocate.
    func nextFrame() async throws -> (presentationTime: CMTime, depthMap: FilmtoneDepthMap)? {
        if isCancelled {
            return nil
        }
        if !didStart {
            guard reader.startReading() else {
                NSLog("[VideoDepthSourceService] startReading failed: \(String(describing: reader.error))")
                throw reader.error ?? FilmtoneMediaError.depthUnsupportedFormat
            }
            didStart = true
        }

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await Task.detached(priority: .utility) { [output, reader, orientation] in
                guard let sample = output.copyNextSampleBuffer() else {
                    if reader.status == .failed, let err = reader.error {
                        NSLog("[VideoDepthSourceService] reader failed mid-stream: \(err)")
                        throw err
                    }
                    return nil
                }
                let pts = CMSampleBufferGetPresentationTimeStamp(sample)
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
                    return nil
                }
                let normalized = try Self.normalizeDepthFrame(pixelBuffer)
                let map = FilmtoneDepthMap(
                    width: CVPixelBufferGetWidth(normalized),
                    height: CVPixelBufferGetHeight(normalized),
                    orientation: orientation,
                    pixelBuffer: normalized,
                    source: .avDepthData,
                    intrinsics: nil
                )
                return (pts, map)
            }.value
        } onCancel: {
            self.cancel()
        }
    }

    /// Stops the underlying reader and marks the stream as terminated.
    /// Idempotent.
    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        if didStart, reader.status == .reading {
            reader.cancelReading()
        }
    }

    // MARK: - Per-frame normalization

    /// Mirrors `DepthSourceService.normalizeFloat32Depth` semantics: produce a
    /// freshly-allocated `kCVPixelFormatType_OneComponent32Float` plane with
    /// values linearly mapped to `[0=near, 1=far]`. We accept both
    /// DisparityFloat16 (1/depth, larger = nearer) and DepthFloat32 (metric,
    /// smaller = nearer) inputs and unify the output convention so downstream
    /// shaders stay source-agnostic.
    private static func normalizeDepthFrame(_ source: CVPixelBuffer) throws -> CVPixelBuffer {
        let format = CVPixelBufferGetPixelFormatType(source)
        switch format {
        case kCVPixelFormatType_DisparityFloat16:
            return try normalizeDisparityHalf(source)
        case kCVPixelFormatType_DepthFloat32:
            return try normalizeDepthFloat32(source)
        default:
            throw FilmtoneMediaError.depthUnsupportedFormat
        }
    }

    private static func normalizeDisparityHalf(_ source: CVPixelBuffer) throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        guard width > 0, height > 0 else {
            throw FilmtoneMediaError.depthUnsupportedFormat
        }

        let lockResult = CVPixelBufferLockBaseAddress(source, .readOnly)
        guard lockResult == kCVReturnSuccess else {
            throw FilmtoneMediaError.depthUnsupportedFormat
        }
        defer { CVPixelBufferUnlockBaseAddress(source, .readOnly) }

        guard let srcBase = CVPixelBufferGetBaseAddress(source) else {
            throw FilmtoneMediaError.depthUnsupportedFormat
        }
        let srcStride = CVPixelBufferGetBytesPerRow(source)
        let srcPtr = srcBase.assumingMemoryBound(to: UInt16.self)
        let srcRowFloats = srcStride / MemoryLayout<UInt16>.size

        // Pass 1: scan disparity range. Disparity = 1/depth, so larger value
        // corresponds to a nearer pixel; we invert during write so the output
        // convention (0=near, 1=far) matches the still path.
        var minDisp: Float32 = .greatestFiniteMagnitude
        var maxDisp: Float32 = -.greatestFiniteMagnitude
        var hasFinite = false
        for y in 0..<height {
            let row = srcPtr.advanced(by: y * srcRowFloats)
            for x in 0..<width {
                let v = Self.float16ToFloat32(row[x])
                if v.isFinite, v > 0 {
                    if v < minDisp { minDisp = v }
                    if v > maxDisp { maxDisp = v }
                    hasFinite = true
                }
            }
        }

        let destination = try allocateNormalizedPlane(width: width, height: height)
        let dstLock = CVPixelBufferLockBaseAddress(destination, [])
        guard dstLock == kCVReturnSuccess else {
            throw FilmtoneMediaError.depthUnsupportedFormat
        }
        defer { CVPixelBufferUnlockBaseAddress(destination, []) }

        guard let dstBase = CVPixelBufferGetBaseAddress(destination) else {
            throw FilmtoneMediaError.depthUnsupportedFormat
        }
        let dstStride = CVPixelBufferGetBytesPerRow(destination)
        let dstPtr = dstBase.assumingMemoryBound(to: Float32.self)
        let dstRowFloats = dstStride / MemoryLayout<Float32>.size

        let denom = maxDisp - minDisp
        let canNormalize = hasFinite && denom > .ulpOfOne

        for y in 0..<height {
            let srcRow = srcPtr.advanced(by: y * srcRowFloats)
            let dstRow = dstPtr.advanced(by: y * dstRowFloats)
            for x in 0..<width {
                let v = Self.float16ToFloat32(srcRow[x])
                let normalized: Float32
                if !v.isFinite || v <= 0 {
                    normalized = 0.5
                } else if canNormalize {
                    // Invert so output sticks to "0=near, 1=far" regardless
                    // of whether the source was disparity or metric depth.
                    let dispNorm = (v - minDisp) / denom
                    normalized = 1.0 - dispNorm
                } else {
                    normalized = 0.5
                }
                dstRow[x] = normalized
            }
        }

        return destination
    }

    private static func normalizeDepthFloat32(_ source: CVPixelBuffer) throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        guard width > 0, height > 0 else {
            throw FilmtoneMediaError.depthUnsupportedFormat
        }

        let lockResult = CVPixelBufferLockBaseAddress(source, .readOnly)
        guard lockResult == kCVReturnSuccess else {
            throw FilmtoneMediaError.depthUnsupportedFormat
        }
        defer { CVPixelBufferUnlockBaseAddress(source, .readOnly) }

        guard let srcBase = CVPixelBufferGetBaseAddress(source) else {
            throw FilmtoneMediaError.depthUnsupportedFormat
        }
        let srcStride = CVPixelBufferGetBytesPerRow(source)
        let srcPtr = srcBase.assumingMemoryBound(to: Float32.self)
        let srcRowFloats = srcStride / MemoryLayout<Float32>.size

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

        let destination = try allocateNormalizedPlane(width: width, height: height)
        let dstLock = CVPixelBufferLockBaseAddress(destination, [])
        guard dstLock == kCVReturnSuccess else {
            throw FilmtoneMediaError.depthUnsupportedFormat
        }
        defer { CVPixelBufferUnlockBaseAddress(destination, []) }

        guard let dstBase = CVPixelBufferGetBaseAddress(destination) else {
            throw FilmtoneMediaError.depthUnsupportedFormat
        }
        let dstStride = CVPixelBufferGetBytesPerRow(destination)
        let dstPtr = dstBase.assumingMemoryBound(to: Float32.self)
        let dstRowFloats = dstStride / MemoryLayout<Float32>.size

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

    private static func allocateNormalizedPlane(width: Int, height: Int) throws -> CVPixelBuffer {
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
            throw FilmtoneMediaError.depthUnsupportedFormat
        }
        return destination
    }

    /// Half→Float32 expansion. CoreVideo gives us a packed UInt16 buffer for
    /// DisparityFloat16, and Swift exposes IEEE 754 binary16 via
    /// `Float(Float16(bitPattern:))` on iOS 14+.
    private static func float16ToFloat32(_ bits: UInt16) -> Float32 {
        Float32(Float16(bitPattern: bits))
    }
}
