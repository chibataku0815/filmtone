import CoreGraphics
import CoreImage
import CoreVideo
import FilmLabSwiftCore
import Foundation

/// 8-slot ring-buffer motion-blur accumulator extracted from
/// `FilmtoneExportSession` during the v1.x feature-architecture refactor
/// (Phase 2B-4). Reads `OpticalKernels.motionFeedback` /
/// `OpticalKernels.motionBlend` for the per-frame composite math and
/// shares the session's `CIContext` and output color space so the
/// rendered ring buffer stays byte-parity compatible with the
/// pre-refactor frame loop. Thread-safety is preserved via the
/// per-instance `NSLock` (the export pipeline still drives `apply(...)`
/// on `videoQueue`).
final class FilmtoneMotionBlurAccumulator {
    private static let slotCount = 8

    private let ciContext: CIContext
    private let colorSpace: CGColorSpace
    private let outputFrameRate: Int
    private let lock = NSLock()
    private var ringBuffers = Array<CVPixelBuffer?>(repeating: nil, count: slotCount)
    private var ringImages = Array<CIImage?>(repeating: nil, count: slotCount)
    private var writeIndex = 0
    private var validSlots = 0
    private var storageWidth = 0
    private var storageHeight = 0
    private var lastTimeSeconds: Double?

    init(ciContext: CIContext, colorSpace: CGColorSpace, outputFrameRate: Int) {
        self.ciContext = ciContext
        self.colorSpace = colorSpace
        self.outputFrameRate = max(1, outputFrameRate)
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        resetUnlocked()
    }

    private func resetUnlocked() {
        for index in 0..<Self.slotCount {
            ringImages[index] = nil
        }
        writeIndex = 0
        validSlots = 0
        lastTimeSeconds = nil
    }

    func apply(
        to image: CIImage,
        params: Phase0ParamsDTO,
        timeSeconds: Double,
        outputSize: CGSize
    ) -> CIImage {
        lock.lock()
        defer { lock.unlock() }

        let shutterAngle = FilmtoneMotionBlurMath.clampShutterAngle(params.shutterAngle)
        guard FilmtoneMotionBlurMath.isActive(shutterAngle: shutterAngle) else {
            resetUnlocked()
            return image
        }
        guard ensureStorage(for: outputSize) else {
            resetUnlocked()
            return image
        }

        let normalizedTime = timeSeconds.isFinite ? max(0, timeSeconds) : 0
        if shouldResetBeforeAppending(timeSeconds: normalizedTime) {
            resetUnlocked()
        }

        let extent = CGRect(origin: .zero, size: CGSize(width: storageWidth, height: storageHeight))
        let current = image.cropped(to: extent)
        let previousSlot = (writeIndex - 1 + Self.slotCount) % Self.slotCount
        let previous = validSlots > 0 ? (ringImages[previousSlot] ?? current) : current
        let hasPrevious = validSlots > 0 ? 1.0 : 0.0
        let feedback = OpticalKernels.motionFeedback?.apply(extent: extent, arguments: [
            current,
            previous,
            Self.clamp(params.trailIntensity, min: 0, max: 0.95),
            hasPrevious,
        ]) ?? current

        guard let targetBuffer = ringBuffers[writeIndex] else {
            resetUnlocked()
            return current
        }
        ciContext.render(
            feedback,
            to: targetBuffer,
            bounds: extent,
            colorSpace: colorSpace
        )

        ringImages[writeIndex] = CIImage(
            cvPixelBuffer: targetBuffer,
            options: [.colorSpace: colorSpace]
        ).cropped(to: extent)
        writeIndex = (writeIndex + 1) % Self.slotCount
        validSlots = min(validSlots + 1, Self.slotCount)
        lastTimeSeconds = normalizedTime

        let activeFrames = min(
            FilmtoneMotionBlurMath.activeFrameCount(
                shutterAngle: shutterAngle,
                slotCount: Self.slotCount
            ),
            validSlots
        )
        let weights = FilmtoneMotionBlurMath.blendWeights(
            shutterAngle: shutterAngle,
            activeFrames: activeFrames,
            validSlots: validSlots,
            slotCount: Self.slotCount
        )
        guard activeFrames > 1, let kernel = OpticalKernels.motionBlend else {
            return ringImages[(writeIndex - 1 + Self.slotCount) % Self.slotCount] ?? current
        }

        let black = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1)).cropped(to: extent)
        var args: [Any] = []
        for offset in 0..<Self.slotCount {
            let slot = (writeIndex - 1 - offset + (Self.slotCount * 2)) % Self.slotCount
            args.append(ringImages[slot] ?? black)
        }
        for weight in weights {
            args.append(weight)
        }

        return kernel.apply(extent: extent, arguments: args)?.cropped(to: extent) ?? current
    }

    private func ensureStorage(for outputSize: CGSize) -> Bool {
        let width = max(1, Int(outputSize.width.rounded()))
        let height = max(1, Int(outputSize.height.rounded()))
        if width != storageWidth || height != storageHeight {
            storageWidth = width
            storageHeight = height
            ringBuffers = Array<CVPixelBuffer?>(repeating: nil, count: Self.slotCount)
            resetUnlocked()
        }

        for index in 0..<Self.slotCount where ringBuffers[index] == nil {
            guard let buffer = Self.makePixelBuffer(width: width, height: height) else {
                return false
            }
            ringBuffers[index] = buffer
        }
        return true
    }

    private func shouldResetBeforeAppending(timeSeconds: Double) -> Bool {
        guard let previous = lastTimeSeconds else {
            return false
        }
        let frameInterval = 1.0 / Double(outputFrameRate)
        let delta = timeSeconds - previous
        if delta < frameInterval * 0.25 {
            return true
        }
        if delta > max(frameInterval * 3.5, 0.16) {
            return true
        }
        return false
    }

    private static func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
        ]
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess else {
            return nil
        }
        return buffer
    }

    private static func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}
