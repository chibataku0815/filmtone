import AVFoundation
import CryptoKit
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
    var security: FilmtoneAutomationBatchPlanSecurity?
}

struct FilmtoneAutomationBatchPlanSecurity: Codable, Equatable {
    var schemaVersion: Int
    var issuer: String
    var expiresAtIso: String
    var signature: String
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

enum FilmtoneAutomationSecurityError: Error, CustomStringConvertible {
    case tooManyPaths(Int, limit: Int)
    case invalidPath(String)
    case sensitivePath(String)
    case outsideAllowedRoots(String, kind: String, allowedRoots: [String])
    case missingPlanSignature
    case missingPlanSecret
    case expiredPlanSignature
    case invalidPlanSignature

    var description: String {
        switch self {
        case .tooManyPaths(let count, let limit):
            return "Too many paths: \(count). The Filmtone MCP limit is \(limit)."
        case .invalidPath(let label):
            return "\(label) must be a non-empty local file path."
        case .sensitivePath(let path):
            return "Filmtone MCP will not access sensitive path: \(path)"
        case .outsideAllowedRoots(let path, let kind, let allowedRoots):
            return "\(kind) path is outside Filmtone MCP allowed roots: \(path). Allowed roots: \(allowedRoots.joined(separator: ", "))"
        case .missingPlanSignature:
            return "runBatch requires a signed preview plan from Filmtone MCP. Run preview_batch_job again."
        case .missingPlanSecret:
            return "runBatch requires FILMTONE_AUTOMATION_PLAN_SECRET from the MCP runner."
        case .expiredPlanSignature:
            return "Batch plan security signature expired. Run preview_batch_job again."
        case .invalidPlanSignature:
            return "Batch plan security signature is invalid. Run preview_batch_job again."
        }
    }
}

enum FilmtoneAutomationSecurityPolicy {
    static let maxPathCount = 128
    static let maxPathLength = 4096
    static let defaultMaxScanFiles = 500

    static var maxScanFiles: Int {
        guard let raw = ProcessInfo.processInfo.environment["FILMTONE_MCP_MAX_SCAN_FILES"],
              let parsed = Int(raw),
              parsed > 0 else {
            return defaultMaxScanFiles
        }
        return parsed
    }

    static func validateSourcePaths(_ paths: [String]) throws {
        if paths.count > maxPathCount {
            throw FilmtoneAutomationSecurityError.tooManyPaths(paths.count, limit: maxPathCount)
        }
        for (index, path) in paths.enumerated() {
            _ = try validatePath(path, kind: "source", label: "paths[\(index)]")
        }
    }

    static func validateOutputPath(_ path: String, label: String) throws {
        _ = try validatePath(path, kind: "output", label: label)
    }

    static func validateOutputFilePath(_ path: String, label: String) throws {
        let canonical = try validatePath(path, kind: "output", label: label)
        guard canonical.lowercased().hasSuffix(".mp4") else {
            throw FilmtoneAutomationSecurityError.invalidPath(label)
        }
    }

    static func validateRunBatchPlan(_ plan: FilmtoneAutomationBatchPlan) throws {
        guard let security = plan.security else {
            throw FilmtoneAutomationSecurityError.missingPlanSignature
        }
        guard let secret = ProcessInfo.processInfo.environment["FILMTONE_AUTOMATION_PLAN_SECRET"],
              !secret.isEmpty else {
            throw FilmtoneAutomationSecurityError.missingPlanSecret
        }
        guard let expiresAt = parseIsoDate(security.expiresAtIso),
              expiresAt > Date() else {
            throw FilmtoneAutomationSecurityError.expiredPlanSignature
        }
        let expected = sign(plan: plan, security: security.withoutSignature, secret: secret)
        guard expected == security.signature else {
            throw FilmtoneAutomationSecurityError.invalidPlanSignature
        }
        for (index, item) in plan.items.enumerated() {
            try validateSourcePaths([item.sourcePath])
            try validateOutputFilePath(item.outputPath, label: "plan.items[\(index)].outputPath")
        }
    }

    private static func validatePath(_ path: String, kind: String, label: String) throws -> String {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              path.utf8.count <= maxPathLength,
              !path.contains("\0") else {
            throw FilmtoneAutomationSecurityError.invalidPath(label)
        }
        let canonical = canonicalPath(path)
        if isSensitivePath(canonical) {
            throw FilmtoneAutomationSecurityError.sensitivePath(redactHome(canonical))
        }
        let roots = kind == "source" ? allowedSourceRoots : allowedOutputRoots
        guard roots.contains(where: { isWithin(root: $0, path: canonical) }) else {
            throw FilmtoneAutomationSecurityError.outsideAllowedRoots(
                redactHome(canonical),
                kind: kind,
                allowedRoots: roots.map(redactHome)
            )
        }
        return canonical
    }

    private static var allowedSourceRoots: [String] {
        if let roots = parseRoots(ProcessInfo.processInfo.environment["FILMTONE_MCP_ALLOWED_SOURCE_ROOTS"]) {
            return roots
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            FileManager.default.currentDirectoryPath,
            FileManager.default.temporaryDirectory.path,
            "/tmp",
            "\(home)/Movies",
            "\(home)/Pictures",
            "\(home)/Desktop",
            "\(home)/Downloads",
            "/Volumes",
        ].map(canonicalPath)
    }

    private static var allowedOutputRoots: [String] {
        if let roots = parseRoots(ProcessInfo.processInfo.environment["FILMTONE_MCP_ALLOWED_OUTPUT_ROOTS"]) {
            return roots
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            FileManager.default.currentDirectoryPath,
            FileManager.default.temporaryDirectory.path,
            "/tmp",
            "\(home)/Movies",
            "\(home)/Pictures",
            "\(home)/Desktop",
            "\(home)/Downloads",
            "/Volumes",
        ].map(canonicalPath)
    }

    private static func parseRoots(_ raw: String?) -> [String]? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let separators = CharacterSet(charactersIn: ":\n")
        let roots = raw
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(canonicalPath)
        return roots.isEmpty ? nil : Array(Set(roots)).sorted()
    }

    private static func canonicalPath(_ path: String) -> String {
        let expanded: String
        if path == "~" {
            expanded = FileManager.default.homeDirectoryForCurrentUser.path
        } else if path.hasPrefix("~/") {
            expanded = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(String(path.dropFirst(2))).path
        } else {
            expanded = path
        }
        var probe = URL(fileURLWithPath: expanded).standardizedFileURL
        var missing: [String] = []
        while !FileManager.default.fileExists(atPath: probe.path) {
            let parent = probe.deletingLastPathComponent()
            if parent.path == probe.path { break }
            missing.insert(probe.lastPathComponent, at: 0)
            probe = parent
        }
        var resolved = FileManager.default.fileExists(atPath: probe.path)
            ? probe.resolvingSymlinksInPath()
            : probe
        for component in missing {
            resolved.appendPathComponent(component)
        }
        return resolved.standardizedFileURL.path
    }

    private static func isWithin(root: String, path: String) -> Bool {
        if path == root { return true }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return path.hasPrefix(prefix)
    }

    private static func isSensitivePath(_ path: String) -> Bool {
        let home = canonicalPath(FileManager.default.homeDirectoryForCurrentUser.path)
        let sensitiveRoots = [
            "/",
            "/System",
            "/Library",
            "/private/etc",
            "/etc",
            "/usr",
            "/bin",
            "/sbin",
            "/var/db",
            "/private/var/db",
            "\(home)/Library",
            "\(home)/.ssh",
            "\(home)/.gnupg",
            "\(home)/.aws",
            "\(home)/.config",
            "\(home)/.kube",
            "\(home)/.docker",
        ].map(canonicalPath)
        if sensitiveRoots.contains(where: { root in
            path == root || (root != "/" && isWithin(root: root, path: path))
        }) {
            return true
        }
        let sensitiveComponents: Set<String> = [
            ".aws", ".azure", ".config", ".docker", ".gnupg", ".kube",
            ".ssh", ".zsh_history", ".bash_history",
        ]
        return path.split(separator: "/").contains { sensitiveComponents.contains(String($0)) }
    }

    private static func redactHome(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~/" + String(path.dropFirst(home.count + 1))
        }
        return path
    }

    private static func parseIsoDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func sign(
        plan: FilmtoneAutomationBatchPlan,
        security: FilmtoneAutomationBatchPlanSecurity,
        secret: String
    ) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let payload = planSignaturePayload(plan: plan, security: security)
        let code = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return code.map { String(format: "%02x", $0) }.joined()
    }

    private static func planSignaturePayload(
        plan: FilmtoneAutomationBatchPlan,
        security: FilmtoneAutomationBatchPlanSecurity
    ) -> String {
        var parts: [String] = []
        push(&parts, String(security.schemaVersion))
        push(&parts, security.issuer)
        push(&parts, security.expiresAtIso)
        push(&parts, plan.createdAtIso)
        push(&parts, plan.look.requested ?? "")
        push(&parts, plan.look.label)
        push(&parts, plan.look.presetName)
        push(&parts, formatNumber(plan.look.presetStrength))
        push(&parts, plan.look.lookSlug ?? "")
        push(&parts, String(plan.profiles.count))
        plan.profiles.forEach { push(&parts, $0.rawValue) }
        push(&parts, String(plan.options.overwrite))
        push(&parts, String(plan.options.continueOnError))
        push(&parts, String(plan.options.recursive))
        push(&parts, String(plan.items.count))
        for item in plan.items {
            push(&parts, item.sourcePath)
            push(&parts, item.outputPath)
            push(&parts, item.profile.rawValue)
            push(&parts, item.status.rawValue)
            push(&parts, item.reason ?? "")
            pushDimensions(&parts, item.sourceDisplaySize)
            pushDimensions(&parts, item.outputSize)
            push(&parts, item.durationSeconds.map(formatNumber) ?? "")
            push(&parts, item.nominalFrameRate.map(formatNumber) ?? "")
            push(&parts, item.hasAudio.map { String($0) } ?? "")
            push(&parts, String(item.warnings.count))
            item.warnings.forEach { push(&parts, $0) }
        }
        push(&parts, String(plan.warnings.count))
        plan.warnings.forEach { push(&parts, $0) }
        return parts.joined(separator: "|")
    }

    private static func pushDimensions(_ parts: inout [String], _ dimensions: FilmtoneAutomationDimensions?) {
        push(&parts, dimensions.map { String($0.width) } ?? "")
        push(&parts, dimensions.map { String($0.height) } ?? "")
    }

    private static func push(_ parts: inout [String], _ value: String) {
        parts.append("\(value.utf8.count):\(value)")
    }

    private static func formatNumber(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

private extension FilmtoneAutomationBatchPlanSecurity {
    var withoutSignature: FilmtoneAutomationBatchPlanSecurity {
        FilmtoneAutomationBatchPlanSecurity(
            schemaVersion: schemaVersion,
            issuer: issuer,
            expiresAtIso: expiresAtIso,
            signature: ""
        )
    }
}

enum FilmtoneAutomationCore {
    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v"]
    static let stillExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "tif", "tiff"]

    static func inspectSources(
        _ request: FilmtoneAutomationInspectSourcesRequest
    ) async throws -> FilmtoneAutomationInspectSourcesResponse {
        try FilmtoneAutomationSecurityPolicy.validateSourcePaths(request.paths)
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
    ) async throws -> FilmtoneAutomationPreviewBatchResponse {
        try FilmtoneAutomationSecurityPolicy.validateSourcePaths(request.paths)
        if let outputDirectory = request.outputDirectory {
            try FilmtoneAutomationSecurityPolicy.validateOutputPath(outputDirectory, label: "outputDirectory")
        }
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
    ) async throws -> FilmtoneAutomationAnswerContext {
        let sources: [FilmtoneAutomationSourceInspection]
        if let paths = request.paths, !paths.isEmpty {
            sources = try await inspectSources(
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
        let maxScanFiles = FilmtoneAutomationSecurityPolicy.maxScanFiles
        var didHitScanLimit = false
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
                        if candidates.count >= maxScanFiles {
                            didHitScanLimit = true
                            break
                        }
                        candidates.append(child)
                    }
                } else {
                    do {
                        let children = try FileManager.default.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: keys,
                            options: [.skipsHiddenFiles]
                        )
                        for child in children where isSupportedSource(child) {
                            if candidates.count >= maxScanFiles {
                                didHitScanLimit = true
                                break
                            }
                            candidates.append(child)
                        }
                    } catch {
                        warnings.append("Could not read directory \(url.path): \(error)")
                    }
                }
            } else if isSupportedSource(url) {
                if candidates.count < maxScanFiles {
                    candidates.append(url)
                } else {
                    didHitScanLimit = true
                }
            } else {
                if candidates.count < maxScanFiles {
                    candidates.append(url)
                } else {
                    didHitScanLimit = true
                }
            }
        }
        if didHitScanLimit {
            warnings.append("Scan limit reached after \(maxScanFiles) candidate files. Narrow the folder or set FILMTONE_MCP_MAX_SCAN_FILES explicitly.")
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
