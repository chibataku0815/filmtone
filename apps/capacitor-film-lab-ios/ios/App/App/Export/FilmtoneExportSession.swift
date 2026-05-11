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
    /// Phase 2B-5B: stateful optics orchestrator. Owns Metal renderer
    /// lifecycle, Metal/CI gate, once/per-frame telemetry flags, Backlight
    /// Veil profile resolution, and the edge optics / glow family /
    /// vignette stage bodies. `loadedDepthMap` lifetime stays on the
    /// session and is passed per glow-family call.
    private let opticsCompositor: OpticsCompositor
    private lazy var renderStageProfiler: FilmtoneExportRenderStageProfiler? =
        Self.makeRenderStageProfiler(
            ciContext: ciContext,
            colorSpace: outputColorSpace,
            metrics: performanceMetrics
        )
    /// Phase 2B-6A: non-optics color stage collaborator. Owns prepared
    /// input/creative LUT state and the kernel-based color stages (base
    /// grade, tone compression, print) plus LUT application. Stage
    /// ordering and `applyGrade` orchestration still live on the session.
    private let gradeRenderPipeline: GradeRenderPipeline
    /// Phase 2B-7A: media writer / reader primitive collaborator. Owns
    /// writer construction, video input / reader-output settings, audio
    /// pipeline setup, audio append, finish/wait, and CMTime helpers.
    /// `exportVideo`, `exportStillImage`, and the render path still live on
    /// the session and forward `checkCancelled` into the writer.
    private let mediaWriter: ExportMediaWriter
    /// Phase 2B-7B: per-frame append / rasterize collaborator. Owns the
    /// writer readiness wait, pixel-buffer-pool allocation, CI render,
    /// output color metadata application, the adaptor append, and the
    /// per-frame signpost intervals. `exportVideo` retains the loop and
    /// passes a render closure that reuses `renderableImage(...)` so the
    /// grade / motion / depth stage order stays session-owned.
    private let frameAppender: ExportFrameAppender
    /// Phase 2B-8A: source image normalization collaborator. Owns still
    /// source loading, video pixel-buffer wrapping with HDR-to-SDR tone-map
    /// detection, AVAssetTrack→Core Image orientation transform, still /
    /// video / preview scale-crop normalization, and preview extent
    /// validation. `renderableImage`, `renderableStillImage`,
    /// `renderablePreviewVideoImage`, and `applyGrade` keep stage order on
    /// the session and delegate only the wrapping / scaling primitives.
    private let sourceImageNormalizer: ExportSourceImageNormalizer
    private let sourceSeed: Double
    /// Phase 2B-8B: Filmtone Connect package companion assembler. Owns source
    /// media copy, combined / pre-optical / post-optical cube + DCTL writes,
    /// reference-after JPEG path orchestration via a session-supplied closure,
    /// the eight-field `Companions` value, `SidecarPackage` payload, and the
    /// ordered package-file URI list. The reference-after JPEG body itself
    /// (poster-time, preview CGImage copy, JPEG write) moved to
    /// `ExportPreviewRenderer` in Phase 2B-9C; the session-supplied closure
    /// now forwards into `previewRenderer.writeReferenceAfterImage(...)`.
    private let connectPackageAssembler: ExportConnectPackageAssembler
    /// Phase 2B-8C: filmtone-ios-export-session-v1 sidecar writer collaborator.
    /// Owns device-identity assembly, depth / Saved Look / Camera Profile
    /// sidecar blocks, builder-inputs construction,
    /// `FilmtoneExportSidecarBuilder.build` + atomic write, and the
    /// log-and-return-nil fallback. The session passes a `Telemetry`
    /// snapshot of mutable state into `write(...)` so an eviction between
    /// routing and sidecar write cannot drop truth fields.
    private let sidecarWriter: ExportSidecarWriter
    /// Phase 2B-9A: still-image writer / adaptor / render-append loop
    /// collaborator. Owns the pixel-buffer adaptor setup, the 3-second
    /// frame loop, per-frame pool allocation, CI render, output color
    /// metadata application, the adaptor append, rendering / writing
    /// progress updates, finish handoff, and `CompletedExport` assembly.
    /// `exportStillImage(progress:)` keeps source-image loading, HEIC
    /// depth payload loading, output-size calculation, and
    /// `renderableStillImage(...)` on the session.
    private let stillImageWriter: ExportStillImageWriter
    /// Phase 2B-9B: mezzanine routing / quality prewarm / route telemetry
    /// collaborator. Owns route selection across
    /// hdr / sdr / qualityHDR / qualitySDR / source-direct, the quality
    /// prewarm gate, the export-time telemetry block (used-variant
    /// detection, invalidated-before-open race guard, valid status with
    /// consumed URL / metrics snapshot, and `disabled-on-ios` validation
    /// status), and the `estimatedDataRate` / quality variant policy
    /// helpers. `exportVideo(...)` keeps `AVURLAsset` opening, depth
    /// reader, writer / reader pipeline, frame loop, and sidecar writing
    /// on the session and assigns the returned `RouteResult` / `Bool?`
    /// into session telemetry properties so the sidecar truth-snapshot
    /// timing is unchanged.
    private let mezzanineRouter: ExportMezzanineRouter
    /// Phase 2B-9C: still / video preview render + reference-after JPEG
    /// collaborator. Owns the preview-image generation path (source load,
    /// scale, grade-closure invocation, preview JPEG pair), the zero-
    /// tolerance image generator with 0.5s fallback, 25%-clamped poster
    /// time, and CI JPEG writing. `applyGrade(...)`,
    /// `renderableStillImage(...)`, `renderablePreviewVideoImage(...)`,
    /// and `scaledSize(...)` stay on the session; `renderPreviewFrame()`
    /// is a thin facade that clears CI caches and delegates to the
    /// renderer with an `applyGrade` closure, and the Connect package
    /// reference-after closure now calls
    /// `previewRenderer.writeReferenceAfterImage(...)`.
    private let previewRenderer: ExportPreviewRenderer
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
    /// Phase 2B-5B: storage lives on `opticsCompositor`; this is a pass-through
    /// so external readers (FilmtoneMediaRuntime → BenchmarkCollector) keep
    /// the existing `session.depthPrefilterMs` accessor.
    var depthPrefilterMs: Double? { opticsCompositor.depthPrefilterMs }
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
        let disableGlowFamilyForExport = Self.environmentFlagEnabled("FILMTONE_EXPORT_DISABLE_GLOW_FAMILY")
        let useMetalOpticsForExport = Self.environmentFlagEnabled("FILMTONE_EXPORT_METAL_OPTICS")
        let outputURL = try cacheStore.temporaryExportURL(pathExtension: request.output.container)
        self.outputURL = outputURL
        let colorPipeline = FilmtoneColorPipeline.defaultOutputContract(
            sourceMetadata: request.sourceProbe?.sourceVideoMetadata?.color,
            sourceColorClass: request.sourceProbe?.sourceVideoMetadata?.colorClass
        )
        self.colorPipeline = colorPipeline
        let workingColorSpace = colorPipeline.workingColorSpace
        let outputColorSpace = colorPipeline.destinationColorSpace
        self.outputColorSpace = outputColorSpace
        let ciContext = CIContext(options: [
            .cacheIntermediates: false,
            .priorityRequestLow: false,
            .workingColorSpace: workingColorSpace,
            .workingFormat: NSNumber(value: CIFormat.RGBAh.rawValue),
            .outputColorSpace: outputColorSpace,
        ])
        self.ciContext = ciContext
        self.opticsCompositor = OpticsCompositor(
            request: request,
            disableGlowFamilyForExport: disableGlowFamilyForExport,
            useMetalOpticsForExport: useMetalOpticsForExport,
            ciContext: ciContext,
            colorPipeline: colorPipeline
        )
        // v1.3 Camera Profiles Phase E: dispatch through
        // `ExportInputLutBuilder.makeActiveInputLut` when the caller passed
        // an explicit `cameraProfile`; legacy (nil) callers fall through to
        // `.auto` inside the builder, so v1.2 behavior stays byte-identical
        // when no profile was selected. A user-imported `request.inputLut`
        // always wins (existing precedence).
        let preparedInputLut = ExportInputLutBuilder.makePreparedLut(from: request.inputLut)
            ?? ExportInputLutBuilder.makeActiveInputLut(
                for: cameraProfile,
                probe: request.sourceProbe
            )
        let legacyCreativeLut = request.creativeLut ?? request.lut.map {
            SerializableLutDTO(size: $0.size, data: $0.data, intensity: $0.intensity)
        }
        let preparedCreativeLut = ExportInputLutBuilder.makePreparedLut(from: legacyCreativeLut)
        self.gradeRenderPipeline = GradeRenderPipeline(
            preparedInputLut: preparedInputLut,
            preparedCreativeLut: preparedCreativeLut,
            outputColorSpace: outputColorSpace
        )
        let mediaWriter = ExportMediaWriter(
            outputURL: outputURL,
            outputFPS: request.output.fps,
            colorPipeline: colorPipeline
        )
        self.mediaWriter = mediaWriter
        self.frameAppender = ExportFrameAppender(
            ciContext: ciContext,
            outputColorSpace: outputColorSpace,
            colorPipeline: colorPipeline,
            performanceMetrics: self.performanceMetrics,
            signposter: self.signposter,
            mediaWriter: mediaWriter
        )
        self.sourceImageNormalizer = ExportSourceImageNormalizer(
            colorPipeline: colorPipeline
        )
        self.sourceSeed = Self.makeStableSourceSeed(from: sourceURL.absoluteString)
        self.connectPackageAssembler = ExportConnectPackageAssembler(
            request: request,
            sourceURL: sourceURL,
            outputURL: outputURL,
            sourceSeed: self.sourceSeed
        )
        self.sidecarWriter = ExportSidecarWriter(
            request: request,
            outputURL: outputURL,
            colorPipeline: colorPipeline,
            appliedSavedLook: appliedSavedLook,
            cameraProfileSelection: cameraProfile,
            highlightMarkers: self.highlightMarkers,
            captureProvenance: captureProvenance
        )
        self.stillImageWriter = ExportStillImageWriter(
            ciContext: ciContext,
            outputColorSpace: outputColorSpace,
            colorPipeline: colorPipeline,
            mediaWriter: mediaWriter,
            outputFPS: request.output.fps
        )
        let mezzanineRouter = ExportMezzanineRouter(
            request: request,
            sourceURL: sourceURL,
            mezzanineService: mezzanineService
        )
        self.mezzanineRouter = mezzanineRouter
        self.previewRenderer = ExportPreviewRenderer(
            request: request,
            sourceURL: sourceURL,
            outputURL: outputURL,
            cacheStore: cacheStore,
            ciContext: ciContext,
            outputColorSpace: outputColorSpace,
            sourceImageNormalizer: self.sourceImageNormalizer,
            mezzanineRouter: mezzanineRouter
        )
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
        return try previewRenderer.renderPreviewFrame { [self] image, time in
            applyGrade(to: image, timeSeconds: time)
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
        let performance = performanceMetrics.sidecarPerformance(
            elapsedMs: elapsedMs,
            disabledRenderStages: opticsCompositor.disabledRenderStages,
            acceleratedRenderStages: opticsCompositor.acceleratedRenderStages
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
        let packageCompanions: ExportConnectPackageAssembler.Companions?
        if request.connectPackage == true {
            packageCompanions = connectPackageAssembler.makeCompanions(
                result: result,
                writeReferenceAfterImage: { [previewRenderer] url, sourceDurationSec in
                    try previewRenderer.writeReferenceAfterImage(
                        to: url,
                        sourceDurationSec: sourceDurationSec
                    )
                }
            )
        } else {
            packageCompanions = nil
        }

        // T2 (v1.1): write the filmtone-ios-export-session-v1 sidecar next to the
        // export output. Failure here must NOT fail the export itself — missing
        // sidecar just surfaces as `sidecarUri = nil` downstream.
        let sidecarUri = sidecarWriter.write(
            outputSize: result.outputSize,
            fileSizeBytes: fileSizeBytes,
            elapsedMs: elapsedMs,
            realtimeRatio: realtimeRatio,
            audioPreserved: result.audioPreserved,
            package: packageCompanions?.sidecarPackage,
            performance: performance,
            telemetry: ExportSidecarWriter.Telemetry(
                degradedDecodePath: degradedDecodePath,
                depthResolution: depthResolution,
                videoDepthFramesProcessed: videoDepthFramesProcessed,
                videoDepthSourceLabel: videoDepthSourceLabel,
                didUseMezzanineVariant: didUseMezzanineVariant,
                mezzanineConsumedURLLastPathComponent: mezzanineConsumedURLLastPathComponent,
                mezzanineConsumedMetrics: mezzanineConsumedMetrics,
                mezzanineGeneratedDuringExport: mezzanineGeneratedDuringExport,
                mezzanineValidationStatus: mezzanineValidationStatus
            )
        )
        let packageFileUris = connectPackageAssembler.makePackageFileUris(
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

    private func exportVideo(
        progress: @escaping (Phase0ExportProgressDTO) -> Void,
        highlightSegments: [FilmtoneHighlightClipSegment]? = nil
    ) throws -> CompletedExport {
        if let generated = try mezzanineRouter.prepareQualityMezzanineForExport(progress: progress) {
            mezzanineGeneratedDuringExport = generated
        }
        let route = mezzanineRouter.routeSourceForExport()
        let effectiveSourceURL = route.sourceURL
        didUseMezzanineVariant = route.didUseVariant
        mezzanineValidationStatus = route.validationStatus
        mezzanineConsumedURLLastPathComponent = route.consumedURLLastPathComponent
        mezzanineConsumedMetrics = route.consumedMetrics
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
        let writer = try mediaWriter.makeWriter(outputSize: outputSize)
        let videoInput = mediaWriter.makeVideoInput(outputSize: outputSize)
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
            let pair = mediaWriter.makeAudioPipeline(for: audioTrack)
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
        let videoOutputSelection = mediaWriter.makeVideoReaderOutput(
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
            let rawTime = ExportMediaWriter.validPresentationTime(for: sampleBuffer)
            if sourceTimeOffset == nil {
                sourceTimeOffset = rawTime
            }
            let timelineTime = ExportMediaWriter.nonNegativeTime(
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
            let appendedFrame = try frameAppender.appendVideoSample(
                sample.buffer,
                videoInput: videoInput,
                writer: writer,
                reader: reader,
                adaptor: adaptor,
                videoTrack: videoTrack,
                outputSize: outputSize,
                outputPresentationTime: outputPresentationTime,
                renderTimeSeconds: sourceTimeSec.isFinite ? sourceTimeSec : (outputTimeSec.isFinite ? outputTimeSec : 0),
                waitForReady: false,
                checkCancelled: checkCancelled,
                renderFrameImage: { [self] imageBuffer, transform, outputSize, timeSeconds in
                    renderableImage(
                        from: imageBuffer,
                        transform: transform,
                        outputSize: outputSize,
                        timeSeconds: timeSeconds
                    )
                }
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
                            let previousDelta = ExportMediaWriter.absoluteSecondsBetween(
                                previous.timelineTime,
                                sourceTime
                            )
                            let lookaheadDelta = ExportMediaWriter.absoluteSecondsBetween(
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

                        try mediaWriter.appendAudioSample(
                            sampleBuffer,
                            audioInput: audioInput,
                            writer: writer,
                            reader: reader,
                            waitForReady: false,
                            checkCancelled: checkCancelled
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
            try mediaWriter.finish(writer: writer, checkCancelled: checkCancelled)
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
        guard let image = sourceImageNormalizer.loadedSourceImage(at: sourceURL) else {
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
        let filteredImage = renderableStillImage(image, outputSize: outputSize, timeSeconds: 0)
        return try stillImageWriter.write(
            filteredImage: filteredImage,
            outputSize: outputSize,
            progress: progress,
            checkCancelled: checkCancelled
        )
    }

    private func renderableImage(
        from imageBuffer: CVPixelBuffer,
        transform: CGAffineTransform,
        outputSize: CGSize,
        timeSeconds: Double
    ) -> CIImage {
        let base = sourceImageNormalizer.scaledVideoSourceImage(
            sourceImageNormalizer.sourceVideoImage(from: imageBuffer),
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
        let base = sourceImageNormalizer.scaledStillSourceImage(image, outputSize: outputSize)
        let graded = applyGrade(to: base, timeSeconds: timeSeconds)
        return graded.cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    func renderablePreviewVideoImage(
        from image: CIImage,
        outputSize: CGSize,
        timeSeconds: Double,
        motionAccumulator: FilmtoneMotionBlurAccumulator? = nil
    ) throws -> CIImage {
        let base = sourceImageNormalizer.scaledPreviewVideoSourceImage(
            sourceImageNormalizer.sourcePreviewVideoImage(from: image),
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
        try sourceImageNormalizer.validatePreviewVideoImage(motionApplied, outputSize: outputSize)
        return motionApplied
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
        let params = opticsCompositor.paramsApplyingBacklightVeil(to: request.grade.params)
        let presetVersion = request.grade.presetVersion
        var current = image

        // Phase 2 段階 1: clear the per-frame Metal vignette flag before any
        // stage runs. `applyGlowFamilyStage` sets it true when the Metal
        // optics chain absorbs the vignette pass; `applyVignetteStage`
        // consumes it to skip the CI path.
        opticsCompositor.resetFrameState()

        current = gradeRenderPipeline.applyInputLutStage(to: current)
        profileRenderSubstage(.inputLut, image: current, outputSize: stageProfilingOutputSize)
        current = gradeRenderPipeline.applyBaseGradeStage(to: current, params: params, presetVersion: presetVersion)
        profileRenderSubstage(.baseGrade, image: current, outputSize: stageProfilingOutputSize)
        current = gradeRenderPipeline.applyToneCompressionStage(to: current, params: params, presetVersion: presetVersion)
        profileRenderSubstage(.toneCompression, image: current, outputSize: stageProfilingOutputSize)
        current = opticsCompositor.applyEdgeOpticsStage(to: current, params: params)
        profileRenderSubstage(.edgeOptics, image: current, outputSize: stageProfilingOutputSize)
        current = opticsCompositor.applyGlowFamilyStage(
            to: current,
            params: params,
            loadedDepthMap: loadedDepthMap
        )
        profileRenderSubstage(.glowFamily, image: current, outputSize: stageProfilingOutputSize)
        current = opticsCompositor.applyVignetteStage(to: current, params: params)
        profileRenderSubstage(.vignette, image: current, outputSize: stageProfilingOutputSize)
        current = applyGrainStage(to: current, params: params, timeSeconds: timeSeconds)
        profileRenderSubstage(.grain, image: current, outputSize: stageProfilingOutputSize)
        current = gradeRenderPipeline.applyCreativeLutStage(to: current)
        profileRenderSubstage(.creativeLut, image: current, outputSize: stageProfilingOutputSize)
        current = gradeRenderPipeline.applyPrintStage(to: current, params: params)
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

        opticsCompositor.resetFrameState()
        current = gradeRenderPipeline.applyInputLutStage(to: current)
        current = gradeRenderPipeline.applyBaseGradeStage(to: current, params: params, presetVersion: presetVersion)
        current = gradeRenderPipeline.applyToneCompressionStage(to: current, params: params, presetVersion: presetVersion)
        current = gradeRenderPipeline.applyCreativeLutStage(to: current)
        current = gradeRenderPipeline.applyPrintStage(to: current, params: params)

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

    private static func makeStableSourceSeed(from string: String) -> Double {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Double(hash % 8_192)
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

    private func checkCancelled() throws {
        if cancelled {
            throw FilmtoneMediaError.exportCancelled
        }
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
