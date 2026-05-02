import AVFoundation
import CoreImage
import CryptoKit
import Foundation
import VideoToolbox

/// Mezzanine profile variant. SDR/HDR are preview-grade (1920 long edge, modest
/// bitrate, used by Speed export). qualitySDR/qualityHDR are master-grade
/// (source resolution preserved, near-lossless bitrate, used by Quality export
/// for heavy external sources — ProRes, DNxHD, >100Mbps HEVC). The variant is
/// part of the cache key so all four mezzanines for the same source coexist.
enum ProfileVariant: String {
    case sdr
    case hdr
    case qualitySDR
    case qualityHDR
}

final class MezzanineService {
    struct Profile {
        // v=3: HDR mezzanine (v1.2). v=4: depth flag participation (v1.3) — every
        // prior cache entry naturally invalidates on the bump. The `depthEnabled`
        // discriminator added to the signature payload below means a depth-on
        // export does not collide with a depth-off export from the same source.
        // v=5: qualitySDR/qualityHDR variants (v1.4) — adds source-resolution
        // master-grade mezzanine for heavy external sources so Quality export
        // can skip raw decode.
        static let version = 5

        let variant: ProfileVariant
        let codec: AVVideoCodecType
        /// Long-edge target for downscale variants (sdr/hdr). Quality variants
        /// ignore this and preserve source resolution via `outputSize(forTrack:)`.
        let longEdge: Int
        /// Fixed bitrate for sdr/hdr; base 4K bitrate for quality* (scales by
        /// output area via `effectiveBitrate(forOutputSize:)`, floor 2 Mbps).
        let bitrate: Int

        static let sdr = Profile(
            variant: .sdr,
            codec: .h264,
            longEdge: 1920,
            bitrate: 12_000_000
        )

        static let hdr = Profile(
            variant: .hdr,
            codec: .hevc,
            longEdge: 1920,
            bitrate: 25_000_000
        )

        static let qualitySDR = Profile(
            variant: .qualitySDR,
            codec: .hevc,
            longEdge: 0,
            bitrate: 80_000_000
        )

        static let qualityHDR = Profile(
            variant: .qualityHDR,
            codec: .hevc,
            longEdge: 0,
            bitrate: 120_000_000
        )

        static func profile(for variant: ProfileVariant) -> Profile {
            switch variant {
            case .sdr: return .sdr
            case .hdr: return .hdr
            case .qualitySDR: return .qualitySDR
            case .qualityHDR: return .qualityHDR
            }
        }

        /// True if this variant emits 10-bit BT.2020/HLG-tagged output.
        var isHDR: Bool {
            switch variant {
            case .hdr, .qualityHDR: return true
            case .sdr, .qualitySDR: return false
            }
        }

        /// True if this variant skips downscale and emits at the source's
        /// native resolution (quality variants).
        var preservesSourceResolution: Bool {
            switch variant {
            case .qualitySDR, .qualityHDR: return true
            case .sdr, .hdr: return false
            }
        }

        func outputSize(forTrack track: AVAssetTrack) -> CGSize {
            if preservesSourceResolution {
                let transformed = track.naturalSize.applying(track.preferredTransform)
                let w = max(2, Int(abs(transformed.width).rounded()) / 2 * 2)
                let h = max(2, Int(abs(transformed.height).rounded()) / 2 * 2)
                return CGSize(width: w, height: h)
            }
            return FilmtoneExportSession.scaledSize(for: track, longEdge: longEdge)
        }

        /// Quality variants scale base bitrate by output area (4K = 1.0).
        /// FHD ends up around 25%, 2K around 50%. Floor at 2 Mbps so very small
        /// outputs still get a reasonable encode.
        func effectiveBitrate(forOutputSize size: CGSize) -> Int {
            guard preservesSourceResolution else { return bitrate }
            let area = size.width * size.height
            let fourKArea: CGFloat = 3840 * 2160
            let scale = min(1.0, max(0.0, area / fourKArea))
            return max(2_000_000, Int(CGFloat(bitrate) * scale))
        }
    }

    struct Limits {
        // v1.4: expanded from 1 GB / 4 entries to fit qualitySDR + qualityHDR
        // alongside preview-grade variants for several heavy sources. Sits in
        // Library/Caches/FilmtonePhase0/mezzanine/ so the OS can purge under
        // disk pressure; user data is unaffected.
        static let maxBytes: Int64 = 4_294_967_296
        static let maxEntries: Int = 16
    }

    enum GenerationError: Error {
        case unsupportedSource(String)
        case writerFailed(String)
        case readerFailed(String)
        case cancelled
    }

    private let cacheStore: CacheStore
    private let fileManager: FileManager
    private let ciContext: CIContext
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let inFlightQueue = DispatchQueue(label: "MezzanineService.inflight")
    private var inFlight: [String: Task<URL, Error>] = [:]

    init(
        cacheStore: CacheStore,
        fileManager: FileManager = .default
    ) {
        self.cacheStore = cacheStore
        self.fileManager = fileManager
        self.ciContext = CIContext(options: [
            .cacheIntermediates: false,
            .priorityRequestLow: true,
        ])
        // Lazy cold-start prune: any files left past caps from a prior session
        // or an unclean shutdown get evicted before we start writing new ones.
        try? cacheStore.pruneMezzanine(
            maxBytes: Limits.maxBytes,
            maxEntries: Limits.maxEntries
        )
    }

    // MARK: - Signature

    /// SHA-256 cache key over (source identity, profile variant + version + codec settings).
    /// Variant is in the payload so SDR and HDR cache files for the same source never collide.
    /// Bumping `Profile.version` invalidates every prior entry on next lookup.
    /// v1.3: `depthEnabled` participates in the payload so depth-on / depth-off exports
    /// from the same source live in different cache slots without poisoning one another.
    func signature(for sourceURL: URL, profile: Profile, depthEnabled: Bool = false) throws -> String {
        let attrs = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let mtimeMs: Int64 = {
            guard let date = attrs[.modificationDate] as? Date else { return 0 }
            return Int64(date.timeIntervalSince1970 * 1000)
        }()
        let durationSec = Int(CMTimeGetSeconds(AVURLAsset(url: sourceURL).duration).rounded())

        let payload: [String: Any] = [
            "path": sourceURL.path,
            "sizeBytes": size,
            "mtimeMs": mtimeMs,
            "trackDurationRoundedSec": durationSec,
            "profile": [
                "version": Profile.version,
                "variant": profile.variant.rawValue,
                "codec": profile.codec.rawValue,
                "longEdge": profile.longEdge,
                "bitrate": profile.bitrate,
            ],
            "depthEnabled": depthEnabled,
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        )
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Public API

    /// Returns mezzanine URL if a valid cache file already exists for `sourceURL` at `variant`.
    /// Touches contentModificationDate for LRU recency. Does not trigger generation.
    /// `depthEnabled` participates in the cache key (see `signature(for:profile:depthEnabled:)`).
    func existingMezzanineURL(
        for sourceURL: URL,
        variant: ProfileVariant,
        depthEnabled: Bool = false
    ) -> URL? {
        let profile = Profile.profile(for: variant)
        guard let sig = try? signature(for: sourceURL, profile: profile, depthEnabled: depthEnabled),
              let url = try? cacheStore.mezzanineFileURL(signature: sig),
              fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        try? cacheStore.touch(url)
        return url
    }

    /// Ensures a mezzanine file for `sourceURL` exists at `variant`, generating if missing.
    /// Multiple concurrent calls for the same (source, variant) coalesce to a single task.
    /// Generation is atomic: writes to a `.partial` sibling and renames on success
    /// so a crash mid-transcode never leaves a readable-but-corrupt `.mp4` behind.
    /// `depthEnabled` participates in the cache key (see `signature(for:profile:depthEnabled:)`).
    @discardableResult
    func ensureMezzanine(
        sourceURL: URL,
        variant: ProfileVariant = .sdr,
        depthEnabled: Bool = false
    ) async throws -> URL {
        let profile = Profile.profile(for: variant)
        let sig = try signature(for: sourceURL, profile: profile, depthEnabled: depthEnabled)
        let destURL = try cacheStore.mezzanineFileURL(signature: sig)

        if fileManager.fileExists(atPath: destURL.path) {
            return destURL
        }

        let task: Task<URL, Error> = inFlightQueue.sync {
            if let existing = inFlight[sig] { return existing }
            let tempURL = destURL.appendingPathExtension("partial")
            let newTask = Task<URL, Error> { [weak self] in
                guard let self else { throw GenerationError.cancelled }
                defer {
                    self.inFlightQueue.sync { self.inFlight[sig] = nil }
                }
                // Clean any stale partial from a prior crashed run.
                try? self.fileManager.removeItem(at: tempURL)
                try Task.checkCancellation()
                try await self.generate(
                    sourceURL: sourceURL,
                    destinationURL: tempURL,
                    profile: profile
                )
                try Task.checkCancellation()
                // Atomic promote so existingMezzanineURL only ever sees complete files.
                if self.fileManager.fileExists(atPath: destURL.path) {
                    try? self.fileManager.removeItem(at: destURL)
                }
                try self.fileManager.moveItem(at: tempURL, to: destURL)
                try? self.cacheStore.touch(destURL)
                try? self.cacheStore.pruneMezzanine(
                    maxBytes: Limits.maxBytes,
                    maxEntries: Limits.maxEntries
                )
                return destURL
            }
            inFlight[sig] = newTask
            return newTask
        }

        return try await task.value
    }

    // MARK: - Generation

    private func generate(sourceURL: URL, destinationURL: URL, profile: Profile) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .utility).async { [self] in
                do {
                    try self.generateSync(
                        sourceURL: sourceURL,
                        destinationURL: destinationURL,
                        profile: profile
                    )
                    continuation.resume(returning: ())
                } catch {
                    // Clean partial output on failure so a future ensure retries.
                    try? self.fileManager.removeItem(at: destinationURL)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func generateSync(sourceURL: URL, destinationURL: URL, profile: Profile) throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw GenerationError.unsupportedSource("No video track found.")
        }

        let outputSize = profile.outputSize(forTrack: videoTrack)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)
        writer.movieFragmentInterval = .invalid

        let width = Int(outputSize.width.rounded())
        let height = Int(outputSize.height.rounded())
        // D2.2 / v1.4: profile.variant drives codec, profile level, color metadata, pixel format.
        // sdr         → H.264 High AutoLevel, 32BGRA, deviceRGB (byte-identical to v=2 preview path).
        // hdr         → HEVC Main10 AutoLevel, 420YpCbCr10BiPlanarVideoRange, BT.2020 / HLG metadata.
        // qualitySDR  → HEVC Main AutoLevel at source resolution, 32BGRA, deviceRGB.
        // qualityHDR  → HEVC Main10 AutoLevel at source resolution, 420YpCbCr10BiPlanarVideoRange,
        //               BT.2020 / HLG metadata.
        // Quality variants are gated by FilmtoneMezzanineRoutePolicy.qualityPrewarmVariant —
        // only invoked for ProRes / DNxHD / >100 Mbps sources where re-encode is a net UX win.
        let isHDR = profile.isHDR
        let bitrate = profile.effectiveBitrate(forOutputSize: outputSize)
        let profileLevel: String = {
            switch profile.codec {
            case .hevc:
                return isHDR
                    ? (kVTProfileLevel_HEVC_Main10_AutoLevel as String)
                    : (kVTProfileLevel_HEVC_Main_AutoLevel as String)
            default:
                return AVVideoProfileLevelH264HighAutoLevel
            }
        }()
        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoProfileLevelKey: profileLevel,
            AVVideoAllowFrameReorderingKey: false,
        ]
        var videoSettings: [String: Any] = [
            AVVideoCodecKey: profile.codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: compressionProperties,
        ]
        if isHDR {
            videoSettings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
            ]
        }
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = .identity

        let writerPixelFormat: OSType = isHDR
            ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            : kCVPixelFormatType_32BGRA
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(writerPixelFormat),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw GenerationError.writerFailed("Video input could not be added.")
        }
        writer.add(videoInput)

        let audioTrack = asset.tracks(withMediaType: .audio).first
        let audioOutput: AVAssetReaderTrackOutput?
        let audioInput: AVAssetWriterInput?
        if let audioTrack {
            let output = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                ]
            )
            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVEncoderBitRateKey: 128_000,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 44_100,
                ]
            )
            input.expectsMediaDataInRealTime = false
            audioOutput = output
            audioInput = input
            if writer.canAdd(input) { writer.add(input) }
        } else {
            audioOutput = nil
            audioInput = nil
        }

        let reader = try AVAssetReader(asset: asset)
        // Reader pixel format must match the variant: SDR keeps 8-bit 32BGRA so the
        // current deviceRGB CIContext path stays byte-identical; HDR upgrades to
        // 10-bit 4:2:0 video-range to preserve wide-gamut precision end-to-end.
        let readerPixelFormat: OSType = isHDR
            ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            : kCVPixelFormatType_32BGRA
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(readerPixelFormat),
            ]
        )
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else {
            throw GenerationError.readerFailed("Video output could not be added.")
        }
        reader.add(videoOutput)

        if let audioOutput, reader.canAdd(audioOutput) {
            reader.add(audioOutput)
        }

        guard writer.startWriting() else {
            throw GenerationError.writerFailed(writer.error?.localizedDescription ?? "Writer failed to start.")
        }
        guard reader.startReading() else {
            throw GenerationError.readerFailed(reader.error?.localizedDescription ?? "Reader failed to start.")
        }
        writer.startSession(atSourceTime: .zero)

        // Per-call HDR rendering pipeline: Rec.2020 working color space + half-float RGBA
        // working format keeps wide-gamut precision through CI; render colorSpace is
        // ITU-R 2100 HLG so the encoder receives correctly-tagged HLG samples that match
        // the AVVideoColorPropertiesKey tags above. SDR path keeps the long-lived
        // deviceRGB ciContext untouched to stay byte-identical to v=2.
        let renderContext: CIContext
        let renderColorSpace: CGColorSpace
        if isHDR {
            let workingSpace = CGColorSpace(name: CGColorSpace.itur_2020)
                ?? CGColorSpaceCreateDeviceRGB()
            renderContext = CIContext(options: [
                .cacheIntermediates: false,
                .priorityRequestLow: true,
                .workingColorSpace: workingSpace,
                .workingFormat: NSNumber(value: CIFormat.RGBAh.rawValue),
            ])
            renderColorSpace = CGColorSpace(name: CGColorSpace.itur_2100_HLG)
                ?? workingSpace
        } else {
            renderContext = self.ciContext
            renderColorSpace = self.colorSpace
        }

        let group = DispatchGroup()
        let videoQueue = DispatchQueue(label: "MezzanineService.video")
        let audioQueue = DispatchQueue(label: "MezzanineService.audio")
        let failureLock = NSLock()
        let completionLock = NSLock()
        var videoFinished = false
        var audioFinished = audioInput == nil
        var capturedError: Error?

        let preferredTransform = videoTrack.preferredTransform

        func finishVideo(markAsFinished: Bool) {
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !videoFinished else { return }
            if markAsFinished { videoInput.markAsFinished() }
            videoFinished = true
            group.leave()
        }

        func finishAudio(markAsFinished: Bool) {
            guard let audioInput else { return }
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !audioFinished else { return }
            if markAsFinished { audioInput.markAsFinished() }
            audioFinished = true
            group.leave()
        }

        func fail(_ error: Error) {
            failureLock.lock()
            let shouldStore = capturedError == nil
            if shouldStore { capturedError = error }
            failureLock.unlock()
            guard shouldStore else { return }
            reader.cancelReading()
            writer.cancelWriting()
            finishVideo(markAsFinished: true)
            finishAudio(markAsFinished: true)
        }

        group.enter()
        videoInput.requestMediaDataWhenReady(on: videoQueue) {
            while videoInput.isReadyForMoreMediaData {
                if capturedError != nil {
                    finishVideo(markAsFinished: true)
                    return
                }
                autoreleasepool {
                    guard let sampleBuffer = videoOutput.copyNextSampleBuffer() else {
                        if reader.status == .failed {
                            fail(GenerationError.readerFailed(reader.error?.localizedDescription ?? "Video read failed."))
                        } else {
                            finishVideo(markAsFinished: true)
                        }
                        return
                    }

                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                        return
                    }
                    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let sourceImage = self.orientAndScale(
                        CIImage(cvPixelBuffer: pixelBuffer),
                        transform: preferredTransform,
                        outputSize: outputSize
                    )

                    guard let pool = adaptor.pixelBufferPool else {
                        fail(GenerationError.writerFailed("Pixel buffer pool unavailable."))
                        return
                    }
                    var rendered: CVPixelBuffer?
                    let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &rendered)
                    guard status == kCVReturnSuccess, let rendered else {
                        fail(GenerationError.writerFailed("Could not create output pixel buffer."))
                        return
                    }

                    renderContext.render(
                        sourceImage,
                        to: rendered,
                        bounds: CGRect(origin: .zero, size: outputSize),
                        colorSpace: renderColorSpace
                    )

                    if !adaptor.append(rendered, withPresentationTime: presentationTime) {
                        fail(GenerationError.writerFailed(writer.error?.localizedDescription ?? "Append failed."))
                        return
                    }
                }
            }
        }

        if let audioInput, let audioOutput {
            group.enter()
            audioInput.requestMediaDataWhenReady(on: audioQueue) {
                while audioInput.isReadyForMoreMediaData {
                    if capturedError != nil {
                        finishAudio(markAsFinished: true)
                        return
                    }
                    guard let sampleBuffer = audioOutput.copyNextSampleBuffer() else {
                        if reader.status == .failed {
                            fail(GenerationError.readerFailed(reader.error?.localizedDescription ?? "Audio read failed."))
                        } else {
                            finishAudio(markAsFinished: true)
                        }
                        return
                    }
                    if !audioInput.append(sampleBuffer) {
                        fail(GenerationError.writerFailed(writer.error?.localizedDescription ?? "Audio append failed."))
                        return
                    }
                }
            }
        }

        group.wait()

        if let capturedError {
            throw capturedError
        }

        if reader.status == .failed {
            throw GenerationError.readerFailed(reader.error?.localizedDescription ?? "Reader failed.")
        }

        let finishGroup = DispatchGroup()
        finishGroup.enter()
        writer.finishWriting {
            finishGroup.leave()
        }
        finishGroup.wait()

        if writer.status != .completed {
            throw GenerationError.writerFailed(writer.error?.localizedDescription ?? "Writer did not complete.")
        }
    }

    private func orientAndScale(
        _ image: CIImage,
        transform: CGAffineTransform,
        outputSize: CGSize
    ) -> CIImage {
        let oriented = image.transformed(by: FilmtoneExportSession.coreImageVideoTransform(
            for: transform,
            sourceExtent: image.extent
        ))
        let normalized = oriented.transformed(by: CGAffineTransform(
            translationX: -oriented.extent.origin.x,
            y: -oriented.extent.origin.y
        ))
        let scaleX = outputSize.width / normalized.extent.width
        let scaleY = outputSize.height / normalized.extent.height
        return normalized
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: CGRect(origin: .zero, size: outputSize))
    }
}
