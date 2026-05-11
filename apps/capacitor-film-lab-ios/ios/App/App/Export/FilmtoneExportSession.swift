import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import FilmLabSwiftCore
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
    /// inside `ExportInputLutBuilder.makeActiveInputLut`, preserving the
    /// pre-Phase-E behavior.
    /// Kept off `Phase0ExportRequestDTO` because it's iOS-side state, not
    /// a value the JS bridge needs to round-trip.
    private let cameraProfileSelection: CameraProfileSelection?
    /// Source-relative marker intent captured in the editor. The export
    /// session only writes it into the sidecar; media pixels and Photos save
    /// remain unchanged.
    private let highlightMarkers: FilmtoneHighlightMarkers?
    /// M14-C (2026-05-09): capture-package master/proxy provenance,
    /// resolved by the caller (typically `FilmtoneEditorStore.export`)
    /// from the M14-A `ExportSourceDecision`. Photos / Files non-
    /// capture edits pass nil → sidecar block omitted. The session
    /// itself does not look this up — keeping the dependency-injection
    /// edge here means `FilmtoneExportSession` stays free of
    /// `FilmtoneCapturePackage` references.
    private let captureProvenance: SidecarCaptureProvenance?
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
    let ciContext: CIContext
    let colorPipeline: FilmtoneColorPipelineContract
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
        cameraProfile: CameraProfileSelection? = nil,
        highlightMarkers: FilmtoneHighlightMarkers? = nil,
        captureProvenance: SidecarCaptureProvenance? = nil
    ) throws {
        self.request = request
        self.sourceURL = sourceURL
        self.cacheStore = cacheStore
        self.mezzanineService = mezzanineService
        self.appliedSavedLook = appliedSavedLook
        self.cameraProfileSelection = cameraProfile
        self.highlightMarkers = highlightMarkers?.isEmpty == false ? highlightMarkers : nil
        self.captureProvenance = captureProvenance
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
        // v1.3 Camera Profiles Phase E: dispatch through
        // `ExportInputLutBuilder.makeActiveInputLut` when the caller passed
        // an explicit `cameraProfile`; legacy (nil) callers fall through to
        // `.auto` inside the builder, so v1.2 behavior stays byte-identical
        // when no profile was selected. A user-imported `request.inputLut`
        // always wins (existing precedence).
        self.preparedInputLut = ExportInputLutBuilder.makePreparedLut(from: request.inputLut)
            ?? ExportInputLutBuilder.makeActiveInputLut(
                for: cameraProfile,
                probe: request.sourceProbe
            )
        let legacyCreativeLut = request.creativeLut ?? request.lut.map {
            SerializableLutDTO(size: $0.size, data: $0.data, intensity: $0.intensity)
        }
        self.preparedCreativeLut = ExportInputLutBuilder.makePreparedLut(from: legacyCreativeLut)
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
    /// once across all entry points (SwiftUI UI, Live Activity intent,
    /// background-task expiration). The operation is idempotent at the
    /// session level (single Bool write), so duplicate invocations from
    /// different entry points are harmless.
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

    func runHighlightReel(
        progress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws -> Phase0ExportResultDTO {
        defer {
            ciContext.clearCaches()
        }
        guard request.sourceKind == .video else {
            throw FilmtoneMediaError.exportFailed("Highlight is available for video sources only.")
        }
        guard let segments = highlightMarkers?.highlightReelSegments(), !segments.isEmpty else {
            throw FilmtoneMediaError.exportFailed("Add at least one highlight marker before creating a Highlight.")
        }

        let startedAt = Date()
        progress(.init(stage: .preflight, progress: 0.03, currentFrame: nil, totalFrames: nil, message: "Preparing Highlight"))
        let result = try exportVideo(
            progress: progress,
            highlightSegments: segments
        )
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000.0)
        let fileSizeBytes = try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        let realtimeRatio: Double?
        if let duration = result.sourceDurationSec, duration > 0 {
            realtimeRatio = Double(elapsedMs) / (duration * 1000.0)
        } else {
            realtimeRatio = nil
        }

        progress(.init(stage: .completed, progress: 1.0, currentFrame: result.frameCount, totalFrames: result.frameCount, message: "Highlight complete"))

        return Phase0ExportResultDTO(
            outputUri: outputURL.absoluteString,
            elapsedMs: elapsedMs,
            outputWidth: Int(result.outputSize.width.rounded()),
            outputHeight: Int(result.outputSize.height.rounded()),
            outputFps: request.output.fps,
            fileSizeBytes: fileSizeBytes,
            realtimeRatio: realtimeRatio,
            audioPreserved: false,
            benchmarkRecord: nil,
            sidecarUri: nil,
            packageFileUris: nil
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
        let cameraProfileBlock: SidecarCameraProfile? = ExportSourceProfileResolver.makeCameraProfileSidecar(
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
            performance: performance,
            highlightMarkers: highlightMarkers,
            captureProvenance: captureProvenance
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
        progress: @escaping (Phase0ExportProgressDTO) -> Void,
        highlightSegments: [FilmtoneHighlightClipSegment]? = nil
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
        let depthReader = try ExportDepthPayloadManager.resolveReader(
            asset: asset,
            depthEnabled: request.depthEnabled ?? false
        )
        defer { depthReader?.cancel() }
        if depthReader != nil {
            videoDepthSourceLabel = "AVDepthDataTrack"
            videoDepthFramesProcessed = 0
            videoDepthDecodeMs = 0
        }

        let sourceDurationSec = CMTimeGetSeconds(asset.duration)
        let highlightTimeline = highlightSegments.flatMap {
            FilmtoneHighlightReelFrameTimeline(
                segments: $0,
                outputFps: request.output.fps
            )
        }
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

        let audioTrack = highlightTimeline == nil && request.output.preserveAudio
            ? asset.tracks(withMediaType: .audio).first
            : nil
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

        let outputFrameCount = highlightTimeline?.totalFrameCount ?? max(
            1,
            Int(floor((sourceDurationSec.isFinite ? sourceDurationSec : 0) * Double(request.output.fps) + 1e-6))
        )
        let outputDurationSec = highlightTimeline?.durationSec
            ?? (sourceDurationSec.isFinite ? sourceDurationSec : 0)
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

        func sourceLookupTime(for frameIndex: Int) -> CMTime {
            guard let highlightTimeline,
                  let sourceTimeSec = highlightTimeline.sourceTimeSec(forOutputFrameIndex: frameIndex) else {
                return outputPresentationTime(for: frameIndex)
            }
            return CMTime(seconds: sourceTimeSec, preferredTimescale: 60_000)
        }

        func sourceSegmentIndex(for frameIndex: Int) -> Int? {
            highlightTimeline?.segmentIndex(forOutputFrameIndex: frameIndex)
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

        func prepareDepthForSourceTime(at sourceLookupTime: CMTime) {
            guard let reader = depthReader else {
                loadedDepthMap = nil
                return
            }
            let lookupTime = CMTimeAdd(sourceLookupTime, sourceTimeOffset ?? .zero)
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
                switch ExportDepthPayloadManager.pullNextFrame(reader: reader) {
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
        var renderedHighlightSegmentIndex: Int?

        func appendOutputFrame(
            using sample: TimedVideoSample,
            at outputPresentationTime: CMTime,
            sourceLookupTime: CMTime,
            sourceSegmentIndex: Int?
        ) throws {
            prepareDepthForSourceTime(at: sourceLookupTime)
            if let sourceSegmentIndex,
               sourceSegmentIndex != renderedHighlightSegmentIndex {
                exportMotionBlurAccumulator.reset()
                renderedHighlightSegmentIndex = sourceSegmentIndex
            }
            let outputTimeSec = CMTimeGetSeconds(outputPresentationTime)
            let sourceTimeSec = CMTimeGetSeconds(sourceLookupTime)
            let appendedFrame = try appendVideoSample(
                sample.buffer,
                videoInput: videoInput,
                writer: writer,
                reader: reader,
                adaptor: adaptor,
                videoTrack: videoTrack,
                outputSize: outputSize,
                outputPresentationTime: outputPresentationTime,
                renderTimeSeconds: sourceTimeSec.isFinite ? sourceTimeSec : (outputTimeSec.isFinite ? outputTimeSec : 0),
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
                    sourceDurationSec: outputDurationSec
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
                        let sourceTime = sourceLookupTime(for: nextOutputFrameIndex)
                        if CMTimeCompare(sourceTime, lookahead.timelineTime) < 0 {
                            guard let previous = previousVideoSample else {
                                throw FilmtoneMediaError.exportFailed("The first decoded video frame was unavailable.")
                            }
                            let previousDelta = Self.absoluteSecondsBetween(
                                previous.timelineTime,
                                sourceTime
                            )
                            let lookaheadDelta = Self.absoluteSecondsBetween(
                                lookahead.timelineTime,
                                sourceTime
                            )
                            let selectedSample = previousDelta <= lookaheadDelta ? previous : lookahead
                            try appendOutputFrame(
                                using: selectedSample,
                                at: outputTime,
                                sourceLookupTime: sourceTime,
                                sourceSegmentIndex: sourceSegmentIndex(for: nextOutputFrameIndex)
                            )
                        } else {
                            previousVideoSample = lookahead
                            lookaheadVideoSample = nil
                        }
                        continue
                    }

                    if sourceReaderExhausted, let previous = previousVideoSample {
                        let outputTime = outputPresentationTime(for: nextOutputFrameIndex)
                        try appendOutputFrame(
                            using: previous,
                            at: outputTime,
                            sourceLookupTime: sourceLookupTime(for: nextOutputFrameIndex),
                            sourceSegmentIndex: sourceSegmentIndex(for: nextOutputFrameIndex)
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
            sourceDurationSec: outputDurationSec.isFinite ? outputDurationSec : nil,
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

    func renderablePreviewVideoImage(
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
        // Backlight Veil Phase 1c — when a Backlight Veil family is active,
        // its 12 spatial keys (bloom / halation / diffusion / lensSoftness /
        // rgbShift) override the user's optical signature so the scatter
        // math has the canonical plate inputs. Color-grade params (exposure
        // / contrast / LUT etc.) stay untouched, so the user's Look color
        // is preserved and the Veil layers on top as a lens veil.
        let baseParams = request.grade.params
        let params: Phase0ParamsDTO
        if let veilSpatial = currentBacklightVeilProfile()?.spatial {
            params = applyBacklightVeilSpatialOverrides(baseParams, spatial: veilSpatial)
        } else {
            params = baseParams
        }
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

    func applyLivePreviewGrade(
        to image: CIImage,
        timeSeconds: Double,
        mode: FilmtoneLivePreviewRenderMode
    ) -> CIImage {
        switch mode {
        case .fullPreview:
            return applyGrade(to: image, timeSeconds: timeSeconds)
        case .recordingMonitor:
            return applyRecordingMonitorGrade(to: image)
        }
    }

    private func applyRecordingMonitorGrade(to image: CIImage) -> CIImage {
        let params = request.grade.params
        let presetVersion = request.grade.presetVersion
        var current = image

        metalVignetteAppliedThisFrame = false
        current = applyInputLutStage(to: current)
        current = applyBaseGradeStage(to: current, params: params, presetVersion: presetVersion)
        current = applyToneCompressionStage(to: current, params: params, presetVersion: presetVersion)
        current = applyCreativeLutStage(to: current)
        current = applyPrintStage(to: current, params: params)

        return current.cropped(to: image.extent)
    }

    var outputFrameRate: Int {
        request.output.fps
    }

    func makeMotionBlurAccumulator() -> FilmtoneMotionBlurAccumulator {
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
        let aberrationSoften = OpticsResampling.aberrationEdgeSoften(for: rgbShiftNormalized)
        if aberrationSoften > 0.0001 || params.lensSoftness > 0.0001 {
            current = applyEdgeSoftness(
                to: current,
                aberrationSoften: aberrationSoften,
                lensSoftness: params.lensSoftness
            )
        }

        return current
    }

    /// Backlight Veil Phase 1c — resolves the request-selected profile
    /// (6 optical + 12 spatial keys) from `Phase0ExportRequestDTO`. Returns
    /// nil when OFF, in which case the legacy composite path runs unchanged.
    private func currentBacklightVeilProfile()
        -> FilmtoneOpticalFiltersGenerated.Profile? {
        guard
            let filterId = request.opticalFilterProfileId,
            let profile = FilmtoneOpticalFiltersGenerated.backlightVeilProfiles
                .first(where: { $0.id == filterId })
        else {
            return nil
        }
        return profile
    }

    /// Backlight Veil Phase 1c (energy max-merge port from macOS, 2026-05-06)
    /// — produces a `Phase0ParamsDTO` that layers the active Backlight Veil
    /// profile's spatial keys onto the existing `params`. Color-grade params
    /// (exposure / contrast / saturation / LUT etc.) remain untouched.
    ///
    /// Two merge regimes for the 12 spatial keys:
    ///   * **Energy keys** (`bloomStrength` / `halationIntensity` / `diffusion`
    ///     / `lensSoftness` / `rgbShift`): `max(params[k], veil[k])`. Veil
    ///     profiles are authored against the reset baseline; absolute overwrite
    ///     would let a Look (Stone `lensSoftness=0.095`, `rgbShift=0.0032`)
    ///     get clobbered by Veil's lower defaults (Veil 1/4 `lensSoftness=0.08`,
    ///     `rgbShift=0.0007`), perceptually weakening the veil.
    ///   * **Structural keys** (`bloomThreshold` / `bloomRadius` /
    ///     `bloomSoftKnee` / `halationThreshold` / `halationRadius` /
    ///     `halationHue` / `halationSoftKnee`): absolute overwrite — Veil's
    ///     spatial shape wins so the scatter math has stable plate inputs.
    ///
    /// Mirrors macOS `FilmtonePresetCatalog.applyVeilPatch`
    /// (`apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePresetCatalog.swift`).
    /// Note: iOS `state.paramOverrides` mixes Look-derived patch and
    /// user-manual edits in one map, so user-manual overrides do not get
    /// last-write-wins precedence over Veil energy keys here (macOS does,
    /// because it threads `paramOverrides` separately). Tracked as known
    /// iOS divergence.
    private func applyBacklightVeilSpatialOverrides(
        _ params: Phase0ParamsDTO,
        spatial s: FilmtoneOpticalFiltersGenerated.SpatialKeys
    ) -> Phase0ParamsDTO {
        Phase0ParamsDTO(
            exposure: params.exposure,
            contrast: params.contrast,
            saturation: params.saturation,
            temperature: params.temperature,
            tint: params.tint,
            rgbShift: max(params.rgbShift, s.rgbShift),
            lensSoftness: max(params.lensSoftness, s.lensSoftness),
            grainRadialMix: params.grainRadialMix,
            grainSize: params.grainSize,
            bloomThreshold: s.bloomThreshold,
            bloomStrength: max(params.bloomStrength, s.bloomStrength),
            bloomRadius: s.bloomRadius,
            diffusion: max(params.diffusion, s.diffusion),
            halationIntensity: max(params.halationIntensity, s.halationIntensity),
            halationSpread: params.halationSpread,
            halationHue: s.halationHue,
            halationThreshold: s.halationThreshold,
            halationRadius: s.halationRadius,
            bloomSoftKnee: s.bloomSoftKnee,
            halationSoftKnee: s.halationSoftKnee,
            compressionAmount: params.compressionAmount,
            compressionRange: params.compressionRange,
            printContrast: params.printContrast,
            cyan: params.cyan,
            magenta: params.magenta,
            yellow: params.yellow,
            shutterAngle: params.shutterAngle,
            trailIntensity: params.trailIntensity,
            fade: params.fade,
            shadowTone: params.shadowTone,
            highlightTone: params.highlightTone,
            shadowHue: params.shadowHue,
            highlightHue: params.highlightHue,
            vignette: params.vignette,
            grainIntensity: params.grainIntensity
        )
    }

    private func applyGlowFamilyStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        let backlightVeilOptical = currentBacklightVeilProfile()?.optical

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
            let opticalScatterParams: FilmtoneMetalOpticsRenderer.OpticalScatterParams? =
                backlightVeilOptical.map { keys in
                    FilmtoneMetalOpticsRenderer.OpticalScatterParams(
                        directTransmission: keys.directTransmission,
                        blackRetention: keys.blackRetention,
                        scatterStrength: keys.scatterStrength,
                        highlightReactivity: keys.highlightReactivity,
                        warmScatter: keys.warmScatter,
                        spectralTail: keys.spectralTail
                    )
                }
            let glowParams = FilmtoneMetalOpticsRenderer.GlowFrameParams(
                bloomStrength: params.bloomStrength,
                bloomThreshold: params.bloomThreshold,
                bloomSoftKnee: params.bloomSoftKnee,
                bloomRadius: params.bloomRadius,
                bloomMipLevels: OpticsResampling.bloomMipLevels,
                bloomSpreadBoost: OpticsResampling.bloomSpreadBoost,
                halationIntensity: params.halationIntensity,
                halationThreshold: params.halationThreshold,
                halationSoftKnee: params.halationSoftKnee,
                halationRadius: params.halationRadius,
                halationHue: params.halationHue,
                halationMipLevels: OpticsResampling.halationMipLevels,
                halationSpread: params.halationSpread,
                halationSpreadDivisor: OpticsResampling.halationSpreadDivisor,
                diffusion: params.diffusion,
                diffusionMipLevels: OpticsResampling.diffusionMipLevels,
                diffusionCompositeBase: OpticsResampling.diffusionCompositeBase,
                glowBaseScale: OpticsResampling.glowBaseScale,
                opticalScatter: opticalScatterParams
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
        let black = OpticsResampling.blackImage(for: extent)

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
                levelCount: OpticsResampling.bloomMipLevels,
                spreadMultiplier: OpticsResampling.bloomSpreadBoost,
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
                tintColor: OpticsResampling.halationColor(for: params.halationHue)
            )
            halationImage = buildMipBlurComposite(
                from: halationPlate,
                radius: params.halationRadius,
                levelCount: OpticsResampling.halationMipLevels,
                spreadMultiplier: 1.0 + max(params.halationSpread, 0) / OpticsResampling.halationSpreadDivisor,
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
                levelCount: OpticsResampling.diffusionMipLevels,
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

        if let backlightVeilOptical {
            // Backlight Veil Phase 1c CI fallback — verbatim WGSL §4.4 port.
            // 9 args (3 spatial floats + 6 optical floats); diffusionBase
            // drops out because the new kernel multiplies diffused by the
            // hardcoded 0.24 from WGSL.
            guard let kernel = OpticalKernels.glowCompositeBacklightVeil else {
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
                backlightVeilOptical.directTransmission,
                backlightVeilOptical.blackRetention,
                backlightVeilOptical.scatterStrength,
                backlightVeilOptical.highlightReactivity,
                backlightVeilOptical.warmScatter,
                backlightVeilOptical.spectralTail,
            ]) ?? image
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
            OpticsResampling.diffusionCompositeBase,
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
            OpticsResampling.extentOriginVector(for: image.extent),
            OpticsResampling.extentSizeVector(for: image.extent),
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
            OpticsResampling.extentOriginVector(for: image.extent),
            OpticsResampling.extentSizeVector(for: image.extent),
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
            return OpticsResampling.blackImage(for: image.extent)
        }

        return kernel.apply(extent: image.extent, arguments: [
            image,
            Self.clamp(threshold),
            Self.clamp(knee),
            tintColor,
        ]) ?? OpticsResampling.blackImage(for: image.extent)
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
                OpticsResampling.extentOriginVector(for: image.extent),
                OpticsResampling.extentSizeVector(for: image.extent),
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
            Self.clamp(aberrationSoften / OpticsResampling.aberrationEdgeSoftenMax),
            0.82
        )
        let blurRadius = min(
            Self.lerp(
                OpticsResampling.aberrationBlurRadiusMin,
                OpticsResampling.aberrationBlurRadiusMax,
                aberrationDrive
            ) + (lensDrive * OpticsResampling.lensSoftnessBlurBoost),
            OpticsResampling.aberrationBlurRadiusCap
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
                OpticsResampling.extentOriginVector(for: image.extent),
                OpticsResampling.extentSizeVector(for: image.extent),
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
            return OpticsResampling.blackImage(for: extent)
        }

        var mips = OpticsResampling.buildMipPyramid(
            from: image,
            levelCount: levelCount,
            initialScale: OpticsResampling.glowBaseScale / max(spreadMultiplier, 0.0001),
            useTentResampling: useTentResampling
        )
        guard !mips.isEmpty else {
            return OpticsResampling.blackImage(for: extent)
        }

        let weights = OpticsResampling.computeMipWeights(radius: Self.clamp(radius), levels: mips.count)
        if mips.count > 1 {
            for index in stride(from: mips.count - 2, through: 0, by: -1) {
                let lowRes = mips[index + 1]
                let highRes = mips[index]
                let restored = useTentResampling
                    ? OpticsResampling.tentUpsampledImage(lowRes, to: highRes.extent)
                    : OpticsResampling.upsampledImage(lowRes, to: highRes.extent)
                let weighted = OpticsResampling.weightedImage(restored, weight: weights[index + 1])
                mips[index] = OpticsResampling.addImages(weighted, highRes).cropped(to: highRes.extent)
            }
        }

        let output = useTentResampling
            ? OpticsResampling.tentUpsampledImage(mips[0], to: extent)
            : OpticsResampling.upsampledImage(mips[0], to: extent)
        return output.cropped(to: extent)
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

func filmtonePreviewCompositionDebugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("[FilmtonePreview][Composition] \(message())")
    #endif
}
