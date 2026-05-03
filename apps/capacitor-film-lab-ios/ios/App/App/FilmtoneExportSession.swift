import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import os
import UIKit

final class FilmtoneExportSession {
    private let request: Phase0ExportRequestDTO
    private let sourceURL: URL
    private let cacheStore: CacheStore
    private let mezzanineService: MezzanineService?
    private let outputURL: URL
    /// v1.3 Item 2 Phase E: the Saved Look that was applied to the editor at
    /// export time, resolved by the caller (typically `FilmtoneEditorStore`)
    /// from `LibraryStoreActor.loadLook(id:)`. The session itself does not
    /// look this up — keeping the dependency injection edge here means
    /// `FilmtoneExportSession` stays free of the `LibraryStoreActor` actor
    /// reference and remains constructible from non-MainActor contexts.
    /// Pass nil when no Saved Look was active (or after dirtying the project
    /// state since apply); the sidecar's `savedLook` block is then omitted.
    private let appliedSavedLook: SavedLookEntry?
    /// v1.3 Camera Profiles Phase E — explicit Camera Profile selection
    /// passed in by the caller (typically `FilmtoneEditorStore.export` →
    /// `FilmtoneEditorFacade.runExport`). nil falls through to `.auto`
    /// inside `makeActiveInputLut`, preserving the pre-Phase-E behavior.
    /// Kept off `Phase0ExportRequestDTO` because it's iOS-side state, not
    /// a value the JS bridge needs to round-trip.
    private let cameraProfileSelection: CameraProfileSelection?
    private(set) var didUseMezzanineVariant: ProfileVariant?
    /// v1.4 sidecar telemetry: route validation outcome for the consumed
    /// mezzanine. "valid" when the routed-to URL passed isValidMezzanine right
    /// before AVURLAsset open; "invalidated-before-open" when a race (eviction
    /// or overwrite) made us fall back to source-direct after attribution.
    /// nil when no mezzanine was even routed (source-direct from the start).
    private(set) var mezzanineValidationStatus: String?
    /// v1.4 sidecar telemetry: whether this export synchronously generated the
    /// quality mezzanine via `ensureMezzanineBlocking` (true) vs picking up an
    /// already-prewarmed cache (false). nil when no quality variant was
    /// requested at all (the v1.4 default on iOS).
    private(set) var mezzanineGeneratedDuringExport: Bool?
    /// v1.4 sidecar telemetry: snapshot of the consumed cache file's metrics,
    /// captured at routing time so an OS Library/Caches eviction between
    /// AVURLAsset open and sidecar write does not silently drop the truth
    /// fields. Stays nil when no mezzanine was consumed.
    private(set) var mezzanineConsumedMetrics: MezzanineService.MezzanineMetrics?
    /// v1.4 sidecar telemetry: filename of the consumed cache (the SHA-256
    /// hex from `signature(...)`). Captured alongside metrics. Stays nil
    /// when no mezzanine was consumed.
    private(set) var mezzanineConsumedURLLastPathComponent: String?
    fileprivate let ciContext: CIContext
    fileprivate let colorPipeline: FilmtoneColorPipelineContract
    /// v1.5 export speed profile instrumentation. Five per-frame intervals
    /// (`decode`, `wait-encoder`, `build-graph`, `render`, `append`) emitted
    /// to Instruments via the `os_signpost` lane. Categories let us split
    /// per-frame timings from one-shot setup work in the Instruments UI.
    private let signposter = OSSignposter(
        subsystem: "com.chibatakumi.film.lab.export",
        category: "frame"
    )
    private let performanceMetrics = FilmtoneExportPerformanceMetrics()
    private let disableGlowFamilyForExport: Bool
    /// v1.5 Metal optics prototype: replaces `applyGlowFamilyStage` with a
    /// custom MTLComputePipeline path. Read from `FILMTONE_EXPORT_METAL_OPTICS`
    /// at init; runtime gating (Quality only / video / no-depth) is applied at
    /// the call site. Production path is unchanged when this flag is off.
    private let useMetalOpticsForExport: Bool
    private lazy var metalOpticsRenderer: FilmtoneMetalOpticsRenderer? =
        FilmtoneMetalOpticsRenderer(
            workingColorSpace: colorPipeline.workingColorSpace,
            ciContext: ciContext
        )
    private var metalOpticsActiveOnce = false
    /// Phase 2 段階 1: true once a frame's vignette stage was applied inside
    /// the Metal optics chain. Surfaced via sidecar `acceleratedRenderStages`
    /// alongside `"GlowFamily/metal"`.
    private var metalVignetteActiveOnce = false
    /// Frame-scope flag set when the Metal optics chain applied vignette in
    /// the same pass as glow. Read by `applyVignetteStage` to skip the CI
    /// path. Reset at the top of each `applyGrade` call.
    private var metalVignetteAppliedThisFrame = false
    private lazy var renderStageProfiler: FilmtoneExportRenderStageProfiler? =
        Self.makeRenderStageProfiler(
            ciContext: ciContext,
            colorSpace: outputColorSpace,
            metrics: performanceMetrics
        )
    private let preparedInputLut: PreparedLut?
    private let preparedCreativeLut: PreparedLut?
    private let sourceSeed: Double
    private let outputColorSpace: CGColorSpace
    private var degradedDecodePath = false
    private var cancelled = false
    /// v1.3 (D3.2): depth payload loaded by `exportStillImage` before grading;
    /// consumed by `applyGlowFamilyStage` to drive the depth prefilter on the
    /// glow trio. Remains nil for video exports and for still HEICs that lack
    /// AVDepthData or for which `request.depthEnabled` is false/nil.
    private var loadedDepthMap: FilmtoneDepthMap?
    /// v1.3 (D3.4): wall-clock cost accumulator for the three depth prefilter
    /// stages, surfaced through BenchmarkCollector via FilmtoneMediaRuntime.
    private(set) var depthPrefilterMs: Double?
    /// v1.3 (D3.5): mirror of the depth payload's pixel dimensions (post
    /// orientation), used by the sidecar callsite. nil when no depth was used.
    private(set) var depthResolution: (width: Int, height: Int)?
    /// v1.3 Phase B: count of video frames for which a depth sample was matched
    /// and forwarded to the prefilter. nil for still-image exports; 0 means the
    /// asset had a depth track but no frame matched (e.g. video began before
    /// the first depth pts, or every pull failed mid-stream).
    private(set) var videoDepthFramesProcessed: Int?
    /// v1.3 Phase B: cumulative wall-clock cost (ms) of `nextFrame` pulls during
    /// video export. nil for stills; the matching counter is
    /// `videoDepthFramesProcessed`.
    private(set) var videoDepthDecodeMs: Double?
    /// v1.3 Phase B: the `videoDepthSource` vocabulary value emitted into the
    /// sidecar (`AVDepthDataTrack` is the only emitted variant; no
    /// discriminator planned). nil when no depth reader opened.
    private(set) var videoDepthSourceLabel: String?
    private lazy var exportMotionBlurAccumulator = FilmtoneMotionBlurAccumulator(
        ciContext: ciContext,
        colorSpace: outputColorSpace,
        outputFrameRate: request.output.fps
    )

    /// v1.3 (D3.4): read-only accessor for the originating request. Used by
    /// FilmtoneMediaRuntime to pull `depthRenderer` for bench telemetry without
    /// exposing the full DTO via a stored property leak.
    var requestSnapshot: Phase0ExportRequestDTO { request }
    private static let aberrationEdgeSoftenScale = 32.0
    private static let aberrationEdgeSoftenMax = 0.52
    private static let aberrationEdgeSoftenCurve = 1.55
    private static let aberrationBlurRadiusMin = 1.6
    private static let aberrationBlurRadiusMax = 6.2
    private static let aberrationBlurRadiusCap = 7.8
    private static let lensSoftnessBlurBoost = 1.85
    private static let glowBaseScale = 0.5
    private static let bloomSpreadBoost = 1.25
    private static let halationSpreadDivisor = 12.0
    private static let diffusionCompositeBase = 0.87
    private static let bloomMipLevels = 6
    private static let halationMipLevels = 6
    private static let diffusionMipLevels = 4
    private static let glowUpsampleBlurRadius = 1.0
    private static let connectCubeFilenameSuffix = "combined-color.cube"
    private static let connectPreOpticalCubeFilenameSuffix = "pre-optical-color.cube"
    private static let connectPostOpticalCubeFilenameSuffix = "post-optical-color.cube"
    private static let connectReferenceAfterFilenameSuffix = "reference-after.jpg"
    private static let connectDctlFilenameSuffix = "filmtone-bridge.dctl"

    private static func environmentFlagEnabled(
        _ name: String,
        processInfo: ProcessInfo = .processInfo
    ) -> Bool {
        guard let rawValue = processInfo.environment[name] else {
            return false
        }
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    private struct ConnectPackageCompanions {
        let sourceMediaURL: URL
        let cubeURL: URL
        let preOpticalCubeURL: URL
        let postOpticalCubeURL: URL
        let dctlURL: URL
        let referenceAfterURL: URL
        let referenceAfterTimeSec: Double
        let sidecarPackage: SidecarPackage
    }

    init(
        request: Phase0ExportRequestDTO,
        sourceURL: URL,
        cacheStore: CacheStore,
        mezzanineService: MezzanineService? = nil,
        appliedSavedLook: SavedLookEntry? = nil,
        cameraProfile: CameraProfileSelection? = nil
    ) throws {
        self.request = request
        self.sourceURL = sourceURL
        self.cacheStore = cacheStore
        self.mezzanineService = mezzanineService
        self.appliedSavedLook = appliedSavedLook
        self.cameraProfileSelection = cameraProfile
        self.disableGlowFamilyForExport = Self.environmentFlagEnabled("FILMTONE_EXPORT_DISABLE_GLOW_FAMILY")
        self.useMetalOpticsForExport = Self.environmentFlagEnabled("FILMTONE_EXPORT_METAL_OPTICS")
        self.outputURL = try cacheStore.temporaryExportURL(pathExtension: request.output.container)
        let colorPipeline = FilmtoneColorPipeline.defaultOutputContract(
            sourceMetadata: request.sourceProbe?.sourceVideoMetadata?.color,
            sourceColorClass: request.sourceProbe?.sourceVideoMetadata?.colorClass
        )
        self.colorPipeline = colorPipeline
        let workingColorSpace = colorPipeline.workingColorSpace
        let outputColorSpace = colorPipeline.destinationColorSpace
        self.outputColorSpace = outputColorSpace
        self.ciContext = CIContext(options: [
            .cacheIntermediates: false,
            .priorityRequestLow: false,
            .workingColorSpace: workingColorSpace,
            .workingFormat: NSNumber(value: CIFormat.RGBAh.rawValue),
            .outputColorSpace: outputColorSpace,
        ])
        // v1.3 Camera Profiles Phase E: dispatch through `makeActiveInputLut`
        // when the caller passed an explicit `cameraProfile`; legacy (nil)
        // callers fall through to `.auto` inside `makeActiveInputLut`, so
        // v1.2 behavior stays byte-identical when no profile was selected.
        // A user-imported `request.inputLut` always wins (existing
        // precedence).
        self.preparedInputLut = Self.makePreparedLut(from: request.inputLut)
            ?? Self.makeActiveInputLut(
                for: cameraProfile,
                probe: request.sourceProbe
            )
        let legacyCreativeLut = request.creativeLut ?? request.lut.map {
            SerializableLutDTO(size: $0.size, data: $0.data, intensity: $0.intensity)
        }
        self.preparedCreativeLut = Self.makePreparedLut(from: legacyCreativeLut)
        self.sourceSeed = Self.makeStableSourceSeed(from: sourceURL.absoluteString)
        if disableGlowFamilyForExport {
            NSLog("FilmtoneExportSession: GlowFamily disabled by FILMTONE_EXPORT_DISABLE_GLOW_FAMILY")
        }
        if useMetalOpticsForExport {
            NSLog("FilmtoneExportSession: Metal optics prototype enabled by FILMTONE_EXPORT_METAL_OPTICS (Quality video only)")
        }
    }

    /// Flips the internal cancellation flag. Should normally be reached via
    /// ``ExportCancelController/cancel(reason:)`` so the cancel propagates
    /// once across all entry points (WebView UI, Live Activity intent,
    /// background-task expiration). Direct callers exist only as a defensive
    /// mirror in ``FilmtoneMediaPlugin/cancelExport(_:)`` — the operation is
    /// idempotent at the session level (single Bool write), so the duplicate
    /// is harmless.
    func cancel() {
        cancelled = true
    }

    func makeSharedGradeProcessor() -> FilmtoneSharedGradeProcessor {
        FilmtoneSharedGradeProcessor(session: self)
    }

    func renderPreviewFrame() throws -> Phase0PreviewRenderResultDTO {
        defer {
            ciContext.clearCaches()
        }

        switch request.sourceKind {
        case .image:
            return try renderStillPreview()
        case .video:
            return try renderVideoPreview()
        }
    }

    func run(
        progress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws -> Phase0ExportResultDTO {
        defer {
            ciContext.clearCaches()
        }

        // v1.3 Phase B: video sources with `AVDepthDataTrack` now flow into
        // `exportVideo`, which probes the asset and either wires
        // up the per-frame depth pull or throws `depthUnsupportedForVideoSource`
        // when the requested depth-on path has no underlying track. The throw
        // moved one layer down because reliable detection is async and
        // `Phase0ExportRequestDTO` does not carry the picker's
        // `SourceInfoDTO.hasDepth`; trusting an asset-side probe over a
        // client-supplied flag also matches `feedback_no_fallback_bug_hotbed`
        // (no silent fallback — explicit throw when depth was requested but
        // the source can't supply it).

        let startedAt = Date()
        progress(.init(stage: .preflight, progress: 0.03, currentFrame: nil, totalFrames: nil, message: "Preparing export"))

        let result: CompletedExport
        switch request.sourceKind {
        case .video:
            result = try exportVideo(progress: progress)
        case .image:
            result = try exportStillImage(progress: progress)
        }

        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000.0)
        let disabledRenderStages = disableGlowFamilyForExport
            ? [FilmtoneExportRenderSubstage.glowFamily.rawValue]
            : []
        var acceleratedRenderStages: [String] = []
        if metalOpticsActiveOnce {
            acceleratedRenderStages.append(FilmtoneExportRenderSubstage.glowFamily.rawValue + "/metal")
        }
        if metalVignetteActiveOnce {
            acceleratedRenderStages.append(FilmtoneExportRenderSubstage.vignette.rawValue + "/metal")
        }
        let performance = performanceMetrics.sidecarPerformance(
            elapsedMs: elapsedMs,
            disabledRenderStages: disabledRenderStages,
            acceleratedRenderStages: acceleratedRenderStages
        )
        if let performance {
            NSLog(
                "Filmtone export profile: elapsed=%dms media=%@ decode=%.2fms waitEncoder=%.2fms build=%.2fms render=%.2fms append=%.2fms writerFinish=%.2fms residual=%@ frames=%d",
                performance.exportElapsedMs,
                performance.mediaPipelineMs.map { String(format: "%.2fms", $0) } ?? "nil",
                performance.decodeMs,
                performance.waitEncoderMs,
                performance.buildGraphMs,
                performance.renderMs,
                performance.appendMs,
                performance.writerFinishMs,
                performance.mediaPipelineResidualMs.map { String(format: "%.2fms", $0) } ?? "nil",
                performance.renderedFrames
            )
            if let stageProfile = performance.renderStageProfile {
                let stageSummary = stageProfile.stages.map { stage in
                    String(
                        format: "%@ cumulative=%.2fms estIncremental=%@ samples=%d failures=%d",
                        stage.stage,
                        stage.cumulativeMs,
                        stage.estimatedIncrementalMs.map { String(format: "%.2fms", $0) } ?? "nil",
                        stage.samples,
                        stage.failures
                    )
                }.joined(separator: " | ")
                NSLog(
                    "Filmtone export render stage profile: mode=%@ stride=%d sampledFrames=%d totalFrames=%d forcedRender=%.2fms %@",
                    stageProfile.mode,
                    stageProfile.frameStride,
                    stageProfile.sampledFrames,
                    stageProfile.totalFrames,
                    stageProfile.forcedRenderMs,
                    stageSummary
                )
            }
        }
        let fileSizeBytes = try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        let realtimeRatio: Double?
        if let duration = result.sourceDurationSec, duration > 0 {
            realtimeRatio = Double(elapsedMs) / (duration * 1000.0)
        } else {
            realtimeRatio = nil
        }

        // v1.4: only build the multi-GB Filmtone Connect package companion set
        // when the caller explicitly requested it via `connectPackage: true`.
        // Save-to-Photos / share-sheet flows leave the flag absent, which used
        // to write a full-size source.mov copy + cubes + DCTL on every export
        // and chewed through Library/Caches headroom (a contributor to the
        // mezzanine-cache eviction story).
        let packageCompanions: ConnectPackageCompanions?
        if request.connectPackage == true {
            packageCompanions = makeConnectPackageCompanions(result: result)
        } else {
            packageCompanions = nil
        }

        // T2 (v1.1): write the filmtone-ios-export-session-v1 sidecar next to the
        // export output. Failure here must NOT fail the export itself — missing
        // sidecar just surfaces as `sidecarUri = nil` downstream.
        let sidecarUri = writeExportSidecar(
            outputSize: result.outputSize,
            fileSizeBytes: fileSizeBytes,
            elapsedMs: elapsedMs,
            realtimeRatio: realtimeRatio,
            audioPreserved: result.audioPreserved,
            package: packageCompanions?.sidecarPackage,
            performance: performance
        )
        let packageFileUris = makePackageFileUris(
            sidecarUri: sidecarUri,
            companions: packageCompanions
        )

        progress(.init(stage: .completed, progress: 1.0, currentFrame: result.frameCount, totalFrames: result.frameCount, message: "Export complete"))

        return Phase0ExportResultDTO(
            outputUri: outputURL.absoluteString,
            elapsedMs: elapsedMs,
            outputWidth: Int(result.outputSize.width.rounded()),
            outputHeight: Int(result.outputSize.height.rounded()),
            outputFps: request.output.fps,
            fileSizeBytes: fileSizeBytes,
            realtimeRatio: realtimeRatio,
            audioPreserved: result.audioPreserved,
            benchmarkRecord: nil,
            sidecarUri: sidecarUri,
            packageFileUris: packageFileUris
        )
    }

    /// Assemble and atomically write the filmtone-ios-export-session-v1 sidecar.
    /// Returns the sidecar absolute URL string on success, `nil` on any failure.
    private func writeExportSidecar(
        outputSize: CGSize,
        fileSizeBytes: Int?,
        elapsedMs: Int,
        realtimeRatio: Double?,
        audioPreserved: Bool?,
        package: SidecarPackage?,
        performance: SidecarPerformance?
    ) -> String? {
        let identity = SidecarDeviceIdentity(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            deviceModel: UIDevice.current.filmtoneModelIdentifier,
            iosVersion: UIDevice.current.systemVersion,
            exportedAtIso: ISO8601DateFormatter.filmtoneSidecar.string(from: Date())
        )

        let hdrPolicy = request.sourceProbe?.sourceVideoMetadata?.hdrPreparationPolicy

        // v1.3 (D3.5): depth block. Always emitted — `used: false` is the
        // explicit signal that depth was not consumed (vs. absent field which
        // would mean "v1.2 sidecar / unknown"). Renderer is "ci" by default
        // (Phase A ships only the Core Image kernel; the contract reserves
        // "metal" for Phase B).
        let depthSidecar: SidecarDepthInfo
        if let res = depthResolution {
            depthSidecar = SidecarDepthInfo(
                used: true,
                source: "avDepthData",
                resolutionWidth: res.width,
                resolutionHeight: res.height,
                renderer: request.depthRenderer ?? DepthRenderer.ci.rawValue,
                framesWithDepth: videoDepthFramesProcessed,
                videoDepthSource: videoDepthSourceLabel
            )
        } else {
            // Video that opened a depth reader but never matched a frame
            // (asset began before first depth pts, or every pull failed) still
            // owes the importer `used: false` plus the diagnostic block —
            // `framesWithDepth: 0` distinguishes "asset had a track" from "no
            // track at all" (still / no-opt-in path keeps both nil).
            depthSidecar = SidecarDepthInfo(
                used: false,
                source: nil,
                resolutionWidth: nil,
                resolutionHeight: nil,
                renderer: nil,
                framesWithDepth: videoDepthSourceLabel != nil ? (videoDepthFramesProcessed ?? 0) : nil,
                videoDepthSource: videoDepthSourceLabel
            )
        }

        // v1.3 Item 2 Phase E: convert the resolved Saved Look entry (if any)
        // into the builder-local `SidecarSavedLookRef`. Built-in entries
        // surface `bundled: true` + `bundledSlug`; user-saved entries omit
        // both via `encodeIfPresent`. The sidecar block itself is `nil` when
        // no Saved Look was applied at export time.
        let savedLookRef: SidecarSavedLookRef? = appliedSavedLook.map { entry in
            SidecarSavedLookRef(
                id: entry.id.uuidString,
                name: entry.name,
                updatedAtIso: ISO8601DateFormatter.filmtoneSidecar.string(from: entry.updatedAt),
                bundled: entry.bundled ? true : nil,
                bundledSlug: entry.bundledSlug
            )
        }

        // v1.3 Camera Profiles Phase G: flatten the active CameraProfileSelection
        // (+ resolved catalog entry if any) into stringly-typed sidecar
        // fields. Auto + no probe match → selectionKind="auto", no catalog
        // entry. Auto + match → catalog id and resolvedFromAutoVia set so
        // downstream readers can tell user-explicit picks from auto picks.
        let cameraProfileBlock: SidecarCameraProfile? = Self.makeCameraProfileSidecar(
            for: cameraProfileSelection,
            probeColorClass: request.sourceProbe?.sourceVideoMetadata?.colorClass
        )

        let inputs = SidecarBuildInputs(
            request: request,
            sourceProbe: request.sourceProbe,
            hdrPolicy: hdrPolicy,
            degradedDecodePath: degradedDecodePath,
            outputURL: outputURL,
            outputSize: outputSize,
            fileSizeBytes: fileSizeBytes,
            elapsedMs: elapsedMs,
            realtimeRatio: realtimeRatio,
            audioPreserved: audioPreserved,
            identity: identity,
            // v1.2: render-mode + mezzanine variant + profile-version for sidecar truth.
            // Stream D owns the field declarations on SidecarBuildInputs; this call site
            // populates them per the cross-stream contract.
            renderMode: (request.renderMode ?? .quality).rawValue,
            mezzanineUsedVariant: didUseMezzanineVariant?.rawValue,
            mezzanineProfileVersion: didUseMezzanineVariant != nil ? MezzanineService.Profile.version : nil,
            // v1.4 truth fields. All nil when no mezzanine was consumed; populated
            // from the snapshot we captured in exportVideo (so an eviction between
            // routing and sidecar write cannot strip them).
            mezzanineUrlLastPathComponent: mezzanineConsumedURLLastPathComponent,
            mezzanineFileSizeBytes: mezzanineConsumedMetrics?.fileSizeBytes,
            mezzanineDurationSec: mezzanineConsumedMetrics?.durationSec,
            mezzanineWidth: mezzanineConsumedMetrics?.width,
            mezzanineHeight: mezzanineConsumedMetrics?.height,
            mezzanineCodec: mezzanineConsumedMetrics?.codec,
            mezzaninePrewarmHit: mezzanineGeneratedDuringExport.map { !$0 },
            mezzanineGeneratedDuringExport: mezzanineGeneratedDuringExport,
            mezzanineValidationStatus: mezzanineValidationStatus,
            colorPipeline: colorPipeline,
            package: package,
            depth: depthSidecar,
            appliedSavedLook: savedLookRef,
            cameraProfile: cameraProfileBlock,
            performance: performance
        )

        let sidecarURL = FilmtoneExportSidecarBuilder.sidecarURL(for: outputURL)
        do {
            let payload = try FilmtoneExportSidecarBuilder.build(inputs)
            try payload.write(to: sidecarURL, options: [.atomic])
            return sidecarURL.absoluteString
        } catch {
            filmtonePreviewCompositionDebugLog(
                "sidecar write failed at \(sidecarURL.path): \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func makeConnectPackageCompanions(
        result: CompletedExport
    ) -> ConnectPackageCompanions? {
        let directoryURL = outputURL.deletingLastPathComponent()
        let packageStem = outputURL.deletingPathExtension().lastPathComponent
        let sourceExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let sourcePackageURL = directoryURL
            .appendingPathComponent("\(packageStem)-source.\(sourceExtension)")
        let cubeURL = directoryURL
            .appendingPathComponent("\(packageStem)-\(Self.connectCubeFilenameSuffix)")
        let preOpticalCubeURL = directoryURL
            .appendingPathComponent("\(packageStem)-\(Self.connectPreOpticalCubeFilenameSuffix)")
        let postOpticalCubeURL = directoryURL
            .appendingPathComponent("\(packageStem)-\(Self.connectPostOpticalCubeFilenameSuffix)")
        let dctlURL = directoryURL
            .appendingPathComponent("\(packageStem)-\(Self.connectDctlFilenameSuffix)")
        let referenceURL = directoryURL
            .appendingPathComponent("\(packageStem)-\(Self.connectReferenceAfterFilenameSuffix)")

        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: sourcePackageURL.path) {
                try fileManager.removeItem(at: sourcePackageURL)
            }
            try fileManager.copyItem(at: sourceURL, to: sourcePackageURL)
            try FilmtoneConnectCubeWriter.writeCombinedColorCube(
                for: request,
                to: cubeURL
            )
            try FilmtoneConnectCubeWriter.writePreOpticalColorCube(
                for: request,
                to: preOpticalCubeURL
            )
            try FilmtoneConnectCubeWriter.writePostOpticalColorCube(
                for: request,
                to: postOpticalCubeURL
            )
            try FilmtoneConnectDctlWriter.writeBridgeDctl(
                for: request,
                cubeFilename: cubeURL.lastPathComponent,
                preOpticalColorFilename: preOpticalCubeURL.lastPathComponent,
                postOpticalColorFilename: postOpticalCubeURL.lastPathComponent,
                outputFps: request.output.fps,
                sourceSeed: sourceSeed,
                to: dctlURL
            )
            let referenceAfterTimeSec = try writeReferenceAfterImage(
                to: referenceURL,
                sourceDurationSec: result.sourceDurationSec
            )
            return ConnectPackageCompanions(
                sourceMediaURL: sourcePackageURL,
                cubeURL: cubeURL,
                preOpticalCubeURL: preOpticalCubeURL,
                postOpticalCubeURL: postOpticalCubeURL,
                dctlURL: dctlURL,
                referenceAfterURL: referenceURL,
                referenceAfterTimeSec: referenceAfterTimeSec,
                sidecarPackage: SidecarPackage(
                    sourceMediaFilename: sourcePackageURL.lastPathComponent,
                    renderedMediaFilename: outputURL.lastPathComponent,
                    referenceAfterFilename: referenceURL.lastPathComponent,
                    referenceAfterTimeSec: referenceAfterTimeSec,
                    combinedColorFilename: cubeURL.lastPathComponent,
                    preOpticalColorFilename: preOpticalCubeURL.lastPathComponent,
                    postOpticalColorFilename: postOpticalCubeURL.lastPathComponent,
                    effectsDctlFilename: dctlURL.lastPathComponent
                )
            )
        } catch {
            filmtonePreviewCompositionDebugLog(
                "Filmtone Connect package companion write failed: \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func makePackageFileUris(
        sidecarUri: String?,
        companions: ConnectPackageCompanions?
    ) -> [String]? {
        guard let sidecarUri, let companions else {
            return nil
        }
        return FilmtoneConnectPackageFiles.orderedPackageFileUris(
            renderedUri: outputURL.absoluteString,
            sidecarUri: sidecarUri,
            sourceMediaUri: companions.sourceMediaURL.absoluteString,
            preOpticalCubeUri: companions.preOpticalCubeURL.absoluteString,
            postOpticalCubeUri: companions.postOpticalCubeURL.absoluteString,
            cubeUri: companions.cubeURL.absoluteString,
            dctlUri: companions.dctlURL.absoluteString,
            referenceAfterUri: companions.referenceAfterURL.absoluteString
        )
    }

    private func exportVideo(
        progress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws -> CompletedExport {
        try prepareQualityMezzanineForExport(progress: progress)
        var effectiveSourceURL = resolvedVideoSourceURL()
        // v1.4: telemetry/sidecar records which mezzanine variant the export
        // actually consumed. resolvedVideoSourceURL only returns a mezzanine
        // URL or the original source, so we probe each known variant in
        // preference order (quality > preview-grade) until we find a match.
        didUseMezzanineVariant = nil
        mezzanineValidationStatus = nil
        if effectiveSourceURL != sourceURL, let mezz = mezzanineService {
            let depthEnabled = request.depthEnabled ?? false
            let candidates: [ProfileVariant] = [.qualityHDR, .qualitySDR, .hdr, .sdr]
            for variant in candidates {
                if effectiveSourceURL == mezz.existingMezzanineURL(
                    for: sourceURL,
                    variant: variant,
                    depthEnabled: depthEnabled
                ) {
                    didUseMezzanineVariant = variant
                    break
                }
            }
            // Final race guard: between routing and AVURLAsset(url:) open, the
            // file could have been invalidated (OS Library/Caches eviction
            // under disk pressure, a racing prewarm overwrite, or a manual
            // delete). Re-validate the picked URL; if it's no longer valid,
            // fall back to source-direct AND clear the variant so the sidecar
            // never claims a mezzanine was used when it wasn't.
            if let v = didUseMezzanineVariant,
               !mezz.isValidMezzaninePublic(
                   at: effectiveSourceURL,
                   sourceURL: sourceURL,
                   variant: v
               ) {
                filmtonePreviewCompositionDebugLog(
                    "Mezzanine race: routed-to URL invalidated before AVURLAsset open, falling back to source-direct"
                )
                didUseMezzanineVariant = nil
                effectiveSourceURL = sourceURL
                mezzanineValidationStatus = "invalidated-before-open"
            } else if didUseMezzanineVariant != nil {
                mezzanineValidationStatus = "valid"
                // Snapshot the cache file's identity & metrics now, so a
                // post-export eviction can't strip the truth fields out of
                // the sidecar.
                mezzanineConsumedURLLastPathComponent = effectiveSourceURL.lastPathComponent
                mezzanineConsumedMetrics = mezz.mezzanineMetrics(at: effectiveSourceURL)
            }
        }
        // v1.4: when render mode is .quality and we still have no mezzanine,
        // record an explicit signal that the route policy declined ("disabled
        // on iOS") rather than leaving sidecar `validationStatus` ambiguous.
        if mezzanineValidationStatus == nil,
           (request.renderMode ?? .quality) == .quality,
           didUseMezzanineVariant == nil {
            mezzanineValidationStatus = "disabled-on-ios"
        }
        let asset = AVURLAsset(url: effectiveSourceURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw FilmtoneMediaError.unsupportedSource("No video track was found in the selected source.")
        }

        // v1.3 Phase B: open a depth-track reader when the caller opted into
        // the depth pipeline. The probe lives here (not in `run()`) because
        // detection is async and `Phase0ExportRequestDTO` does not surface the
        // picker's `SourceInfoDTO.hasDepth`. Asset-side truth beats client
        // claims and avoids `feedback_no_fallback_bug_hotbed` (no silent
        // disable). When depth was requested but the asset has no track, we
        // throw `depthUnsupportedForVideoSource` so the WebView sees the same
        // contract violation it saw in Phase A.
        let depthReader = try resolveVideoDepthReader(asset: asset)
        defer { depthReader?.cancel() }
        if depthReader != nil {
            videoDepthSourceLabel = "AVDepthDataTrack"
            videoDepthFramesProcessed = 0
            videoDepthDecodeMs = 0
        }

        let sourceDurationSec = CMTimeGetSeconds(asset.duration)
        let outputSize = Self.scaledSize(for: videoTrack, longEdge: request.output.longEdge)
        let writer = try makeWriter(outputSize: outputSize)
        let videoInput = makeVideoInput(outputSize: outputSize)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(outputSize.width.rounded()),
                kCVPixelBufferHeightKey as String: Int(outputSize.height.rounded()),
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw FilmtoneMediaError.exportFailed("Video writer input could not be added.")
        }
        writer.add(videoInput)

        let audioTrack = request.output.preserveAudio ? asset.tracks(withMediaType: .audio).first : nil
        let audioInput: AVAssetWriterInput?
        let audioOutput: AVAssetReaderTrackOutput?
        if let audioTrack {
            let pair = makeAudioPipeline(for: audioTrack)
            audioInput = pair.input
            audioOutput = pair.output
            if let audioInput, writer.canAdd(audioInput) {
                writer.add(audioInput)
            }
        } else {
            audioInput = nil
            audioOutput = nil
        }

        let reader = try AVAssetReader(asset: asset)
        let videoOutputSelection = makeVideoReaderOutput(
            for: videoTrack,
            reader: reader,
            codecFamily: request.sourceProbe?.codecFamily ?? request.sourceProbe?.sourceVideoMetadata?.codecFamily
        )
        guard let videoOutputSelection else {
            throw FilmtoneMediaError.exportFailed("Video reader output could not be added.")
        }
        let videoOutput = videoOutputSelection.output
        degradedDecodePath = videoOutputSelection.degradedDecodePath
        reader.add(videoOutput)

        if let audioOutput, reader.canAdd(audioOutput) {
            reader.add(audioOutput)
        }

        guard writer.startWriting() else {
            throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The writer failed to start.")
        }
        guard reader.startReading() else {
            throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "The reader failed to start.")
        }
        writer.startSession(atSourceTime: .zero)

        let outputFrameCount = max(
            1,
            Int(floor((sourceDurationSec.isFinite ? sourceDurationSec : 0) * Double(request.output.fps) + 1e-6))
        )
        var renderedFrames = 0
        let completionLock = NSLock()
        let failureLock = NSLock()
        let dispatchGroup = DispatchGroup()
        let videoQueue = DispatchQueue(label: "FilmtoneExportSession.video")
        let audioQueue = DispatchQueue(label: "FilmtoneExportSession.audio")
        var videoInputFinished = false
        var audioInputFinished = audioInput == nil
        var capturedError: Error?

        func finishVideoInput(markAsFinished: Bool) {
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !videoInputFinished else {
                return
            }
            if markAsFinished {
                videoInput.markAsFinished()
            }
            videoInputFinished = true
            dispatchGroup.leave()
        }

        func finishAudioInput(markAsFinished: Bool) {
            guard let audioInput else {
                return
            }

            completionLock.lock()
            defer { completionLock.unlock() }
            guard !audioInputFinished else {
                return
            }
            if markAsFinished {
                audioInput.markAsFinished()
            }
            audioInputFinished = true
            dispatchGroup.leave()
        }

        func failExport(_ error: Error) {
            failureLock.lock()
            let shouldStore = capturedError == nil
            if shouldStore {
                capturedError = error
            }
            failureLock.unlock()

            guard shouldStore else {
                return
            }

            reader.cancelReading()
            writer.cancelWriting()
            finishVideoInput(markAsFinished: true)
            finishAudioInput(markAsFinished: true)
        }

        progress(.init(stage: .reading, progress: 0.11, currentFrame: 0, totalFrames: outputFrameCount, message: "Reading source"))

        // v1.3 Phase B: depth-track frames seldom share the video track's
        // cadence (depth tracks are often ~half-rate). We hold the most-recent
        // depth frame whose pts <= current video pts in `lastDepthFrame`, and
        // peek one ahead in `pendingDepthFrame`. After a mid-stream pull
        // failure we keep `lastDepthFrame` (graceful degrade with `last-known
        // depth`) and stop pulling.
        var lastDepthFrame: (presentationTime: CMTime, depthMap: FilmtoneDepthMap)? = nil
        var pendingDepthFrame: (presentationTime: CMTime, depthMap: FilmtoneDepthMap)? = nil
        var depthReaderExhausted = depthReader == nil
        typealias TimedVideoSample = (buffer: CMSampleBuffer, rawTime: CMTime, timelineTime: CMTime)
        var sourceTimeOffset: CMTime?
        var previousVideoSample: TimedVideoSample?
        var lookaheadVideoSample: TimedVideoSample?
        var sourceReaderExhausted = false
        var nextOutputFrameIndex = 0
        let mediaPipelineStartedNs = DispatchTime.now().uptimeNanoseconds

        func outputPresentationTime(for frameIndex: Int) -> CMTime {
            CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(max(1, request.output.fps)))
        }

        func makeTimedVideoSample(_ sampleBuffer: CMSampleBuffer) -> TimedVideoSample {
            let rawTime = Self.validPresentationTime(for: sampleBuffer)
            if sourceTimeOffset == nil {
                sourceTimeOffset = rawTime
            }
            let timelineTime = Self.nonNegativeTime(
                CMTimeSubtract(rawTime, sourceTimeOffset ?? .zero)
            )
            return (sampleBuffer, rawTime, timelineTime)
        }

        func prepareDepthForOutputFrame(at outputPresentationTime: CMTime) {
            guard let reader = depthReader else {
                loadedDepthMap = nil
                return
            }
            let lookupTime = CMTimeAdd(outputPresentationTime, sourceTimeOffset ?? .zero)
            let decodeStart = Date()
            // Advance until pendingDepthFrame.pts > current output pts (or EOS).
            // The rendered video sample is resampled to the 24 fps output
            // timeline, so depth follows that same output timeline rather than
            // the original source-frame cadence.
            while !depthReaderExhausted,
                  pendingDepthFrame == nil
                    || CMTimeCompare(pendingDepthFrame!.presentationTime, lookupTime) <= 0 {
                if let pf = pendingDepthFrame {
                    lastDepthFrame = pf
                }
                switch pullNextVideoDepthFrame(reader: reader) {
                case .frame(let next):
                    pendingDepthFrame = next
                case .endOfStream:
                    pendingDepthFrame = nil
                    depthReaderExhausted = true
                case .failure(let error):
                    NSLog("FilmtoneExportSession: video depth frame pull failed: \(error). Continuing without depth for remaining frames.")
                    pendingDepthFrame = nil
                    depthReaderExhausted = true
                }
            }
            let depthMapForThisFrame = lastDepthFrame?.depthMap
            let decodeMs = Date().timeIntervalSince(decodeStart) * 1000.0
            videoDepthDecodeMs = (videoDepthDecodeMs ?? 0) + decodeMs
            loadedDepthMap = depthMapForThisFrame
            if let depthMapForThisFrame {
                videoDepthFramesProcessed = (videoDepthFramesProcessed ?? 0) + 1
                // depthResolution is the "did the prefilter run?" signal that
                // both the sidecar and runtime read; setting it on the first
                // matched frame keeps still / video paths telemetry-aligned.
                if depthResolution == nil {
                    depthResolution = (depthMapForThisFrame.width, depthMapForThisFrame.height)
                }
            }
        }

        func appendOutputFrame(
            using sample: TimedVideoSample,
            at outputPresentationTime: CMTime
        ) throws {
            prepareDepthForOutputFrame(at: outputPresentationTime)
            let outputTimeSec = CMTimeGetSeconds(outputPresentationTime)
            let appendedFrame = try appendVideoSample(
                sample.buffer,
                videoInput: videoInput,
                writer: writer,
                reader: reader,
                adaptor: adaptor,
                videoTrack: videoTrack,
                outputSize: outputSize,
                outputPresentationTime: outputPresentationTime,
                renderTimeSeconds: outputTimeSec.isFinite ? outputTimeSec : 0,
                waitForReady: false
            )
            guard appendedFrame else {
                throw FilmtoneMediaError.exportFailed("The decoded video sample did not contain an image buffer.")
            }

            renderedFrames += 1
            nextOutputFrameIndex += 1
            if renderedFrames == 1 || renderedFrames % 12 == 0 {
                let normalizedProgress = renderingProgress(
                    presentationTime: outputPresentationTime,
                    sourceDurationSec: sourceDurationSec
                )
                progress(.init(
                    stage: .rendering,
                    progress: min(0.9, normalizedProgress),
                    currentFrame: renderedFrames,
                    totalFrames: outputFrameCount,
                    message: "Rendering frames"
                ))
            }
        }

        dispatchGroup.enter()
        videoInput.requestMediaDataWhenReady(on: videoQueue) { [self] in
            while videoInput.isReadyForMoreMediaData {
                if capturedError != nil {
                    finishVideoInput(markAsFinished: true)
                    return
                }

                do {
                    try checkCancelled()
                    guard nextOutputFrameIndex < outputFrameCount else {
                        finishVideoInput(markAsFinished: true)
                        return
                    }

                    if previousVideoSample == nil {
                        let decodedSample = performanceMetrics.measure(.decode) {
                            signposter.withIntervalSignpost("decode") {
                                videoOutput.copyNextSampleBuffer()
                            }
                        }
                        guard let sampleBuffer = decodedSample else {
                            if reader.status == .failed {
                                throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "Video read failed.")
                            }
                            finishVideoInput(markAsFinished: true)
                            return
                        }
                        previousVideoSample = makeTimedVideoSample(sampleBuffer)
                        continue
                    }

                    if !sourceReaderExhausted && lookaheadVideoSample == nil {
                        let decodedSample = performanceMetrics.measure(.decode) {
                            signposter.withIntervalSignpost("decode") {
                                videoOutput.copyNextSampleBuffer()
                            }
                        }
                        guard let sampleBuffer = decodedSample else {
                            if reader.status == .failed {
                                throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "Video read failed.")
                            }
                            sourceReaderExhausted = true
                            continue
                        }
                        lookaheadVideoSample = makeTimedVideoSample(sampleBuffer)
                        continue
                    }

                    if let lookahead = lookaheadVideoSample {
                        let outputTime = outputPresentationTime(for: nextOutputFrameIndex)
                        if CMTimeCompare(outputTime, lookahead.timelineTime) < 0 {
                            guard let previous = previousVideoSample else {
                                throw FilmtoneMediaError.exportFailed("The first decoded video frame was unavailable.")
                            }
                            let previousDelta = Self.absoluteSecondsBetween(
                                previous.timelineTime,
                                outputTime
                            )
                            let lookaheadDelta = Self.absoluteSecondsBetween(
                                lookahead.timelineTime,
                                outputTime
                            )
                            let selectedSample = previousDelta <= lookaheadDelta ? previous : lookahead
                            try appendOutputFrame(using: selectedSample, at: outputTime)
                        } else {
                            previousVideoSample = lookahead
                            lookaheadVideoSample = nil
                        }
                        continue
                    }

                    if sourceReaderExhausted, let previous = previousVideoSample {
                        try appendOutputFrame(
                            using: previous,
                            at: outputPresentationTime(for: nextOutputFrameIndex)
                        )
                        continue
                    }
                } catch {
                    failExport(error)
                    return
                }
            }
        }

        if let audioInput, let audioOutput {
            dispatchGroup.enter()
            audioInput.requestMediaDataWhenReady(on: audioQueue) { [self] in
                while audioInput.isReadyForMoreMediaData {
                    if capturedError != nil {
                        finishAudioInput(markAsFinished: true)
                        return
                    }

                    do {
                        try checkCancelled()
                        guard let sampleBuffer = audioOutput.copyNextSampleBuffer() else {
                            if reader.status == .failed {
                                throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "Audio read failed.")
                            }
                            finishAudioInput(markAsFinished: true)
                            return
                        }

                        try appendAudioSample(
                            sampleBuffer,
                            audioInput: audioInput,
                            writer: writer,
                            reader: reader,
                            waitForReady: false
                        )
                    } catch {
                        failExport(error)
                        return
                    }
                }
            }
        }

        dispatchGroup.wait()
        performanceMetrics.recordMediaPipeline(elapsedSince: mediaPipelineStartedNs)

        if let capturedError {
            throw capturedError
        }

        if reader.status == .failed {
            throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "Video read failed.")
        }

        progress(.init(stage: .writing, progress: 0.92, currentFrame: renderedFrames, totalFrames: outputFrameCount, message: "Writing output"))
        try performanceMetrics.measure(.writerFinish) {
            try finish(writer: writer)
        }

        return CompletedExport(
            outputSize: outputSize,
            frameCount: renderedFrames,
            sourceDurationSec: sourceDurationSec.isFinite ? sourceDurationSec : nil,
            audioPreserved: audioInput != nil
        )
    }

    private func exportStillImage(
        progress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws -> CompletedExport {
        guard let image = loadedSourceImage(at: sourceURL) else {
            throw FilmtoneMediaError.unsupportedSource("The selected image could not be loaded.")
        }

        // v1.3 (D3.2): load AVDepthData payload before the grade pipeline so
        // applyGlowFamilyStage can pass it into the depth prefilter. Gated on
        // (a) explicit opt-in via Phase0ExportRequestDTO.depthEnabled, (b) the
        // SourceInfoDTO.hasDepth signal Stream A wired through AssetPickerService,
        // and (c) the source actually being a HEIC on disk. Anything else
        // produces depthMap=nil → glow trio runs byte-identical to v1.2
        // (`feedback_no_fallback_bug_hotbed`: no silent fallback inside the
        // depth path, only a clean off-state).
        if (request.depthEnabled ?? false),
           sourceURL.pathExtension.lowercased() == "heic"
              || sourceURL.pathExtension.lowercased() == "heif" {
            let semaphore = DispatchSemaphore(value: 0)
            var loaded: FilmtoneDepthMap?
            Task.detached(priority: .userInitiated) {
                defer { semaphore.signal() }
                do {
                    loaded = try await DepthSourceService().loadDepthMap(from: self.sourceURL)
                } catch {
                    // Tech failure (corrupt aux dict / allocation) — degrade to
                    // depth-off rather than failing the export. Phase A users
                    // expect "no depth available" UX, not a hard stop.
                    filmtonePreviewCompositionDebugLog(
                        "DepthSourceService.loadDepthMap failed: \(error.localizedDescription)"
                    )
                    loaded = nil
                }
            }
            semaphore.wait()
            self.loadedDepthMap = loaded
            if let loaded {
                self.depthResolution = (loaded.width, loaded.height)
            }
        }

        let outputSize = Self.scaledSize(for: image.extent.size, longEdge: request.output.longEdge)
        let writer = try makeWriter(outputSize: outputSize)
        let videoInput = makeVideoInput(outputSize: outputSize)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(outputSize.width.rounded()),
                kCVPixelBufferHeightKey as String: Int(outputSize.height.rounded()),
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw FilmtoneMediaError.exportFailed("Still-image writer input could not be added.")
        }
        writer.add(videoInput)

        guard writer.startWriting() else {
            throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The writer failed to start.")
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(request.output.fps * 3, 1)
        let filteredImage = renderableStillImage(image, outputSize: outputSize, timeSeconds: 0)
        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw FilmtoneMediaError.exportFailed("Pixel buffer pool is unavailable.")
        }

        for frameIndex in 0..<frameCount {
            try checkCancelled()
            try autoreleasepool {
                try waitUntilReadyForMoreMediaData(videoInput, writer: writer, label: "video")

                var renderedBuffer: CVPixelBuffer?
                let creationStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &renderedBuffer)
                guard creationStatus == kCVReturnSuccess, let renderedBuffer else {
                    throw FilmtoneMediaError.exportFailed("A render pixel buffer could not be created.")
                }

                ciContext.render(
                    filteredImage,
                    to: renderedBuffer,
                    bounds: CGRect(origin: .zero, size: outputSize),
                    colorSpace: outputColorSpace
                )
                attachOutputColorMetadata(to: renderedBuffer)

                let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(request.output.fps))
                if !adaptor.append(renderedBuffer, withPresentationTime: presentationTime) {
                    throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The still frame could not be appended.")
                }
            }

            if frameIndex == 0 || frameIndex % 12 == 0 {
                let normalizedProgress = 0.12 + (Double(frameIndex + 1) / Double(frameCount)) * 0.74
                progress(.init(
                    stage: .rendering,
                    progress: min(0.9, normalizedProgress),
                    currentFrame: frameIndex + 1,
                    totalFrames: frameCount,
                    message: "Rendering still image"
                ))
            }
        }

        videoInput.markAsFinished()
        progress(.init(stage: .writing, progress: 0.92, currentFrame: frameCount, totalFrames: frameCount, message: "Writing output"))
        try finish(writer: writer)

        return CompletedExport(
            outputSize: outputSize,
            frameCount: frameCount,
            sourceDurationSec: Double(frameCount) / Double(request.output.fps),
            audioPreserved: false
        )
    }

    private func renderStillPreview() throws -> Phase0PreviewRenderResultDTO {
        guard let image = loadedSourceImage(at: sourceURL) else {
            throw FilmtoneMediaError.unsupportedSource("The selected image could not be loaded.")
        }

        let outputSize = Self.scaledSize(for: image.extent.size, longEdge: request.output.longEdge)
        let original = scaledStillSourceImage(image, outputSize: outputSize)
        let graded = applyGrade(to: original, timeSeconds: 0).cropped(to: original.extent)

        let originalURL = try writePreviewImage(original, preferredName: "filmtone-preview-original")
        let gradedURL = try writePreviewImage(graded, preferredName: "filmtone-preview-graded")

        return Phase0PreviewRenderResultDTO(
            originalUri: originalURL.absoluteString,
            gradedUri: gradedURL.absoluteString,
            width: Int(outputSize.width.rounded()),
            height: Int(outputSize.height.rounded()),
            posterTimeSec: nil
        )
    }

    private func renderVideoPreview() throws -> Phase0PreviewRenderResultDTO {
        // v1.4: read from the same effective URL the export will consume so
        // preview ↔ export bytes stay symmetric within each renderMode. When
        // the relevant mezzanine variant is missing (still being generated, or
        // policy declined), this transparently falls back to source.
        let effectiveSourceURL = resolvedVideoSourceURL()
        let asset = AVURLAsset(url: effectiveSourceURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw FilmtoneMediaError.unsupportedSource("No video track was found in the selected source.")
        }

        let sourceDurationSec = CMTimeGetSeconds(asset.duration)
        let posterTimeSec = makePreviewPosterTime(sourceDurationSec: sourceDurationSec)
        let outputSize = Self.scaledSize(for: videoTrack, longEdge: request.output.longEdge)

        let posterTime = CMTime(seconds: posterTimeSec, preferredTimescale: 600)
        let cgImage = try copyPreviewCGImage(for: asset, at: posterTime)
        let posterImage = CIImage(cgImage: cgImage)
        let original = scaledStillSourceImage(posterImage, outputSize: outputSize)
        let graded = applyGrade(to: original, timeSeconds: posterTimeSec).cropped(to: original.extent)

        let originalURL = try writePreviewImage(original, preferredName: "filmtone-preview-original")
        let gradedURL = try writePreviewImage(graded, preferredName: "filmtone-preview-graded")

        return Phase0PreviewRenderResultDTO(
            originalUri: originalURL.absoluteString,
            gradedUri: gradedURL.absoluteString,
            width: Int(outputSize.width.rounded()),
            height: Int(outputSize.height.rounded()),
            posterTimeSec: posterTimeSec
        )
    }

    private func copyPreviewCGImage(for asset: AVAsset, at time: CMTime) throws -> CGImage {
        do {
            return try configuredPreviewGenerator(asset: asset, tolerance: .zero).copyCGImage(at: time, actualTime: nil)
        } catch {
            let fallbackTolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
            return try configuredPreviewGenerator(asset: asset, tolerance: fallbackTolerance)
                .copyCGImage(at: time, actualTime: nil)
        }
    }

    private func configuredPreviewGenerator(asset: AVAsset, tolerance: CMTime) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        return generator
    }

    private func makeWriter(outputSize: CGSize) throws -> AVAssetWriter {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        writer.movieFragmentInterval = .invalid
        return writer
    }

    private func makeVideoInput(outputSize: CGSize) -> AVAssetWriterInput {
        let width = Int(outputSize.width.rounded())
        let height = Int(outputSize.height.rounded())
        let bitRate = max(width * height * 6, 3_000_000)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoExpectedSourceFrameRateKey: request.output.fps,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAllowFrameReorderingKey: false,
            ],
            AVVideoColorPropertiesKey: colorPipeline.writerColorProperties,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        input.transform = .identity
        return input
    }

    private func makeVideoReaderOutput(
        for track: AVAssetTrack,
        reader: AVAssetReader,
        codecFamily: SourceCodecFamilyDTO?
    ) -> (output: AVAssetReaderTrackOutput, degradedDecodePath: Bool)? {
        let candidates: [(pixelFormat: OSType, degraded: Bool)]
        if codecFamily == .prores422 {
            candidates = [
                (kCVPixelFormatType_422YpCbCr16, false),
                (kCVPixelFormatType_64RGBAHalf, true),
                (kCVPixelFormatType_32BGRA, true),
            ]
        } else {
            candidates = [
                (kCVPixelFormatType_32BGRA, false),
            ]
        }

        for candidate in candidates {
            let output = AVAssetReaderTrackOutput(
                track: track,
                outputSettings: colorPipeline.videoReaderOutputSettings(pixelFormat: candidate.pixelFormat)
            )
            output.alwaysCopiesSampleData = false
            if reader.canAdd(output) {
                return (output, candidate.degraded)
            }
        }

        return nil
    }

    private func makeAudioPipeline(
        for track: AVAssetTrack
    ) -> (input: AVAssetWriterInput, output: AVAssetReaderTrackOutput) {
        let output = AVAssetReaderTrackOutput(
            track: track,
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
        return (input, output)
    }

    private func renderableImage(
        from imageBuffer: CVPixelBuffer,
        transform: CGAffineTransform,
        outputSize: CGSize,
        timeSeconds: Double
    ) -> CIImage {
        let base = scaledVideoSourceImage(
            sourceVideoImage(from: imageBuffer),
            transform: transform,
            outputSize: outputSize
        )
        renderStageProfiler?.beginFrame()
        let graded = applyGrade(
            to: base,
            timeSeconds: timeSeconds,
            stageProfilingOutputSize: outputSize
        )
            .cropped(to: CGRect(origin: .zero, size: outputSize))
        let motionApplied = applyVideoMotionStage(
            to: graded,
            timeSeconds: timeSeconds,
            outputSize: outputSize,
            accumulator: exportMotionBlurAccumulator
        )
        profileRenderSubstage(.motion, image: motionApplied, outputSize: outputSize)
        return motionApplied
    }

    private func renderableStillImage(
        _ image: CIImage,
        outputSize: CGSize,
        timeSeconds: Double
    ) -> CIImage {
        let base = scaledStillSourceImage(image, outputSize: outputSize)
        let graded = applyGrade(to: base, timeSeconds: timeSeconds)
        return graded.cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    fileprivate func renderablePreviewVideoImage(
        from image: CIImage,
        outputSize: CGSize,
        timeSeconds: Double,
        motionAccumulator: FilmtoneMotionBlurAccumulator? = nil
    ) throws -> CIImage {
        let base = scaledPreviewVideoSourceImage(
            sourcePreviewVideoImage(from: image),
            outputSize: outputSize
        )
        let graded = applyGrade(to: base, timeSeconds: timeSeconds)
        let cropped = graded.cropped(to: CGRect(origin: .zero, size: outputSize))
        let motionApplied = applyVideoMotionStage(
            to: cropped,
            timeSeconds: timeSeconds,
            outputSize: outputSize,
            accumulator: motionAccumulator
        )
        try validatePreviewVideoImage(motionApplied, outputSize: outputSize)
        return motionApplied
    }

    private func scaledVideoFrameImage(
        from imageBuffer: CVPixelBuffer,
        transform: CGAffineTransform,
        outputSize: CGSize
    ) -> CIImage {
        scaledVideoSourceImage(
            sourceVideoImage(from: imageBuffer),
            transform: transform,
            outputSize: outputSize
        )
    }

    private func scaledVideoSourceImage(
        _ image: CIImage,
        transform: CGAffineTransform,
        outputSize: CGSize
    ) -> CIImage {
        let oriented = image.transformed(by: Self.coreImageVideoTransform(
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

    private func scaledPreviewVideoSourceImage(_ image: CIImage, outputSize: CGSize) -> CIImage {
        // AVVideoComposition's CI filtering request already respects track presentation.
        let normalized = image.transformed(by: CGAffineTransform(
            translationX: -image.extent.origin.x,
            y: -image.extent.origin.y
        ))
        let scaleX = outputSize.width / normalized.extent.width
        let scaleY = outputSize.height / normalized.extent.height
        return normalized
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    private func scaledStillSourceImage(_ image: CIImage, outputSize: CGSize) -> CIImage {
        let normalized = image.transformed(by: CGAffineTransform(
            translationX: -image.extent.origin.x,
            y: -image.extent.origin.y
        ))
        let scaleX = outputSize.width / normalized.extent.width
        let scaleY = outputSize.height / normalized.extent.height
        return normalized
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    private func validatePreviewVideoImage(_ image: CIImage, outputSize: CGSize) throws {
        let extent = image.extent.standardized
        guard
            extent.origin.x.isFinite,
            extent.origin.y.isFinite,
            extent.size.width.isFinite,
            extent.size.height.isFinite,
            !extent.isNull,
            !extent.isInfinite,
            extent.size.width > 0.5,
            extent.size.height > 0.5
        else {
            throw FilmtoneMediaError.exportFailed(
                filmtoneLocalized(
                    "filmtone.preview.video.invalid_extent",
                    defaultValue: "The live video preview produced an invalid frame.",
                    comment: "Error shown when the live video preview frame is invalid."
                )
            )
        }

        let expected = CGRect(origin: .zero, size: outputSize).standardized
        guard
            abs(extent.origin.x - expected.origin.x) < 0.5,
            abs(extent.origin.y - expected.origin.y) < 0.5,
            abs(extent.size.width - expected.size.width) < 0.5,
            abs(extent.size.height - expected.size.height) < 0.5
        else {
            throw FilmtoneMediaError.exportFailed(
                filmtoneLocalized(
                    "filmtone.preview.video.unexpected_extent",
                    defaultValue: "The live video preview frame size was invalid.",
                    comment: "Error shown when the live video preview frame extent is unexpected."
                )
            )
        }
    }

    static func coreImageVideoTransform(
        for preferredTransform: CGAffineTransform,
        sourceExtent: CGRect
    ) -> CGAffineTransform {
        // AVAssetTrack.preferredTransform is expressed in the track's top-left
        // coordinate space. Convert it into Core Image's bottom-left space
        // before rasterizing decoded buffers or portrait clips land 180° off.
        let sourceRect = CGRect(origin: .zero, size: sourceExtent.size)
        let displayedRect = sourceRect.applying(preferredTransform).standardized
        let inputFlip = CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -sourceRect.height)
        let outputFlip = CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -displayedRect.height)
        return inputFlip
            .concatenating(preferredTransform)
            .concatenating(outputFlip)
    }

    fileprivate func applyGrade(
        to image: CIImage,
        timeSeconds: Double,
        stageProfilingOutputSize: CGSize? = nil
    ) -> CIImage {
        let params = request.grade.params
        let presetVersion = request.grade.presetVersion
        var current = image

        // Phase 2 段階 1: clear the per-frame Metal vignette flag before any
        // stage runs. `applyGlowFamilyStage` sets it true when the Metal
        // optics chain absorbs the vignette pass; `applyVignetteStage`
        // consumes it to skip the CI path.
        metalVignetteAppliedThisFrame = false

        current = applyInputLutStage(to: current)
        profileRenderSubstage(.inputLut, image: current, outputSize: stageProfilingOutputSize)
        current = applyBaseGradeStage(to: current, params: params, presetVersion: presetVersion)
        profileRenderSubstage(.baseGrade, image: current, outputSize: stageProfilingOutputSize)
        current = applyToneCompressionStage(to: current, params: params, presetVersion: presetVersion)
        profileRenderSubstage(.toneCompression, image: current, outputSize: stageProfilingOutputSize)
        current = applyEdgeOpticsStage(to: current, params: params)
        profileRenderSubstage(.edgeOptics, image: current, outputSize: stageProfilingOutputSize)
        current = applyGlowFamilyStage(to: current, params: params)
        profileRenderSubstage(.glowFamily, image: current, outputSize: stageProfilingOutputSize)
        current = applyVignetteStage(to: current, params: params)
        profileRenderSubstage(.vignette, image: current, outputSize: stageProfilingOutputSize)
        current = applyGrainStage(to: current, params: params, timeSeconds: timeSeconds)
        profileRenderSubstage(.grain, image: current, outputSize: stageProfilingOutputSize)
        current = applyCreativeLutStage(to: current)
        profileRenderSubstage(.creativeLut, image: current, outputSize: stageProfilingOutputSize)
        current = applyPrintStage(to: current, params: params)
        profileRenderSubstage(.printStage, image: current, outputSize: stageProfilingOutputSize)

        return current.cropped(to: image.extent)
    }

    fileprivate var outputFrameRate: Int {
        request.output.fps
    }

    fileprivate func makeMotionBlurAccumulator() -> FilmtoneMotionBlurAccumulator {
        FilmtoneMotionBlurAccumulator(
            ciContext: ciContext,
            colorSpace: outputColorSpace,
            outputFrameRate: request.output.fps
        )
    }

    private func applyVideoMotionStage(
        to image: CIImage,
        timeSeconds: Double,
        outputSize: CGSize,
        accumulator: FilmtoneMotionBlurAccumulator?
    ) -> CIImage {
        guard let accumulator else {
            return image
        }
        return accumulator.apply(
            to: image,
            params: request.grade.params,
            timeSeconds: timeSeconds,
            outputSize: outputSize
        )
    }

    private func profileRenderSubstage(
        _ stage: FilmtoneExportRenderSubstage,
        image: CIImage,
        outputSize: CGSize?
    ) {
        guard let outputSize else {
            return
        }
        renderStageProfiler?.forceRender(stage, image: image, outputSize: outputSize)
    }

    private func applyInputLutStage(to image: CIImage) -> CIImage {
        guard let preparedInputLut else {
            return image
        }
        return applyLut(preparedInputLut, to: image)
    }

    private func applyBaseGradeStage(to image: CIImage, params: Phase0ParamsDTO, presetVersion: String) -> CIImage {
        let epsilon = 0.0001
        guard
            abs(params.exposure) > epsilon ||
            abs(params.contrast - 1.0) > epsilon ||
            abs(params.saturation - 1.0) > epsilon ||
            abs(params.temperature) > epsilon ||
            abs(params.tint) > epsilon ||
            abs(params.fade) > epsilon ||
            abs(params.shadowTone) > epsilon ||
            abs(params.highlightTone) > epsilon
        else {
            return image
        }

        let kernel: CIColorKernel?
        switch presetVersion {
        case "v2":
            kernel = OpticalKernels.baseGradeV2
        case "v1":
            kernel = OpticalKernels.baseGrade
        default:
            assertionFailure("Unknown presetVersion: \(presetVersion)")
            kernel = OpticalKernels.baseGradeV2
        }
        guard let kernel else {
            return image
        }

        // v1 kernel takes the original 7 args; v2 takes 11 (adds shadowTone /
        // highlightTone / shadowHue / highlightHue for density-dependent
        // split-tone).
        let args: [Any]
        switch presetVersion {
        case "v1":
            args = [
                image,
                params.exposure,
                params.contrast,
                params.saturation,
                params.temperature,
                params.tint,
                params.fade,
            ]
        default:
            args = [
                image,
                params.exposure,
                params.contrast,
                params.saturation,
                params.temperature,
                params.tint,
                params.fade,
                params.shadowTone,
                params.highlightTone,
                params.shadowHue,
                params.highlightHue,
            ]
        }
        return kernel.apply(extent: image.extent, arguments: args) ?? image
    }

    private func applyToneCompressionStage(to image: CIImage, params: Phase0ParamsDTO, presetVersion: String) -> CIImage {
        guard params.compressionAmount > 0.0001 else {
            return image
        }
        let kernel: CIColorKernel?
        switch presetVersion {
        case "v2":
            kernel = OpticalKernels.filmCompressionV2
        case "v1":
            kernel = OpticalKernels.filmCompression
        default:
            assertionFailure("Unknown presetVersion: \(presetVersion)")
            kernel = OpticalKernels.filmCompressionV2
        }
        guard let kernel else {
            return image
        }
        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.compressionAmount,
            params.compressionRange,
        ]) ?? image
    }

    private func applyEdgeOpticsStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        var current = image

        if params.rgbShift > 0.0001 {
            current = applyRadialRGBShift(params.rgbShift, to: current)
        }

        let rgbShiftNormalized = Self.clamp(
            params.rgbShift / max(FilmtonePhase0Generated.rgbShiftMax, 0.0001)
        )
        let aberrationSoften = Self.aberrationEdgeSoften(for: rgbShiftNormalized)
        if aberrationSoften > 0.0001 || params.lensSoftness > 0.0001 {
            current = applyEdgeSoftness(
                to: current,
                aberrationSoften: aberrationSoften,
                lensSoftness: params.lensSoftness
            )
        }

        return current
    }

    private func applyGlowFamilyStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        // v1.5 Metal optics prototype gate. Quality video exports without
        // depth payload may route the entire glow family chain to the custom
        // MTLComputePipeline path. The renderer falls back internally on any
        // allocation/encoding failure, but we also gate on call-site safety
        // (depth requires the CI prefilter, still images use loadedDepthMap).
        if useMetalOpticsForExport,
           !disableGlowFamilyForExport,
           request.sourceKind == .video,
           (request.renderMode ?? .quality) == .quality,
           loadedDepthMap == nil,
           let renderer = metalOpticsRenderer
        {
            let glowParams = FilmtoneMetalOpticsRenderer.GlowFrameParams(
                bloomStrength: params.bloomStrength,
                bloomThreshold: params.bloomThreshold,
                bloomSoftKnee: params.bloomSoftKnee,
                bloomRadius: params.bloomRadius,
                bloomMipLevels: Self.bloomMipLevels,
                bloomSpreadBoost: Self.bloomSpreadBoost,
                halationIntensity: params.halationIntensity,
                halationThreshold: params.halationThreshold,
                halationSoftKnee: params.halationSoftKnee,
                halationRadius: params.halationRadius,
                halationHue: params.halationHue,
                halationMipLevels: Self.halationMipLevels,
                halationSpread: params.halationSpread,
                halationSpreadDivisor: Self.halationSpreadDivisor,
                diffusion: params.diffusion,
                diffusionMipLevels: Self.diffusionMipLevels,
                diffusionCompositeBase: Self.diffusionCompositeBase,
                glowBaseScale: Self.glowBaseScale
            )
            // Phase 2 段階 1: fold the vignette stage into the same Metal
            // pass when the params justify it. Vignette is only chained when
            // intensity > epsilon; otherwise the chain runs glow-only and
            // applyVignetteStage stays a no-op (CI path also no-ops).
            let vignetteParams = vignetteFrameParams(image: image, params: params)
            let chainParams = FilmtoneMetalOpticsRenderer.OpticsChainParams(
                glow: glowParams,
                vignette: vignetteParams
            )
            if let metalResult = renderer.renderOpticsChain(
                input: image,
                outputExtent: image.extent,
                params: chainParams
            ) {
                metalOpticsActiveOnce = true
                if vignetteParams != nil {
                    metalVignetteActiveOnce = true
                    metalVignetteAppliedThisFrame = true
                }
                return metalResult
            }
        }

        guard !disableGlowFamilyForExport else {
            return image
        }

        let extent = image.extent
        let black = Self.blackImage(for: extent)

        // v1.3 (D3.2): depth × ray-angle prefilter on the glow trio.
        // Gated on `loadedDepthMap != nil`, which is only set in
        // `exportStillImage` when (depthEnabled && HEIC && hasDepth). With the
        // current contract `hiddenDefaults.depthMistGain == depthGlowGain == 0`
        // and the per-variant rayAngleGain/gamma/innerThreshold defaults, the
        // FilmtoneDepthPrefilter.apply short-circuits to `image` unchanged
        // (its first guard returns input when both gains are 0). UI inject of
        // non-zero gains is deferred to Stream 4 (a later wave); Phase A
        // landing is byte-identical to v1.2 unless a future call-site supplies
        // non-zero gains.
        let depthCI: CIImage? = self.loadedDepthMap?.ciImage
        let cameraOpticsDTO = self.request.sourceProbe?.cameraOptics
        let hidden = FilmtonePhase0Generated.hiddenDefaults
        let depthStart = (depthCI != nil) ? Date() : nil

        let bloomImage: CIImage
        if params.bloomStrength > 0.0001 {
            let bloomInput: CIImage
            if let depthCI {
                bloomInput = FilmtoneDepthPrefilter.apply(
                    to: image,
                    depth: depthCI,
                    imageExtent: extent,
                    optics: cameraOpticsDTO,
                    params: .init(
                        variant: .bloom,
                        depthGain: hidden.depthGlowGain,
                        rayAngleGain: hidden.depthBloomRayAngleGain,
                        rayAngleGamma: hidden.depthRayAngleGamma,
                        rayAngleInnerThreshold: hidden.depthRayAngleInnerThreshold
                    )
                )
            } else {
                bloomInput = image
            }
            let bloomPlate = extractHighlightPlate(
                from: bloomInput,
                threshold: params.bloomThreshold,
                knee: params.bloomSoftKnee,
                tintColor: CIColor(red: 1, green: 1, blue: 1, alpha: 1)
            )
            bloomImage = buildMipBlurComposite(
                from: bloomPlate,
                radius: params.bloomRadius,
                levelCount: Self.bloomMipLevels,
                spreadMultiplier: Self.bloomSpreadBoost,
                useTentResampling: true
            )
        } else {
            bloomImage = black
        }

        let halationImage: CIImage
        if params.halationIntensity > 0.0001 {
            let halationInput: CIImage
            if let depthCI {
                halationInput = FilmtoneDepthPrefilter.apply(
                    to: image,
                    depth: depthCI,
                    imageExtent: extent,
                    optics: cameraOpticsDTO,
                    params: .init(
                        variant: .halation,
                        depthGain: hidden.depthGlowGain,
                        rayAngleGain: hidden.depthHalationRayAngleGain,
                        rayAngleGamma: hidden.depthRayAngleGamma,
                        rayAngleInnerThreshold: hidden.depthRayAngleInnerThreshold
                    )
                )
            } else {
                halationInput = image
            }
            let halationPlate = extractHighlightPlate(
                from: halationInput,
                threshold: params.halationThreshold,
                knee: params.halationSoftKnee,
                tintColor: Self.halationColor(for: params.halationHue)
            )
            halationImage = buildMipBlurComposite(
                from: halationPlate,
                radius: params.halationRadius,
                levelCount: Self.halationMipLevels,
                spreadMultiplier: 1.0 + max(params.halationSpread, 0) / Self.halationSpreadDivisor,
                useTentResampling: true
            )
        } else {
            halationImage = black
        }

        let diffusionImage: CIImage
        if params.diffusion > 0.0001 {
            let diffusionInput: CIImage
            if let depthCI {
                diffusionInput = FilmtoneDepthPrefilter.apply(
                    to: image,
                    depth: depthCI,
                    imageExtent: extent,
                    optics: cameraOpticsDTO,
                    params: .init(
                        variant: .mist,
                        depthGain: hidden.depthMistGain,
                        rayAngleGain: hidden.depthMistRayAngleGain,
                        rayAngleGamma: hidden.depthRayAngleGamma,
                        rayAngleInnerThreshold: hidden.depthRayAngleInnerThreshold
                    )
                )
            } else {
                diffusionInput = image
            }
            diffusionImage = buildMipBlurComposite(
                from: diffusionInput,
                radius: 0.9,
                levelCount: Self.diffusionMipLevels,
                spreadMultiplier: 1.15,
                useTentResampling: true
            )
        } else {
            diffusionImage = black
        }

        if let depthStart {
            let elapsed = Date().timeIntervalSince(depthStart) * 1000.0
            self.depthPrefilterMs = (self.depthPrefilterMs ?? 0) + elapsed
        }

        guard
            params.bloomStrength > 0.0001 ||
            params.halationIntensity > 0.0001 ||
            params.diffusion > 0.0001
        else {
            return image
        }

        guard let kernel = OpticalKernels.glowComposite else {
            return image
        }

        return kernel.apply(extent: extent, arguments: [
            image,
            bloomImage,
            halationImage,
            diffusionImage,
            params.bloomStrength,
            params.halationIntensity,
            params.diffusion,
            Self.diffusionCompositeBase,
        ]) ?? image
    }

    /// Build the Metal vignette parameter struct from the same inputs
    /// `applyVignetteStage` would consume. Returns nil when the CI path
    /// would also no-op (intensity below threshold), so caller can decide
    /// whether to chain the vignette pass at all.
    private func vignetteFrameParams(
        image: CIImage,
        params: Phase0ParamsDTO
    ) -> FilmtoneMetalOpticsRenderer.VignetteFrameParams? {
        guard params.vignette > 0.0001 else {
            return nil
        }
        let optics = request.sourceProbe?.cameraOptics
        let resolved = FilmtoneRayAngleOptics.resolve(
            optics: optics,
            imageWidth: Double(image.extent.width),
            imageHeight: Double(image.extent.height)
        )
        let opticsCIVector = FilmtoneRayAngleOptics.kernelArgs(
            resolved: resolved,
            imageWidth: Double(image.extent.width),
            imageHeight: Double(image.extent.height)
        )
        let opticsPack = SIMD3<Float>(
            Float(opticsCIVector.x),
            Float(opticsCIVector.y),
            Float(opticsCIVector.z)
        )
        let applyMask: Float = (optics?.source == "metadata") ? 1.0 : 0.0
        let gamma = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleGamma
        let innerThreshold = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleInnerThreshold
        return FilmtoneMetalOpticsRenderer.VignetteFrameParams(
            intensity: params.vignette,
            opticsPack: opticsPack,
            applyMask: applyMask,
            gamma: gamma,
            innerThreshold: innerThreshold
        )
    }

    private func applyVignetteStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        // Phase 2 段階 1: when the Metal optics chain absorbed the vignette
        // pass for this frame, the CI vignette is already represented in
        // `image` and re-applying would double the falloff.
        if metalVignetteAppliedThisFrame {
            return image
        }
        guard params.vignette > 0.0001 else {
            return image
        }
        guard let kernel = OpticalKernels.vignette else {
            return image
        }

        let optics = request.sourceProbe?.cameraOptics
        let resolved = FilmtoneRayAngleOptics.resolve(
            optics: optics,
            imageWidth: Double(image.extent.width),
            imageHeight: Double(image.extent.height)
        )
        let opticsPack = FilmtoneRayAngleOptics.kernelArgs(
            resolved: resolved,
            imageWidth: Double(image.extent.width),
            imageHeight: Double(image.extent.height)
        )
        // Mask only activates on trustworthy lens metadata — `"assumed"` /
        // nil / `"fallback65"` sources keep vignette byte-identical with
        // pre-Stream-2 output. Gamma / inner come from the shared contract
        // defaults so the ray-angle math stays locked to SSOT rather than
        // Swift-side constants.
        let applyMask: Double = (optics?.source == "metadata") ? 1.0 : 0.0
        let gamma = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleGamma
        let innerThreshold = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleInnerThreshold

        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.vignette,
            Self.extentOriginVector(for: image.extent),
            Self.extentSizeVector(for: image.extent),
            gamma,
            innerThreshold,
            opticsPack,
            applyMask,
        ]) ?? image
    }

    private func applyGrainStage(
        to image: CIImage,
        params: Phase0ParamsDTO,
        timeSeconds: Double
    ) -> CIImage {
        let grainIntensity = max(0, min(FilmtonePhase0Generated.grainIntensityMax, params.grainIntensity))
        guard grainIntensity > 0.0001 else {
            return image
        }
        guard let kernel = OpticalKernels.grain else {
            return image
        }
        let normalizedTime = timeSeconds.isFinite ? max(timeSeconds, 0) : 0
        return kernel.apply(extent: image.extent, arguments: [
            image,
            grainIntensity,
            params.grainRadialMix,
            params.grainSize,
            normalizedTime,
            sourceSeed,
            Self.extentOriginVector(for: image.extent),
            Self.extentSizeVector(for: image.extent),
        ]) ?? image
    }

    private func applyCreativeLutStage(to image: CIImage) -> CIImage {
        guard let preparedCreativeLut else {
            return image
        }
        return applyLut(preparedCreativeLut, to: image)
    }

    private func applyPrintStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        let epsilon = 0.0001
        guard
            params.printContrast > epsilon ||
            abs(params.cyan) > epsilon ||
            abs(params.magenta) > epsilon ||
            abs(params.yellow) > epsilon
        else {
            return image
        }

        guard let kernel = OpticalKernels.printStage else {
            return image
        }

        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.printContrast,
            params.cyan,
            params.magenta,
            params.yellow,
        ]) ?? image
    }

    private func applyLut(_ lut: PreparedLut, to image: CIImage) -> CIImage {
        let lutImage = image.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": lut.size,
            "inputCubeData": lut.cubeData,
            "inputColorSpace": outputColorSpace,
        ])

        guard lut.intensity < 0.999 else {
            return lutImage
        }

        let alphaAdjusted = lutImage.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: lut.intensity),
        ])
        return alphaAdjusted
            .applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: image,
            ])
            .cropped(to: image.extent)
    }

    private func extractHighlightPlate(
        from image: CIImage,
        threshold: Double,
        knee: Double,
        tintColor: CIColor
    ) -> CIImage {
        guard let kernel = OpticalKernels.softKneeHighlight else {
            return Self.blackImage(for: image.extent)
        }

        return kernel.apply(extent: image.extent, arguments: [
            image,
            Self.clamp(threshold),
            Self.clamp(knee),
            tintColor,
        ]) ?? Self.blackImage(for: image.extent)
    }

    private func applyRadialRGBShift(_ amount: Double, to image: CIImage) -> CIImage {
        guard let kernel = OpticalKernels.radialRGBSplit else {
            return image
        }

        let padding = CGFloat(max(4.0, abs(amount) * max(image.extent.width, image.extent.height)))
        return kernel.apply(
            extent: image.extent,
            roiCallback: { _, rect in
                rect.insetBy(dx: -padding, dy: -padding)
            },
            arguments: [
                image,
                amount,
                Self.extentOriginVector(for: image.extent),
                Self.extentSizeVector(for: image.extent),
            ]
        ) ?? image
    }

    private func applyEdgeSoftness(
        to image: CIImage,
        aberrationSoften: Double,
        lensSoftness: Double
    ) -> CIImage {
        let lensDrive = pow(Self.clamp(lensSoftness), 0.78)
        let aberrationDrive = pow(
            Self.clamp(aberrationSoften / Self.aberrationEdgeSoftenMax),
            0.82
        )
        let blurRadius = min(
            Self.lerp(
                Self.aberrationBlurRadiusMin,
                Self.aberrationBlurRadiusMax,
                aberrationDrive
            ) + (lensDrive * Self.lensSoftnessBlurBoost),
            Self.aberrationBlurRadiusCap
        )
        guard blurRadius > 0.0001, let kernel = OpticalKernels.edgeSoftnessBlend else {
            return image
        }

        let blurred = image
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: blurRadius,
            ])
            .cropped(to: image.extent)

        return kernel.apply(
            extent: image.extent,
            roiCallback: { _, rect in rect },
            arguments: [
                image,
                blurred,
                Self.clamp(aberrationSoften),
                Self.clamp(lensSoftness),
                Self.extentOriginVector(for: image.extent),
                Self.extentSizeVector(for: image.extent),
            ]
        ) ?? image
    }

    private func buildMipBlurComposite(
        from image: CIImage,
        radius: Double,
        levelCount: Int,
        spreadMultiplier: Double,
        useTentResampling: Bool = false
    ) -> CIImage {
        let extent = image.extent.integral
        guard levelCount > 0 else {
            return Self.blackImage(for: extent)
        }

        var mips = Self.buildMipPyramid(
            from: image,
            levelCount: levelCount,
            initialScale: Self.glowBaseScale / max(spreadMultiplier, 0.0001),
            useTentResampling: useTentResampling
        )
        guard !mips.isEmpty else {
            return Self.blackImage(for: extent)
        }

        let weights = Self.computeMipWeights(radius: Self.clamp(radius), levels: mips.count)
        if mips.count > 1 {
            for index in stride(from: mips.count - 2, through: 0, by: -1) {
                let lowRes = mips[index + 1]
                let highRes = mips[index]
                let restored = useTentResampling
                    ? Self.tentUpsampledImage(lowRes, to: highRes.extent)
                    : Self.upsampledImage(lowRes, to: highRes.extent)
                let weighted = Self.weightedImage(restored, weight: weights[index + 1])
                mips[index] = Self.addImages(weighted, highRes).cropped(to: highRes.extent)
            }
        }

        let output = useTentResampling
            ? Self.tentUpsampledImage(mips[0], to: extent)
            : Self.upsampledImage(mips[0], to: extent)
        return output.cropped(to: extent)
    }

    private static func buildMipPyramid(
        from image: CIImage,
        levelCount: Int,
        initialScale: Double,
        useTentResampling: Bool = false
    ) -> [CIImage] {
        guard levelCount > 0 else {
            return []
        }

        var mips: [CIImage] = []
        var current = useTentResampling
            ? tentDownsampledImage(image, scale: initialScale)
            : downsampledImage(image, scale: initialScale)
        mips.append(current)

        guard levelCount > 1 else {
            return mips
        }

        for _ in 1..<levelCount {
            current = useTentResampling
                ? tentDownsampledImage(current, scale: 0.5)
                : downsampledImage(current, scale: 0.5)
            mips.append(current)
        }

        return mips
    }

    private static func downsampledImage(_ image: CIImage, scale: Double) -> CIImage {
        let safeScale = min(1.0, max(scale, 0.0001))
        let targetSize = CGSize(
            width: max(1.0, round(image.extent.width * safeScale)),
            height: max(1.0, round(image.extent.height * safeScale))
        )
        let scaled = scaledImage(image, scale: safeScale)
        return scaled.cropped(to: CGRect(origin: .zero, size: targetSize))
    }

    private static func upsampledImage(_ image: CIImage, to extent: CGRect) -> CIImage {
        guard image.extent.width > 0.0001, image.extent.height > 0.0001 else {
            return blackImage(for: extent)
        }

        let scale = extent.width / image.extent.width
        let upsampled = scaledImage(image, scale: scale).cropped(to: extent)
        guard scale > 1.0001, glowUpsampleBlurRadius > 0.0001 else {
            return upsampled
        }

        return upsampled
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: glowUpsampleBlurRadius,
            ])
            .cropped(to: extent)
    }

    private static func tentDownsampledImage(_ image: CIImage, scale: Double) -> CIImage {
        let safeScale = min(1.0, max(scale, 0.0001))
        let sourceExtent = image.extent.integral
        let targetSize = CGSize(
            width: max(1.0, round(sourceExtent.width * safeScale)),
            height: max(1.0, round(sourceExtent.height * safeScale))
        )
        let targetExtent = CGRect(origin: .zero, size: targetSize)

        guard let kernel = OpticalKernels.tentDownsample else {
            return downsampledImage(image, scale: scale)
        }

        return kernel.apply(
            extent: targetExtent,
            roiCallback: { _, _ in sourceExtent },
            arguments: [
                image,
                extentOriginVector(for: sourceExtent),
                extentSizeVector(for: sourceExtent),
                extentOriginVector(for: targetExtent),
                CIVector(
                    x: sourceExtent.width / max(targetExtent.width, 1.0),
                    y: sourceExtent.height / max(targetExtent.height, 1.0)
                ),
            ]
        ) ?? downsampledImage(image, scale: scale)
    }

    private static func tentUpsampledImage(_ image: CIImage, to extent: CGRect) -> CIImage {
        guard image.extent.width > 0.0001, image.extent.height > 0.0001 else {
            return blackImage(for: extent)
        }
        let sourceExtent = image.extent.integral
        let targetExtent = extent.integral

        guard let kernel = OpticalKernels.tentUpsample else {
            return upsampledImage(image, to: extent)
        }

        return kernel.apply(
            extent: targetExtent,
            roiCallback: { _, _ in sourceExtent },
            arguments: [
                image,
                extentOriginVector(for: sourceExtent),
                extentSizeVector(for: sourceExtent),
                extentOriginVector(for: targetExtent),
                CIVector(
                    x: sourceExtent.width / max(targetExtent.width, 1.0),
                    y: sourceExtent.height / max(targetExtent.height, 1.0)
                ),
            ]
        ) ?? upsampledImage(image, to: extent)
    }

    private static func scaledImage(_ image: CIImage, scale: Double) -> CIImage {
        guard abs(scale - 1.0) > 0.0001 else {
            return image
        }
        return image.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: scale,
            kCIInputAspectRatioKey: 1.0,
        ])
    }

    private static func weightedImage(_ image: CIImage, weight: Double) -> CIImage {
        guard weight > 0 else {
            return blackImage(for: image.extent)
        }
        guard abs(weight - 1.0) > 0.0001 else {
            return image
        }
        let vector = CIVector(x: weight, y: 0, z: 0, w: 0)
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        return image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": vector,
            "inputGVector": CIVector(x: 0, y: weight, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: weight, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": zero,
        ])
    }

    private static func addImages(_ foreground: CIImage, _ background: CIImage) -> CIImage {
        foreground
            .applyingFilter("CIAdditionCompositing", parameters: [
                kCIInputBackgroundImageKey: background,
            ])
            .cropped(to: background.extent)
    }

    private static func blackImage(for extent: CGRect) -> CIImage {
        CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1)).cropped(to: extent)
    }

    private static func extentOriginVector(for extent: CGRect) -> CIVector {
        CIVector(x: extent.origin.x, y: extent.origin.y)
    }

    private static func extentSizeVector(for extent: CGRect) -> CIVector {
        CIVector(x: extent.width, y: extent.height)
    }

    private static func computeMipWeights(radius: Double, levels: Int) -> [Double] {
        (0..<levels).map { index in
            let t = Double(index) / Double(max(levels - 1, 1))
            let base = exp(-3.0 * (1.0 - radius) * t)
            let wide = exp(-0.5 * radius * (1.0 - t))
            return (base * (1.0 - radius)) + (wide * radius)
        }
    }

    private static func halationColor(for hue: Double) -> CIColor {
        let t = clamp(hue / 100.0)
        let red = (0xe8 + ((0xc8 - 0xe8) * t)) / 255.0
        let green = (0x10 + ((0x60 - 0x10) * t)) / 255.0
        let blue = (0x20 + ((0x10 - 0x20) * t)) / 255.0
        return CIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    private static func aberrationEdgeSoften(for normalizedRgbShift: Double) -> Double {
        let normalized = clamp(normalizedRgbShift)
        guard normalized > 0.0001 else {
            return 0
        }

        let linear = normalized * (aberrationEdgeSoftenScale * FilmtonePhase0Generated.rgbShiftMax)
        let boosted = pow(normalized, aberrationEdgeSoftenCurve) * aberrationEdgeSoftenMax
        return min(aberrationEdgeSoftenMax, max(linear, boosted))
    }

    private static func makeStableSourceSeed(from string: String) -> Double {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Double(hash % 8_192)
    }

    private static func clamp(_ value: Double, min minValue: Double = 0, max maxValue: Double = 1) -> Double {
        min(max(value, minValue), maxValue)
    }

    private static func lerp(_ start: Double, _ end: Double, _ t: Double) -> Double {
        start + ((end - start) * t)
    }

    private func appendVideoSample(
        _ sampleBuffer: CMSampleBuffer,
        videoInput: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        videoTrack: AVAssetTrack,
        outputSize: CGSize,
        outputPresentationTime: CMTime? = nil,
        renderTimeSeconds: Double? = nil,
        waitForReady: Bool = true
    ) throws -> Bool {
        try autoreleasepool { () throws -> Bool in
            if waitForReady {
                try performanceMetrics.measure(.waitEncoder) {
                    try signposter.withIntervalSignpost("wait-encoder") {
                        try waitUntilReadyForMoreMediaData(videoInput, writer: writer, reader: reader, label: "video")
                    }
                }
            }

            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return false
            }
            guard let pixelBufferPool = adaptor.pixelBufferPool else {
                throw FilmtoneMediaError.exportFailed("Pixel buffer pool is unavailable.")
            }

            let sourcePresentationTime = Self.validPresentationTime(for: sampleBuffer)
            let outputTime = outputPresentationTime ?? sourcePresentationTime
            let presentationTimeSec = renderTimeSeconds ?? CMTimeGetSeconds(sourcePresentationTime)
            let frameImage = performanceMetrics.measure(.buildGraph) {
                signposter.withIntervalSignpost("build-graph") {
                    renderableImage(
                        from: imageBuffer,
                        transform: videoTrack.preferredTransform,
                        outputSize: outputSize,
                        timeSeconds: presentationTimeSec.isFinite ? presentationTimeSec : 0
                    )
                }
            }

            var renderedBuffer: CVPixelBuffer?
            let creationStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &renderedBuffer)
            guard creationStatus == kCVReturnSuccess, let renderedBuffer else {
                throw FilmtoneMediaError.exportFailed("A render pixel buffer could not be created.")
            }

            performanceMetrics.measure(.render) {
                signposter.withIntervalSignpost("render") {
                    ciContext.render(
                        frameImage,
                        to: renderedBuffer,
                        bounds: CGRect(origin: .zero, size: outputSize),
                        colorSpace: outputColorSpace
                    )
                }
            }
            attachOutputColorMetadata(to: renderedBuffer)

            let appended = performanceMetrics.measure(.append) {
                signposter.withIntervalSignpost("append") {
                    adaptor.append(renderedBuffer, withPresentationTime: outputTime)
                }
            }
            if !appended {
                throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The frame could not be appended.")
            }
            performanceMetrics.recordRenderedFrame()

            return true
        }
    }

    private func appendAudioSample(
        _ sampleBuffer: CMSampleBuffer,
        audioInput: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader,
        waitForReady: Bool = true
    ) throws {
        try autoreleasepool {
            if waitForReady {
                try waitUntilReadyForMoreMediaData(audioInput, writer: writer, reader: reader, label: "audio")
            }

            if !audioInput.append(sampleBuffer) {
                throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "Audio samples could not be appended.")
            }
        }
    }

    // MARK: - v1.3 Phase B video depth helpers

    /// Sync-bridges `VideoDepthSourceService` for the (sync) video export
    /// pipeline. Returns nil when the caller didn't opt in OR the asset has no
    /// depth track AND depth wasn't requested. Throws
    /// `depthUnsupportedForVideoSource` when depth WAS requested but no track
    /// exists, and `depthUnsupportedFormat` when a track exists but the reader
    /// can't be wired (propagated from `VideoDepthSourceService`).
    private func resolveVideoDepthReader(asset: AVAsset) throws -> VideoDepthFrameReader? {
        guard request.depthEnabled ?? false else {
            return nil
        }
        // Defense-in-depth fast-path: skip the asset-side depth track probe and
        // reader bring-up when every depth gain in the active profile is zero.
        // Mirrors `FilmtoneDepthPrefilter.apply`'s own short-circuit at lines
        // 74-80 (`depthGain <= 0 && rayAngleGain <= 0` → input unchanged) and
        // the still-image gating comment at lines 1127-1133 (current contract
        // `hiddenDefaults.depthMistGain == depthGlowGain == 0`). Becomes a
        // meaningful win once D5.5 (CD承認) flips those gains; today it just
        // makes the dark-code path explicit instead of relying on the per-stage
        // prefilter early return.
        let hidden = FilmtonePhase0Generated.hiddenDefaults
        if hidden.depthMistGain == 0 && hidden.depthGlowGain == 0 {
            NSLog("FilmtoneExportSession: video depth track decode skipped (all profile depth gains zero)")
            return nil
        }
        let service = VideoDepthSourceService()
        let semaphore = DispatchSemaphore(value: 0)
        var hasTrack = false
        var probeError: Error?
        Task.detached(priority: .userInitiated) {
            defer { semaphore.signal() }
            hasTrack = await service.hasDepthTrack(in: asset)
        }
        semaphore.wait()
        guard hasTrack else {
            throw FilmtoneMediaError.depthUnsupportedForVideoSource
        }
        var reader: VideoDepthFrameReader?
        let openSemaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            defer { openSemaphore.signal() }
            do {
                reader = try await service.makeReader(for: asset)
            } catch {
                probeError = error
            }
        }
        openSemaphore.wait()
        if let probeError {
            throw probeError
        }
        return reader
    }

    /// Sync-bridges `VideoDepthFrameReader.nextFrame` for the per-frame loop on
    /// `videoQueue`. The result is a tri-state instead of `throws` because
    /// callers want to distinguish "stream ended" from "transient failure" so
    /// they can apply the per-source recovery contract from Phase A.
    private enum VideoDepthFramePullResult {
        case frame((presentationTime: CMTime, depthMap: FilmtoneDepthMap))
        case endOfStream
        case failure(Error)
    }

    private func pullNextVideoDepthFrame(reader: VideoDepthFrameReader) -> VideoDepthFramePullResult {
        let semaphore = DispatchSemaphore(value: 0)
        var pulled: (presentationTime: CMTime, depthMap: FilmtoneDepthMap)?
        var pullError: Error?
        Task.detached(priority: .userInitiated) {
            defer { semaphore.signal() }
            do {
                pulled = try await reader.nextFrame()
            } catch {
                pullError = error
            }
        }
        semaphore.wait()
        if let pullError {
            return .failure(pullError)
        }
        guard let pulled else {
            return .endOfStream
        }
        return .frame(pulled)
    }

    private func finish(writer: AVAssetWriter) throws {
        try checkCancelled()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        let waitResult = semaphore.wait(timeout: .now() + 30)
        if waitResult == .timedOut {
            writer.cancelWriting()
            throw FilmtoneMediaError.exportFailed("The writer did not finish output within the expected time.")
        }

        try checkCancelled()

        guard writer.status == .completed else {
            throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The export did not complete.")
        }
    }

    private static func validPresentationTime(for sampleBuffer: CMSampleBuffer) -> CMTime {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard time.isValid, time.isNumeric else {
            return .zero
        }
        return time
    }

    private static func nonNegativeTime(_ time: CMTime) -> CMTime {
        guard time.isValid, time.isNumeric else {
            return .zero
        }
        return CMTimeCompare(time, .zero) < 0 ? .zero : time
    }

    private static func absoluteSecondsBetween(_ lhs: CMTime, _ rhs: CMTime) -> Double {
        let seconds = abs(CMTimeGetSeconds(CMTimeSubtract(lhs, rhs)))
        return seconds.isFinite ? seconds : Double.greatestFiniteMagnitude
    }

    private func estimatedVideoFrameRate(for track: AVAssetTrack) -> Double {
        if let frameRate = request.sourceProbe?.frameRate, frameRate.isFinite, frameRate > 0 {
            return frameRate
        }
        let nominalFrameRate = Double(track.nominalFrameRate)
        if nominalFrameRate.isFinite, nominalFrameRate > 0 {
            return nominalFrameRate
        }
        return Double(request.output.fps)
    }

    private func renderingProgress(
        presentationTime: CMTime,
        sourceDurationSec: Double
    ) -> Double {
        guard sourceDurationSec.isFinite, sourceDurationSec > 0 else {
            return 0.12
        }
        let presentationSec = CMTimeGetSeconds(presentationTime)
        guard presentationSec.isFinite else {
            return 0.12
        }
        let normalized = min(max(presentationSec / sourceDurationSec, 0), 1)
        return 0.12 + (normalized * 0.74)
    }

    private func makePreviewPosterTime(sourceDurationSec: Double) -> Double {
        guard sourceDurationSec.isFinite, sourceDurationSec > 0 else {
            return 0
        }
        let candidate = sourceDurationSec * 0.25
        return min(max(candidate, 0), sourceDurationSec)
    }

    private func waitUntilReadyForMoreMediaData(
        _ input: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader? = nil,
        label: String
    ) throws {
        let startedWaitingAt = Date()
        while !input.isReadyForMoreMediaData {
            try checkCancelled()

            if let reader {
                switch reader.status {
                case .failed:
                    throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "The reader failed while waiting for media data.")
                case .cancelled:
                    throw FilmtoneMediaError.exportCancelled
                default:
                    break
                }
            }

            switch writer.status {
            case .failed:
                throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The writer failed while waiting for media data.")
            case .cancelled:
                throw FilmtoneMediaError.exportCancelled
            case .completed:
                throw FilmtoneMediaError.exportFailed("The writer completed before all media data was appended.")
            default:
                break
            }

            if Date().timeIntervalSince(startedWaitingAt) >= 15 {
                throw FilmtoneMediaError.exportFailed("The \(label) writer input stopped accepting media data.")
            }

            Thread.sleep(forTimeInterval: 0.002)
        }
    }

    private func checkCancelled() throws {
        if cancelled {
            throw FilmtoneMediaError.exportCancelled
        }
    }

    private func writePreviewImage(_ image: CIImage, preferredName: String) throws -> URL {
        let url = try cacheStore.temporaryPreviewURL(preferredName: preferredName, pathExtension: "jpg")
        try writeJPEGImage(image, to: url)
        return url
    }

    private func writeReferenceAfterImage(
        to url: URL,
        sourceDurationSec: Double?
    ) throws -> Double {
        let asset = AVURLAsset(url: outputURL)
        let assetDuration = CMTimeGetSeconds(asset.duration)
        let duration = assetDuration.isFinite && assetDuration > 0
            ? assetDuration
            : (sourceDurationSec ?? 0)
        let posterTimeSec = makePreviewPosterTime(sourceDurationSec: duration)
        let posterTime = CMTime(
            seconds: posterTimeSec,
            preferredTimescale: 600
        )
        let cgImage = try copyPreviewCGImage(for: asset, at: posterTime)
        try writeJPEGImage(CIImage(cgImage: cgImage), to: url)
        return posterTimeSec
    }

    private func writeJPEGImage(_ image: CIImage, to url: URL) throws {
        guard let data = ciContext.jpegRepresentation(
            of: image,
            colorSpace: outputColorSpace,
            options: [:]
        ) else {
            throw FilmtoneMediaError.exportFailed("JPEG data could not be created.")
        }
        try data.write(to: url, options: .atomic)
    }

    private func loadedSourceImage(at url: URL) -> CIImage? {
        CIImage(contentsOf: url, options: colorPipeline.stillImageOptions())
    }

    private func sourceVideoImage(from imageBuffer: CVPixelBuffer) -> CIImage {
        let options = colorPipeline.sourceImageOptions(
            for: imageBuffer,
            toneMapHDRToSDR: shouldToneMapHDRToSDR(imageBuffer)
        )
        return CIImage(cvPixelBuffer: imageBuffer, options: options)
    }

    private func sourcePreviewVideoImage(from image: CIImage) -> CIImage {
        // AVVideoComposition already provides this image in presentation
        // orientation. Rewrapping its backing pixel buffer drops that transform
        // and makes portrait clips preview as raw landscape frames.
        return image
    }

    private func shouldToneMapHDRToSDR(_ imageBuffer: CVPixelBuffer) -> Bool {
        guard let transferFunction = CVBufferGetAttachment(
            imageBuffer,
            kCVImageBufferTransferFunctionKey,
            nil
        )?.takeUnretainedValue() else {
            return false
        }

        return CFEqual(transferFunction, kCVImageBufferTransferFunction_ITU_R_2100_HLG) ||
            CFEqual(transferFunction, kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ)
    }

    private func attachOutputColorMetadata(to imageBuffer: CVPixelBuffer) {
        colorPipeline.applyOutputMetadata(to: imageBuffer)
    }

    private static func makePreparedLut(from lut: SerializableLutDTO?) -> PreparedLut? {
        guard let lut, lut.size > 1, !lut.data.isEmpty else {
            return nil
        }

        let floatData = rgbaCubeData(from: lut.data, size: lut.size)
        let cubeData = floatData.withUnsafeBufferPointer { pointer in
            Data(buffer: pointer)
        }

        return PreparedLut(
            size: lut.size,
            intensity: lut.intensity,
            cubeData: cubeData
        )
    }

    /// v1.3 Camera Profiles Phase G: build the sidecar provenance block
    /// for the active selection. Returns nil when the selection is `.auto`
    /// AND the probe doesn't resolve to any catalog entry — the legacy
    /// "auto, no source profile" case stays byte-identical to v1.2.
    private static func makeCameraProfileSidecar(
        for selection: CameraProfileSelection?,
        probeColorClass: SourceColorClassDTO?
    ) -> SidecarCameraProfile? {
        switch selection ?? .auto {
        case .auto:
            // Auto with a probe that maps to a catalog entry — record the
            // resolution. Auto without a match returns nil so the v1.2
            // "no profile applied" path keeps producing an empty
            // cameraProfile block.
            guard let entry = FilmtoneSourceProfileCatalog.entry(forColorClass: probeColorClass) else {
                return SidecarCameraProfile(
                    selectionKind: "auto",
                    catalogId: nil,
                    curve: nil,
                    impl: nil,
                    resolvedFromAutoVia: probeColorClass?.rawValue
                )
            }
            return SidecarCameraProfile(
                selectionKind: "auto",
                catalogId: entry.id,
                curve: entry.curve?.rawValue,
                impl: implTag(entry.impl),
                resolvedFromAutoVia: probeColorClass?.rawValue
            )
        case .builtIn(let catalogId):
            guard let entry = FilmtoneSourceProfileCatalog.entry(forCatalogId: catalogId) else {
                return SidecarCameraProfile(
                    selectionKind: "built-in",
                    catalogId: catalogId,
                    curve: nil,
                    impl: nil,
                    resolvedFromAutoVia: nil
                )
            }
            return SidecarCameraProfile(
                selectionKind: "built-in",
                catalogId: entry.id,
                curve: entry.curve?.rawValue,
                impl: implTag(entry.impl),
                resolvedFromAutoVia: nil
            )
        case .userImport:
            return SidecarCameraProfile(
                selectionKind: "user-import",
                catalogId: nil,
                curve: nil,
                impl: nil,
                resolvedFromAutoVia: nil
            )
        }
    }

    private static func implTag(_ impl: SourceProfileImpl) -> String {
        switch impl {
        case .nilProfile:    return "nil-profile"
        case .nativePolicy:  return "native-policy"
        case .synthesized:   return "synthesized"
        case .bundledCube:   return "bundled-cube"
        }
    }

    private static func makeAutomaticInputLut(for policy: SourceInputTransformPolicyDTO?) -> PreparedLut? {
        switch policy?.strategy {
        case .appleLogToRec709:
            return makeAppleLogToRec709Lut(size: 33, rec2020GamutMap: true)
        case .appleLog2ToRec709:
            return makeAppleLogToRec709Lut(size: 33, rec2020GamutMap: true)
        default:
            return nil
        }
    }

    // v1.3 Camera Profiles Phase E: synthesized 33³ cubes (V-Log, S-Log3)
    // are recomputed once per app run and reused across exports. Keyed by
    // a curve identity string so the cache survives multiple exports of
    // the same source profile without rebuilding ~575 KB of cube data.
    private static let synthesizedInputLutCache = NSCache<NSString, NSData>()

    /// v1.3 Camera Profiles Phase E entry point. When `selection` is nil
    /// (legacy callers) or `.auto`, falls back to the existing
    /// `makeAutomaticInputLut` detection path. Otherwise dispatches
    /// through `FilmtoneSourceProfileCatalog`.
    private static func makeActiveInputLut(
        for selection: CameraProfileSelection?,
        probe: SourceProbeDTO?
    ) -> PreparedLut? {
        switch selection ?? .auto {
        case .auto:
            return makeAutomaticInputLut(for: probe?.inputTransformPolicy)
        case .builtIn(let catalogId):
            guard let entry = FilmtoneSourceProfileCatalog.entry(forCatalogId: catalogId) else {
                return nil
            }
            return makeInputLut(forImpl: entry.impl)
        case .userImport:
            // v1.3: a user-imported `.cube` is carried by `request.inputLut`
            // and is consumed by the caller's `makePreparedLut(from:)` path
            // ahead of `makeActiveInputLut`. The `.userImport` selection
            // therefore short-circuits to nil here so the export pipeline
            // does not double-apply.
            return nil
        }
    }

    private static func makeInputLut(forImpl impl: SourceProfileImpl) -> PreparedLut? {
        switch impl {
        case .nilProfile:
            return nil
        case .nativePolicy(let strategy):
            switch strategy {
            case .appleLogToRec709, .appleLog2ToRec709:
                return makeAppleLogToRec709Lut(size: 33, rec2020GamutMap: true)
            default:
                return nil
            }
        case .synthesized(let curve):
            return makeSynthesizedInputLut(curve: curve)
        case .bundledCube:
            // Reserved for v1.4 (e.g. ARRI LogC4 once licensed). v1.3
            // catalog never selects this case; if it ever shows up in v1.3
            // we explicitly fall through to nil rather than silently
            // returning the wrong cube.
            return nil
        }
    }

    private static func makeSynthesizedInputLut(curve: SourceProfileCurve) -> PreparedLut? {
        let cubeSize = 33
        let cacheKey = "synthesized.\(curve.rawValue).\(cubeSize)" as NSString
        if let cached = synthesizedInputLutCache.object(forKey: cacheKey) {
            return PreparedLut(size: cubeSize, intensity: 1, cubeData: cached as Data)
        }
        let rgb: [Float]
        switch curve {
        case .djiDLog:
            rgb = FilmtoneSourceProfileMath.makeDlogToRec709Cube(size: cubeSize)
        case .djiDLogM:
            rgb = FilmtoneSourceProfileMath.makeDlogMToRec709Cube(size: cubeSize)
        case .canonCLog:
            rgb = FilmtoneSourceProfileMath.makeCanonClogToRec709Cube(size: cubeSize)
        case .canonLog3CinemaGamut:
            rgb = FilmtoneSourceProfileMath.makeCanonLog3CineGamutToRec709Cube(size: cubeSize)
        case .panasonicVLog:
            rgb = FilmtoneSourceProfileMath.makeVlogToRec709Cube(size: cubeSize)
        case .sonySLog3:
            rgb = FilmtoneSourceProfileMath.makeSlog3ToRec709Cube(size: cubeSize)
        case .appleLog, .appleLog2:
            // Apple Log curves ride the native path, not synthesized —
            // FilmtoneSourceProfileCatalog ensures `.appleLog*` always
            // arrives here through `nativePolicy`. If the catalog ever
            // mismatches (test fixture mistake), fall through to the
            // existing Apple Log Lut so the pipeline degrades safely.
            return makeAppleLogToRec709Lut(size: cubeSize, rec2020GamutMap: true)
        }
        let cubeData = packRgbToRgbaCubeData(rgb: rgb, size: cubeSize)
        synthesizedInputLutCache.setObject(cubeData as NSData, forKey: cacheKey)
        return PreparedLut(size: cubeSize, intensity: 1, cubeData: cubeData)
    }

    private static func packRgbToRgbaCubeData(rgb: [Float], size: Int) -> Data {
        let count = size * size * size
        precondition(rgb.count == count * 3, "RGB cube data is malformed")
        var rgba = [Float](repeating: 0, count: count * 4)
        for i in 0..<count {
            rgba[i * 4 + 0] = rgb[i * 3 + 0]
            rgba[i * 4 + 1] = rgb[i * 3 + 1]
            rgba[i * 4 + 2] = rgb[i * 3 + 2]
            rgba[i * 4 + 3] = 1
        }
        return rgba.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private static func rgbaCubeData(from data: [Double], size: Int) -> [Float] {
        let expectedRGBCount = size * size * size * 3
        let expectedRGBACount = size * size * size * 4
        if data.count == expectedRGBACount {
            return data.map(Float.init)
        }

        var rgba: [Float] = []
        rgba.reserveCapacity(expectedRGBACount)
        let count = min(data.count, expectedRGBCount)
        var index = 0
        while index < count {
            rgba.append(Float(data[index]))
            rgba.append(Float(index + 1 < count ? data[index + 1] : 0))
            rgba.append(Float(index + 2 < count ? data[index + 2] : 0))
            rgba.append(1)
            index += 3
        }

        while rgba.count < expectedRGBACount {
            rgba.append(0)
            rgba.append(0)
            rgba.append(0)
            rgba.append(1)
        }
        return rgba
    }

    private static func makeAppleLogToRec709Lut(size: Int, rec2020GamutMap: Bool) -> PreparedLut? {
        guard size > 1 else {
            return nil
        }

        var values: [Float] = []
        values.reserveCapacity(size * size * size * 4)
        for blueIndex in 0..<size {
            let blue = Double(blueIndex) / Double(size - 1)
            for greenIndex in 0..<size {
                let green = Double(greenIndex) / Double(size - 1)
                for redIndex in 0..<size {
                    let red = Double(redIndex) / Double(size - 1)
                    let converted = appleLogPixelToRec709(
                        red: red,
                        green: green,
                        blue: blue,
                        rec2020GamutMap: rec2020GamutMap
                    )
                    values.append(Float(converted.red))
                    values.append(Float(converted.green))
                    values.append(Float(converted.blue))
                    values.append(1)
                }
            }
        }

        let cubeData = values.withUnsafeBufferPointer { pointer in
            Data(buffer: pointer)
        }
        return PreparedLut(size: size, intensity: 1, cubeData: cubeData)
    }

    private static func appleLogPixelToRec709(
        red: Double,
        green: Double,
        blue: Double,
        rec2020GamutMap: Bool
    ) -> (red: Double, green: Double, blue: Double) {
        let linearRed = appleLogDecode(red)
        let linearGreen = appleLogDecode(green)
        let linearBlue = appleLogDecode(blue)

        let mapped: (red: Double, green: Double, blue: Double)
        if rec2020GamutMap {
            mapped = rec2020ToRec709(red: linearRed, green: linearGreen, blue: linearBlue)
        } else {
            mapped = (linearRed, linearGreen, linearBlue)
        }

        return (
            rec709Encode(filmtoneSdrShoulder(mapped.red)),
            rec709Encode(filmtoneSdrShoulder(mapped.green)),
            rec709Encode(filmtoneSdrShoulder(mapped.blue))
        )
    }

    // v1.3 Camera Profiles Phase B-1: the four primitives below moved to
    // `FilmtoneSourceProfileMath` so V-Log / S-Log3 (and any future curve)
    // share the identical Filmtone SDR shoulder + Rec.709 encode pair.
    // The thin wrappers here keep call sites in this file (e.g.
    // `appleLogPixelToRec709`) source-stable; the math is byte-identical
    // to the pre-Phase-B-1 implementation.

    @inline(__always)
    private static func appleLogDecode(_ encoded: Double) -> Double {
        FilmtoneSourceProfileMath.appleLogDecode(encoded)
    }

    @inline(__always)
    private static func rec2020ToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        FilmtoneSourceProfileMath.rec2020ToRec709(red: red, green: green, blue: blue)
    }

    @inline(__always)
    private static func filmtoneSdrShoulder(_ linear: Double) -> Double {
        FilmtoneSourceProfileMath.filmtoneSdrShoulder(linear)
    }

    @inline(__always)
    private static func rec709Encode(_ linear: Double) -> Double {
        FilmtoneSourceProfileMath.rec709Encode(linear)
    }

    private func resolvedVideoSourceURL() -> URL {
        // v1.4: routing covers both Speed (preview-grade mezzanine) and Quality
        // (quality-grade mezzanine, only generated for heavy sources via
        // FilmtoneMezzanineRoutePolicy.qualityPrewarmVariant). Quality export
        // prepares eligible heavy-source mezzanines before reaching this
        // routing point; policy-declined light sources remain source-direct.
        // Preview reads via this same function so preview ↔ export bytes
        // remain symmetric within each renderMode.
        guard let mezz = mezzanineService else {
            filmtonePreviewCompositionDebugLog(
                "Mezzanine routing: service unavailable, source-direct"
            )
            return sourceURL
        }

        let depthEnabled = request.depthEnabled ?? false
        let hdrURL = mezz.existingMezzanineURL(
            for: sourceURL,
            variant: .hdr,
            depthEnabled: depthEnabled
        )
        let sdrURL = mezz.existingMezzanineURL(
            for: sourceURL,
            variant: .sdr,
            depthEnabled: depthEnabled
        )
        let qualityHDRURL = mezz.existingMezzanineURL(
            for: sourceURL,
            variant: .qualityHDR,
            depthEnabled: depthEnabled
        )
        let qualitySDRURL = mezz.existingMezzanineURL(
            for: sourceURL,
            variant: .qualitySDR,
            depthEnabled: depthEnabled
        )
        let colorClass = request.sourceProbe?.sourceVideoMetadata?.colorClass
        let selectedVariant = FilmtoneMezzanineRoutePolicy.selectedVariant(
            renderMode: request.renderMode?.rawValue,
            colorClass: colorClass,
            hasHDRMezzanine: hdrURL != nil,
            hasSDRMezzanine: sdrURL != nil,
            hasQualityHDRMezzanine: qualityHDRURL != nil,
            hasQualitySDRMezzanine: qualitySDRURL != nil
        )

        switch selectedVariant {
        case .hdr:
            filmtonePreviewCompositionDebugLog("Mezzanine routing: hdr (Speed)")
            return hdrURL ?? sourceURL
        case .sdr:
            filmtonePreviewCompositionDebugLog("Mezzanine routing: sdr (Speed)")
            return sdrURL ?? sourceURL
        case .qualityHDR:
            filmtonePreviewCompositionDebugLog("Mezzanine routing: qualityHDR")
            return qualityHDRURL ?? sourceURL
        case .qualitySDR:
            filmtonePreviewCompositionDebugLog("Mezzanine routing: qualitySDR")
            return qualitySDRURL ?? sourceURL
        case nil:
            filmtonePreviewCompositionDebugLog(
                "Mezzanine routing: policy declined for \(colorClass?.rawValue ?? "unknown") at \(request.renderMode?.rawValue ?? "unknown"), source-direct"
            )
            return sourceURL
        }
    }

    private func prepareQualityMezzanineForExport(
        progress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws {
        guard (request.renderMode ?? .quality) == .quality,
              let variant = qualityMezzanineVariantForExport()
        else {
            // v1.4: on iOS, FilmtoneMezzanineRoutePolicy.qualityPrewarmVariant
            // returns nil for every source class (HEVC re-encode pre-cost is
            // not recovered by decode-time savings on Apple Silicon). Quality
            // export reads source-direct in this branch.
            return
        }
        guard let mezz = mezzanineService else {
            throw FilmtoneMediaError.exportFailed(
                "Quality mezzanine is required for this heavy source, but the cache service is unavailable."
            )
        }

        let depthEnabled = request.depthEnabled ?? false
        if mezz.existingMezzanineURL(for: sourceURL, variant: variant, depthEnabled: depthEnabled) != nil {
            filmtonePreviewCompositionDebugLog("Quality mezzanine ready before export: \(variant.rawValue)")
            mezzanineGeneratedDuringExport = false
            return
        }

        progress(.init(
            stage: .preflight,
            progress: 0.06,
            currentFrame: nil,
            totalFrames: nil,
            message: "Preparing quality cache"
        ))

        do {
            _ = try mezz.ensureMezzanineBlocking(
                sourceURL: sourceURL,
                variant: variant,
                depthEnabled: depthEnabled
            ) { fraction in
                progress(.init(
                    stage: .preflight,
                    progress: 0.06 + min(0.049, max(0.0, fraction) * 0.049),
                    currentFrame: nil,
                    totalFrames: nil,
                    message: "Preparing quality cache"
                ))
            }
            filmtonePreviewCompositionDebugLog("Quality mezzanine generated for export: \(variant.rawValue)")
            mezzanineGeneratedDuringExport = true
        } catch {
            throw FilmtoneMediaError.exportFailed(
                "Quality mezzanine generation failed for this heavy source (\(variant.rawValue)): \(error.localizedDescription)"
            )
        }
    }

    private func qualityMezzanineVariantForExport() -> ProfileVariant? {
        guard let probe = request.sourceProbe else {
            return MezzanineColorProbe.qualityPrewarmVariant(sourceURL: sourceURL)
        }

        let colorClass = probe.sourceVideoMetadata?.colorClass
        let codecFamily = probe.sourceVideoMetadata?.codecFamily ?? probe.codecFamily
        let estimatedDataRate = estimatedDataRate(from: probe)
        guard let routeVariant = FilmtoneMezzanineRoutePolicy.qualityPrewarmVariant(
            for: colorClass,
            codecFamily: codecFamily,
            estimatedDataRate: estimatedDataRate
        ) else {
            return nil
        }

        switch routeVariant {
        case .qualitySDR:
            return .qualitySDR
        case .qualityHDR:
            return .qualityHDR
        case .sdr, .hdr:
            return nil
        }
    }

    private func estimatedDataRate(from probe: SourceProbeDTO) -> Double? {
        guard let fileSizeBytes = probe.fileSizeBytes,
              let durationSec = probe.durationSec,
              fileSizeBytes > 0,
              durationSec > 0
        else {
            return nil
        }
        return Double(fileSizeBytes) * 8.0 / durationSec
    }

    private static func makeRenderStageProfiler(
        ciContext: CIContext,
        colorSpace: CGColorSpace,
        metrics: FilmtoneExportPerformanceMetrics
    ) -> FilmtoneExportRenderStageProfiler? {
        guard let configuration = FilmtoneExportRenderStageProfiler.Configuration.current() else {
            return nil
        }
        metrics.enableRenderStageProfiling(
            frameStride: configuration.frameStride,
            source: configuration.source
        )
        NSLog(
            "Filmtone export render stage profiler enabled: mode=forced-boundary-render frameStride=%d source=%@",
            configuration.frameStride,
            configuration.source
        )
        return FilmtoneExportRenderStageProfiler(
            configuration: configuration,
            ciContext: ciContext,
            colorSpace: colorSpace,
            metrics: metrics
        )
    }

    static func scaledSize(for track: AVAssetTrack, longEdge: Int) -> CGSize {
        let transformed = track.naturalSize.applying(track.preferredTransform)
        let sourceSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        return scaledSize(for: sourceSize, longEdge: longEdge)
    }

    static func scaledSize(for sourceSize: CGSize, longEdge: Int) -> CGSize {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return CGSize(width: longEdge, height: longEdge)
        }

        let maxEdge = max(sourceSize.width, sourceSize.height)
        let scale = min(CGFloat(longEdge) / maxEdge, 1.0)
        let width = max(2, Int((sourceSize.width * scale).rounded()) / 2 * 2)
        let height = max(2, Int((sourceSize.height * scale).rounded()) / 2 * 2)
        return CGSize(width: width, height: height)
    }
}

private struct CompletedExport {
    let outputSize: CGSize
    let frameCount: Int
    let sourceDurationSec: Double?
    let audioPreserved: Bool
}

private enum FilmtoneExportRenderSubstage: String, CaseIterable {
    case inputLut = "InputLut"
    case baseGrade = "BaseGrade"
    case toneCompression = "ToneCompression"
    case edgeOptics = "EdgeOptics"
    case glowFamily = "GlowFamily"
    case vignette = "Vignette"
    case grain = "Grain"
    case creativeLut = "CreativeLut"
    case printStage = "PrintStage"
    case motion = "Motion"
}

private final class FilmtoneExportRenderStageProfiler {
    struct Configuration {
        let frameStride: Int
        let source: String

        static func current(processInfo: ProcessInfo = .processInfo) -> Configuration? {
            if let argumentConfiguration = fromArguments(processInfo.arguments) {
                return argumentConfiguration
            }
            guard let environmentValue = processInfo.environment[environmentKey] else {
                return nil
            }
            return make(value: environmentValue, source: "env:\(environmentKey)")
        }

        private static let environmentKey = "FILMTONE_EXPORT_RENDER_STAGE_PROFILE"
        private static let argumentPrefix = "--filmtone-export-render-stage-profile"

        private static func fromArguments(_ arguments: [String]) -> Configuration? {
            for (index, argument) in arguments.enumerated() {
                if argument == argumentPrefix {
                    let nextValue = arguments.indices.contains(index + 1)
                        && !arguments[index + 1].hasPrefix("--")
                        ? arguments[index + 1]
                        : nil
                    return make(value: nextValue, source: "argument:\(argumentPrefix)")
                }
                let prefix = "\(argumentPrefix)="
                if argument.hasPrefix(prefix) {
                    let value = String(argument.dropFirst(prefix.count))
                    return make(value: value, source: "argument:\(argumentPrefix)")
                }
            }
            return nil
        }

        private static func make(value: String?, source: String) -> Configuration? {
            let normalized = (value ?? "1")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if normalized.isEmpty || normalized == "1" || normalized == "true" || normalized == "yes" || normalized == "on" {
                return Configuration(frameStride: 1, source: source)
            }
            if normalized == "0" || normalized == "false" || normalized == "no" || normalized == "off" {
                return nil
            }
            guard let parsedStride = Int(normalized), parsedStride > 0 else {
                return Configuration(frameStride: 1, source: source)
            }
            return Configuration(frameStride: parsedStride, source: source)
        }
    }

    private let configuration: Configuration
    private let ciContext: CIContext
    private let colorSpace: CGColorSpace
    private let metrics: FilmtoneExportPerformanceMetrics
    private var frameIndex = 0
    private var shouldProfileCurrentFrame = false
    private var scratchBuffer: CVPixelBuffer?
    private var scratchWidth = 0
    private var scratchHeight = 0

    init(
        configuration: Configuration,
        ciContext: CIContext,
        colorSpace: CGColorSpace,
        metrics: FilmtoneExportPerformanceMetrics
    ) {
        self.configuration = configuration
        self.ciContext = ciContext
        self.colorSpace = colorSpace
        self.metrics = metrics
    }

    func beginFrame() {
        frameIndex += 1
        shouldProfileCurrentFrame = (frameIndex - 1) % configuration.frameStride == 0
        if shouldProfileCurrentFrame {
            metrics.recordRenderStageProfiledFrame()
        }
    }

    func forceRender(
        _ stage: FilmtoneExportRenderSubstage,
        image: CIImage,
        outputSize: CGSize
    ) {
        guard shouldProfileCurrentFrame else {
            return
        }
        let width = max(1, Int(outputSize.width.rounded()))
        let height = max(1, Int(outputSize.height.rounded()))
        guard let scratch = scratchPixelBuffer(width: width, height: height) else {
            metrics.recordRenderSubstageFailure(stage)
            return
        }
        let bounds = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        metrics.measureRenderSubstage(stage) {
            ciContext.render(
                image,
                to: scratch,
                bounds: bounds,
                colorSpace: colorSpace
            )
        }
    }

    private func scratchPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        if let scratchBuffer, scratchWidth == width, scratchHeight == height {
            return scratchBuffer
        }
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
        guard status == kCVReturnSuccess, let buffer else {
            return nil
        }
        scratchBuffer = buffer
        scratchWidth = width
        scratchHeight = height
        return buffer
    }
}

private final class FilmtoneExportPerformanceMetrics {
    enum Stage {
        case decode
        case waitEncoder
        case buildGraph
        case render
        case append
        case writerFinish
    }

    private let devicePerformanceAtStart = DevicePerformanceSnapshot.current()
    private let lock = NSLock()
    private var decodeNs: UInt64 = 0
    private var waitEncoderNs: UInt64 = 0
    private var buildGraphNs: UInt64 = 0
    private var renderNs: UInt64 = 0
    private var appendNs: UInt64 = 0
    private var writerFinishNs: UInt64 = 0
    private var mediaPipelineNs: UInt64?
    private var decodeSamples = 0
    private var renderedFrames = 0
    private var renderStageProfileFrameStride: Int?
    private var renderStageProfileSource: String?
    private var renderStageProfiledFrames = 0
    private var renderSubstageNs = Dictionary(
        uniqueKeysWithValues: FilmtoneExportRenderSubstage.allCases.map { ($0, UInt64(0)) }
    )
    private var renderSubstageSamples = Dictionary(
        uniqueKeysWithValues: FilmtoneExportRenderSubstage.allCases.map { ($0, 0) }
    )
    private var renderSubstageFailures = Dictionary(
        uniqueKeysWithValues: FilmtoneExportRenderSubstage.allCases.map { ($0, 0) }
    )

    func measure<T>(_ stage: Stage, _ work: () throws -> T) rethrows -> T {
        let started = DispatchTime.now().uptimeNanoseconds
        defer {
            record(stage, elapsedNs: DispatchTime.now().uptimeNanoseconds - started)
        }
        return try work()
    }

    func recordRenderedFrame() {
        lock.lock()
        renderedFrames += 1
        lock.unlock()
    }

    func enableRenderStageProfiling(frameStride: Int, source: String) {
        lock.lock()
        renderStageProfileFrameStride = frameStride
        renderStageProfileSource = source
        lock.unlock()
    }

    func recordRenderStageProfiledFrame() {
        lock.lock()
        renderStageProfiledFrames += 1
        lock.unlock()
    }

    func measureRenderSubstage(_ stage: FilmtoneExportRenderSubstage, _ work: () -> Void) {
        let started = DispatchTime.now().uptimeNanoseconds
        work()
        let elapsed = DispatchTime.now().uptimeNanoseconds - started
        lock.lock()
        renderSubstageNs[stage, default: 0] += elapsed
        renderSubstageSamples[stage, default: 0] += 1
        lock.unlock()
    }

    func recordRenderSubstageFailure(_ stage: FilmtoneExportRenderSubstage) {
        lock.lock()
        renderSubstageFailures[stage, default: 0] += 1
        lock.unlock()
    }

    func recordMediaPipeline(elapsedSince started: UInt64) {
        let now = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        mediaPipelineNs = now >= started ? now - started : 0
        lock.unlock()
    }

    func sidecarPerformance(
        elapsedMs: Int,
        disabledRenderStages: [String] = [],
        acceleratedRenderStages: [String] = []
    ) -> SidecarPerformance? {
        let snapshot: (
            decodeNs: UInt64,
            waitEncoderNs: UInt64,
            buildGraphNs: UInt64,
            renderNs: UInt64,
            appendNs: UInt64,
            writerFinishNs: UInt64,
            mediaPipelineNs: UInt64?,
            decodeSamples: Int,
            renderedFrames: Int,
            renderStageProfileFrameStride: Int?,
            renderStageProfileSource: String?,
            renderStageProfiledFrames: Int,
            renderSubstages: [RenderSubstageSnapshot]
        )
        lock.lock()
        let renderSubstages = FilmtoneExportRenderSubstage.allCases.map {
            RenderSubstageSnapshot(
                stage: $0,
                elapsedNs: renderSubstageNs[$0, default: 0],
                samples: renderSubstageSamples[$0, default: 0],
                failures: renderSubstageFailures[$0, default: 0]
            )
        }
        snapshot = (
            decodeNs,
            waitEncoderNs,
            buildGraphNs,
            renderNs,
            appendNs,
            writerFinishNs,
            mediaPipelineNs,
            decodeSamples,
            renderedFrames,
            renderStageProfileFrameStride,
            renderStageProfileSource,
            renderStageProfiledFrames,
            renderSubstages
        )
        lock.unlock()

        let hasVideoMetrics = snapshot.renderedFrames > 0 || snapshot.decodeSamples > 0
        guard hasVideoMetrics || snapshot.writerFinishNs > 0 else {
            return nil
        }

        let decodeMs = Self.ms(snapshot.decodeNs)
        let waitEncoderMs = Self.ms(snapshot.waitEncoderNs)
        let buildGraphMs = Self.ms(snapshot.buildGraphNs)
        let renderMs = Self.ms(snapshot.renderNs)
        let appendMs = Self.ms(snapshot.appendNs)
        let writerFinishMs = Self.ms(snapshot.writerFinishNs)
        let mediaPipelineMs = snapshot.mediaPipelineNs.map(Self.ms)
        let mediaPipelineResidualMs = mediaPipelineMs.map {
            max(0, $0 - decodeMs - waitEncoderMs - buildGraphMs - renderMs - appendMs)
        }
        let avgRenderMsPerFrame = snapshot.renderedFrames > 0
            ? renderMs / Double(snapshot.renderedFrames)
            : nil
        let renderShareOfExport = elapsedMs > 0
            ? renderMs / Double(elapsedMs)
            : nil
        let renderShareOfMediaPipeline = mediaPipelineMs.flatMap { value in
            value > 0 ? renderMs / value : nil
        }
        let renderStageProfile = Self.makeRenderStageProfile(
            frameStride: snapshot.renderStageProfileFrameStride,
            source: snapshot.renderStageProfileSource,
            sampledFrames: snapshot.renderStageProfiledFrames,
            totalFrames: snapshot.renderedFrames,
            substages: snapshot.renderSubstages
        )
        let devicePerformanceAtEnd = DevicePerformanceSnapshot.current()

        return SidecarPerformance(
            exportElapsedMs: elapsedMs,
            mediaPipelineMs: mediaPipelineMs,
            decodeMs: decodeMs,
            decodeSamples: snapshot.decodeSamples,
            waitEncoderMs: waitEncoderMs,
            buildGraphMs: buildGraphMs,
            renderMs: renderMs,
            appendMs: appendMs,
            writerFinishMs: writerFinishMs,
            mediaPipelineResidualMs: mediaPipelineResidualMs,
            renderedFrames: snapshot.renderedFrames,
            avgRenderMsPerFrame: avgRenderMsPerFrame,
            renderShareOfExport: renderShareOfExport,
            renderShareOfMediaPipeline: renderShareOfMediaPipeline,
            thermalStateAtStart: devicePerformanceAtStart.thermalState,
            thermalStateAtEnd: devicePerformanceAtEnd.thermalState,
            lowPowerModeEnabledAtStart: devicePerformanceAtStart.lowPowerModeEnabled,
            lowPowerModeEnabledAtEnd: devicePerformanceAtEnd.lowPowerModeEnabled,
            processorCount: devicePerformanceAtStart.processorCount,
            activeProcessorCountAtStart: devicePerformanceAtStart.activeProcessorCount,
            activeProcessorCountAtEnd: devicePerformanceAtEnd.activeProcessorCount,
            physicalMemoryBytes: devicePerformanceAtStart.physicalMemoryBytes,
            disabledRenderStages: disabledRenderStages.isEmpty ? nil : disabledRenderStages,
            acceleratedRenderStages: acceleratedRenderStages.isEmpty ? nil : acceleratedRenderStages,
            renderStageProfile: renderStageProfile
        )
    }

    private func record(_ stage: Stage, elapsedNs: UInt64) {
        lock.lock()
        switch stage {
        case .decode:
            decodeNs += elapsedNs
            decodeSamples += 1
        case .waitEncoder:
            waitEncoderNs += elapsedNs
        case .buildGraph:
            buildGraphNs += elapsedNs
        case .render:
            renderNs += elapsedNs
        case .append:
            appendNs += elapsedNs
        case .writerFinish:
            writerFinishNs += elapsedNs
        }
        lock.unlock()
    }

    private struct RenderSubstageSnapshot {
        let stage: FilmtoneExportRenderSubstage
        let elapsedNs: UInt64
        let samples: Int
        let failures: Int
    }

    private struct DevicePerformanceSnapshot {
        let thermalState: String
        let lowPowerModeEnabled: Bool
        let processorCount: Int
        let activeProcessorCount: Int
        let physicalMemoryBytes: UInt64

        static func current(processInfo: ProcessInfo = .processInfo) -> DevicePerformanceSnapshot {
            DevicePerformanceSnapshot(
                thermalState: thermalStateLabel(processInfo.thermalState),
                lowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
                processorCount: processInfo.processorCount,
                activeProcessorCount: processInfo.activeProcessorCount,
                physicalMemoryBytes: processInfo.physicalMemory
            )
        }

        private static func thermalStateLabel(_ state: ProcessInfo.ThermalState) -> String {
            switch state {
            case .nominal:
                return "nominal"
            case .fair:
                return "fair"
            case .serious:
                return "serious"
            case .critical:
                return "critical"
            @unknown default:
                return "unknown"
            }
        }
    }

    private static func makeRenderStageProfile(
        frameStride: Int?,
        source: String?,
        sampledFrames: Int,
        totalFrames: Int,
        substages: [RenderSubstageSnapshot]
    ) -> SidecarRenderStageProfile? {
        guard let frameStride, let source else {
            return nil
        }

        var previousCumulativeMs: Double?
        var previousCumulativeAvgMs: Double?
        var previousEstimatedCumulativeMs: Double?
        let stages = substages.map { substage -> SidecarRenderStageMetric in
            let cumulativeMs = ms(substage.elapsedNs)
            let cumulativeAvgMs = substage.samples > 0
                ? cumulativeMs / Double(substage.samples)
                : nil
            let estimatedCumulativeMs = cumulativeAvgMs.map { $0 * Double(totalFrames) }
            let incrementalMs = previousCumulativeMs.map { cumulativeMs - $0 }
            let incrementalAvgMs = cumulativeAvgMs.flatMap { currentAvg in
                previousCumulativeAvgMs.map { currentAvg - $0 }
            }
            let estimatedIncrementalMs = estimatedCumulativeMs.flatMap { currentEstimated in
                previousEstimatedCumulativeMs.map { currentEstimated - $0 }
            }

            previousCumulativeMs = cumulativeMs
            previousCumulativeAvgMs = cumulativeAvgMs
            previousEstimatedCumulativeMs = estimatedCumulativeMs

            return SidecarRenderStageMetric(
                stage: substage.stage.rawValue,
                samples: substage.samples,
                failures: substage.failures,
                cumulativeMs: cumulativeMs,
                cumulativeAvgMsPerSample: cumulativeAvgMs,
                estimatedCumulativeMs: estimatedCumulativeMs,
                incrementalMsFromPreviousStage: incrementalMs,
                incrementalAvgMsPerSample: incrementalAvgMs,
                estimatedIncrementalMs: estimatedIncrementalMs
            )
        }

        return SidecarRenderStageProfile(
            mode: "forced-boundary-render",
            source: source,
            frameStride: frameStride,
            sampledFrames: sampledFrames,
            totalFrames: totalFrames,
            forcedRenderMs: substages.reduce(0) { $0 + ms($1.elapsedNs) },
            stages: stages
        )
    }

    private static func ms(_ ns: UInt64) -> Double {
        Double(ns) / 1_000_000.0
    }
}

final class FilmtoneSharedGradeProcessor {
    private let session: FilmtoneExportSession
    private lazy var motionBlurAccumulator = session.makeMotionBlurAccumulator()

    init(session: FilmtoneExportSession) {
        self.session = session
    }

    func makeVideoComposition(
        asset: AVAsset,
        videoTrack _: AVAssetTrack,
        outputSize: CGSize
    ) -> AVMutableVideoComposition {
        let composition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { [session] request in
                do {
                    let timeSeconds = CMTimeGetSeconds(request.compositionTime)
                    let processed = try session.renderablePreviewVideoImage(
                        from: request.sourceImage,
                        outputSize: outputSize,
                        timeSeconds: timeSeconds.isFinite ? timeSeconds : 0,
                        motionAccumulator: self.motionBlurAccumulator
                    )
                    request.finish(with: processed, context: session.ciContext)
                } catch {
                    filmtonePreviewCompositionDebugLog(
                        "live composition frame failed at \(CMTimeGetSeconds(request.compositionTime))s: \(error.localizedDescription)"
                    )
                    request.finish(with: error)
                }
            }
        )
        composition.renderSize = outputSize
        composition.frameDuration = CMTime(
            value: 1,
            timescale: CMTimeScale(max(1, session.outputFrameRate))
        )
        session.colorPipeline.applyOutputMetadata(to: composition)
        return composition
    }
}

private func filmtonePreviewCompositionDebugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("[FilmtonePreview][Composition] \(message())")
    #endif
}

extension ISO8601DateFormatter {
    /// Shared formatter used by the export sidecar writer. Configured to emit
    /// millisecond-precision UTC stamps (e.g. `2026-04-24T12:00:00.000Z`).
    static let filmtoneSidecar: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct PreparedLut {
    let size: Int
    let intensity: Double
    let cubeData: Data
}

fileprivate final class FilmtoneMotionBlurAccumulator {
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

private enum OpticalKernels {
    static let baseGrade = CIColorKernel(source: """
kernel vec4 baseGrade(__sample image, float exposure, float contrast, float saturation, float temperature, float tint, float fade) {
    vec4 color = image;
    color.rgb *= pow(2.0, exposure);
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    color.rgb = mix(vec3(luma), color.rgb, saturation);
    color.r += temperature * 0.1;
    color.b -= temperature * 0.1;
    color.r += tint * 0.05;
    color.g -= tint * 0.08;
    color.b += tint * 0.05;
    color.rgb = color.rgb + fade * (1.0 - color.rgb);
    return color;
}
""")

    // v2 (presetVersion="v2"): film-aware tonal grade.
    //   1) Contrast: 3-piece curve (toe smoothstep / linear mid / shoulder
    //      smoothstep) — film density-style separation, no Reinhard mush.
    //   2) Saturation: chroma-scale (luma + chroma * sat) — per-channel hue
    //      preserved, no Reinhard hue drift.
    //   3) Temperature/tint: unchanged from v1.
    //   4) Crosstalk: density-dependent split-tone via shadowHue/shadowTone +
    //      highlightHue/highlightTone — gives shadow/highlight real *color*
    //      (cyan/magenta/amber) instead of muddy white-lift.
    //   5) Fade: shadow-only mask (no highlight bleed) — strong fade only
    //      lifts the bottom of the curve, keeps highlight punch.
    static let baseGradeV2 = CIColorKernel(source: """
kernel vec4 baseGradeV2(__sample image, float exposure, float contrast, float saturation, float temperature, float tint, float fade, float shadowTone, float highlightTone, float shadowHue, float highlightHue) {
    vec4 color = image;

    // 1. Exposure
    color.rgb *= pow(2.0, exposure);

    // 2. Contrast — 3-piece film density curve
    float c = contrast - 1.0;
    vec3 toeMask = vec3(1.0) - smoothstep(vec3(0.0), vec3(0.18), color.rgb);
    vec3 shoulderMask = smoothstep(vec3(0.85), vec3(1.0), color.rgb);
    vec3 linearPart = (color.rgb - vec3(0.5)) * contrast + vec3(0.5);
    vec3 toePart = color.rgb * (1.0 - 0.35 * c);
    vec3 shoulderPart = vec3(1.0) - (vec3(1.0) - color.rgb) * (1.0 - 0.35 * c);
    color.rgb = mix(linearPart, toePart, toeMask);
    color.rgb = mix(color.rgb, shoulderPart, shoulderMask);

    // 3. Saturation — chroma scale (hue-preserving)
    float lumaSat = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 chroma = color.rgb - vec3(lumaSat);
    color.rgb = vec3(lumaSat) + chroma * saturation;

    // 4. Temperature / Tint
    color.r += temperature * 0.1;
    color.b -= temperature * 0.1;
    color.r += tint * 0.05;
    color.g -= tint * 0.08;
    color.b += tint * 0.05;

    // 5. Crosstalk — density-dependent split-tone with hue/tone fields
    float lumaCT = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float shadowMaskCT = 1.0 - smoothstep(0.0, 0.5, lumaCT);
    float highlightMaskCT = smoothstep(0.5, 1.0, lumaCT);
    vec3 shadowChroma = vec3(
        cos(radians(shadowHue)),
        cos(radians(shadowHue - 120.0)),
        cos(radians(shadowHue - 240.0))
    ) * 0.3;
    vec3 highlightChroma = vec3(
        cos(radians(highlightHue)),
        cos(radians(highlightHue - 120.0)),
        cos(radians(highlightHue - 240.0))
    ) * 0.3;
    color.rgb += shadowMaskCT * shadowTone * shadowChroma;
    color.rgb += highlightMaskCT * highlightTone * highlightChroma;

    // 6. Fade — shadow-only (no highlight bleed)
    float lumaFade = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float shadowFadeMask = 1.0 - smoothstep(0.0, 0.4, lumaFade);
    color.rgb = color.rgb + shadowFadeMask * fade * (vec3(1.0) - color.rgb) * 0.6;

    return color;
}
""")

    static let filmCompression = CIColorKernel(source: """
kernel vec4 filmCompression(__sample image, float amount, float range) {
    vec4 color = image;
    if (amount < 0.001) {
        return color;
    }
    float r = clamp(range, 0.0, 1.0);
    float k = mix(5.15, 2.85, r);
    float rangeSoft = smoothstep(0.82, 1.0, r);
    float amt = amount * (1.0 - 0.18 * rangeSoft);
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float x = clamp(k * (luma - 0.5), -5.5, 5.5);
    float s = 1.0 / (1.0 + exp(-x));
    float scale = luma > 0.001 ? mix(luma, s, amt) / luma : 1.0;
    color.rgb = clamp(color.rgb * scale, 0.0, 1.0);
    return color;
}
""")

    // v2 (presetVersion="v2"): luma-only film latitude compression.
    //   - Same v1 sigmoid knee at 0.82 (the wider 0.65 knee in the original
    //     v2 attempt under-compressed mid-range; reverted to 0.82).
    //   - Highlight squeeze above luma=0.7 is luma-only (single scalar applied
    //     uniformly to RGB) — preserves hue. The original v2 used per-channel
    //     `compressed * compressed` quadratic which destroyed hue at strong
    //     contrast. Squeeze magnitude reduced to 0.10 to avoid micro-banding.
    static let filmCompressionV2 = CIColorKernel(source: """
kernel vec4 filmCompressionV2(__sample image, float amount, float range) {
    vec4 color = image;
    if (amount < 0.001) {
        return color;
    }
    float r = clamp(range, 0.0, 1.0);
    float k = mix(5.15, 2.85, r);
    float rangeSoft = smoothstep(0.82, 1.0, r);
    float amt = amount * (1.0 - 0.18 * rangeSoft);
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float x = clamp(k * (luma - 0.5), -5.5, 5.5);
    float sigm = 1.0 / (1.0 + exp(-x));
    float scale = luma > 0.001 ? mix(luma, sigm, amt) / luma : 1.0;
    vec3 compressed = color.rgb * scale;
    float hiMask = smoothstep(0.7, 1.0, luma);
    float squeezeFactor = 1.0 - hiMask * amt * 0.10;
    color.rgb = clamp(compressed * squeezeFactor, 0.0, 1.0);
    return color;
}
""")

    static let printStage = CIColorKernel(source: """
vec3 applyPrintContrast(vec3 rgb, float amount) {
    if (amount < 0.001) {
        return rgb;
    }
    float k = mix(1.0, 5.0, amount);
    vec3 s = 1.0 / (1.0 + exp(-k * (rgb - 0.5)));
    return clamp(mix(rgb, s, amount), 0.0, 1.0);
}

kernel vec4 printStage(__sample image, float printContrast, float cyan, float magenta, float yellow) {
    vec4 color = image;
    float cmyScale = 0.15;
    color.r -= cyan * cmyScale;
    color.g -= magenta * cmyScale;
    color.b -= yellow * cmyScale;
    color.rgb = applyPrintContrast(color.rgb, printContrast);
    return vec4(clamp(color.rgb, 0.0, 1.0), image.a);
    }
""")

    static let motionFeedback = CIColorKernel(source: """
kernel vec4 motionFeedback(__sample currentFrame, __sample previousFrame, float trailIntensity, float hasPrevious) {
    float trail = clamp(trailIntensity, 0.0, 0.95) * clamp(hasPrevious, 0.0, 1.0);
    vec3 rgb = mix(currentFrame.rgb, previousFrame.rgb, trail);
    return vec4(clamp(rgb, 0.0, 1.0), currentFrame.a);
}
""")

    static let motionBlend = CIColorKernel(source: """
kernel vec4 motionBlend(
    __sample frame0,
    __sample frame1,
    __sample frame2,
    __sample frame3,
    __sample frame4,
    __sample frame5,
    __sample frame6,
    __sample frame7,
    float weight0,
    float weight1,
    float weight2,
    float weight3,
    float weight4,
    float weight5,
    float weight6,
    float weight7
) {
    vec4 color = frame0 * weight0
        + frame1 * weight1
        + frame2 * weight2
        + frame3 * weight3
        + frame4 * weight4
        + frame5 * weight5
        + frame6 * weight6
        + frame7 * weight7;
    return vec4(clamp(color.rgb, 0.0, 1.0), clamp(color.a, 0.0, 1.0));
}
""")

    static let softKneeHighlight = CIColorKernel(source: """
kernel vec4 softKneeHighlight(__sample image, float threshold, float knee, __color tintColor) {
    float luma = dot(image.rgb, vec3(0.2126, 0.7152, 0.0722));
    float safeThreshold = max(threshold, 1e-4);
    float safeKnee = max(knee * safeThreshold, 1e-4);
    float t = clamp((luma - threshold + safeKnee) / (2.0 * safeKnee), 0.0, 1.0);
    float contribution = t * t * mix(safeKnee, 1.0, t);
    contribution = max(contribution, max(0.0, luma - threshold));
    return vec4(image.rgb * contribution * tintColor.rgb, image.a);
}
""")

    static let glowComposite = CIColorKernel(source: """
vec3 glowShoulder(vec3 energy) {
    return 1.0 - exp(-max(energy, vec3(0.0)));
}

float glowHeadroom(vec3 baseRgb, float floorValue) {
    float luma = dot(baseRgb, vec3(0.2126, 0.7152, 0.0722));
    return mix(floorValue, 1.0, sqrt(clamp(1.0 - luma, 0.0, 1.0)));
}

kernel vec4 glowComposite(__sample base, __sample bloom, __sample halation, __sample diffusionImage, float bloomStrength, float halationIntensity, float diffusionAmount, float diffusionBase) {
    vec3 baseRgb = base.rgb;
    vec3 result = baseRgb;
    vec3 glowEnergy = bloom.rgb * bloomStrength + halation.rgb * halationIntensity;
    vec3 glow = glowShoulder(glowEnergy) * glowHeadroom(baseRgb, 0.82);
    result = result + min(glow, max(vec3(0.0), vec3(1.0) - result));

    if (diffusionAmount > 0.0) {
        vec3 diffOpacity = glowShoulder(diffusionImage.rgb * diffusionAmount * diffusionBase) * glowHeadroom(baseRgb, 0.88);
        result = result + min(diffOpacity, max(vec3(0.0), vec3(1.0) - result));
    }

    return vec4(clamp(result, 0.0, 1.0), base.a);
}
""")

    // Vignette kernel with optional ray-angle field mask (T3, Stream 2, v1.1).
    //
    // `opticsPack` = vec3(tanHalfFovX, tanHalfFovY, referenceIncidence).
    // `applyMask` is 1.0 only when `cameraOptics.source == "metadata"`;
    // for `"assumed"` / nil / fallback65 sources it stays 0.0.
    //
    // Math note: the mask must modulate the *darkening amount*, not the final
    // pixel multiplier. At the center `mask = 0` (no edge falloff); applying
    // that as a final multiplier would drive the center to black. Instead we
    // fold the mask into `intensity * dist^2` so the center always stays
    // untouched (`vig = 1.0`) and only the edge falloff is scaled by
    // optics-aware weight. When `applyMask = 0`, `effectiveMask = 1.0` and
    // the formula collapses to the original `1 - intensity * dist^2`,
    // byte-identical with pre-Stream-2 output.
    //
    // ── v1.1.1 (Portrait Optics 物理化 / 2026-04-25) ─────────────────────────
    //
    // Planned physicalization (M1 owns the math change; T3 left this comment
    // ahead of the code edit). Three coordinated moves:
    //
    //   1. `dist` becomes pixel-circular instead of UV-isotropic.
    //      Before: `length(uv - 0.5) * 1.414`  (UV circle → pixel ellipse,
    //              portrait gets a vertically stretched falloff).
    //      After:  `length((uv - 0.5) * extentSize) / halfDiag`,
    //              where `halfDiag = length(extentSize * 0.5)`.
    //      Result: corner = 1.0 regardless of aspect, true circular falloff
    //              in pixel space, aspect自動追従.
    //
    //   2. Ray-angle reference incidence becomes **actual-corner reference**.
    //      `opticsPack.z` is currently derived from the fixed 65° HFOV
    //      reference geometry, so portrait input only reaches normalized
    //      ≈ 0.49 at the corner. M1 will have the call site (kernelArgs in
    //      FilmtoneRayAngleOptics) compute `refIncidence` directly from the
    //      *resolved* `tanHalfFovX/Y` so the actual image corner saturates
    //      at mask = 1.0 for any aspect / FOV combination.
    //
    //   3. Center invariance (the v1.1 ray-angle requirement: "image center
    //      must not be darkened") is preserved by construction:
    //          uv = (0.5, 0.5)  ⇒  sensor = 0  ⇒  ray = 0  ⇒  incidence = 0
    //      so `normalized = 0` and `mask = 0` at the center, independent of
    //      the new reference. Edge-only falloff scaling is unchanged.
    //
    // Moving Postcard 哲学的根拠: vignette は「光学中心からの実 pixel 距離」
    // 基準であるべき (UV 比例ではない)。aspect 不依存の真円グラデーションこそ
    // フィルム的真実性に整合し、portrait / landscape どちらでもレンズ収差の
    // 体感が一致する。
    //
    // Desktop divergence (Risks 2): `packages/film-lab-renderer/src/webgpu/
    // shaders/composite.frag.wgsl.ts` および `rayAngleOptics.ts` は Desktop
    // v1.0.x として **frozen**。本物理化は iOS 単独で先行し、Desktop reconcile
    // は別 PR / follow-up issue (life ラベル `creative` `tech`) で扱う。
    // sidecar JSON / DTO (fxPx, fyPx, fovXDeg, fovYDeg) は無変更のため
    // contract verifier は通過する。
    //
    // Implementation owner: **M1 (Phase 2)**. T3 はコメント先行のみで、
    // この時点では数式 (vec2/vec3/float 計算) は一切変更しない。
    static let vignette = CIColorKernel(source: """
kernel vec4 vignette(__sample image, float intensity, vec2 extentOrigin, vec2 extentSize, float rayAngleGamma, float rayAngleInner, vec3 opticsPack, float applyMask) {
    vec4 color = image;
    vec2 uv = (destCoord() - extentOrigin) / extentSize;
    vec2 distPx = (uv - vec2(0.5, 0.5)) * extentSize;
    float halfDiag = length(extentSize * 0.5);
    float dist = length(distPx) / max(halfDiag, 1.0);

    vec2 sensor = (uv - vec2(0.5, 0.5)) * 2.0;
    float rayX = sensor.x * opticsPack.x;
    float rayY = sensor.y * opticsPack.y;
    float viewZ = 1.0 / sqrt(rayX * rayX + rayY * rayY + 1.0);
    float incidence = 1.0 - viewZ;
    float refIncidence = max(opticsPack.z, 1.0e-5);
    float normalized = clamp(incidence / refIncidence, 0.0, 1.0);
    float gammaSafe = max(rayAngleGamma, 0.001);
    float innerSafe = clamp(rayAngleInner, 0.0, 0.8);
    float shaped = pow(normalized, gammaSafe);
    float t = clamp((shaped - innerSafe) / max(1.0 - innerSafe, 1.0e-6), 0.0, 1.0);
    float mask = t * t * (3.0 - 2.0 * t);
    float effectiveMask = mix(1.0, mask, clamp(applyMask, 0.0, 1.0));

    float vig = 1.0 - intensity * dist * dist * effectiveMask;
    color.rgb *= clamp(vig, 0.0, 1.0);
    return color;
}
""")

    // NOTE: aspect 補正は v1.1.1 では vignette / edgeSoftnessBlend のみ pixel-physical 化。grain と radialRGBSplit は v1.2 follow-up（intensity / hue で見た目 dominate しており優先度低い）。
    static let grain = CIColorKernel(source: """
float grainPixelHash(vec2 p, float seed) {
    return fract(sin(dot(p + vec2(seed, seed * 0.73), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

float grainClumpHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grainClumpNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = grainClumpHash(i);
    float b = grainClumpHash(i + vec2(1.0, 0.0));
    float c = grainClumpHash(i + vec2(0.0, 1.0));
    float d = grainClumpHash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

kernel vec4 grain(__sample image, float intensity, float radialMix, float grainSize, float timeSeconds, float sourceSeed, vec2 extentOrigin, vec2 extentSize) {
    vec4 color = image;
    vec2 uv = (destCoord() - extentOrigin) / extentSize;
    float size = clamp(grainSize, 0.0, 1.0);
    vec2 grainDelta = uv - vec2(0.5, 0.5);
    grainDelta.x *= extentSize.x / max(extentSize.y, 1.0);
    float grainRadial = clamp(length(grainDelta) * 2.0, 0.0, 1.0);
    float grainRadialWeight = mix(0.76, 1.42, pow(grainRadial, 1.35));
    float grainRadialEffective = mix(1.0, grainRadialWeight, clamp(radialMix, 0.0, 1.0));

    float grainFrame = floor(max(timeSeconds, 0.0) * 3.0);
    vec2 pixelCoord = uv * extentSize;
    float grainDiameter = mix(1.6, 5.6, pow(size, 0.72));
    vec2 grainCell = floor(pixelCoord / grainDiameter);
    float fineLuma = grainPixelHash(pixelCoord, grainFrame * 1.7 + sourceSeed * 13.0);
    float cellLuma = grainPixelHash(grainCell, grainFrame * 1.7 + sourceSeed * 13.0);
    float lumaGrain = mix(fineLuma, cellLuma, mix(0.28, 0.76, size));
    float chromaR = grainPixelHash(grainCell, grainFrame * 2.3 + 500.0 + sourceSeed * 7.0) * 0.22;
    float chromaB = grainPixelHash(grainCell, grainFrame * 3.1 + 1000.0 + sourceSeed * 5.0) * 0.22;

    float clumpScale = mix(80.0, 20.0, size);
    float clump = grainClumpNoise((uv * extentSize / clumpScale) + vec2(grainFrame * 0.5 + sourceSeed * 0.1, sourceSeed * 0.07));
    float densityMod = mix(1.0, 0.3 + clump * 1.4, size * 0.7);
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float lumaVisibility = mix(1.12, 0.78, smoothstep(0.18, 0.92, luma));

    float weight = intensity * 1.08 * grainRadialEffective * densityMod * lumaVisibility;
    color.r += (lumaGrain + chromaR) * weight;
    color.g += lumaGrain * weight;
    color.b += (lumaGrain + chromaB) * weight;
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    return color;
}
""")

    // NOTE: aspect 補正は v1.1.1 では vignette / edgeSoftnessBlend のみ pixel-physical 化。grain と radialRGBSplit は v1.2 follow-up（intensity / hue で見た目 dominate しており優先度低い）。
    static let radialRGBSplit = CIKernel(source: """
kernel vec4 radialRGBSplit(sampler image, float amount, vec2 extentOrigin, vec2 extentSize) {
    vec2 coord = destCoord();
    vec2 uv = (coord - extentOrigin) / extentSize;
    vec2 delta = uv - vec2(0.5, 0.5);
    delta.x *= extentSize.x / max(extentSize.y, 1.0);
    float radial = clamp(length(delta) * 2.0, 0.0, 1.0);
    float weight = pow(radial, 1.65);
    float amt = amount * weight;
    vec2 dir = normalize(delta + vec2(1e-5, 1e-5));
    vec2 offset = vec2(dir.x * amt * extentSize.x, dir.y * amt * extentSize.y);
    vec4 center = sample(image, samplerTransform(image, coord));
    float r = sample(image, samplerTransform(image, coord + offset)).r;
    float b = sample(image, samplerTransform(image, coord - offset)).b;
    return vec4(r, center.g, b, center.a);
}
""")

    static let tentDownsample = CIKernel(source: """
vec2 mirrorCoord(vec2 coord, vec2 origin, vec2 size) {
    vec2 safeSize = max(size, vec2(1.0, 1.0));
    vec2 uv = (coord - origin) / safeSize;
    vec2 tiled = mod(uv, 2.0);
    vec2 mirroredUv = 1.0 - abs(tiled - 1.0);
    return origin + (mirroredUv * safeSize);
}

vec4 sampleMirror(sampler image, vec2 coord, vec2 origin, vec2 size) {
    return sample(image, samplerTransform(image, mirrorCoord(coord, origin, size)));
}

kernel vec4 tentDownsample(sampler image, vec2 sourceOrigin, vec2 sourceSize, vec2 targetOrigin, vec2 sourceStep) {
    vec2 coord = destCoord();
    vec2 sourceCoord = sourceOrigin + ((coord - targetOrigin) * sourceStep);

    vec4 a = sampleMirror(image, sourceCoord + vec2(-2.0,  2.0), sourceOrigin, sourceSize);
    vec4 b = sampleMirror(image, sourceCoord + vec2( 0.0,  2.0), sourceOrigin, sourceSize);
    vec4 c = sampleMirror(image, sourceCoord + vec2( 2.0,  2.0), sourceOrigin, sourceSize);

    vec4 dd = sampleMirror(image, sourceCoord + vec2(-1.0,  1.0), sourceOrigin, sourceSize);
    vec4 e  = sampleMirror(image, sourceCoord + vec2( 1.0,  1.0), sourceOrigin, sourceSize);

    vec4 f = sampleMirror(image, sourceCoord + vec2(-2.0, 0.0), sourceOrigin, sourceSize);
    vec4 g = sampleMirror(image, sourceCoord, sourceOrigin, sourceSize);
    vec4 h = sampleMirror(image, sourceCoord + vec2( 2.0, 0.0), sourceOrigin, sourceSize);

    vec4 ii = sampleMirror(image, sourceCoord + vec2(-1.0, -1.0), sourceOrigin, sourceSize);
    vec4 j  = sampleMirror(image, sourceCoord + vec2( 1.0, -1.0), sourceOrigin, sourceSize);

    vec4 k = sampleMirror(image, sourceCoord + vec2(-2.0, -2.0), sourceOrigin, sourceSize);
    vec4 l = sampleMirror(image, sourceCoord + vec2( 0.0, -2.0), sourceOrigin, sourceSize);
    vec4 m = sampleMirror(image, sourceCoord + vec2( 2.0, -2.0), sourceOrigin, sourceSize);

    return ((dd + e + ii + j) * 0.125)
         + (g * 0.125)
         + ((a + c + k + m) * 0.03125)
         + ((b + f + h + l) * 0.0625);
}
""")

    static let tentUpsample = CIKernel(source: """
vec2 mirrorCoord(vec2 coord, vec2 origin, vec2 size) {
    vec2 safeSize = max(size, vec2(1.0, 1.0));
    vec2 uv = (coord - origin) / safeSize;
    vec2 tiled = mod(uv, 2.0);
    vec2 mirroredUv = 1.0 - abs(tiled - 1.0);
    return origin + (mirroredUv * safeSize);
}

vec4 sampleMirror(sampler image, vec2 coord, vec2 origin, vec2 size) {
    return sample(image, samplerTransform(image, mirrorCoord(coord, origin, size)));
}

kernel vec4 tentUpsample(sampler image, vec2 sourceOrigin, vec2 sourceSize, vec2 targetOrigin, vec2 sourceStep) {
    vec2 coord = destCoord();
    vec2 sourceCoord = sourceOrigin + ((coord - targetOrigin) * sourceStep);

    vec4 s  = sampleMirror(image, sourceCoord, sourceOrigin, sourceSize);
    vec4 s0 = sampleMirror(image, sourceCoord + vec2(-1.0,  1.0), sourceOrigin, sourceSize);
    vec4 s1 = sampleMirror(image, sourceCoord + vec2( 0.0,  1.0), sourceOrigin, sourceSize);
    vec4 s2 = sampleMirror(image, sourceCoord + vec2( 1.0,  1.0), sourceOrigin, sourceSize);
    vec4 s3 = sampleMirror(image, sourceCoord + vec2(-1.0,  0.0), sourceOrigin, sourceSize);
    vec4 s4 = sampleMirror(image, sourceCoord + vec2( 1.0,  0.0), sourceOrigin, sourceSize);
    vec4 s5 = sampleMirror(image, sourceCoord + vec2(-1.0, -1.0), sourceOrigin, sourceSize);
    vec4 s6 = sampleMirror(image, sourceCoord + vec2( 0.0, -1.0), sourceOrigin, sourceSize);
    vec4 s7 = sampleMirror(image, sourceCoord + vec2( 1.0, -1.0), sourceOrigin, sourceSize);

    vec4 upsampled = (s * 4.0)
                   + ((s1 + s3 + s4 + s6) * 2.0)
                   + (s0 + s2 + s5 + s7);
    return upsampled / 16.0;
}
""")

    // ── edgeSoftnessBlend (v1.1.1 Portrait Optics 物理化 / 2026-04-25) ─────
    //
    // Known bug (現行 line 内 `edgeDelta.x *= extentSize.x / max(extentSize.y, 1.0)`):
    // 横長前提の aspect 補正により、portrait 入力では左右エッジの edgeR が
    // ~0.397 までしか達しない (landscape 左右では 1.0 saturate)。
    // smoothstep(0.25, 1.0, edgeR) のため左右エッジでレンズソフトが
    // 視認困難なレベルまで弱まる。
    //
    // Planned replacement (M1 owner / Phase 2):
    //
    //     vec2 edgePx = (uv - vec2(0.5)) * extentSize;
    //     float halfDiag = length(extentSize * 0.5);
    //     float edgeR = clamp(length(edgePx) / max(halfDiag, 1.0), 0.0, 1.0);
    //
    // Effect:
    //   - corner で常に edgeR = 1.0 (aspect 不依存)
    //   - エッジ中点は短軸 ~0.49 / 長軸 ~0.872、aspect 自動追従
    //   - portrait 左右 / landscape 左右が同等の lensSoft 強度に到達
    //
    // `lensR` (現行 `length(edgeDelta) * 2.0`) も同基準で再導出される予定:
    //
    //     float lensR = clamp(length(edgePx) / max(halfDiag, 1.0), 0.0, 1.0);
    //
    // (スケール係数は M1 で QA 結果を見て微調整。0.5×halfDiag normalize や
    // 元の 2.0 ゲインに相当する別係数になる可能性あり。)
    //
    // Moving Postcard 哲学: 物理的に「光学中心からの実 pixel 距離」基準で
    // レンズ収差 (edge softness, aberration soften, lensSoftness) を
    // 再現する。UV 比例の楕円落ち込みは光学的に意味がない。
    //
    // Desktop divergence: Desktop renderer (composite.frag.wgsl.ts) は
    // v1.0.x frozen。iOS 単独で物理化、reconcile は follow-up issue。
    //
    // Implementation owner: **M1 (Phase 2)**. T3 はコメント先行のみ、
    // 数式に一切手を入れない。
    static let edgeSoftnessBlend = CIKernel(source: """
kernel vec4 edgeSoftnessBlend(sampler sharp, sampler blurred, float aberrationSoften, float lensSoftness, vec2 extentOrigin, vec2 extentSize) {
    vec2 coord = destCoord();
    vec2 uv = (coord - extentOrigin) / extentSize;
    vec2 edgePx = (uv - vec2(0.5, 0.5)) * extentSize;
    float halfDiag = length(extentSize * 0.5);
    float edgeR = clamp(length(edgePx) / max(halfDiag, 1.0), 0.0, 1.0);
    float edgeMask = smoothstep(0.25, 1.0, edgeR);
    float lensR = clamp(length(edgePx) / max(halfDiag, 1.0), 0.0, 1.0);
    float lensW = pow(lensR, 1.52);
    float lensDrive = pow(clamp(lensSoftness, 0.0, 1.0), 0.78);
    float lensWeight = clamp(lensDrive * lensW, 0.0, 1.0);
    float lensMix = lensWeight * 0.72;
    float softenAmt = clamp((aberrationSoften * edgeMask) + (lensMix * edgeMask), 0.0, 1.0);
    vec4 sharpSample = sample(sharp, samplerTransform(sharp, coord));
    vec4 blurSample = sample(blurred, samplerTransform(blurred, coord));
    return mix(sharpSample, blurSample, softenAmt);
}
""")
}
