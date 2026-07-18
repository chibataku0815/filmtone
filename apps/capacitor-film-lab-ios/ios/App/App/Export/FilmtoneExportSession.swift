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
    private var lastAudioDiagnostics: ExportAudioDiagnostics?
    private var lastAudioDiagnosticsURI: String?
    private var lastAudioDebugSummary: String?
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
    /// grade, tone compression, print) plus LUT application.
    /// R3: also owns the per-frame `applyGrade` stage orchestration plus
    /// `applyVideoMotionStage` / grain / film-damage / film-breath, taking
    /// `opticsCompositor`, `loadedDepthMap`, and the render-stage
    /// profiling hook as parameters from the session. `request`,
    /// `opticsCompositor`'s instance, and `loadedDepthMap`'s mutable
    /// per-frame lifetime stay session-owned.
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
    /// Phase 4-B Detail Softness: session-derived additive bias resolved
    /// once from `request.sourceProbe`. Fed into
    /// `FilmtoneDetailSoftness.deriveUniforms(...)` at the detail-softness
    /// stage. Never persisted; not in any saved Look or export JSON.
    private let sourceDetailBias: Double
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
    /// `renderableStillImage(...)`, and `renderablePreviewVideoImage(...)`
    /// stay on the session; `renderPreviewFrame()`
    /// is a thin facade that clears CI caches and delegates to the
    /// renderer with an `applyGrade` closure, and the Connect package
    /// reference-after closure now calls
    /// `previewRenderer.writeReferenceAfterImage(...)`.
    private let previewRenderer: ExportPreviewRenderer
    /// Phase 2B-10D: video export writer / reader / adaptor / audio
    /// pipeline / reader output / `degradedDecodePath` / writer-start /
    /// reader-start / `startSession(atSourceTime:)` setup collaborator.
    /// `exportVideo(...)` keeps mezzanine routing, asset / video-track
    /// lookup, depth reader setup, timeline construction, queue pump
    /// orchestration, `appendOutputFrame(...)`, post-wait finish, and
    /// `CompletedExport` assembly.
    private let videoIOBuilder: ExportVideoIOBuilder
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
        outputFrameRate: request.effectiveOutputFPS
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
            outputFPS: request.effectiveOutputFPS,
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
        self.sourceSeed = GradeRenderPipeline.makeStableSourceSeed(from: sourceURL.absoluteString)
        self.sourceDetailBias = GradeRenderPipeline.resolveSourceDetailBias(
            from: request.sourceProbe,
            cameraProfile: cameraProfile
        )
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
            outputFPS: request.effectiveOutputFPS
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
        self.videoIOBuilder = ExportVideoIOBuilder(
            request: request,
            mediaWriter: mediaWriter
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
        lastAudioDiagnostics = nil
        lastAudioDiagnosticsURI = nil
        lastAudioDebugSummary = nil

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
        // Stills (sourceDurationSec=nil) fall back to outputDurationSec so wall-clock
        // ratio against the 3s filler timeline is preserved.
        if let duration = result.sourceDurationSec ?? result.outputDurationSec, duration > 0 {
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
                writeReferenceAfterImage: { [previewRenderer] url, outputDurationSec in
                    try previewRenderer.writeReferenceAfterImage(
                        to: url,
                        sourceDurationSec: outputDurationSec
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
            audioDiagnostics: lastAudioDiagnostics,
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
        let timingMetadata: FilmtoneVideoTimingMetadataDTO? = request.sourceKind == .video
            ? FilmtoneVideoTimingMetadataDTO.make(
                policy: request.videoTimingPolicy,
                sourceDurationSec: request.sourceProbe?.durationSec,
                sourceFrameCount: result.frameCount
            )
            : nil

        progress(.init(stage: .completed, progress: 1.0, currentFrame: result.frameCount, totalFrames: result.frameCount, message: "Export complete"))

        return Phase0ExportResultDTO(
            outputUri: outputURL.absoluteString,
            elapsedMs: elapsedMs,
            outputWidth: Int(result.outputSize.width.rounded()),
            outputHeight: Int(result.outputSize.height.rounded()),
            outputFps: request.effectiveOutputFPS,
            fileSizeBytes: fileSizeBytes,
            realtimeRatio: realtimeRatio,
            audioPreserved: result.audioPreserved,
            videoTimingMode: timingMetadata?.videoTimingMode,
            audioPolicy: timingMetadata?.audioPolicy,
            benchmarkRecord: nil,
            sidecarUri: sidecarUri,
            audioDiagnosticsUri: lastAudioDiagnosticsURI,
            audioDebugSummary: lastAudioDebugSummary,
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
        if let duration = result.sourceDurationSec ?? result.outputDurationSec, duration > 0 {
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
            outputFps: request.effectiveOutputFPS,
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
        let audioSourceAsset = AVURLAsset(url: sourceURL)
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
        let depthMatcher = ExportVideoDepthMatcher(reader: depthReader)
        defer { depthMatcher.cancel() }
        if depthMatcher.hasReader {
            videoDepthSourceLabel = "AVDepthDataTrack"
            videoDepthFramesProcessed = 0
            videoDepthDecodeMs = 0
        }

        let sourceDurationSec = CMTimeGetSeconds(asset.duration)
        let highlightTimeline = highlightSegments.flatMap {
            FilmtoneHighlightReelFrameTimeline(
                segments: $0,
                outputFps: request.effectiveOutputFPS
            )
        }
        // Phase 2B-10B: output frame count / duration, source lookup mapping,
        // source-time-offset normalization, per-sample timeline time, segment
        // index, and rendering progress math live in `ExportVideoTimeline`.
        // The session keeps owning reader / writer setup, dispatch queues,
        // decode loop, lookahead selection, frame append, audio append,
        // completion / failure locks, and depth matcher orchestration.
        let videoTimeline = ExportVideoTimeline(
            highlightTimeline: highlightTimeline,
            outputFPS: request.effectiveOutputFPS,
            sourceDurationSec: sourceDurationSec,
            timingPolicy: highlightTimeline == nil ? request.videoTimingPolicy : .init(mode: .normal, sourceFPS: request.sourceVideoFPS)
        )
        let io = try videoIOBuilder.makeContext(
            asset: asset,
            audioAsset: audioSourceAsset,
            videoTrack: videoTrack,
            highlightTimeline: highlightTimeline
        )
        let outputSize = io.outputSize
        let writer = io.writer
        let videoInput = io.videoInput
        let adaptor = io.adaptor
        let audioInput = io.audioInput
        let audioOutput = io.audioOutput
        let audioReader = io.audioReader
        let reader = io.reader
        let videoOutput = io.videoOutput
        degradedDecodePath = io.degradedDecodePath
        let audioStatsTracker = ExportAudioSampleStatsTracker()

        let videoQueue = DispatchQueue(label: "FilmtoneExportSession.video")
        let audioQueue = DispatchQueue(label: "FilmtoneExportSession.audio")
        // Phase 2B-10C: dispatch group / completion / failure lifecycle
        // live in `ExportVideoCompletionCoordinator`. The video queue body
        // (sample decode, lookahead selection, output frame loop, per-frame
        // progress emission) lives in `ExportVideoFramePump`. The audio
        // queue body lives in `ExportVideoAudioPump`. The session keeps
        // owning reader / writer setup, `appendOutputFrame(...)`, depth
        // preparation, motion blur reset, render stage order, sidecar
        // assembly, and the audio preservation gate.
        let completionCoordinator = ExportVideoCompletionCoordinator(
            reader: reader,
            audioReader: audioReader,
            writer: writer,
            videoInput: videoInput,
            audioInput: audioInput
        )
        let videoFramePump = ExportVideoFramePump(
            videoInput: videoInput,
            videoOutput: videoOutput,
            reader: reader,
            videoQueue: videoQueue,
            timeline: videoTimeline,
            completion: completionCoordinator,
            performanceMetrics: performanceMetrics,
            signposter: signposter
        )

        progress(.init(stage: .reading, progress: 0.11, currentFrame: 0, totalFrames: videoTimeline.outputFrameCount, message: "Reading source"))

        let mediaPipelineStartedNs = DispatchTime.now().uptimeNanoseconds

        func prepareDepthForSourceTime(at sourceLookupTime: CMTime) {
            guard depthMatcher.hasReader else {
                loadedDepthMap = nil
                return
            }
            let result = depthMatcher.matchDepthFrame(
                for: sourceLookupTime,
                sourceTimeOffset: videoTimeline.sourceTimeOffset
            )
            videoDepthDecodeMs = (videoDepthDecodeMs ?? 0) + result.decodeMs
            loadedDepthMap = result.depthMap
            if let depthMap = result.depthMap {
                videoDepthFramesProcessed = (videoDepthFramesProcessed ?? 0) + 1
                // depthResolution is the "did the prefilter run?" signal that
                // both the sidecar and runtime read; setting it on the first
                // matched frame keeps still / video paths telemetry-aligned.
                if depthResolution == nil {
                    depthResolution = (depthMap.width, depthMap.height)
                }
            }
        }
        var renderedHighlightSegmentIndex: Int?

        func appendOutputFrame(_ request: ExportVideoFramePump.AppendRequest) throws {
            prepareDepthForSourceTime(at: request.sourceLookupTime)
            if let sourceSegmentIndex = request.sourceSegmentIndex,
               sourceSegmentIndex != renderedHighlightSegmentIndex {
                exportMotionBlurAccumulator.reset()
                renderedHighlightSegmentIndex = sourceSegmentIndex
            }
            let outputTimeSec = CMTimeGetSeconds(request.outputPresentationTime)
            let sourceTimeSec = CMTimeGetSeconds(request.sourceLookupTime)
            let appendedFrame = try frameAppender.appendVideoSample(
                request.sample.buffer,
                videoInput: videoInput,
                writer: writer,
                reader: reader,
                adaptor: adaptor,
                videoTrack: videoTrack,
                outputSize: outputSize,
                outputPresentationTime: request.outputPresentationTime,
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
        }

        completionCoordinator.enterVideo()
        videoFramePump.start(
            progress: progress,
            checkCancelled: checkCancelled,
            appendFrame: { request in
                try appendOutputFrame(request)
            }
        )

        if let audioInput, let audioOutput, let audioReader {
            completionCoordinator.enterAudio()
            let audioPump = ExportVideoAudioPump(
                audioInput: audioInput,
                audioOutput: audioOutput,
                audioReader: audioReader,
                writer: writer,
                audioQueue: audioQueue,
                mediaWriter: mediaWriter,
                completion: completionCoordinator,
                onSampleAppended: audioStatsTracker.record
            )
            audioPump.start(checkCancelled: checkCancelled)
        }

        completionCoordinator.wait()
        performanceMetrics.recordMediaPipeline(elapsedSince: mediaPipelineStartedNs)

        try completionCoordinator.throwCapturedErrorIfNeeded()

        if reader.status == .failed {
            throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "Video read failed.")
        }

        progress(.init(stage: .writing, progress: 0.92, currentFrame: videoFramePump.renderedFrames, totalFrames: videoTimeline.outputFrameCount, message: "Writing output"))
        try performanceMetrics.measure(.writerFinish) {
            try mediaWriter.finish(writer: writer, checkCancelled: checkCancelled)
        }
        let audioValidation = ExportAudioCompletionValidator.validate(
            sourceAsset: audioSourceAsset,
            effectiveVideoAsset: asset,
            outputURL: outputURL,
            preserveAudioRequested: request.effectivePreserveAudio,
            highlightTimelinePresent: highlightTimeline != nil
        )
        let diagnostics = ExportAudioDiagnostics(
            sourceURL: sourceURL,
            effectiveVideoURL: effectiveSourceURL,
            outputURL: outputURL,
            preserveAudioRequested: request.effectivePreserveAudio,
            highlightTimelinePresent: highlightTimeline != nil,
            mezzanineVariant: didUseMezzanineVariant,
            validation: audioValidation,
            audioReaderStarted: audioReader != nil,
            sampleStats: audioStatsTracker.snapshot()
        )
        let diagnosticsURL = diagnostics.writeLatest()
        lastAudioDiagnostics = diagnostics
        lastAudioDiagnosticsURI = diagnosticsURL?.absoluteString
        lastAudioDebugSummary = diagnostics.summary
        NSLog(
            "[FilmtoneAudioDebug] %@ source=%@ effective=%@ output=%@ failure=%@",
            diagnostics.summary,
            sourceURL.lastPathComponent,
            effectiveSourceURL.lastPathComponent,
            outputURL.lastPathComponent,
            audioValidation.failureReason ?? "nil"
        )
        if let reason = audioValidation.failureReason {
            throw FilmtoneMediaError.exportFailed("Audio preservation failed: \(reason)")
        }

        return CompletedExport(
            outputSize: outputSize,
            frameCount: videoFramePump.renderedFrames,
            sourceDurationSec: sourceDurationSec.isFinite ? sourceDurationSec : nil,
            outputDurationSec: videoTimeline.outputDurationSec.isFinite ? videoTimeline.outputDurationSec : nil,
            audioPreserved: audioValidation.audioPreserved
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

        let outputSize = ExportGeometry.scaledSize(for: image.extent.size, longEdge: request.output.longEdge)
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
        gradeRenderPipeline.applyGrade(
            to: image,
            timeSeconds: timeSeconds,
            rawParams: request.grade.params,
            presetVersion: request.grade.presetVersion,
            sourceDetailBias: sourceDetailBias,
            sourceSeed: sourceSeed,
            opticsCompositor: opticsCompositor,
            loadedDepthMap: loadedDepthMap,
            profileSubstage: { [self] stage, image in
                profileRenderSubstage(stage, image: image, outputSize: stageProfilingOutputSize)
            }
        )
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
        request.effectiveOutputFPS
    }

    func makeMotionBlurAccumulator() -> FilmtoneMotionBlurAccumulator {
        FilmtoneMotionBlurAccumulator(
            ciContext: ciContext,
            colorSpace: outputColorSpace,
            outputFrameRate: request.effectiveOutputFPS
        )
    }

    private func applyVideoMotionStage(
        to image: CIImage,
        timeSeconds: Double,
        outputSize: CGSize,
        accumulator: FilmtoneMotionBlurAccumulator?
    ) -> CIImage {
        gradeRenderPipeline.applyVideoMotionStage(
            to: image,
            timeSeconds: timeSeconds,
            outputSize: outputSize,
            accumulator: accumulator,
            params: request.grade.params
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

    // Phase 4-B Detail Softness / M1 Look Director / grain / film damage /
    // film breath: `resolveSourceDetailBias`, `makeStableSourceSeed`,
    // `applyGrainStage`, `applyFilmDamageStage`, and `paramsApplyingFilmBreath`
    // moved to `GradeRenderPipeline` (R3, god-object regrowth pass). See
    // `gradeRenderPipeline`'s property doc above and `applyGrade`'s call
    // into `gradeRenderPipeline.applyGrade(...)`.

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

}

func filmtonePreviewCompositionDebugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("[FilmtonePreview][Composition] \(message())")
    #endif
}
