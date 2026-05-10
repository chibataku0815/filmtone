// Filmtone V2 native camera capture — completed-take preview loading.

import AVFoundation
import CoreImage
import UIKit

#if os(iOS)

struct FilmtoneCaptureTakeFrameSample: Identifiable {
    let index: Int
    let seconds: Double
    let displayImage: UIImage?
    let sourceImage: UIImage?

    var id: Int { index }
    var image: UIImage? { displayImage }

    init(index: Int, seconds: Double, image: UIImage?) {
        self.index = index
        self.seconds = seconds
        self.displayImage = image
        self.sourceImage = image
    }

    init(
        index: Int,
        seconds: Double,
        displayImage: UIImage?,
        sourceImage: UIImage?
    ) {
        self.index = index
        self.seconds = seconds
        self.displayImage = displayImage
        self.sourceImage = sourceImage
    }
}

final class FilmtoneCaptureTakePreviewLoader {
    static let shared = FilmtoneCaptureTakePreviewLoader()

    private struct FrameCacheKey: Hashable {
        let captureId: String
        let proxyPath: String
        let compact: Bool
    }

    private struct GradedCacheKey: Hashable {
        let captureId: String
        let sampleIndex: Int
        let lookToken: String
        let compact: Bool
    }

    private let lock = NSLock()
    private var frameCache: [FrameCacheKey: [FilmtoneCaptureTakeFrameSample]] = [:]
    private var gradedCache: [GradedCacheKey: UIImage] = [:]
    private static let displayContext = CIContext(options: [.cacheIntermediates: false])

    private init() {}

    static func placeholderSamples(
        duration: Double,
        isCompactHeight: Bool
    ) -> [FilmtoneCaptureTakeFrameSample] {
        sampleFractions(isCompactHeight: isCompactHeight).enumerated().map { index, fraction in
            FilmtoneCaptureTakeFrameSample(
                index: index,
                seconds: sampleSeconds(for: fraction, duration: duration),
                image: nil
            )
        }
    }

    static func defaultSelectedIndex(isCompactHeight: Bool) -> Int {
        isCompactHeight ? 2 : 3
    }

    func loadSamples(
        for package: FilmtoneCapturePackage,
        isCompactHeight: Bool
    ) async -> [FilmtoneCaptureTakeFrameSample] {
        let key = FrameCacheKey(
            captureId: package.captureId,
            proxyPath: package.proxyURL.path,
            compact: isCompactHeight
        )
        if let cached = cachedFrames(for: key) {
            return cached
        }

        let samples = await Self.makeSamples(
            for: package.proxyURL,
            packageDuration: package.recordedDurationSeconds,
            isCompactHeight: isCompactHeight
        )
        storeFrames(samples, for: key)
        return samples
    }

    func gradedSelectedImage(
        for package: FilmtoneCapturePackage,
        sample: FilmtoneCaptureTakeFrameSample,
        isCompactHeight: Bool,
        gradeProcessor: FilmtoneSharedGradeProcessor?
    ) async -> UIImage? {
        guard let sourceImage = sample.sourceImage ?? sample.displayImage else { return nil }
        guard let gradeProcessor else { return sample.displayImage ?? sourceImage }

        let key = GradedCacheKey(
            captureId: package.captureId,
            sampleIndex: sample.index,
            lookToken: Self.lookToken(for: package),
            compact: isCompactHeight
        )
        if let cached = cachedGradedImage(for: key) {
            return cached
        }

        let graded = Self.renderedImage(
            from: sourceImage,
            gradeProcessor: gradeProcessor
        )
        if let graded {
            storeGradedImage(graded, for: key)
        }
        return graded ?? sample.displayImage ?? sourceImage
    }

    private func cachedFrames(
        for key: FrameCacheKey
    ) -> [FilmtoneCaptureTakeFrameSample]? {
        lock.lock()
        defer { lock.unlock() }
        return frameCache[key]
    }

    private func storeFrames(
        _ samples: [FilmtoneCaptureTakeFrameSample],
        for key: FrameCacheKey
    ) {
        lock.lock()
        frameCache[key] = samples
        lock.unlock()
    }

    private func cachedGradedImage(for key: GradedCacheKey) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return gradedCache[key]
    }

    private func storeGradedImage(_ image: UIImage, for key: GradedCacheKey) {
        lock.lock()
        gradedCache[key] = image
        lock.unlock()
    }

    private static func makeSamples(
        for url: URL,
        packageDuration: Double,
        isCompactHeight: Bool
    ) async -> [FilmtoneCaptureTakeFrameSample] {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumFrameSize(isCompactHeight: isCompactHeight)
        generator.requestedTimeToleranceBefore = CMTime.positiveInfinity
        generator.requestedTimeToleranceAfter = CMTime.positiveInfinity

        let durationTime = try? await asset.load(.duration)
        let loadedDuration = durationTime.map(CMTimeGetSeconds) ?? 0
        let duration = packageDuration.isFinite && packageDuration > 0
            ? packageDuration
            : loadedDuration

        var samples: [FilmtoneCaptureTakeFrameSample] = []
        for (index, fraction) in sampleFractions(isCompactHeight: isCompactHeight).enumerated() {
            let seconds = sampleSeconds(for: fraction, duration: duration)
            let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
            let frame = try? await generator.image(at: time)
            samples.append(
                FilmtoneCaptureTakeFrameSample(
                    index: index,
                    seconds: seconds,
                    displayImage: frame.map { Self.readableDisplayImage(from: $0.image) },
                    sourceImage: frame.map { UIImage(cgImage: $0.image) }
                )
            )
        }
        return samples
    }

    private static func renderedImage(
        from image: UIImage,
        gradeProcessor: FilmtoneSharedGradeProcessor
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }
        let input = CIImage(cgImage: cgImage)
        let output = gradeProcessor.applyForLivePreview(input)
        guard let rendered = gradeProcessor.ciContext.createCGImage(
            output,
            from: output.extent
        ) else {
            return image
        }
        return UIImage(cgImage: rendered)
    }

    private static func readableDisplayImage(from image: CGImage) -> UIImage {
        let input = CIImage(cgImage: image)
        let output = input
            .applyingFilter(
                "CIExposureAdjust",
                parameters: ["inputEV": 1.15]
            )
            .applyingFilter(
                "CIGammaAdjust",
                parameters: ["inputPower": 0.82]
            )
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    "inputContrast": 1.18,
                    "inputSaturation": 1.06
                ]
            )
        guard let rendered = displayContext.createCGImage(
            output,
            from: output.extent
        ) else {
            return UIImage(cgImage: image)
        }
        return UIImage(cgImage: rendered)
    }

    private static func sampleFractions(isCompactHeight: Bool) -> [Double] {
        if isCompactHeight {
            return [0.06, 0.24, 0.42, 0.60, 0.78, 0.94]
        }
        return [0.04, 0.17, 0.30, 0.43, 0.56, 0.70, 0.84, 0.96]
    }

    private static func maximumFrameSize(isCompactHeight: Bool) -> CGSize {
        let longEdge: CGFloat = isCompactHeight ? 220 : 320
        return CGSize(width: longEdge, height: longEdge)
    }

    private static func sampleSeconds(for fraction: Double, duration: Double) -> Double {
        guard duration.isFinite, duration > 0.4 else { return 0 }
        return min(duration * fraction, duration - 0.12)
    }

    private static func lookToken(for package: FilmtoneCapturePackage) -> String {
        if let look = package.selectedLook {
            return [
                "look",
                look.canonicalUUID.uuidString,
                String(format: "%.3f", look.intensity)
            ].joined(separator: ":")
        }
        if let customLut = package.customLut {
            return [
                "lut",
                customLut.libraryId?.uuidString ?? customLut.sourceHash ?? customLut.displayName,
                String(customLut.size),
                String(format: "%.3f", customLut.intensity)
            ].joined(separator: ":")
        }
        return "filmtone"
    }
}

#endif
