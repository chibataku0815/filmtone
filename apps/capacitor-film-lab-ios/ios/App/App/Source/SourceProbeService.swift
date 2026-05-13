import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

final class SourceProbeService {
    private let assumedDiagonalFovDeg = 70.0
    private static let toneProbeLongEdge = 96

    func probeSource(at url: URL, fallback: SourceInfoDTO?) throws -> SourceProbeDTO {
        let filename = fallback?.filename ?? url.lastPathComponent
        let kind = fallback?.kind ?? inferKind(for: url)
        let mimeType = fallback?.mimeType ?? UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
        let fileSizeBytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize

        switch kind {
        case .image:
            return try probeImage(
                at: url,
                filename: filename,
                mimeType: mimeType,
                fileSizeBytes: fileSizeBytes
            )
        case .video:
            return try probeVideo(
                at: url,
                filename: filename,
                mimeType: mimeType,
                fileSizeBytes: fileSizeBytes
            )
        }
    }

    private func inferKind(for url: URL) -> FilmtoneSourceKind {
        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .image) == true {
            return .image
        }
        return .video
    }

    private func probeImage(
        at url: URL,
        filename: String,
        mimeType: String?,
        fileSizeBytes: Int?
    ) throws -> SourceProbeDTO {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            throw FilmtoneMediaError.unsupportedSource(
                filmtoneLocalized(
                    "filmtone.error.source.image_metadata",
                    defaultValue: "This image couldn't be read.",
                    comment: "Error shown when image metadata cannot be read from the selected source."
                )
            )
        }

        let width = properties[kCGImagePropertyPixelWidth] as? Int
        let height = properties[kCGImagePropertyPixelHeight] as? Int
        let sourceToneDescriptor = Self.imageToneDescriptor(at: url)

        return SourceProbeDTO(
            uri: url.absoluteString,
            filename: filename,
            kind: .image,
            mimeType: mimeType,
            width: width,
            height: height,
            durationSec: nil,
            fileSizeBytes: fileSizeBytes,
            codec: nil,
            frameRate: nil,
            sourceToneDescriptor: sourceToneDescriptor
        )
    }

    private func probeVideo(
        at url: URL,
        filename: String,
        mimeType: String?,
        fileSizeBytes: Int?
    ) throws -> SourceProbeDTO {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw FilmtoneMediaError.unsupportedSource(
                filmtoneLocalized(
                    "filmtone.error.source.no_video_track",
                    defaultValue: "No video track was found in the selected source.",
                    comment: "Error shown when the selected video file has no video track."
                )
            )
        }

        let rawWidth = Int(abs(track.naturalSize.width).rounded())
        let rawHeight = Int(abs(track.naturalSize.height).rounded())
        let transformedSize = track.naturalSize.applying(track.preferredTransform)
        let width = Int(abs(transformedSize.width).rounded())
        let height = Int(abs(transformedSize.height).rounded())
        let durationSec = CMTimeGetSeconds(asset.duration)
        let frameRate = track.nominalFrameRate > 0 ? Double(track.nominalFrameRate) : nil
        let codec = codecLabel(for: track)
        let codecFamily = codecFamily(for: codec)
        let cameraOptics = cameraOptics(
            for: track,
            asset: asset,
            displayWidth: width,
            displayHeight: height
        )
        let sourceVideoMetadata = sourceVideoMetadata(
            for: track,
            asset: asset,
            codecFamily: codecFamily,
            rawWidth: rawWidth,
            rawHeight: rawHeight,
            displayWidth: width,
            displayHeight: height
        )
        let sourceToneDescriptor = Self.videoToneDescriptor(
            asset: asset,
            durationSec: durationSec
        )

        return SourceProbeDTO(
            uri: url.absoluteString,
            filename: filename,
            kind: .video,
            mimeType: mimeType,
            width: width,
            height: height,
            durationSec: durationSec.isFinite ? durationSec : nil,
            fileSizeBytes: fileSizeBytes,
            codec: codec,
            codecFamily: codecFamily,
            frameRate: frameRate,
            logTransferFunction: sourceVideoMetadata.logTransferFunction,
            inputTransformPolicy: sourceVideoMetadata.inputTransformPolicy,
            cameraOptics: cameraOptics,
            sourceVideoMetadata: sourceVideoMetadata,
            sourceToneDescriptor: sourceToneDescriptor
        )
    }

    // MARK: - Lightweight source tone descriptor

    private static func imageToneDescriptor(at url: URL) -> FilmtoneSourceToneDescriptor? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: toneProbeLongEdge,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return toneDescriptor(from: image)
    }

    private static func videoToneDescriptor(
        asset: AVAsset,
        durationSec: Double
    ) -> FilmtoneSourceToneDescriptor? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: toneProbeLongEdge, height: toneProbeLongEdge)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        // M1 Look Director: sample at 20/50/80% of the source duration so a
        // single mid-frame can't hide an entire night sequence or a flat
        // intro card. Single-frame / zero-duration sources keep the
        // legacy mid-frame behavior.
        let fractions: [Double]
        if durationSec.isFinite && durationSec > 0.05 {
            fractions = [0.2, 0.5, 0.8]
        } else {
            fractions = [0.0]
        }

        var samples: [FilmtoneSourceToneDescriptor] = []
        samples.reserveCapacity(fractions.count)
        for fraction in fractions {
            let second = durationSec.isFinite && durationSec > 0
                ? min(max(durationSec * fraction, 0), durationSec)
                : 0
            if let image = try? generator.copyCGImage(
                at: CMTime(seconds: second, preferredTimescale: 600),
                actualTime: nil
            ), let descriptor = toneDescriptor(from: image) {
                samples.append(descriptor)
            }
        }

        if samples.isEmpty {
            return nil
        }
        return mergeDescriptors(samples)
    }

    /// Merge per-frame descriptors so a multi-shot clip can't be hidden by a
    /// single neutral middle frame. Percentile values average, coverage and
    /// score signals take the maximum so a single night scene survives.
    private static func mergeDescriptors(
        _ samples: [FilmtoneSourceToneDescriptor]
    ) -> FilmtoneSourceToneDescriptor {
        guard let first = samples.first else {
            return FilmtoneSourceToneDescriptor(
                lumaP05: 0,
                lumaP50: 0,
                lumaP95: 0,
                lumaRangeP05P95: 0,
                shadowCoverage: 0,
                highlightCoverage: 0,
                lowMidCoverage: 0,
                saturationMean: 0
            )
        }
        if samples.count == 1 {
            return first
        }
        let count = Double(samples.count)
        let lumaP05 = samples.reduce(0.0) { $0 + $1.lumaP05 } / count
        let lumaP50 = samples.reduce(0.0) { $0 + $1.lumaP50 } / count
        let lumaP95 = samples.reduce(0.0) { $0 + $1.lumaP95 } / count
        let lumaRange = samples.reduce(0.0) { $0 + $1.lumaRangeP05P95 } / count
        let shadow = samples.map { $0.shadowCoverage }.max() ?? 0
        let highlight = samples.map { $0.highlightCoverage }.max() ?? 0
        let lowMid = samples.map { $0.lowMidCoverage }.max() ?? 0
        let saturationMean = samples.reduce(0.0) { $0 + $1.saturationMean } / count
        let night = samples.compactMap { $0.nightPracticalScore }.max()
        let highKey = samples.compactMap { $0.highKeyScore }.max()
        let lowSat = samples.compactMap { $0.lowSaturationFlatScore }.max()
        let hardness = samples.compactMap { $0.digitalHardnessScore }.max()
        return FilmtoneSourceToneDescriptor(
            lumaP05: lumaP05,
            lumaP50: lumaP50,
            lumaP95: lumaP95,
            lumaRangeP05P95: lumaRange,
            shadowCoverage: shadow,
            highlightCoverage: highlight,
            lowMidCoverage: lowMid,
            saturationMean: saturationMean,
            nightPracticalScore: night,
            highKeyScore: highKey,
            lowSaturationFlatScore: lowSat,
            digitalHardnessScore: hardness
        )
    }

    private static func toneDescriptor(from image: CGImage) -> FilmtoneSourceToneDescriptor? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            return nil
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.premultipliedLast.rawValue |
            CGBitmapInfo.byteOrder32Big.rawValue
        )

        let didDraw = pixels.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard
                let baseAddress = rawBuffer.baseAddress,
                let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: bitmapInfo.rawValue
                )
            else {
                return false
            }
            context.interpolationQuality = .low
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard didDraw else {
            return nil
        }

        var lumas: [Double] = []
        lumas.reserveCapacity(width * height)
        // Track per-pixel luma in a parallel grid so we can run a cheap
        // 4-neighbor Laplacian to estimate digital hardness without a
        // second pass over the bitmap.
        var lumaGrid = [Double](repeating: -1, count: width * height)
        var shadowCount = 0
        var highlightCount = 0
        var lowMidCount = 0
        var saturationSum = 0.0
        // Warm highlight pixel = bright luma with a red/yellow hue,
        // proxy for practical lights / candles / signage.
        var warmHighlightCount = 0
        // Saturated bright pixel = bright luma with strong chroma,
        // used as a stricter night-practical signal.
        var saturatedBrightCount = 0

        var pixelIndex = 0
        for y in 0..<height {
            let rowBase = y * bytesPerRow
            for x in 0..<width {
                let offset = rowBase + x * bytesPerPixel
                let alpha = Double(pixels[offset + 3]) / 255.0
                if alpha > 0.001 {
                    let premultiplyScale = alpha < 1 ? 1.0 / alpha : 1.0
                    let red = min(1.0, Double(pixels[offset]) / 255.0 * premultiplyScale)
                    let green = min(1.0, Double(pixels[offset + 1]) / 255.0 * premultiplyScale)
                    let blue = min(1.0, Double(pixels[offset + 2]) / 255.0 * premultiplyScale)
                    let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                    let maxChannel = max(red, green, blue)
                    let minChannel = min(red, green, blue)
                    let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0

                    lumas.append(luma)
                    lumaGrid[pixelIndex] = luma
                    saturationSum += saturation
                    if luma < 0.12 { shadowCount += 1 }
                    if luma > 0.78 { highlightCount += 1 }
                    if luma < 0.28 { lowMidCount += 1 }
                    if luma > 0.7 && red > green && red >= blue && (red - blue) > 0.18 {
                        warmHighlightCount += 1
                    }
                    if luma > 0.6 && saturation > 0.35 {
                        saturatedBrightCount += 1
                    }
                }
                pixelIndex += 1
            }
        }

        guard !lumas.isEmpty else {
            return nil
        }

        lumas.sort()
        let sampleCount = Double(lumas.count)
        let lumaP05 = percentile(lumas, 0.05)
        let lumaP50 = percentile(lumas, 0.50)
        let lumaP95 = percentile(lumas, 0.95)
        let shadowCoverage = Double(shadowCount) / sampleCount
        let highlightCoverage = Double(highlightCount) / sampleCount
        let lowMidCoverage = Double(lowMidCount) / sampleCount
        let saturationMean = saturationSum / sampleCount

        // 4-neighbor Laplacian magnitude over the populated grid. Cheap
        // proxy for "looks like digital sharpness" — high values on phone
        // HEVC, lower on Log/flat or genuine film capture. Skip if either
        // dimension is too small to have interior pixels — `1..<(n - 1)`
        // would otherwise trap on 1px / 2px-edge inputs.
        var laplacianSum = 0.0
        var laplacianCount = 0
        if width > 2 && height > 2 {
            for y in 1..<(height - 1) {
                for x in 1..<(width - 1) {
                    let i = y * width + x
                    let center = lumaGrid[i]
                    if center < 0 { continue }
                    let n = lumaGrid[i - width]
                    let s = lumaGrid[i + width]
                    let e = lumaGrid[i + 1]
                    let w = lumaGrid[i - 1]
                    if n < 0 || s < 0 || e < 0 || w < 0 { continue }
                    let lap = abs(4 * center - n - s - e - w)
                    laplacianSum += lap
                    laplacianCount += 1
                }
            }
        }
        let laplacianMean = laplacianCount > 0 ? laplacianSum / Double(laplacianCount) : 0

        let warmHighlightRatio = Double(warmHighlightCount) / sampleCount
        let saturatedBrightRatio = Double(saturatedBrightCount) / sampleCount

        // Night / practical-light: shadow-heavy frame with at least some
        // bright warm or saturated highlights. Both signals contribute, so
        // a dim shot without practical lights does not register and a bright
        // signage shot without dark surroundings does not register.
        let practicalLightTerm = min(1.0, warmHighlightRatio * 6 + saturatedBrightRatio * 4)
        let shadowTerm = clamp01((shadowCoverage - 0.18) / 0.42)
        let nightPracticalScore = clamp01(shadowTerm * practicalLightTerm)

        // High-key: bright mid-tones with sustained highlight coverage and
        // very few shadows.
        let p50Bright = clamp01((lumaP50 - 0.5) / 0.25)
        let highlightTerm = clamp01((highlightCoverage - 0.08) / 0.3)
        let shadowQuiet = clamp01(1.0 - shadowCoverage / 0.12)
        let highKeyScore = clamp01(p50Bright * 0.5 + highlightTerm * 0.4 + shadowQuiet * 0.1)

        // Low-saturation flat: narrow tonal range and low chroma. Catches
        // Log/profile material that did not metadata-match, plus genuinely
        // flat captures.
        let rangeNarrow = clamp01(1.0 - max(0, lumaP95 - lumaP05) / 0.6)
        let satLow = clamp01(1.0 - saturationMean / 0.28)
        let lowSaturationFlatScore = clamp01(rangeNarrow * 0.55 + satLow * 0.45)

        // Digital hardness: high local contrast with low chroma is the
        // worst-case for a film Look. We add detailSoftness when this is
        // high. The Laplacian threshold is calibrated empirically — phone
        // HEVC averages ~0.06, Log/flat averages ~0.02.
        let lapTerm = clamp01((laplacianMean - 0.025) / 0.06)
        let digitalHardnessScore = clamp01(lapTerm * 0.7 + (1.0 - saturationMean) * 0.3)

        return FilmtoneSourceToneDescriptor(
            lumaP05: lumaP05,
            lumaP50: lumaP50,
            lumaP95: lumaP95,
            lumaRangeP05P95: max(0, lumaP95 - lumaP05),
            shadowCoverage: shadowCoverage,
            highlightCoverage: highlightCoverage,
            lowMidCoverage: lowMidCoverage,
            saturationMean: saturationMean,
            nightPracticalScore: nightPracticalScore,
            highKeyScore: highKeyScore,
            lowSaturationFlatScore: lowSaturationFlatScore,
            digitalHardnessScore: digitalHardnessScore
        )
    }

    private static func clamp01(_ value: Double) -> Double {
        return max(0, min(1, value))
    }

    private static func percentile(_ sortedValues: [Double], _ fraction: Double) -> Double {
        guard !sortedValues.isEmpty else {
            return 0
        }
        let clampedFraction = max(0, min(1, fraction))
        let position = clampedFraction * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        }
        let blend = position - Double(lowerIndex)
        return sortedValues[lowerIndex] * (1 - blend) + sortedValues[upperIndex] * blend
    }

    // MARK: - Source video metadata (T1 HDR + T4 display/timing)

    private func sourceVideoMetadata(
        for track: AVAssetTrack,
        asset: AVAsset,
        codecFamily: SourceCodecFamilyDTO,
        rawWidth: Int,
        rawHeight: Int,
        displayWidth: Int,
        displayHeight: Int
    ) -> SourceVideoMetadataDTO {
        let colorMetadata = colorMetadataDTO(for: track, asset: asset)
        let colorClass = codecFamily == .proresRaw
            ? SourceColorClassDTO.unsupported
            : SourceColorClassifier.classify(colorMetadata)
        let hdrPolicy = HdrPreparationPolicyDeriver.derive(colorClass: colorClass)
        let inputTransformPolicy = SourceInputTransformPolicyDeriver.derive(
            colorClass: colorClass,
            codecFamily: codecFamily,
            logTransferFunction: colorMetadata.logTransferFunction
        )
        let displayGeometry = displayGeometryDTO(
            for: track,
            rawWidth: rawWidth,
            rawHeight: rawHeight,
            displayWidth: displayWidth,
            displayHeight: displayHeight
        )
        let timing = timingMetadataDTO(for: track)
        return SourceVideoMetadataDTO(
            display: displayGeometry,
            color: colorMetadata,
            colorClass: colorClass,
            hdrPreparationPolicy: hdrPolicy,
            timing: timing,
            codecFamily: codecFamily,
            logTransferFunction: colorMetadata.logTransferFunction,
            inputTransformPolicy: inputTransformPolicy
        )
    }

    private func colorMetadataDTO(for track: AVAssetTrack, asset: AVAsset) -> SourceColorMetadataDTO {
        let extensions: [CFString: Any] = {
            guard let description = track.formatDescriptions.first else { return [:] }
            let cmDescription = description as! CMFormatDescription
            return (CMFormatDescriptionGetExtensions(cmDescription) as? [CFString: Any]) ?? [:]
        }()

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
        let rawLogTransfer = {
            if #available(iOS 17.2, *) {
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
        // Mastering display and content light CFString constants are not reliably
        // exported by every SDK. Always pass nil for cfKey and rely on the String
        // lookup. Presence alone is enough; payload is not inspected in v1.1.
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

        let normalizedTransfer = SourceColorMetadataNormalizer.normalizeTransfer(rawTransfer)
        let normalizedPrimaries = SourceColorMetadataNormalizer.normalizePrimaries(rawPrimaries)
        let normalizedMatrix = SourceColorMetadataNormalizer.normalizeMatrix(rawMatrix)
        let normalizedLogTransfer = SourceColorMetadataNormalizer.normalizeLogTransferFunction(rawLogTransfer)
            ?? firstSampleLogTransferFunction(asset: asset, track: track)

        return SourceColorMetadataDTO(
            colorRange: nil,
            // iOS has no separate "color space" attachment at the formatDescription level;
            // the YCbCr matrix is the closest analog. The classifier accepts bt2020nc/c
            // from this slot to keep wide-gamut detection working for iPhone HLG clips.
            colorSpace: normalizedMatrix,
            colorTransfer: normalizedTransfer ?? normalizedLogTransfer?.rawValue,
            colorPrimaries: normalizedPrimaries,
            logTransferFunction: normalizedLogTransfer,
            hasMasteringDisplayMetadata: hasMasteringDisplay,
            hasContentLightMetadata: hasContentLight
        )
    }

    private func firstSampleLogTransferFunction(asset: AVAsset, track: AVAssetTrack) -> SourceLogTransferFunctionDTO? {
        guard #available(iOS 17.2, *) else {
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
                let raw = CVBufferGetAttachment(imageBuffer, kCVImageBufferLogTransferFunctionKey, nil)?
                    .takeUnretainedValue()
            else {
                return nil
            }
            return SourceColorMetadataNormalizer.normalizeLogTransferFunction(String(describing: raw))
        } catch {
            return nil
        }
    }

    private func displayGeometryDTO(
        for track: AVAssetTrack,
        rawWidth: Int,
        rawHeight: Int,
        displayWidth: Int,
        displayHeight: Int
    ) -> SourceDisplayGeometryDTO {
        let (rotationDeg, source) = rotationFromTransform(track.preferredTransform)
        return SourceDisplayGeometryDTO(
            rawWidth: rawWidth,
            rawHeight: rawHeight,
            displayWidth: displayWidth,
            displayHeight: displayHeight,
            rotationDeg: rotationDeg,
            source: source
        )
    }

    private func rotationFromTransform(_ transform: CGAffineTransform) -> (Int?, String) {
        // Classify the 4 canonical MP4/MOV rotations. preferredTransform is the
        // concatenation of rotation + flip; for portrait clips iOS emits one of:
        //   0:   identity                (a= 1, b= 0, c= 0, d= 1)
        //   90:  clockwise               (a= 0, b= 1, c=-1, d= 0)
        //   180: upside-down             (a=-1, b= 0, c= 0, d=-1)
        //   270: counter-clockwise       (a= 0, b=-1, c= 1, d= 0)
        let epsilon = 0.01
        let a = transform.a
        let b = transform.b
        let c = transform.c
        let d = transform.d
        func near(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool { abs(lhs - rhs) < epsilon }

        if near(a, 1), near(b, 0), near(c, 0), near(d, 1) {
            return (0, "preferred-transform")
        }
        if near(a, 0), near(b, 1), near(c, -1), near(d, 0) {
            return (90, "preferred-transform")
        }
        if near(a, -1), near(b, 0), near(c, 0), near(d, -1) {
            return (180, "preferred-transform")
        }
        if near(a, 0), near(b, -1), near(c, 1), near(d, 0) {
            return (270, "preferred-transform")
        }
        return (nil, "raw")
    }

    private func timingMetadataDTO(for track: AVAssetTrack) -> SourceVideoTimingMetadataDTO {
        let nominal = Double(track.nominalFrameRate)
        let isValid = nominal.isFinite && nominal > 0
        return SourceVideoTimingMetadataDTO(
            nominalFrameRate: isValid ? nominal : nil,
            // v1.1 does not probe sample buffers, so estimatedFrameRate stays nil.
            // VFR / rates-diverged detection is deferred to v1.2 bounded sampling.
            estimatedFrameRate: nil,
            sourceFrameRateTrusted: isValid,
            trustReason: isValid ? "nominal-only" : "missing-or-invalid-rate"
        )
    }

    private func cameraOptics(
        for track: AVAssetTrack,
        asset: AVAsset,
        displayWidth: Int,
        displayHeight: Int
    ) -> CameraOpticsDTO {
        let width = safeDimension(displayWidth, fallback: 1920)
        let height = safeDimension(displayHeight, fallback: 1080)
        let make = metadataString(
            in: asset,
            commonKeys: ["make"],
            identifierFragments: ["make"]
        )
        let model = metadataString(
            in: asset,
            commonKeys: ["model"],
            identifierFragments: ["model"]
        )
        let lens = metadataString(
            in: asset,
            commonKeys: [],
            identifierFragments: ["lens"]
        )

        if let horizontalFov = horizontalFieldOfViewDeg(for: track),
           horizontalFov > 0,
           horizontalFov < 179
        {
            let rotated = isRightAngleRotation(track.preferredTransform)
            let focal = focalPxFromFov(
                sizePx: rotated ? height : width,
                fovDeg: horizontalFov
            )
            return cameraOptics(
                source: "metadata",
                width: width,
                height: height,
                focalPx: focal,
                lensModel: lens,
                cameraMake: make,
                cameraModel: model
            )
        }

        let diagonal = hypot(width, height)
        let focal = focalPxFromFov(sizePx: diagonal, fovDeg: assumedDiagonalFovDeg)
        return cameraOptics(
            source: "assumed",
            width: width,
            height: height,
            focalPx: focal,
            lensModel: lens,
            cameraMake: make,
            cameraModel: model
        )
    }

    private func cameraOptics(
        source: String,
        width: Double,
        height: Double,
        focalPx: Double,
        lensModel: String?,
        cameraMake: String?,
        cameraModel: String?
    ) -> CameraOpticsDTO {
        return CameraOpticsDTO(
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

    private func horizontalFieldOfViewDeg(for track: AVAssetTrack) -> Double? {
        guard let description = track.formatDescriptions.first else {
            return nil
        }
        let cmDescription = description as! CMFormatDescription
        guard
            let extensions = CMFormatDescriptionGetExtensions(cmDescription) as? [CFString: Any],
            let raw = extensions[kCMFormatDescriptionExtension_HorizontalFieldOfView] as? NSNumber
        else {
            return nil
        }
        let deg = raw.doubleValue / 1000.0
        return deg.isFinite ? deg : nil
    }

    private func metadataString(
        in asset: AVAsset,
        commonKeys: [String],
        identifierFragments: [String]
    ) -> String? {
        let commonKeySet = Set(commonKeys.map { $0.lowercased() })
        let fragments = identifierFragments.map { $0.lowercased() }
        for item in asset.commonMetadata + asset.metadata {
            if let key = item.commonKey {
                let normalizedKey = String(describing: key).lowercased()
                if commonKeySet.contains(where: { normalizedKey.contains($0) }) {
                    return trimmedMetadataString(item.stringValue)
                }
            }
            if let identifier = item.identifier {
                let normalized = String(describing: identifier).lowercased()
                if fragments.contains(where: { normalized.contains($0) }) {
                    return trimmedMetadataString(item.stringValue)
                }
            }
        }
        return nil
    }

    private func trimmedMetadataString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    private func safeDimension(_ value: Int, fallback: Double) -> Double {
        return value > 0 ? Double(value) : fallback
    }

    private func isRightAngleRotation(_ transform: CGAffineTransform) -> Bool {
        return abs(transform.b) > 0.5 && abs(transform.c) > 0.5
    }

    private func focalPxFromFov(sizePx: Double, fovDeg: Double) -> Double {
        return sizePx / (2 * tan((fovDeg * .pi / 180) / 2))
    }

    private func fovFromFocalPx(sizePx: Double, focalPx: Double) -> Double {
        return 2 * atan(sizePx / (2 * focalPx)) * 180 / .pi
    }

    private func codecLabel(for track: AVAssetTrack) -> String? {
        guard let description = track.formatDescriptions.first else {
            return nil
        }
        let mediaSubType = CMFormatDescriptionGetMediaSubType(description as! CMFormatDescription)
        return fourCCString(mediaSubType)
    }

    private func codecFamily(for codec: String?) -> SourceCodecFamilyDTO {
        switch codec?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "avc1", "avc3", "h264":
            return .h264
        case "hvc1", "hev1", "hevc":
            return .hevc
        case "apco", "apcs", "apcn", "apch":
            return .prores422
        case "ap4h", "ap4x":
            return .prores4444
        case "aprn", "aprh":
            return .proresRaw
        default:
            return .other
        }
    }

    private func fourCCString(_ value: FourCharCode) -> String {
        let bytes: [CChar] = [
            CChar((value >> 24) & 0xff),
            CChar((value >> 16) & 0xff),
            CChar((value >> 8) & 0xff),
            CChar(value & 0xff),
            0,
        ]
        return String(cString: bytes)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
