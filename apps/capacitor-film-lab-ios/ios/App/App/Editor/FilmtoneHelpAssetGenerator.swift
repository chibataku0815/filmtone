import AVFoundation
import CoreGraphics
import CoreImage
import FilmLabSwiftCore
import Foundation
import UIKit

/// One-shot in-app generator that renders the before/after JPEGs used by
/// `FilmtoneAdjustmentHelpSheet`'s comparison view. Triggered with launch
/// argument `-filmtoneGenerateHelpAssets <sourceDir>`; AppDelegate catches
/// the arg before bootstrapping the editor store, runs this synchronously,
/// and exits the process. The driver script
/// `apps/capacitor-film-lab-ios/scripts/generate-help-comparison-assets.sh`
/// pulls the JPEGs out of the simulator's app container and stages them
/// into `Assets.xcassets/HelpCompare*.imageset/`.
///
/// Render path: nine still families go through `renderPreviewFrame()` with
/// a JPEG poster extracted from the source MP4 (`sourceKind = .image`).
/// Motion is the exception — `renderPreviewFrame()` deliberately skips
/// `applyVideoMotionStage`, so motion runs the full `run()` export against
/// the MP4 with `shutterAngle`/`trailIntensity` set, then we sample a late
/// frame from the resulting MP4. Either path uses the production engine
/// math.
enum FilmtoneHelpAssetGenerator {
    static let launchArgument = "-filmtoneGenerateHelpAssets"
    static let completionSentinel = "FILMTONE_HELP_ASSET_GENERATOR_DONE"
    static let failureSentinel = "FILMTONE_HELP_ASSET_GENERATOR_FAILED"

    enum GeneratorError: Error {
        case missingSourceDirectory(URL)
        case missingScene(String, URL)
        case stillExtractionFailed(String, Error)
        case renderFailed(String, Error)
        case exportFailed(String, Error)
        case invalidOutputURL(String)
        case writeFailed(URL)
    }

    private struct Scene {
        let id: String
        let filename: String
        let posterTimeSec: Double
    }

    private struct Family {
        let id: String
        let sceneId: String
        let overrides: [String: Double]
    }

    private static let sceneSkin = Scene(
        id: "skin",
        filename: "6454597_Woman Hand Gua Sha Window_By_Zed_Artlist_HD.mp4",
        posterTimeSec: 6.0
    )

    private static let sceneGlow = Scene(
        id: "glow",
        filename: "6608500_Intimate Lighter Warm Glow Cozy Ambiance_By_Pressmaster_Artlist_HD.mp4",
        posterTimeSec: 2.5
    )

    private static let scenes: [Scene] = [sceneSkin, sceneGlow]
    private static let scenesById: [String: Scene] = [
        sceneSkin.id: sceneSkin,
        sceneGlow.id: sceneGlow,
    ]

    private static let stillFamilies: [Family] = [
        Family(id: "strength", sceneId: "glow", overrides: [
            "bloomStrength": 0.30,
            "halationIntensity": 0.20,
            "contrast": 1.10,
            "grainIntensity": 0.04,
        ]),
        Family(id: "exposure", sceneId: "skin", overrides: [
            "exposure": 0.50,
        ]),
        Family(id: "contrast", sceneId: "skin", overrides: [
            "contrast": 1.30,
            "printContrast": 0.20,
        ]),
        Family(id: "saturation", sceneId: "skin", overrides: [
            "saturation": 1.40,
            "cyan": 0.10,
            "magenta": -0.05,
            "yellow": 0.10,
        ]),
        Family(id: "tone", sceneId: "skin", overrides: [
            "compressionAmount": 0.40,
            "compressionRange": 0.50,
            "shadowTone": 0.20,
            "highlightTone": -0.20,
        ]),
        Family(id: "optics", sceneId: "glow", overrides: [
            "rgbShift": 0.0030,
            "lensSoftness": 0.30,
            "vignette": 0.40,
            "diffusion": 0.10,
        ]),
        Family(id: "glow", sceneId: "glow", overrides: [
            "bloomThreshold": 0.65,
            "bloomStrength": 0.45,
            "bloomRadius": 0.55,
        ]),
        Family(id: "halation", sceneId: "glow", overrides: [
            "halationIntensity": 0.40,
            "halationSpread": 22.0,
            "halationHue": 12.0,
            "halationThreshold": 0.6,
            "halationRadius": 0.55,
        ]),
        Family(id: "grain", sceneId: "skin", overrides: [
            "grainIntensity": 0.06,
            "grainSize": 0.45,
            "grainRadialMix": 0.7,
        ]),
    ]

    private static let motionFamily = Family(id: "motion", sceneId: "skin", overrides: [
        "shutterAngle": 540.0,
        "trailIntensity": 0.18,
    ])

    static func runIfRequested() throws -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: launchArgument) else {
            return false
        }
        let nextIndex = index + 1
        let sourceDir: URL
        if args.indices.contains(nextIndex), args[nextIndex].hasPrefix("/") {
            sourceDir = URL(fileURLWithPath: args[nextIndex])
        } else {
            sourceDir = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .deletingLastPathComponent()
                .appendingPathComponent("Downloads", isDirectory: true)
        }
        do {
            try run(sourceDir: sourceDir)
        } catch {
            NSLog("\(failureSentinel) error=\(error)")
            throw error
        }
        return true
    }

    static func run(sourceDir: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceDir.path, isDirectory: &isDir),
              isDir.boolValue else {
            throw GeneratorError.missingSourceDirectory(sourceDir)
        }

        let cacheStore = try CacheStore()
        let outputDir = cacheStore.rootURL.appendingPathComponent("help-assets", isDirectory: true)
        if FileManager.default.fileExists(atPath: outputDir.path) {
            try FileManager.default.removeItem(at: outputDir)
        }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var sceneStills: [String: URL] = [:]
        for scene in scenes {
            let mp4URL = sourceDir.appendingPathComponent(scene.filename)
            guard FileManager.default.fileExists(atPath: mp4URL.path) else {
                throw GeneratorError.missingScene(scene.id, mp4URL)
            }
            let stillURL = outputDir.appendingPathComponent("source-\(scene.id).jpg")
            do {
                try extractStill(from: mp4URL, at: scene.posterTimeSec, to: stillURL)
            } catch {
                throw GeneratorError.stillExtractionFailed(scene.id, error)
            }
            sceneStills[scene.id] = stillURL
        }

        var sceneBeforesEmitted = Set<String>()
        for family in stillFamilies {
            guard let stillURL = sceneStills[family.sceneId] else {
                throw GeneratorError.missingScene(family.sceneId, sourceDir)
            }
            let request = makeImageRequest(stillURL: stillURL, overrides: family.overrides)
            let session: FilmtoneExportSession
            do {
                session = try FilmtoneExportSession(
                    request: request,
                    sourceURL: stillURL,
                    cacheStore: cacheStore
                )
            } catch {
                throw GeneratorError.renderFailed(family.id, error)
            }
            let result: Phase0PreviewRenderResultDTO
            do {
                result = try session.renderPreviewFrame()
            } catch {
                throw GeneratorError.renderFailed(family.id, error)
            }

            if !sceneBeforesEmitted.contains(family.sceneId),
               let originalURL = URL(string: result.originalUri) {
                let beforeOut = outputDir.appendingPathComponent("before-\(family.sceneId).jpg")
                try writeCenterCroppedJPEG(from: originalURL, to: beforeOut)
                sceneBeforesEmitted.insert(family.sceneId)
            }
            if let gradedURL = URL(string: result.gradedUri) {
                let afterOut = outputDir.appendingPathComponent("after-\(family.id).jpg")
                try writeCenterCroppedJPEG(from: gradedURL, to: afterOut)
            }
        }

        try renderMotionAfter(
            cacheStore: cacheStore,
            sourceDir: sourceDir,
            outputDir: outputDir
        )

        NSLog("\(completionSentinel) outputDir=\(outputDir.path)")
    }

    // MARK: - Motion

    private static func renderMotionAfter(
        cacheStore: CacheStore,
        sourceDir: URL,
        outputDir: URL
    ) throws {
        guard let scene = scenesById[motionFamily.sceneId] else {
            throw GeneratorError.missingScene(motionFamily.sceneId, sourceDir)
        }
        let mp4URL = sourceDir.appendingPathComponent(scene.filename)
        let request = makeVideoRequest(mp4URL: mp4URL, overrides: motionFamily.overrides)
        let session: FilmtoneExportSession
        do {
            session = try FilmtoneExportSession(
                request: request,
                sourceURL: mp4URL,
                cacheStore: cacheStore
            )
        } catch {
            throw GeneratorError.exportFailed(motionFamily.id, error)
        }
        let result: Phase0ExportResultDTO
        do {
            result = try session.run(progress: { _ in })
        } catch {
            throw GeneratorError.exportFailed(motionFamily.id, error)
        }
        guard let outputMp4URL = URL(string: result.outputUri) else {
            throw GeneratorError.invalidOutputURL(result.outputUri)
        }
        let durationSec = CMTimeGetSeconds(AVURLAsset(url: outputMp4URL).duration)
        let posterTime = max(0.5, durationSec * 0.8)
        let rawStill = outputDir.appendingPathComponent("after-motion-raw.jpg")
        try extractStill(from: outputMp4URL, at: posterTime, to: rawStill)
        let afterMotion = outputDir.appendingPathComponent("after-motion.jpg")
        try writeCenterCroppedJPEG(from: rawStill, to: afterMotion)
        try? FileManager.default.removeItem(at: rawStill)
        try? FileManager.default.removeItem(at: outputMp4URL)
    }

    // MARK: - Request construction

    private static func makeImageRequest(
        stillURL: URL,
        overrides: [String: Double]
    ) -> Phase0ExportRequestDTO {
        Phase0ExportRequestDTO(
            sourceUri: stillURL.absoluteString,
            sourceKind: .image,
            sourceProbe: nil,
            output: FilmtonePhase0Generated.outputProfile,
            grade: makeGrade(overrides: overrides),
            lut: nil,
            inputLut: nil,
            creativeLut: nil,
            renderMode: nil,
            depthEnabled: nil,
            depthRenderer: nil
        )
    }

    private static func makeVideoRequest(
        mp4URL: URL,
        overrides: [String: Double]
    ) -> Phase0ExportRequestDTO {
        Phase0ExportRequestDTO(
            sourceUri: mp4URL.absoluteString,
            sourceKind: .video,
            sourceProbe: nil,
            output: FilmtonePhase0Generated.outputProfile,
            grade: makeGrade(overrides: overrides),
            lut: nil,
            inputLut: nil,
            creativeLut: nil,
            renderMode: nil,
            depthEnabled: nil,
            depthRenderer: nil
        )
    }

    private static func makeGrade(overrides: [String: Double]) -> Phase0GradeDTO {
        var params = FilmtonePhase0Generated.resetParams
        for (key, value) in overrides {
            params.setValue(FilmtonePhase0Math.clampParam(key, value), for: key)
        }
        return Phase0GradeDTO(
            presetName: FilmtonePhase0Generated.presetDefault,
            presetVersion: FilmtonePhase0Generated.presetVersion,
            quickState: Phase0QuickStateDTO(filmCharacter: 0, era: 0, dynamics: 0),
            params: params.asDTO()
        )
    }

    // MARK: - Frame extraction & cropping

    private static func extractStill(
        from mp4URL: URL,
        at timeSec: Double,
        to outputURL: URL
    ) throws {
        let asset = AVURLAsset(url: mp4URL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        let cgImage = try generator.copyCGImage(
            at: CMTime(seconds: timeSec, preferredTimescale: 600),
            actualTime: nil
        )
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.jpegData(compressionQuality: 0.96) else {
            throw GeneratorError.writeFailed(outputURL)
        }
        try data.write(to: outputURL, options: .atomic)
    }

    private static let outputAspectWidth: CGFloat = 600
    private static let outputAspectHeight: CGFloat = 552

    private static func writeCenterCroppedJPEG(
        from inputURL: URL,
        to outputURL: URL
    ) throws {
        let data = try Data(contentsOf: inputURL)
        guard let image = UIImage(data: data) else {
            throw GeneratorError.writeFailed(outputURL)
        }
        let cropped = centerCropped(image, aspectW: outputAspectWidth, aspectH: outputAspectHeight)
        let scaled = scaled(cropped, to: CGSize(width: outputAspectWidth, height: outputAspectHeight))
        guard let outData = scaled.jpegData(compressionQuality: 0.88) else {
            throw GeneratorError.writeFailed(outputURL)
        }
        try outData.write(to: outputURL, options: .atomic)
    }

    private static func centerCropped(
        _ image: UIImage,
        aspectW: CGFloat,
        aspectH: CGFloat
    ) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let srcW = CGFloat(cgImage.width)
        let srcH = CGFloat(cgImage.height)
        let targetAspect = aspectW / aspectH
        let srcAspect = srcW / srcH
        let cropRect: CGRect
        if srcAspect > targetAspect {
            let cropW = srcH * targetAspect
            cropRect = CGRect(x: (srcW - cropW) / 2.0, y: 0, width: cropW, height: srcH)
        } else {
            let cropH = srcW / targetAspect
            cropRect = CGRect(x: 0, y: (srcH - cropH) / 2.0, width: srcW, height: cropH)
        }
        guard let cropped = cgImage.cropping(to: cropRect.integral) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func scaled(_ image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
