import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import Foundation
import ImageIO

// Phase 2 C1: probe a source URL (video) or a CIImage / CGImageSource (still)
// for the color metadata `FilmtoneColorPipeline.defaultOutputContract`
// expects. Mirrors the iOS extraction in
// `MezzanineColorProbe.sourceColorClass(track:)` and
// `SourceProbeService.colorMetadataDTO(for:asset:)`.
//
// Modern AVFoundation async API (`asset.loadTracks` / `track.load(.duration)`
// etc.) is used directly — no sync deprecation warnings introduced.
//
// Still extraction reads CGImage colorSpace via ImageIO so iPhone Display P3
// photos resolve to "smpte432" primaries and the factory returns a
// `displayP3` fallback CIImage option.
enum FilmtoneSourceProberError: Error {
    case missingVideoTrack(URL)
    case missingFormatDescription(URL)
    case unreadableStill(URL)
}

struct FilmtoneSourceProbeResult: Sendable {
    let metadata: SourceColorMetadataDTO?
    let colorClass: SourceColorClassDTO?
    let cameraOptics: CameraOpticsDTO?
}

// AVAssetTrack / AVURLAsset are not Sendable, so neither is this probe.
// The probe is consumed inside the single export Task that produced it; no
// cross-Task hand-off ever happens, so Sendable conformance is unnecessary.
struct FilmtoneVideoTrackProbe {
    let asset: AVURLAsset
    let track: AVAssetTrack
    let durationSeconds: Double
    let naturalSize: CGSize
    let preferredTransform: CGAffineTransform
    let nominalFrameRate: Float
    let metadata: SourceColorMetadataDTO?
    let colorClass: SourceColorClassDTO?
    let cameraOptics: CameraOpticsDTO?

    var probeResult: FilmtoneSourceProbeResult {
        FilmtoneSourceProbeResult(metadata: metadata, colorClass: colorClass, cameraOptics: cameraOptics)
    }
}

enum FilmtoneSourceProber {
    static func probeVideo(sourceURL: URL) async throws -> FilmtoneVideoTrackProbe {
        let asset = AVURLAsset(url: sourceURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = videoTracks.first else {
            throw FilmtoneSourceProberError.missingVideoTrack(sourceURL)
        }

        // AVAssetTrack is not Sendable; using `async let` here splits track
        // ownership across child tasks and Swift 6 flags it as a data race.
        // The variadic AVAsynchronousKeyValueLoading.load(_:_:_:_:) resolves
        // all four track properties on a single underlying request.
        let (size, transform, frameRate, descriptions) = try await track.load(
            .naturalSize,
            .preferredTransform,
            .nominalFrameRate,
            .formatDescriptions
        )
        let durationCMTime = try await asset.load(.duration)
        let durationSec = max(0, CMTimeGetSeconds(durationCMTime))

        let metadata = colorMetadata(from: descriptions, asset: asset, track: track)
        let colorClass = metadata.map(SourceColorClassifier.classify)

        let optics = await cameraOptics(
            from: descriptions,
            asset: asset,
            displayWidth: Int(size.width),
            displayHeight: Int(size.height),
            preferredTransform: transform
        )

        return FilmtoneVideoTrackProbe(
            asset: asset,
            track: track,
            durationSeconds: durationSec,
            naturalSize: size,
            preferredTransform: transform,
            nominalFrameRate: frameRate,
            metadata: metadata,
            colorClass: colorClass,
            cameraOptics: optics
        )
    }

    static func probeStill(sourceURL: URL) -> FilmtoneSourceProbeResult {
        guard
            let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
            CGImageSourceGetCount(imageSource) > 0
        else {
            return FilmtoneSourceProbeResult(metadata: nil, colorClass: nil, cameraOptics: nil)
        }

        let properties =
            CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
            as? [CFString: Any] ?? [:]

        return probeStill(properties: properties)
    }

    static func probeStill(properties: [CFString: Any]) -> FilmtoneSourceProbeResult {
        // Camera optics for stills: future work could extract EXIF focal
        // length from kCGImagePropertyExifDictionary. PNG test fixtures
        // carry no EXIF, so cameraOptics is nil → applyMask stays 0.
        let profileName =
            (properties[kCGImagePropertyProfileName] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        let colorModel = properties[kCGImagePropertyColorModel] as? String

        let primaries = primaries(forProfileName: profileName, colorModel: colorModel)
        let transfer = transfer(forProfileName: profileName)

        guard primaries != nil || transfer != nil else {
            return FilmtoneSourceProbeResult(metadata: nil, colorClass: nil, cameraOptics: nil)
        }

        let metadata = SourceColorMetadataDTO(
            colorRange: nil,
            colorSpace: nil,
            colorTransfer: transfer,
            colorPrimaries: primaries,
            logTransferFunction: nil,
            hasMasteringDisplayMetadata: false,
            hasContentLightMetadata: false
        )
        let colorClass = SourceColorClassifier.classify(metadata)
        return FilmtoneSourceProbeResult(metadata: metadata, colorClass: colorClass, cameraOptics: nil)
    }

    private static func colorMetadata(
        from descriptions: [CMFormatDescription],
        asset: AVAsset,
        track: AVAssetTrack
    ) -> SourceColorMetadataDTO? {
        guard let cmDescription = descriptions.first else {
            return nil
        }
        let extensions = (CMFormatDescriptionGetExtensions(cmDescription) as? [CFString: Any]) ?? [:]

        let rawTransfer = FormatExtensionReader.string(
            in: extensions,
            cfKey: kCMFormatDescriptionExtension_TransferFunction,
            stringKey: "TransferFunction"
        )
        let rawPrimaries = FormatExtensionReader.string(
            in: extensions,
            cfKey: kCMFormatDescriptionExtension_ColorPrimaries,
            stringKey: "ColorPrimaries"
        )
        let rawMatrix = FormatExtensionReader.string(
            in: extensions,
            cfKey: kCMFormatDescriptionExtension_YCbCrMatrix,
            stringKey: "YCbCrMatrix"
        )
        let rawLogTransfer: String? = {
            if #available(macOS 14.2, *) {
                return FormatExtensionReader.string(
                    in: extensions,
                    cfKey: kCMFormatDescriptionExtension_LogTransferFunction,
                    stringKey: "LogTransferFunction"
                )
            }
            return FormatExtensionReader.string(
                in: extensions,
                cfKey: nil,
                stringKey: "LogTransferFunction"
            )
        }()
        let formatDescriptionLogTransfer =
            SourceColorMetadataNormalizer.normalizeLogTransferFunction(rawLogTransfer)
        let sampleLogTransfer = formatDescriptionLogTransfer == nil
            ? firstSampleLogTransferFunction(asset: asset, track: track)
            : nil
        let normalizedLogTransfer = resolveLogTransfer(
            formatDescriptionRaw: rawLogTransfer,
            firstSampleFallback: sampleLogTransfer
        )

        let normalizedTransfer = SourceColorMetadataNormalizer.normalizeTransfer(rawTransfer)
        let normalizedPrimaries = SourceColorMetadataNormalizer.normalizePrimaries(rawPrimaries)
        let normalizedMatrix = SourceColorMetadataNormalizer.normalizeMatrix(rawMatrix)

        let hasMasteringDisplay = FormatExtensionReader.hasKey(
            in: extensions,
            cfKey: nil,
            stringKey: "MasteringDisplayColorVolume"
        )
        let hasContentLight = FormatExtensionReader.hasKey(
            in: extensions,
            cfKey: nil,
            stringKey: "ContentLightLevelInfo"
        )

        return SourceColorMetadataDTO(
            colorRange: nil,
            colorSpace: normalizedMatrix,
            colorTransfer: normalizedTransfer ?? normalizedLogTransfer?.rawValue,
            colorPrimaries: normalizedPrimaries,
            logTransferFunction: normalizedLogTransfer,
            hasMasteringDisplayMetadata: hasMasteringDisplay,
            hasContentLightMetadata: hasContentLight
        )
    }

    static func resolveLogTransfer(
        formatDescriptionRaw rawLogTransfer: String?,
        firstSampleFallback: SourceLogTransferFunctionDTO?
    ) -> SourceLogTransferFunctionDTO? {
        SourceColorMetadataNormalizer.normalizeLogTransferFunction(rawLogTransfer)
            ?? firstSampleFallback
    }

    private static func firstSampleLogTransferFunction(
        asset: AVAsset,
        track: AVAssetTrack
    ) -> SourceLogTransferFunctionDTO? {
        guard #available(macOS 14.2, *) else {
            return nil
        }

        do {
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(
                track: track,
                outputSettings: [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                    AVVideoAllowWideColorKey: true,
                ]
            )
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else {
                return nil
            }
            reader.add(output)
            guard reader.startReading() else {
                return nil
            }
            defer {
                if reader.status == .reading {
                    reader.cancelReading()
                }
            }
            guard
                let sampleBuffer = output.copyNextSampleBuffer(),
                let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
                let raw = CVBufferCopyAttachment(
                    imageBuffer,
                    kCVImageBufferLogTransferFunctionKey,
                    nil
                )
            else {
                return nil
            }
            return SourceColorMetadataNormalizer.normalizeLogTransferFunction(String(describing: raw))
        } catch {
            return nil
        }
    }

    // MARK: - Still helpers

    private static func primaries(
        forProfileName profileName: String?,
        colorModel: String?
    ) -> String? {
        guard let profileName else {
            // RGB / CMYK colorModel without a named profile is treated as bt709
            // (matches CIImage default sRGB / Rec.709 working space).
            if colorModel == "RGB" {
                return "bt709"
            }
            return nil
        }

        if profileName.contains("display p3") || profileName.contains("displayp3") {
            return "smpte432"
        }
        if profileName.contains("dci-p3") || profileName.contains("dci p3") {
            return "smpte431"
        }
        if profileName.contains("rec. 2020") || profileName.contains("rec.2020") || profileName.contains("bt.2020") {
            return "bt2020"
        }
        if profileName.contains("rec. 709") || profileName.contains("rec.709") || profileName.contains("bt.709") {
            return "bt709"
        }
        if profileName.contains("srgb") || profileName.contains("iec61966") {
            return "bt709"
        }
        return nil
    }

    private static func transfer(forProfileName profileName: String?) -> String? {
        guard let profileName else { return nil }
        if profileName.contains("hlg") {
            return "arib-std-b67"
        }
        if profileName.contains("pq") || profileName.contains("smpte 2084") {
            return "smpte2084"
        }
        if profileName.contains("display p3") || profileName.contains("displayp3") {
            return "iec61966-2-1"
        }
        if profileName.contains("srgb") || profileName.contains("iec61966") {
            return "iec61966-2-1"
        }
        if profileName.contains("rec. 709") || profileName.contains("rec.709") || profileName.contains("bt.709") {
            return "bt709"
        }
        return nil
    }

    // MARK: - Camera optics (Phase 2 C5c)

    private static let assumedDiagonalFovDeg = 70.0

    private static func cameraOptics(
        from descriptions: [CMFormatDescription],
        asset: AVURLAsset,
        displayWidth: Int,
        displayHeight: Int,
        preferredTransform: CGAffineTransform
    ) async -> CameraOpticsDTO {
        let width = safeDimension(displayWidth, fallback: 1920)
        let height = safeDimension(displayHeight, fallback: 1080)

        let make = await metadataString(in: asset, commonKeys: ["make"], identifierFragments: ["make"])
        let model = await metadataString(in: asset, commonKeys: ["model"], identifierFragments: ["model"])
        let lens = await metadataString(in: asset, commonKeys: [], identifierFragments: ["lens"])

        if let horizontalFov = horizontalFieldOfViewDeg(from: descriptions),
           horizontalFov > 0, horizontalFov < 179
        {
            let rotated = isRightAngleRotation(preferredTransform)
            let focal = focalPxFromFov(sizePx: rotated ? height : width, fovDeg: horizontalFov)
            return buildCameraOpticsDTO(
                source: "metadata", width: width, height: height,
                focalPx: focal, lensModel: lens, cameraMake: make, cameraModel: model
            )
        }

        let diagonal = hypot(width, height)
        let focal = focalPxFromFov(sizePx: diagonal, fovDeg: assumedDiagonalFovDeg)
        return buildCameraOpticsDTO(
            source: "assumed", width: width, height: height,
            focalPx: focal, lensModel: lens, cameraMake: make, cameraModel: model
        )
    }

    private static func buildCameraOpticsDTO(
        source: String, width: Double, height: Double,
        focalPx: Double, lensModel: String?, cameraMake: String?, cameraModel: String?
    ) -> CameraOpticsDTO {
        CameraOpticsDTO(
            source: source,
            fxPx: focalPx,
            fyPx: focalPx,
            cxPx: width / 2,
            cyPx: height / 2,
            fovXDeg: fovFromFocalPx(sizePx: width, focalPx: focalPx),
            fovYDeg: fovFromFocalPx(sizePx: height, focalPx: focalPx),
            focalLength35mm: nil,
            lensModel: lensModel,
            cameraMake: cameraMake,
            cameraModel: cameraModel
        )
    }

    private static func horizontalFieldOfViewDeg(
        from descriptions: [CMFormatDescription]
    ) -> Double? {
        guard let cmDescription = descriptions.first else { return nil }
        guard
            let extensions = CMFormatDescriptionGetExtensions(cmDescription) as? [CFString: Any],
            let raw = extensions[kCMFormatDescriptionExtension_HorizontalFieldOfView] as? NSNumber
        else {
            return nil
        }
        let deg = raw.doubleValue / 1000.0
        return deg.isFinite ? deg : nil
    }

    private static func metadataString(
        in asset: AVURLAsset,
        commonKeys: [String],
        identifierFragments: [String]
    ) async -> String? {
        let commonKeySet = Set(commonKeys.map { $0.lowercased() })
        let fragments = identifierFragments.map { $0.lowercased() }
        let common = (try? await asset.load(.commonMetadata)) ?? []
        let all = (try? await asset.load(.metadata)) ?? []
        for item in common + all {
            if let key = item.commonKey {
                let normalizedKey = String(describing: key).lowercased()
                if commonKeySet.contains(where: { normalizedKey.contains($0) }) {
                    let value = try? await item.load(.stringValue)
                    return trimmedMetadataString(value)
                }
            }
            if let identifier = item.identifier {
                let normalized = String(describing: identifier).lowercased()
                if fragments.contains(where: { normalized.contains($0) }) {
                    let value = try? await item.load(.stringValue)
                    return trimmedMetadataString(value)
                }
            }
        }
        return nil
    }

    private static func trimmedMetadataString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    private static func safeDimension(_ value: Int, fallback: Double) -> Double {
        value > 0 ? Double(value) : fallback
    }

    private static func isRightAngleRotation(_ transform: CGAffineTransform) -> Bool {
        abs(transform.b) > 0.5 && abs(transform.c) > 0.5
    }

    private static func focalPxFromFov(sizePx: Double, fovDeg: Double) -> Double {
        sizePx / (2 * tan((fovDeg * .pi / 180) / 2))
    }

    private static func fovFromFocalPx(sizePx: Double, focalPx: Double) -> Double {
        2 * atan(sizePx / (2 * focalPx)) * 180 / .pi
    }
}
