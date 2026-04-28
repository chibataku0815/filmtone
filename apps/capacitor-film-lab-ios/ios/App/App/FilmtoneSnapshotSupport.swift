import AVFoundation
import CoreVideo
import Foundation
import UIKit

enum FilmtoneSnapshotScene: String {
    case hero
    case presets
    case quick
    case camera
    case export
    case processVideo
    case sourceImportLoading
    case sourceProbeLoading

    static var current: FilmtoneSnapshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-filmtoneSnapshot"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return FilmtoneSnapshotScene(rawValue: arguments[index + 1])
    }
}

struct FilmtoneSnapshotFixture {
    let project: FilmtoneProjectState
    let source: SourceInfoDTO
    let probe: SourceProbeDTO
    let preview: FilmtonePreviewState
    let exportResult: Phase0ExportResultDTO?
    let saveToPhotosState: FilmtoneSaveToPhotosState
    let sourceLoadState: FilmtoneSourceLoadState?

    static func make(scene: FilmtoneSnapshotScene) -> FilmtoneSnapshotFixture {
        if scene == .processVideo {
            return makeProcessVideoFixture()
        }

        if scene == .sourceImportLoading {
            return makeSourceImportLoadingFixture()
        }

        if scene == .sourceProbeLoading {
            return makeSourceProbeLoadingFixture()
        }

        let posters = FilmtoneSnapshotPosterSet.prepare()
        let source = SourceInfoDTO(
            uri: posters.originalURI,
            filename: scene == .camera ? "fujifilm-f-log2.hevc.mov" : "tokyo-night.hevc.mov",
            kind: .video,
            mimeType: "video/quicktime"
        )
        let probe = SourceProbeDTO(
            uri: source.uri,
            filename: source.filename,
            kind: .video,
            mimeType: source.mimeType,
            width: 1170,
            height: 2532,
            durationSec: 18.4,
            fileSizeBytes: 24_300_000,
            codec: "hvc1",
            frameRate: 30
        )

        switch scene {
        case .hero:
            return .init(
                project: makeProject(
                    presetName: "reset",
                    strength: FilmtonePhase0Math.presetStrengthDefault,
                    quickState: .zero
                ),
                source: source,
                probe: probe,
                preview: posters.preview,
                exportResult: nil,
                saveToPhotosState: .notRun,
                sourceLoadState: nil
            )
        case .presets:
            return .init(
                project: makeProject(
                    presetName: "gold200",
                    strength: 0.92,
                    quickState: .init(filmCharacter: 0.12, era: 0.18, dynamics: -0.08)
                ),
                source: source,
                probe: probe,
                preview: posters.preview,
                exportResult: nil,
                saveToPhotosState: .notRun,
                sourceLoadState: nil
            )
        case .quick:
            return .init(
                project: makeProject(
                    presetName: "portra",
                    strength: 0.76,
                    quickState: .init(filmCharacter: 0.42, era: -0.24, dynamics: 0.22)
                ),
                source: source,
                probe: probe,
                preview: posters.preview,
                exportResult: nil,
                saveToPhotosState: .notRun,
                sourceLoadState: nil
            )
        case .camera:
            return .init(
                project: makeProject(
                    presetName: "pro400h",
                    strength: 0.88,
                    quickState: .init(filmCharacter: 0.08, era: -0.14, dynamics: -0.04),
                    inputLut: sampleInputLut
                ),
                source: source,
                probe: probe,
                preview: posters.preview,
                exportResult: nil,
                saveToPhotosState: .notRun,
                sourceLoadState: nil
            )
        case .export:
            return .init(
                project: makeProject(
                    presetName: "cinematic",
                    strength: 0.9,
                    quickState: .init(filmCharacter: 0.18, era: -0.12, dynamics: 0.12)
                ),
                source: source,
                probe: probe,
                preview: posters.preview,
                exportResult: .init(
                    outputUri: posters.gradedURI,
                    elapsedMs: 1180,
                    outputWidth: 1170,
                    outputHeight: 2532,
                    outputFps: 24,
                    fileSizeBytes: 18_400_000,
                    realtimeRatio: 1.9,
                    audioPreserved: true,
                    benchmarkRecord: nil
                ),
                saveToPhotosState: .saved,
                sourceLoadState: nil
            )
        case .processVideo:
            preconditionFailure("processVideo is handled before poster-backed snapshot fixtures are created.")
        case .sourceImportLoading, .sourceProbeLoading:
            preconditionFailure("Loading scenes are handled before poster-backed snapshot fixtures are created.")
        }
    }

    private static func makeSourceImportLoadingFixture() -> FilmtoneSnapshotFixture {
        .init(
            project: makeProject(
                presetName: "cinematic",
                strength: 0.84,
                quickState: .init(filmCharacter: 0.28, era: -0.18, dynamics: 0.16)
            ),
            source: SourceInfoDTO(
                uri: "filmtone://source-import-loading",
                filename: "tokyo-night.hevc.mov",
                kind: .video,
                mimeType: "video/quicktime"
            ),
            probe: SourceProbeDTO(
                uri: "filmtone://source-import-loading",
                filename: "tokyo-night.hevc.mov",
                kind: .video,
                mimeType: "video/quicktime",
                width: 0,
                height: 0,
                durationSec: 0,
                fileSizeBytes: 0,
                codec: "",
                frameRate: 0
            ),
            preview: .empty,
            exportResult: nil,
            saveToPhotosState: .notRun,
            sourceLoadState: .init(
                stage: .importing,
                route: .photoLibrary,
                message: "Importing source…",
                progress: 0.38,
                isDeterminate: true
            )
        )
    }

    private static func makeSourceProbeLoadingFixture() -> FilmtoneSnapshotFixture {
        let posters = FilmtoneSnapshotPosterSet.prepare()
        let source = SourceInfoDTO(
            uri: posters.originalURI,
            filename: "tokyo-night.hevc.mov",
            kind: .video,
            mimeType: "video/quicktime"
        )

        return .init(
            project: makeProject(
                presetName: "cinematic",
                strength: 0.84,
                quickState: .init(filmCharacter: 0.28, era: -0.18, dynamics: 0.16)
            ),
            source: source,
            probe: SourceProbeDTO(
                uri: source.uri,
                filename: source.filename,
                kind: .video,
                mimeType: source.mimeType,
                width: 1170,
                height: 2532,
                durationSec: 0,
                fileSizeBytes: 24_300_000,
                codec: "",
                frameRate: 30
            ),
            preview: .empty,
            exportResult: nil,
            saveToPhotosState: .notRun,
            sourceLoadState: .init(
                stage: .probing,
                route: .photoLibrary,
                message: "Inspecting media…",
                progress: nil,
                isDeterminate: false
            )
        )
    }

    private static func makeProcessVideoFixture() -> FilmtoneSnapshotFixture {
        let video = FilmtoneSnapshotVideoFixture.prepare(
            filename: "tokyo-night-process-refresh.mov"
        )

        return .init(
            project: makeProject(
                presetName: "cinematic",
                strength: 0.82,
                quickState: .init(filmCharacter: 0.14, era: -0.10, dynamics: 0.08)
            ),
            source: video.source,
            probe: video.probe,
            preview: .empty,
            exportResult: nil,
            saveToPhotosState: .notRun,
            sourceLoadState: nil
        )
    }

    private static func makeProject(
        presetName: String,
        strength: Double,
        quickState: FilmtoneQuickState,
        inputLut: ParsedCubeLutDTO? = nil
    ) -> FilmtoneProjectState {
        var project = FilmtonePhase0Math.createProjectState(presetName: presetName)
        project.strength = FilmtonePhase0Math.clampStrength(strength)
        project.quickState = quickState.clamped()

        let resolved = FilmtonePhase0Math.resolveParams(
            presetName: project.presetName,
            strength: project.strength,
            quickState: project.quickState,
            paramOverrides: .empty
        )
        project.paramOverrides = resolved.overrides
        project.params = resolved.effective
        project.inputLut = inputLut
        project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        return project
    }

    private static let sampleInputLut = ParsedCubeLutDTO(
        title: "Fujifilm F-Log2",
        size: 2,
        data: [
            0, 0, 0,
            1, 0, 0,
            0, 1, 0,
            1, 1, 0,
            0, 0, 1,
            1, 0, 1,
            0, 1, 1,
            1, 1, 1,
        ],
        intensity: 1
    )
}

private struct FilmtoneSnapshotVideoFixture {
    let source: SourceInfoDTO
    let probe: SourceProbeDTO

    static func prepare(filename: String) -> FilmtoneSnapshotVideoFixture {
        do {
            let directory = try snapshotAssetsDirectory()
            let sourceURL = directory.appendingPathComponent("snapshot-process-source.mov")

            if !FileManager.default.fileExists(atPath: sourceURL.path) {
                try writeVideo(to: sourceURL)
            }

            let source = SourceInfoDTO(
                uri: sourceURL.absoluteString,
                filename: filename,
                kind: .video,
                mimeType: "video/quicktime"
            )

            let probeService = SourceProbeService()
            let probe: SourceProbeDTO
            do {
                probe = try probeService.probeSource(at: sourceURL, fallback: source)
            } catch {
                try writeVideo(to: sourceURL)
                probe = try probeService.probeSource(at: sourceURL, fallback: source)
            }

            return .init(source: source, probe: probe)
        } catch {
            fatalError("Failed to prepare Filmtone snapshot video fixture: \(error.localizedDescription)")
        }
    }

    private static let frameRate = 24
    private static let frameCount = 30
    private static let size = CGSize(width: 540, height: 960)

    private static func snapshotAssetsDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmtone-snapshot-assets", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func writeVideo(to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_400_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            ]
        )

        guard writer.canAdd(input) else {
            throw FilmtoneSnapshotVideoError("Snapshot video writer couldn't add its video input.")
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? FilmtoneSnapshotVideoError("Snapshot video writer failed to start.")
        }
        writer.startSession(atSourceTime: .zero)

        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw FilmtoneSnapshotVideoError("Snapshot video writer couldn't create a pixel buffer pool.")
        }

        for frameIndex in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }

            let pixelBuffer = try makePixelBuffer(from: pixelBufferPool, frameIndex: frameIndex)
            let frameTime = CMTime(value: Int64(frameIndex), timescale: Int32(frameRate))
            guard adaptor.append(pixelBuffer, withPresentationTime: frameTime) else {
                throw writer.error ?? FilmtoneSnapshotVideoError("Snapshot video writer failed to append frame \(frameIndex).")
            }
        }

        input.markAsFinished()
        try finishWriting(writer)
    }

    private static func makePixelBuffer(
        from pool: CVPixelBufferPool,
        frameIndex: Int
    ) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw FilmtoneSnapshotVideoError("Snapshot video writer couldn't allocate a pixel buffer.")
        }

        renderFrame(into: pixelBuffer, frameIndex: frameIndex)
        return pixelBuffer
    }

    private static func renderFrame(into pixelBuffer: CVPixelBuffer, frameIndex: Int) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return
        }

        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue |
            CGImageAlphaInfo.premultipliedFirst.rawValue

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return
        }

        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        drawFrame(
            in: context,
            progress: CGFloat(frameIndex) / CGFloat(max(frameCount - 1, 1))
        )
    }

    private static func drawFrame(
        in context: CGContext,
        progress: CGFloat
    ) {
        let bounds = CGRect(origin: .zero, size: size)
        context.setFillColor(UIColor.black.cgColor)
        context.fill(bounds)

        let top = UIColor(red: 0.09, green: 0.14, blue: 0.23, alpha: 1)
        let bottom = UIColor(red: 0.03, green: 0.05, blue: 0.08, alpha: 1)
        let accent = UIColor(red: 0.96, green: 0.74, blue: 0.35, alpha: 1)
        let teal = UIColor(red: 0.38, green: 0.62, blue: 0.74, alpha: 1)

        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [top.cgColor, bottom.cgColor] as CFArray,
            locations: [0, 1]
        )
        context.drawLinearGradient(
            gradient!,
            start: CGPoint(x: size.width * 0.16, y: 0),
            end: CGPoint(x: size.width * 0.82, y: size.height),
            options: []
        )

        let glowRect = CGRect(
            x: size.width * (0.08 + 0.34 * progress),
            y: 120 + 22 * sin(progress * .pi * 2),
            width: 220,
            height: 220
        )
        context.saveGState()
        context.setShadow(offset: .zero, blur: 56, color: teal.withAlphaComponent(0.5).cgColor)
        context.setFillColor(teal.withAlphaComponent(0.22).cgColor)
        context.fillEllipse(in: glowRect)
        context.restoreGState()

        let horizonY = size.height * 0.62
        context.setFillColor(UIColor.black.withAlphaComponent(0.36).cgColor)
        context.fill(CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY))

        for index in 0..<7 {
            let width = CGFloat(34 + ((index * 11) % 38))
            let height = CGFloat(160 + ((index * 43) % 180))
            let x = CGFloat(28 + index * 66)
            let y = horizonY - height
            let rect = CGRect(x: x, y: y, width: width, height: height)
            context.setFillColor(UIColor.white.withAlphaComponent(0.06).cgColor)
            context.fill(rect)

            context.setFillColor(accent.withAlphaComponent(0.18).cgColor)
            for row in 0..<5 {
                let windowY = y + 18 + CGFloat(row) * 34
                context.fill(
                    CGRect(
                        x: x + 8,
                        y: windowY,
                        width: max(width - 16, 8),
                        height: 6
                    )
                )
            }
        }

        let trailWidth = size.width * 0.34
        let trailX = size.width * (-0.18 + progress * 1.18)
        let trailRect = CGRect(x: trailX, y: horizonY + 82, width: trailWidth, height: 10)
        context.saveGState()
        context.setShadow(offset: .zero, blur: 20, color: accent.withAlphaComponent(0.55).cgColor)
        context.setFillColor(accent.withAlphaComponent(0.72).cgColor)
        context.fill(trailRect)
        context.restoreGState()

        let silhouetteRect = CGRect(x: size.width * 0.36, y: size.height * 0.42, width: 126, height: 280)
        let silhouettePath = UIBezierPath(roundedRect: silhouetteRect, cornerRadius: 54)
        UIColor.black.withAlphaComponent(0.35).setFill()
        silhouettePath.fill()

        let rimPath = UIBezierPath(
            roundedRect: silhouetteRect.insetBy(dx: 10, dy: 14),
            cornerRadius: 44
        )
        accent.withAlphaComponent(0.22).setStroke()
        rimPath.lineWidth = 6
        rimPath.stroke()

        let streakPath = UIBezierPath()
        streakPath.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.2))
        streakPath.addCurve(
            to: CGPoint(x: size.width * 0.88, y: size.height * 0.14),
            controlPoint1: CGPoint(x: size.width * 0.34, y: size.height * 0.16),
            controlPoint2: CGPoint(x: size.width * 0.6, y: size.height * 0.26)
        )
        context.saveGState()
        context.setShadow(offset: .zero, blur: 28, color: teal.withAlphaComponent(0.32).cgColor)
        context.addPath(streakPath.cgPath)
        context.setStrokeColor(teal.withAlphaComponent(0.28).cgColor)
        context.setLineWidth(8)
        context.strokePath()
        context.restoreGState()

        let framePath = UIBezierPath(roundedRect: bounds.insetBy(dx: 18, dy: 18), cornerRadius: 28)
        UIColor.white.withAlphaComponent(0.08).setStroke()
        framePath.lineWidth = 2
        framePath.stroke()
    }

    private static func finishWriting(_ writer: AVAssetWriter) throws {
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        guard writer.status == .completed else {
            throw writer.error ?? FilmtoneSnapshotVideoError("Snapshot video writer didn't complete successfully.")
        }
    }
}

private struct FilmtoneSnapshotVideoError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

private struct FilmtoneSnapshotPosterSet {
    let originalURI: String
    let gradedURI: String
    let preview: FilmtonePreviewState

    static func prepare() -> FilmtoneSnapshotPosterSet {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmtone-snapshot-assets", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let originalURL = directory.appendingPathComponent("snapshot-original.png")
        let gradedURL = directory.appendingPathComponent("snapshot-graded.png")

        if !FileManager.default.fileExists(atPath: originalURL.path) {
            let image = renderPoster(
                top: UIColor(red: 0.10, green: 0.16, blue: 0.24, alpha: 1),
                bottom: UIColor(red: 0.03, green: 0.05, blue: 0.10, alpha: 1),
                highlight: UIColor(red: 0.72, green: 0.78, blue: 0.92, alpha: 1),
                accent: UIColor(red: 0.30, green: 0.42, blue: 0.58, alpha: 1)
            )
            try? image.pngData()?.write(to: originalURL, options: .atomic)
        }

        if !FileManager.default.fileExists(atPath: gradedURL.path) {
            let image = renderPoster(
                top: UIColor(red: 0.32, green: 0.16, blue: 0.08, alpha: 1),
                bottom: UIColor(red: 0.10, green: 0.05, blue: 0.02, alpha: 1),
                highlight: UIColor(red: 0.95, green: 0.70, blue: 0.30, alpha: 1),
                accent: UIColor(red: 0.82, green: 0.44, blue: 0.18, alpha: 1)
            )
            try? image.pngData()?.write(to: gradedURL, options: .atomic)
        }

        return .init(
            originalURI: originalURL.absoluteString,
            gradedURI: gradedURL.absoluteString,
            preview: .still(.init(
                originalPosterURI: originalURL.absoluteString,
                gradedPosterURI: gradedURL.absoluteString,
                width: 1170,
                height: 2532,
                posterTimeSec: 3.2,
                isRendering: false,
                error: nil
            ))
        )
    }

    private static func renderPoster(
        top: UIColor,
        bottom: UIColor,
        highlight: UIColor,
        accent: UIColor
    ) -> UIImage {
        let size = CGSize(width: 1170, height: 2532)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            let bounds = CGRect(origin: .zero, size: size)

            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 1]
            )
            cgContext.drawLinearGradient(
                gradient!,
                start: CGPoint(x: size.width * 0.2, y: 0),
                end: CGPoint(x: size.width * 0.8, y: size.height),
                options: []
            )

            let glowRect = CGRect(x: 120, y: 180, width: 900, height: 1200)
            cgContext.saveGState()
            cgContext.setShadow(offset: .zero, blur: 120, color: highlight.withAlphaComponent(0.45).cgColor)
            cgContext.setFillColor(highlight.withAlphaComponent(0.15).cgColor)
            cgContext.fillEllipse(in: glowRect)
            cgContext.restoreGState()

            let horizonY = size.height * 0.62
            cgContext.setFillColor(UIColor.black.withAlphaComponent(0.35).cgColor)
            cgContext.fill(CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY))

            for index in 0..<11 {
                let width = CGFloat(68 + ((index * 23) % 140))
                let height = CGFloat(220 + ((index * 73) % 520))
                let x = CGFloat(48 + index * 98)
                let y = horizonY - height
                let rect = CGRect(x: x, y: y, width: width, height: height)
                cgContext.setFillColor(UIColor.white.withAlphaComponent(0.05).cgColor)
                cgContext.fill(rect)

                cgContext.setFillColor(accent.withAlphaComponent(0.22).cgColor)
                for row in 0..<7 {
                    let windowY = y + 28 + CGFloat(row) * 56
                    let windowWidth = max(width - 24, 16)
                    cgContext.fill(
                        CGRect(x: x + 12, y: windowY, width: windowWidth, height: 10)
                    )
                }
            }

            let subjectRect = CGRect(x: 420, y: 960, width: 300, height: 720)
            let subjectPath = UIBezierPath(roundedRect: subjectRect, cornerRadius: 140)
            UIColor.black.withAlphaComponent(0.32).setFill()
            subjectPath.fill()

            let rimPath = UIBezierPath(roundedRect: subjectRect.insetBy(dx: 18, dy: 22), cornerRadius: 120)
            highlight.withAlphaComponent(0.22).setStroke()
            rimPath.lineWidth = 12
            rimPath.stroke()

            let floorPath = UIBezierPath()
            floorPath.move(to: CGPoint(x: 0, y: size.height))
            floorPath.addLine(to: CGPoint(x: 0, y: size.height * 0.78))
            floorPath.addCurve(
                to: CGPoint(x: size.width, y: size.height * 0.74),
                controlPoint1: CGPoint(x: size.width * 0.25, y: size.height * 0.70),
                controlPoint2: CGPoint(x: size.width * 0.7, y: size.height * 0.8)
            )
            floorPath.addLine(to: CGPoint(x: size.width, y: size.height))
            floorPath.close()
            accent.withAlphaComponent(0.18).setFill()
            floorPath.fill()

            let framePath = UIBezierPath(roundedRect: bounds.insetBy(dx: 36, dy: 36), cornerRadius: 48)
            UIColor.white.withAlphaComponent(0.08).setStroke()
            framePath.lineWidth = 4
            framePath.stroke()
        }
    }
}
