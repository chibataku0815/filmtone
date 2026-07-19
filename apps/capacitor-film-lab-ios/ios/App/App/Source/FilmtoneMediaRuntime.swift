import AVFoundation
import FilmLabSwiftCore
import Foundation
import UIKit

struct FilmtonePreparedVideoPreviewItem {
    let item: AVPlayerItem
    let width: Int
    let height: Int
    let durationSec: Double?
}

struct FilmtonePreparedVideoPreviewComposition {
    let videoComposition: AVVideoComposition
    let width: Int
    let height: Int
    let durationSec: Double?
}

final class FilmtoneMediaRuntime {
    private let cacheStore: CacheStore
    private let mezzanineService: MezzanineService
    private let sourceProbeService = SourceProbeService()
    private let photoLibraryService = PhotoLibraryService()
    private let memoryWarningCounter: () -> Int
    private let invalidFileURLError: (String) -> Error
    private var idleTimerDisabledBeforeExport = false
    private var exportIdleTimerActive = false

    init(
        cacheStore: CacheStore,
        mezzanineService: MezzanineService,
        memoryWarningCounter: @escaping () -> Int = { 0 },
        invalidFileURLError: @escaping (String) -> Error
    ) {
        self.cacheStore = cacheStore
        self.mezzanineService = mezzanineService
        self.memoryWarningCounter = memoryWarningCounter
        self.invalidFileURLError = invalidFileURLError
    }

    func fileExists(uri: String) -> Bool {
        guard let fileURL = try? resolveFileURL(uri) else {
            return false
        }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    func resolveFileURL(_ uri: String) throws -> URL {
        if let fileURL = URL(string: uri), fileURL.isFileURL {
            return fileURL
        }

        if FileManager.default.fileExists(atPath: uri) {
            return URL(fileURLWithPath: uri)
        }

        throw invalidFileURLError(uri)
    }

    func cacheInventorySnapshot() throws -> CacheInventoryDTO {
        let inventory = try cacheStore.inventory()
        return CacheInventoryDTO(inventory: inventory)
    }

    @discardableResult
    func releaseCache(protectedURIs: [String]) throws -> CacheReleaseResultDTO {
        let urls = protectedURIs.compactMap { try? resolveFileURL($0) }
        let result = try cacheStore.pruneLowDiskAggressive(protecting: urls)
        return CacheReleaseResultDTO(
            removedCount: result.removedCount,
            removedBytes: result.removedBytes,
            retainedBytes: result.retainedBytes
        )
    }

    func probeSource(
        _ source: SourceInfoDTO,
        sourceURL: URL? = nil
    ) throws -> SourceProbeDTO {
        let resolvedSourceURL = try sourceURL ?? resolveFileURL(source.uri)
        return try sourceProbeService.probeSource(at: resolvedSourceURL, fallback: source)
    }

    func prewarmMezzanines(for source: SourceInfoDTO) {
        guard source.kind == .video,
              let sourceURL = try? resolveFileURL(source.uri)
        else {
            return
        }
        mezzanineService.prewarmEligibleMezzanines(for: sourceURL)
    }

    func renderPreview(
        request: Phase0ExportRequestDTO,
        sourceURL: URL? = nil,
        cameraProfile: CameraProfileSelection? = nil
    ) async throws -> Phase0PreviewRenderResultDTO {
        let session = try makeExportSession(
            request: request,
            sourceURL: sourceURL,
            cameraProfile: cameraProfile
        )

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try session.renderPreviewFrame()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func makeExportSession(
        request: Phase0ExportRequestDTO,
        sourceURL: URL? = nil,
        appliedSavedLook: SavedLookEntry? = nil,
        cameraProfile: CameraProfileSelection? = nil,
        highlightMarkers: FilmtoneHighlightMarkers? = nil,
        highlightReelOptions: FilmtoneHighlightReelOptions = .standard,
        outputPreferredName: String? = nil,
        captureProvenance: SidecarCaptureProvenance? = nil
    ) throws -> FilmtoneExportSession {
        let resolvedSourceURL = try sourceURL ?? resolveFileURL(request.sourceUri)
        return try FilmtoneExportSession(
            request: request,
            sourceURL: resolvedSourceURL,
            cacheStore: cacheStore,
            mezzanineService: mezzanineService,
            appliedSavedLook: appliedSavedLook,
            cameraProfile: cameraProfile,
            highlightMarkers: highlightMarkers,
            highlightReelOptions: highlightReelOptions,
            outputPreferredName: outputPreferredName,
            captureProvenance: captureProvenance
        )
    }

    func makeSharedGradeProcessor(
        request: Phase0ExportRequestDTO,
        sourceURL: URL? = nil,
        appliedSavedLook: SavedLookEntry? = nil,
        cameraProfile: CameraProfileSelection? = nil
    ) throws -> FilmtoneSharedGradeProcessor {
        try makeExportSession(
            request: request,
            sourceURL: sourceURL,
            appliedSavedLook: appliedSavedLook,
            cameraProfile: cameraProfile
        ).makeSharedGradeProcessor()
    }

    func makeOriginalPreviewItem(
        request: Phase0ExportRequestDTO,
        sourceURL: URL? = nil
    ) async throws -> FilmtonePreparedVideoPreviewItem {
        let resolvedSourceURL = try sourceURL ?? resolveFileURL(request.sourceUri)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let asset = AVURLAsset(url: resolvedSourceURL)
                    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                        throw FilmtoneMediaError.unsupportedSource("No video track was found in the selected source.")
                    }
                    let outputSize = ExportGeometry.scaledSize(
                        for: videoTrack,
                        longEdge: request.output.longEdge
                    )
                    let item = AVPlayerItem(asset: asset)
                    let durationSec = CMTimeGetSeconds(asset.duration)
                    continuation.resume(returning: .init(
                        item: item,
                        width: Int(outputSize.width.rounded()),
                        height: Int(outputSize.height.rounded()),
                        durationSec: durationSec.isFinite ? durationSec : nil
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func makeGradedPreviewItem(
        request: Phase0ExportRequestDTO,
        sourceURL: URL? = nil,
        cameraProfile: CameraProfileSelection? = nil
    ) async throws -> FilmtonePreparedVideoPreviewItem {
        let resolvedSourceURL = try sourceURL ?? resolveFileURL(request.sourceUri)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let asset = AVURLAsset(url: resolvedSourceURL)
                    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                        throw FilmtoneMediaError.unsupportedSource("No video track was found in the selected source.")
                    }
                    let outputSize = ExportGeometry.scaledSize(
                        for: videoTrack,
                        longEdge: request.output.longEdge
                    )
                    let processor = try self.makeSharedGradeProcessor(
                        request: request,
                        sourceURL: resolvedSourceURL,
                        cameraProfile: cameraProfile
                    )
                    let item = AVPlayerItem(asset: asset)
                    item.videoComposition = processor.makeVideoComposition(
                        asset: asset,
                        videoTrack: videoTrack,
                        outputSize: outputSize
                    )
                    item.seekingWaitsForVideoCompositionRendering = true
                    let durationSec = CMTimeGetSeconds(asset.duration)
                    continuation.resume(returning: .init(
                        item: item,
                        width: Int(outputSize.width.rounded()),
                        height: Int(outputSize.height.rounded()),
                        durationSec: durationSec.isFinite ? durationSec : nil
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func makeGradedPreviewComposition(
        request: Phase0ExportRequestDTO,
        asset: AVAsset,
        sourceURL: URL? = nil,
        cameraProfile: CameraProfileSelection? = nil
    ) async throws -> FilmtonePreparedVideoPreviewComposition {
        let resolvedSourceURL = try sourceURL ?? resolveFileURL(request.sourceUri)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                        throw FilmtoneMediaError.unsupportedSource("No video track was found in the selected source.")
                    }
                    let outputSize = ExportGeometry.scaledSize(
                        for: videoTrack,
                        longEdge: request.output.longEdge
                    )
                    let processor = try self.makeSharedGradeProcessor(
                        request: request,
                        sourceURL: resolvedSourceURL,
                        cameraProfile: cameraProfile
                    )
                    let composition = processor.makeVideoComposition(
                        asset: asset,
                        videoTrack: videoTrack,
                        outputSize: outputSize
                    )
                    let durationSec = CMTimeGetSeconds(asset.duration)
                    continuation.resume(returning: .init(
                        videoComposition: composition,
                        width: Int(outputSize.width.rounded()),
                        height: Int(outputSize.height.rounded()),
                        durationSec: durationSec.isFinite ? durationSec : nil
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func runExport(
        request: Phase0ExportRequestDTO,
        sourceURL: URL? = nil,
        session: FilmtoneExportSession? = nil,
        collector: BenchmarkCollector? = nil,
        protectedCacheURLs: [URL] = [],
        appliedSavedLook: SavedLookEntry? = nil,
        cameraProfile: CameraProfileSelection? = nil,
        highlightMarkers: FilmtoneHighlightMarkers? = nil,
        captureProvenance: SidecarCaptureProvenance? = nil,
        onProgress: @escaping (Phase0ExportProgressDTO) -> Void
    ) async throws -> Phase0ExportResultDTO {
        let resolvedSourceURL = try sourceURL ?? resolveFileURL(request.sourceUri)
        _ = try? cacheStore.pruneStandard(protecting: [resolvedSourceURL] + protectedCacheURLs)
        let exportSession = try session ?? makeExportSession(
            request: request,
            sourceURL: resolvedSourceURL,
            appliedSavedLook: appliedSavedLook,
            cameraProfile: cameraProfile,
            highlightMarkers: highlightMarkers,
            captureProvenance: captureProvenance
        )
        let benchmarkCollector = collector ?? makeBenchmarkCollector(request: request)

        await beginForegroundExportActivity()
        await ExportCancelController.shared.attach(exportSession)

        // Wave 2 / Stream B (W2-B) §6.6 — request notification permission
        // lazily on the first export. Subsequent exports short-circuit
        // inside the controller. Never throws; user denial leaves the
        // pipeline intact (no completion ping, but export still succeeds).
        await FilmtoneExportNotification.shared.requestPermissionIfNeeded()

        // Wave 2 / Stream B — pre-allocate a unique notification identifier
        // tied to this export run. Computed once so the success-path
        // `scheduleCompletionNotification` and any future telemetry can
        // correlate against a single ID family.
        let exportNotificationID = UUID().uuidString

        // Stream 3 (W1-C) — Live Activity start. Attributes carry the source
        // file name and started-at timestamp; ContentState updates flow via
        // FilmtoneExportLiveActivityController.shared.receive (throttled).
        // §6.5: the Live Activity surfaces the user-facing label
        // ("Master" / "Postcard") even though the WebView label rename is
        // deferred to Stream 4.
        let liveActivityModeLabel = Self.liveActivityModeLabel(
            for: request.renderMode
        )
        let liveActivityStartedAt = Date()
        if #available(iOS 16.2, *) {
            let attributes = FilmtoneExportAttributes(
                sourceFileName: Self.liveActivitySourceFileName(
                    for: request.sourceUri
                ),
                startedAt: liveActivityStartedAt
            )
            let initialState = FilmtoneExportAttributes.ContentState(
                stage: "preflight",
                progress: 0,
                currentFrame: nil,
                totalFrames: nil,
                mode: liveActivityModeLabel,
                elapsedSeconds: 0,
                estimatedRemainingSeconds: nil
            )
            await FilmtoneExportLiveActivityController.shared.start(
                attributes: attributes,
                initialState: initialState
            )
        }

        // Stream 2 — writing-tail protection: `beginBackgroundTask` is
        // acquired only when the writer enters the .writing stage so the
        // mp4 finalization (`AVAssetWriter.finishWriting`) gets ~25-30 s
        // of background-execution headroom even if the user backgrounds
        // the app at 95 %. iOS forbids declaring `UIBackgroundModes` for
        // this use; `beginBackgroundTask` alone gives the headroom under
        // App Review 2.5.4 without an entitlement.
        var bgTaskID = UIBackgroundTaskIdentifier.invalid
        defer {
            if bgTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(bgTaskID)
                bgTaskID = .invalid
            }
        }
        // Stream 3 (W1-C) — capture last observed progress for the final
        // ContentState on success / cancel / error. Updated inside the
        // wrapped progress closure; read in the post-run end calls.
        var lastProgress: Double = 0
        var lastCurrentFrame: Int? = nil
        var lastTotalFrames: Int? = nil
        let wrappedOnProgress: (Phase0ExportProgressDTO) -> Void = { dto in
            if dto.stage == .writing && bgTaskID == .invalid {
                let id = UIApplication.shared.beginBackgroundTask(
                    withName: "filmtone.export.finalize"
                ) {
                    Task {
                        await ExportCancelController.shared.cancel(
                            reason: .backgroundTaskExpiration
                        )
                    }
                }
                bgTaskID = id
            }
            // Stream 3 (W1-C) — forward progress to the Live Activity
            // throttle layer. The closure stays sync (`onProgress` consumers
            // expect sync); the async update is dispatched via Task.
            lastProgress = dto.progress
            lastCurrentFrame = dto.currentFrame
            lastTotalFrames = dto.totalFrames
            if #available(iOS 16.2, *) {
                let elapsed = Date().timeIntervalSince(liveActivityStartedAt)
                let remaining: TimeInterval?
                if dto.progress > 0.05 && elapsed > 1.0 {
                    remaining = elapsed * (1.0 - dto.progress) / dto.progress
                } else {
                    remaining = nil
                }
                let state = FilmtoneExportAttributes.ContentState(
                    stage: dto.stage.rawValue,
                    progress: dto.progress,
                    currentFrame: dto.currentFrame,
                    totalFrames: dto.totalFrames,
                    mode: liveActivityModeLabel,
                    elapsedSeconds: elapsed,
                    estimatedRemainingSeconds: remaining
                )
                Task {
                    await FilmtoneExportLiveActivityController.shared.receive(
                        progress: state
                    )
                }
            }
            onProgress(dto)
        }

        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let exportResult = try self.runExportSession(
                            exportSession,
                            collector: benchmarkCollector,
                            onProgress: wrappedOnProgress
                        )
                        continuation.resume(returning: exportResult)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            await ExportCancelController.shared.detach()
            // Stream 3 (W1-C) — success end. dismissalPolicy: .default keeps
            // the activity visible briefly so the user sees the "Completed"
            // state on the lock screen.
            if #available(iOS 16.2, *) {
                let elapsed = Date().timeIntervalSince(liveActivityStartedAt)
                let finalState = FilmtoneExportAttributes.ContentState(
                    stage: "completed",
                    progress: 1.0,
                    currentFrame: lastCurrentFrame,
                    totalFrames: lastTotalFrames,
                    mode: liveActivityModeLabel,
                    elapsedSeconds: elapsed,
                    estimatedRemainingSeconds: 0
                )
                await FilmtoneExportLiveActivityController.shared.end(
                    success: true,
                    finalState: finalState
                )
            }
            // Wave 2 / Stream B (W2-B) §6.6 — completion Local Notification
            // + success haptic. Both fire only on the success path; cancel
            // and error paths intentionally skip them (the Live Activity's
            // `.immediate` dismissal already conveys failure, and a
            // notification on cancel would feel like a buggy double-confirm).
            await FilmtoneExportNotification.shared.scheduleCompletionNotification(
                exportID: exportNotificationID
            )
            await FilmtoneExportNotification.shared.triggerSuccessHaptic()
            await endForegroundExportActivity()
            return result
        } catch {
            await ExportCancelController.shared.detach()
            // Stream 3 (W1-C) — failure / cancel end. dismissalPolicy:
            // .immediate so a cancelled or failed export does not linger
            // on the lock screen claiming "in progress".
            if #available(iOS 16.2, *) {
                let elapsed = Date().timeIntervalSince(liveActivityStartedAt)
                let finalState = FilmtoneExportAttributes.ContentState(
                    stage: "failed",
                    progress: lastProgress,
                    currentFrame: lastCurrentFrame,
                    totalFrames: lastTotalFrames,
                    mode: liveActivityModeLabel,
                    elapsedSeconds: elapsed,
                    estimatedRemainingSeconds: nil
                )
                await FilmtoneExportLiveActivityController.shared.end(
                    success: false,
                    finalState: finalState
                )
            }
            await endForegroundExportActivity()
            throw error
        }
    }

    func runHighlightReel(
        request: Phase0ExportRequestDTO,
        sourceURL: URL? = nil,
        protectedCacheURLs: [URL] = [],
        appliedSavedLook: SavedLookEntry? = nil,
        cameraProfile: CameraProfileSelection? = nil,
        highlightMarkers: FilmtoneHighlightMarkers?,
        highlightReelOptions: FilmtoneHighlightReelOptions = .standard,
        highlightReelOutputMode: FilmtoneHighlightReelOutputMode = .combined,
        onProgress: @escaping (Phase0ExportProgressDTO) -> Void
    ) async throws -> Phase0ExportResultDTO {
        let resolvedSourceURL = try sourceURL ?? resolveFileURL(request.sourceUri)
        _ = try? cacheStore.pruneStandard(protecting: [resolvedSourceURL] + protectedCacheURLs)

        await beginForegroundExportActivity()
        defer {
            Task { @MainActor in
                await ExportCancelController.shared.detach()
                endForegroundExportActivity()
            }
        }

        switch highlightReelOutputMode {
        case .combined:
            let exportSession = try makeExportSession(
                request: request,
                sourceURL: resolvedSourceURL,
                appliedSavedLook: appliedSavedLook,
                cameraProfile: cameraProfile,
                highlightMarkers: highlightMarkers,
                highlightReelOptions: highlightReelOptions,
                outputPreferredName: Self.highlightReelOutputPreferredName(
                    sourceURL: resolvedSourceURL,
                    durationSec: highlightReelOptions.clipDurationSec
                )
            )
            await ExportCancelController.shared.attach(exportSession)
            return try await runHighlightReelSession(
                exportSession,
                progress: onProgress
            )
        case .separate:
            guard let segments = highlightMarkers?.highlightReelSegments(options: highlightReelOptions),
                  !segments.isEmpty else {
                throw FilmtoneMediaError.exportFailed("Add at least one highlight marker before creating a Highlight.")
            }
            let startedAt = Date()
            var outputUris: [String] = []
            var totalFileSize = 0
            var firstResult: Phase0ExportResultDTO?
            for (index, segment) in segments.enumerated() {
                try Task.checkCancellation()
                let session = try makeExportSession(
                    request: request,
                    sourceURL: resolvedSourceURL,
                    appliedSavedLook: appliedSavedLook,
                    cameraProfile: cameraProfile,
                    highlightMarkers: highlightMarkers,
                    highlightReelOptions: highlightReelOptions,
                    outputPreferredName: Self.highlightReelOutputPreferredName(
                        sourceURL: resolvedSourceURL,
                        durationSec: highlightReelOptions.clipDurationSec,
                        index: index
                    )
                )
                await ExportCancelController.shared.attach(session)
                let total = max(1, segments.count)
                let result = try await runHighlightReelSession(
                    session,
                    segments: [segment]
                ) { progress in
                    let scaledProgress = min(1.0, (Double(index) + progress.progress) / Double(total))
                    onProgress(Phase0ExportProgressDTO(
                        stage: progress.stage,
                        progress: scaledProgress,
                        currentFrame: progress.currentFrame,
                        totalFrames: progress.totalFrames,
                        message: progress.message ?? "Highlight \(index + 1)/\(total)"
                    ))
                }
                await ExportCancelController.shared.detach()
                outputUris.append(result.outputUri)
                totalFileSize += result.fileSizeBytes ?? 0
                if firstResult == nil {
                    firstResult = result
                }
            }

            guard let firstResult, let firstOutputUri = outputUris.first else {
                throw FilmtoneMediaError.exportFailed("Add at least one highlight marker before creating a Highlight.")
            }
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000.0)
            onProgress(Phase0ExportProgressDTO(
                stage: .completed,
                progress: 1.0,
                currentFrame: nil,
                totalFrames: nil,
                message: "Highlight complete"
            ))
            return Phase0ExportResultDTO(
                outputUri: firstOutputUri,
                elapsedMs: elapsedMs,
                outputWidth: firstResult.outputWidth,
                outputHeight: firstResult.outputHeight,
                outputFps: firstResult.outputFps,
                fileSizeBytes: totalFileSize,
                realtimeRatio: nil,
                audioPreserved: false,
                benchmarkRecord: nil,
                sidecarUri: nil,
                packageFileUris: outputUris
            )
        }
    }

    private func runHighlightReelSession(
        _ exportSession: FilmtoneExportSession,
        segments: [FilmtoneHighlightClipSegment]? = nil,
        progress: @escaping (Phase0ExportProgressDTO) -> Void
    ) async throws -> Phase0ExportResultDTO {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try exportSession.runHighlightReel(
                        segments: segments,
                        progress: progress
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func highlightReelOutputPreferredName(
        sourceURL: URL,
        durationSec: Double,
        index: Int? = nil
    ) -> String {
        let sourceName = sourceURL.deletingPathExtension().lastPathComponent
        let baseName = sourceName.isEmpty ? "filmtone" : sourceName
        let durationLabel = highlightDurationLabel(durationSec)
        let prefix = "\(baseName)-highlight-\(durationLabel)"
        guard let index else {
            return prefix
        }
        return "\(prefix)-\(String(format: "%02d", index + 1))"
    }

    private static func highlightDurationLabel(_ durationSec: Double) -> String {
        guard durationSec.isFinite, durationSec > 0 else {
            return "\(Int(FilmtoneHighlightReelOptions.defaultClipDurationSec))s"
        }
        let rounded = durationSec.rounded()
        if abs(durationSec - rounded) < 0.0001 {
            return "\(Int(rounded))s"
        }
        return String(format: "%.1fs", durationSec)
    }

    /// Stream 3 (W1-C) §6.5 — UI label for renderMode in the Live Activity.
    /// Mirrors the planned WebView rename (Stream 4): `.quality` → "Master",
    /// `.speed` → "Postcard". Defaults to "Master" when absent (matches the
    /// runtime default behaviour of `request.renderMode ?? .quality`).
    private static func liveActivityModeLabel(
        for renderMode: Phase0RenderMode?
    ) -> String {
        switch renderMode ?? .quality {
        case .quality: return "Master"
        case .speed:   return "Postcard"
        }
    }

    /// Stream 3 (W1-C) — derive a friendly source file name for the
    /// Live Activity title from the request's source URI. Strips the
    /// `file://` prefix and falls back to the raw URI if URL parsing fails.
    private static func liveActivitySourceFileName(for sourceUri: String) -> String {
        if let url = URL(string: sourceUri), !url.lastPathComponent.isEmpty {
            return url.lastPathComponent
        }
        if let lastSlash = sourceUri.lastIndex(of: "/") {
            return String(sourceUri[sourceUri.index(after: lastSlash)...])
        }
        return sourceUri
    }

    func makeFailureBenchmarkRecord(
        collector: BenchmarkCollector,
        error: Error
    ) -> Phase0ExportBenchmarkRecordDTO {
        collector.makeFailureRecord(error: error)
    }

    func saveToPhotos(uri: String) async throws {
        let fileURL = try resolveFileURL(uri)
        try await saveToPhotos(fileURL: fileURL)
    }

    func saveToPhotos(fileURL: URL) async throws {
        _ = try await photoLibraryService.saveToPhotos(fileURL: fileURL)
    }

    @MainActor
    @discardableResult
    func shareOutput(
        uri: String,
        sidecarUri: String? = nil,
        packageFileUris: [String]? = nil,
        title: String? = nil,
        text: String? = nil,
        presenting: UIViewController
    ) async throws -> Bool {
        let urls: [URL]
        if let packageFileUris, !packageFileUris.isEmpty {
            urls = try packageFileUris.map { try resolveFileURL($0) }
        } else {
            var fallbackURLs: [URL] = [try resolveFileURL(uri)]
            if let sidecarUri, let sidecarURL = try? resolveFileURL(sidecarUri) {
                fallbackURLs.append(sidecarURL)
            }
            urls = fallbackURLs
        }
        return try await shareOutput(
            fileURLs: urls,
            title: title,
            text: text,
            presenting: presenting
        )
    }

    @MainActor
    @discardableResult
    func shareOutput(
        fileURLs: [URL],
        title: String? = nil,
        text: String? = nil,
        presenting: UIViewController
    ) async throws -> Bool {
        let shareSheetService = ShareSheetService()
        return try await shareSheetService.share(
            fileURLs: fileURLs,
            title: title,
            text: text,
            presenting: presenting
        )
    }

    func makeBenchmarkCollector(request: Phase0ExportRequestDTO) -> BenchmarkCollector {
        let collector = BenchmarkCollector(
            request: request,
            memoryWarningCounter: memoryWarningCounter
        )
        // v1.2: capture render mode at construction so the bench record reflects
        // the user-requested mode regardless of whether mezzanine resolution succeeds.
        collector.recordRenderMode(request.renderMode ?? .quality)
        return collector
    }

    private func runExportSession(
        _ session: FilmtoneExportSession,
        collector: BenchmarkCollector,
        onProgress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws -> Phase0ExportResultDTO {
        var result = try session.run(progress: onProgress)
        collector.recordMezzanineUsage(
            used: session.didUseMezzanineVariant != nil,
            variant: session.didUseMezzanineVariant
        )
        // v1.3 (D3.4): mirror depth prefilter usage into the bench record.
        // session.depthResolution is non-nil iff the depth payload loaded AND
        // applyGlowFamilyStage actually invoked the prefilter — that's the same
        // truth surface the sidecar reads, keeping bench/sidecar consistent.
        let depthDidRun = session.depthResolution != nil
        collector.recordDepthUsage(
            used: depthDidRun,
            source: depthDidRun ? "avDepthData" : nil,
            renderer: depthDidRun
                ? (session.requestSnapshot.depthRenderer ?? DepthRenderer.ci.rawValue)
                : nil
        )
        collector.recordDepthPrefilterMs(session.depthPrefilterMs)
        // v1.3 Phase B: forward video depth-track totals (nil for stills).
        collector.recordVideoDepthTotals(
            frames: session.videoDepthFramesProcessed,
            decodeMs: session.videoDepthDecodeMs
        )
        let benchmarkRecord = collector.makeSuccessRecord(result: result)
        result = Phase0ExportResultDTO(
            outputUri: result.outputUri,
            elapsedMs: result.elapsedMs,
            outputWidth: result.outputWidth,
            outputHeight: result.outputHeight,
            outputFps: result.outputFps,
            fileSizeBytes: result.fileSizeBytes,
            realtimeRatio: result.realtimeRatio,
            audioPreserved: result.audioPreserved,
            videoTimingMode: result.videoTimingMode,
            audioPolicy: result.audioPolicy,
            benchmarkRecord: benchmarkRecord,
            // T2 (v1.1): carry the sidecar URI through benchmark reconstruction —
            // without this rebuild preserving it, the UI share chain would lose the JSON URL.
            sidecarUri: result.sidecarUri,
            audioDiagnosticsUri: result.audioDiagnosticsUri,
            audioDebugSummary: result.audioDebugSummary,
            packageFileUris: result.packageFileUris
        )
        return result
    }

    @MainActor
    private func beginForegroundExportActivity() {
        guard !exportIdleTimerActive else {
            return
        }
        idleTimerDisabledBeforeExport = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        exportIdleTimerActive = true
    }

    @MainActor
    private func endForegroundExportActivity() {
        guard exportIdleTimerActive else {
            return
        }
        UIApplication.shared.isIdleTimerDisabled = idleTimerDisabledBeforeExport
        exportIdleTimerActive = false
    }
}
