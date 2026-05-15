import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import FilmLabSwiftCore

enum FilmtoneAutomationCommand: String, Codable {
    case inspectSources
    case answerContext
    case previewBatch
    case runBatch
}

struct FilmtoneAutomationEnvelope: Codable {
    let command: FilmtoneAutomationCommand
    let inspectSources: FilmtoneAutomationInspectSourcesRequest?
    let answerContext: FilmtoneAutomationAnswerContextRequest?
    let previewBatch: FilmtoneAutomationBatchPlanRequest?
    let runBatch: FilmtoneAutomationRunBatchRequest?
}

struct FilmtoneAutomationInspectSourcesRequest: Codable, Equatable {
    var paths: [String]
    var recursive: Bool?
}

struct FilmtoneAutomationBatchPlanRequest: Codable, Equatable {
    var paths: [String]
    var recursive: Bool?
    var outputDirectory: String?
    var look: String?
    var strength: Double?
    var profiles: [FilmtoneAutomationExportProfile]?
    var overwrite: Bool?
    var continueOnError: Bool?
}

struct FilmtoneAutomationRunBatchRequest: Codable, Equatable {
    var plan: FilmtoneAutomationBatchPlan
    var overwrite: Bool?
    var continueOnError: Bool?
}

enum FilmtoneAutomationExportProfile: String, Codable, CaseIterable {
    case social1080
    case archiveH264

    var suffix: String {
        switch self {
        case .social1080: return "social"
        case .archiveH264: return "archive"
        }
    }

    var outputLongEdgeLimit: Double? {
        switch self {
        case .social1080: return 1920
        case .archiveH264: return nil
        }
    }

    var description: String {
        switch self {
        case .social1080:
            return "H.264 MP4, audio preserved, long edge capped at 1920px."
        case .archiveH264:
            return "H.264 MP4, audio preserved, source display size preserved."
        }
    }
}

struct FilmtoneAutomationDimensions: Codable, Equatable {
    var width: Int
    var height: Int
}

struct FilmtoneAutomationAnalysisLimits: Codable, Equatable {
    var visualFrameAnalysis: Bool
    var maskOrSkinDetection: Bool
    var clippingDetection: Bool
    var answerMode: String
    var note: String

    static let stateExportAdvice = FilmtoneAutomationAnalysisLimits(
        visualFrameAnalysis: false,
        maskOrSkinDetection: false,
        clippingDetection: false,
        answerMode: "state-export-advice",
        note: "This MVP does not inspect frame content. Advice must be based on source metadata, Look, grade/export settings, sidecars, and supported workflow facts."
    )
}

struct FilmtoneAutomationInspectSourcesResponse: Codable, Equatable {
    var sources: [FilmtoneAutomationSourceInspection]
    var warnings: [String]
    var analysisLimits: FilmtoneAutomationAnalysisLimits
}

struct FilmtoneAutomationSourceInspection: Codable, Equatable {
    var path: String
    var kind: String
    var exists: Bool
    var durationSeconds: Double?
    var nominalFrameRate: Double?
    var naturalSize: FilmtoneAutomationDimensions?
    var displaySize: FilmtoneAutomationDimensions?
    var hasAudio: Bool?
    var sourceColorClass: String?
    var sourceInterpretation: String?
    var sidecarPath: String?
    var warnings: [String]
}

struct FilmtoneAutomationPreviewBatchResponse: Codable, Equatable {
    var plan: FilmtoneAutomationBatchPlan
    var warnings: [String]
    var analysisLimits: FilmtoneAutomationAnalysisLimits
}

struct FilmtoneAutomationBatchPlan: Codable, Equatable {
    var createdAtIso: String
    var look: FilmtoneAutomationLookPlan
    var profiles: [FilmtoneAutomationExportProfile]
    var options: FilmtoneAutomationBatchOptions
    var items: [FilmtoneAutomationBatchItem]
    var warnings: [String]
}

struct FilmtoneAutomationBatchOptions: Codable, Equatable {
    var overwrite: Bool
    var continueOnError: Bool
    var recursive: Bool
}

struct FilmtoneAutomationLookPlan: Codable, Equatable {
    var requested: String?
    var label: String
    var presetName: String
    var presetStrength: Double
    var lookSlug: String?
}

struct FilmtoneAutomationBatchItem: Codable, Equatable {
    enum Status: String, Codable {
        case ready
        case skipped
        case blocked
    }

    var sourcePath: String
    var outputPath: String
    var profile: FilmtoneAutomationExportProfile
    var status: Status
    var reason: String?
    var sourceDisplaySize: FilmtoneAutomationDimensions?
    var outputSize: FilmtoneAutomationDimensions?
    var durationSeconds: Double?
    var nominalFrameRate: Double?
    var hasAudio: Bool?
    var warnings: [String]
}

struct FilmtoneAutomationAnswerContextRequest: Codable, Equatable {
    var question: String
    var paths: [String]?
    var recursive: Bool?
}

struct FilmtoneAutomationAnswerContext: Codable, Equatable {
    var question: String
    var sources: [FilmtoneAutomationSourceInspection]
    var supportedLooks: [String]
    var supportedExportProfiles: [String: String]
    var analysisLimits: FilmtoneAutomationAnalysisLimits
    var guidance: [String]
}

enum FilmtoneAutomationCore {
    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v"]
    static let stillExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "tif", "tiff"]

    static func inspectSources(
        _ request: FilmtoneAutomationInspectSourcesRequest
    ) async -> FilmtoneAutomationInspectSourcesResponse {
        let scan = expand(paths: request.paths, recursive: request.recursive ?? false)
        var sources: [FilmtoneAutomationSourceInspection] = []
        for candidate in scan.candidates {
            sources.append(await inspect(url: candidate))
        }
        for missing in scan.missing {
            sources.append(FilmtoneAutomationSourceInspection(
                path: missing.path,
                kind: "missing",
                exists: false,
                durationSeconds: nil,
                nominalFrameRate: nil,
                naturalSize: nil,
                displaySize: nil,
                hasAudio: nil,
                sourceColorClass: nil,
                sourceInterpretation: nil,
                sidecarPath: nil,
                warnings: ["Path does not exist."]
            ))
        }
        return FilmtoneAutomationInspectSourcesResponse(
            sources: sources.sorted { $0.path < $1.path },
            warnings: scan.warnings,
            analysisLimits: .stateExportAdvice
        )
    }

    static func previewBatch(
        _ request: FilmtoneAutomationBatchPlanRequest
    ) async -> FilmtoneAutomationPreviewBatchResponse {
        let options = FilmtoneAutomationBatchOptions(
            overwrite: request.overwrite ?? false,
            continueOnError: request.continueOnError ?? true,
            recursive: request.recursive ?? false
        )
        let profiles = request.profiles?.isEmpty == false
            ? request.profiles!
            : [.social1080]
        let look = resolveLook(request.look, strength: request.strength)
        let scan = expand(paths: request.paths, recursive: options.recursive)
        let outputRoot = request.outputDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) }
        var items: [FilmtoneAutomationBatchItem] = []
        var warnings = scan.warnings

        for missing in scan.missing {
            warnings.append("Missing path skipped: \(missing.path)")
        }

        for candidate in scan.candidates.sorted(by: { $0.path < $1.path }) {
            let kind = sourceKind(for: candidate)
            guard kind == "video" else {
                warnings.append("Skipped non-video source: \(candidate.path)")
                continue
            }

            do {
                let probe = try await FilmtoneSourceProber.probeVideo(sourceURL: candidate)
                let display = displayDimensions(naturalSize: probe.naturalSize, transform: probe.preferredTransform)
                for profile in profiles {
                    let outputDirectory = outputRoot ?? candidate.deletingLastPathComponent()
                    let outputURL = outputDirectory
                        .appendingPathComponent(candidate.deletingPathExtension().lastPathComponent + "-\(profile.suffix)")
                        .appendingPathExtension("mp4")
                    let outputSize = outputDimensions(
                        displayWidth: display.width,
                        displayHeight: display.height,
                        profile: profile
                    )
                    let conflict = FileManager.default.fileExists(atPath: outputURL.path)
                    let status: FilmtoneAutomationBatchItem.Status = conflict && !options.overwrite ? .blocked : .ready
                    let reason = conflict && !options.overwrite ? "Output already exists and overwrite is false." : nil
                    items.append(FilmtoneAutomationBatchItem(
                        sourcePath: candidate.path,
                        outputPath: outputURL.path,
                        profile: profile,
                        status: status,
                        reason: reason,
                        sourceDisplaySize: display,
                        outputSize: outputSize,
                        durationSeconds: probe.durationSeconds,
                        nominalFrameRate: Double(probe.nominalFrameRate),
                        hasAudio: probe.audioTrack != nil,
                        warnings: reason.map { [$0] } ?? []
                    ))
                }
            } catch {
                warnings.append("Could not probe video source \(candidate.path): \(error)")
                if !options.continueOnError {
                    break
                }
            }
        }

        let plan = FilmtoneAutomationBatchPlan(
            createdAtIso: isoNow(),
            look: look,
            profiles: profiles,
            options: options,
            items: items,
            warnings: warnings
        )
        return FilmtoneAutomationPreviewBatchResponse(
            plan: plan,
            warnings: warnings,
            analysisLimits: .stateExportAdvice
        )
    }

    static func answerContext(
        _ request: FilmtoneAutomationAnswerContextRequest
    ) async -> FilmtoneAutomationAnswerContext {
        let sources: [FilmtoneAutomationSourceInspection]
        if let paths = request.paths, !paths.isEmpty {
            sources = await inspectSources(
                FilmtoneAutomationInspectSourcesRequest(
                    paths: paths,
                    recursive: request.recursive
                )
            ).sources
        } else {
            sources = []
        }
        return FilmtoneAutomationAnswerContext(
            question: request.question,
            sources: sources,
            supportedLooks: supportedLookLabels(),
            supportedExportProfiles: Dictionary(
                uniqueKeysWithValues: FilmtoneAutomationExportProfile.allCases.map {
                    ($0.rawValue, $0.description)
                }
            ),
            analysisLimits: .stateExportAdvice,
            guidance: [
                "Answer as a Filmtone state/export workflow advisor.",
                "Do not claim visual facts such as clipping, skin warmth, or composition because v1 does not inspect frames.",
                "Recommend preview_batch_job before any export work.",
                "Use social1080 for posting-oriented H.264 output and archiveH264 when source display size should be preserved."
            ]
        )
    }

    static func outputDimensions(
        displayWidth: Int,
        displayHeight: Int,
        profile: FilmtoneAutomationExportProfile
    ) -> FilmtoneAutomationDimensions {
        let width = max(2, displayWidth)
        let height = max(2, displayHeight)
        guard let limit = profile.outputLongEdgeLimit else {
            return FilmtoneAutomationDimensions(width: even(width), height: even(height))
        }
        let longEdge = max(width, height)
        guard Double(longEdge) > limit else {
            return FilmtoneAutomationDimensions(width: even(width), height: even(height))
        }
        let scale = limit / Double(longEdge)
        return FilmtoneAutomationDimensions(
            width: even(Int((Double(width) * scale).rounded())),
            height: even(Int((Double(height) * scale).rounded()))
        )
    }

    static func resolveLook(
        _ requested: String?,
        strength: Double?
    ) -> FilmtoneAutomationLookPlan {
        let clampedStrength = FilmtonePresetCatalog.clampStrength(
            strength ?? FilmtonePresetCatalog.presetStrengthDefault
        )
        guard let raw = requested?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              raw.lowercased() != "none",
              raw.lowercased() != "reset" else {
            return FilmtoneAutomationLookPlan(
                requested: requested,
                label: "None",
                presetName: FilmtonePresetCatalog.defaultName,
                presetStrength: clampedStrength,
                lookSlug: nil
            )
        }

        if let look = FilmtoneCreativePackCatalog.all.first(where: {
            $0.slug == raw || $0.englishName.caseInsensitiveCompare(raw) == .orderedSame
        }) {
            return FilmtoneAutomationLookPlan(
                requested: requested,
                label: look.englishName,
                presetName: FilmtonePresetCatalog.defaultName,
                presetStrength: clampedStrength,
                lookSlug: look.slug
            )
        }

        return FilmtoneAutomationLookPlan(
            requested: requested,
            label: "None",
            presetName: FilmtonePresetCatalog.defaultName,
            presetStrength: clampedStrength,
            lookSlug: nil
        )
    }

    static func exportRequest(
        for item: FilmtoneAutomationBatchItem,
        in plan: FilmtoneAutomationBatchPlan
    ) -> FilmtoneVideoExportRequest {
        FilmtoneVideoExportRequest(
            sourceURL: URL(fileURLWithPath: item.sourcePath),
            outputURL: URL(fileURLWithPath: item.outputPath),
            presetName: plan.look.presetName,
            presetStrength: plan.look.presetStrength,
            lookSlug: plan.look.lookSlug,
            codec: .h264,
            sourceProfileSelection: .auto,
            quickState: .zero,
            paramOverrides: .empty,
            opticalFilterProfileId: nil,
            opticalFilterIntensity: 1.0,
            outputLongEdgeLimit: item.profile.outputLongEdgeLimit
        )
    }

    private static func inspect(url: URL) async -> FilmtoneAutomationSourceInspection {
        let kind = sourceKind(for: url)
        let sidecar = sourceSidecarURL(for: url)
        switch kind {
        case "video":
            do {
                let probe = try await FilmtoneSourceProber.probeVideo(sourceURL: url)
                let display = displayDimensions(naturalSize: probe.naturalSize, transform: probe.preferredTransform)
                let natural = FilmtoneAutomationDimensions(
                    width: max(0, Int(abs(probe.naturalSize.width).rounded())),
                    height: max(0, Int(abs(probe.naturalSize.height).rounded()))
                )
                let contract = FilmtoneColorPipeline.defaultOutputContract(
                    sourceMetadata: probe.metadata,
                    sourceColorClass: probe.colorClass
                )
                return FilmtoneAutomationSourceInspection(
                    path: url.path,
                    kind: "video",
                    exists: true,
                    durationSeconds: probe.durationSeconds,
                    nominalFrameRate: Double(probe.nominalFrameRate),
                    naturalSize: natural,
                    displaySize: display,
                    hasAudio: probe.audioTrack != nil,
                    sourceColorClass: probe.colorClass?.rawValue,
                    sourceInterpretation: contract.sourceInterpretationID,
                    sidecarPath: FileManager.default.fileExists(atPath: sidecar.path) ? sidecar.path : nil,
                    warnings: []
                )
            } catch {
                return FilmtoneAutomationSourceInspection(
                    path: url.path,
                    kind: "video",
                    exists: true,
                    durationSeconds: nil,
                    nominalFrameRate: nil,
                    naturalSize: nil,
                    displaySize: nil,
                    hasAudio: nil,
                    sourceColorClass: nil,
                    sourceInterpretation: nil,
                    sidecarPath: FileManager.default.fileExists(atPath: sidecar.path) ? sidecar.path : nil,
                    warnings: ["Could not probe video: \(error)"]
                )
            }
        case "still":
            let dimensions = stillDimensions(url)
            let probe = FilmtoneSourceProber.probeStill(sourceURL: url)
            let contract = FilmtoneColorPipeline.defaultOutputContract(
                sourceMetadata: probe.metadata,
                sourceColorClass: probe.colorClass
            )
            return FilmtoneAutomationSourceInspection(
                path: url.path,
                kind: "still",
                exists: true,
                durationSeconds: nil,
                nominalFrameRate: nil,
                naturalSize: dimensions,
                displaySize: dimensions,
                hasAudio: nil,
                sourceColorClass: probe.colorClass?.rawValue,
                sourceInterpretation: contract.sourceInterpretationID,
                sidecarPath: FileManager.default.fileExists(atPath: sidecar.path) ? sidecar.path : nil,
                warnings: ["Still export is out of scope for Codex batch MVP."]
            )
        default:
            return FilmtoneAutomationSourceInspection(
                path: url.path,
                kind: "unsupported",
                exists: true,
                durationSeconds: nil,
                nominalFrameRate: nil,
                naturalSize: nil,
                displaySize: nil,
                hasAudio: nil,
                sourceColorClass: nil,
                sourceInterpretation: nil,
                sidecarPath: nil,
                warnings: ["Unsupported source extension."]
            )
        }
    }

    private static func expand(paths: [String], recursive: Bool) -> (
        candidates: [URL],
        missing: [URL],
        warnings: [String]
    ) {
        var candidates: [URL] = []
        var missing: [URL] = []
        var warnings: [String] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                missing.append(url)
                continue
            }
            if isDirectory.boolValue {
                let keys: [URLResourceKey] = [.isRegularFileKey]
                if recursive,
                   let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles]
                   ) {
                    for case let child as URL in enumerator where isSupportedSource(child) {
                        candidates.append(child)
                    }
                } else {
                    do {
                        let children = try FileManager.default.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: keys,
                            options: [.skipsHiddenFiles]
                        )
                        candidates.append(contentsOf: children.filter(isSupportedSource))
                    } catch {
                        warnings.append("Could not read directory \(url.path): \(error)")
                    }
                }
            } else if isSupportedSource(url) {
                candidates.append(url)
            } else {
                candidates.append(url)
            }
        }
        return (
            Array(Set(candidates.map(\.standardizedFileURL))).sorted { $0.path < $1.path },
            missing,
            warnings
        )
    }

    private static func isSupportedSource(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return videoExtensions.contains(ext) || stillExtensions.contains(ext)
    }

    private static func sourceKind(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if videoExtensions.contains(ext) { return "video" }
        if stillExtensions.contains(ext) { return "still" }
        return "unsupported"
    }

    private static func sourceSidecarURL(for url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension("filmtone.json")
    }

    private static func stillDimensions(_ url: URL) -> FilmtoneAutomationDimensions? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        let width = properties[kCGImagePropertyPixelWidth] as? Int
        let height = properties[kCGImagePropertyPixelHeight] as? Int
        guard let width, let height else { return nil }
        return FilmtoneAutomationDimensions(width: width, height: height)
    }

    private static func displayDimensions(
        naturalSize: CGSize,
        transform: CGAffineTransform
    ) -> FilmtoneAutomationDimensions {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let width = abs(rect.width) > 0 ? abs(rect.width) : abs(naturalSize.width)
        let height = abs(rect.height) > 0 ? abs(rect.height) : abs(naturalSize.height)
        return FilmtoneAutomationDimensions(
            width: max(2, Int(width.rounded())),
            height: max(2, Int(height.rounded()))
        )
    }

    private static func even(_ value: Int) -> Int {
        let clamped = max(2, value)
        return clamped % 2 == 0 ? clamped : max(2, clamped - 1)
    }

    private static func supportedLookLabels() -> [String] {
        ["None"] + FilmtoneCreativePackCatalog.all.map(\.englishName)
    }

    private static func isoNow() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
