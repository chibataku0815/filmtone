import Foundation
import UIKit

final class FilmtoneMediaRuntime {
    private let cacheStore: CacheStore
    private let sourceProbeService = SourceProbeService()
    private let photoLibraryService = PhotoLibraryService()
    private let memoryWarningCounter: () -> Int
    private let invalidFileURLError: (String) -> Error
    private var idleTimerDisabledBeforeExport = false
    private var exportIdleTimerActive = false

    init(
        cacheStore: CacheStore,
        memoryWarningCounter: @escaping () -> Int = { 0 },
        invalidFileURLError: @escaping (String) -> Error
    ) {
        self.cacheStore = cacheStore
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

    func probeSource(
        _ source: SourceInfoDTO,
        sourceURL: URL? = nil
    ) throws -> SourceProbeDTO {
        let resolvedSourceURL = try sourceURL ?? resolveFileURL(source.uri)
        return try sourceProbeService.probeSource(at: resolvedSourceURL, fallback: source)
    }

    func renderPreview(
        request: Phase0ExportRequestDTO,
        sourceURL: URL? = nil
    ) async throws -> Phase0PreviewRenderResultDTO {
        let session = try makeExportSession(
            request: request,
            sourceURL: sourceURL
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
        sourceURL: URL? = nil
    ) throws -> FilmtoneExportSession {
        let resolvedSourceURL = try sourceURL ?? resolveFileURL(request.sourceUri)
        return try FilmtoneExportSession(
            request: request,
            sourceURL: resolvedSourceURL,
            cacheStore: cacheStore
        )
    }

    func runExport(
        request: Phase0ExportRequestDTO,
        sourceURL: URL? = nil,
        session: FilmtoneExportSession? = nil,
        collector: BenchmarkCollector? = nil,
        onProgress: @escaping (Phase0ExportProgressDTO) -> Void
    ) async throws -> Phase0ExportResultDTO {
        let exportSession = try session ?? makeExportSession(
            request: request,
            sourceURL: sourceURL
        )
        let benchmarkCollector = collector ?? makeBenchmarkCollector(request: request)

        await beginForegroundExportActivity()

        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let exportResult = try self.runExportSession(
                            exportSession,
                            collector: benchmarkCollector,
                            onProgress: onProgress
                        )
                        continuation.resume(returning: exportResult)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            await endForegroundExportActivity()
            return result
        } catch {
            await endForegroundExportActivity()
            throw error
        }
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
    func shareOutput(
        uri: String,
        title: String? = nil,
        text: String? = nil,
        presenting: UIViewController
    ) async throws {
        let fileURL = try resolveFileURL(uri)
        try await shareOutput(
            fileURL: fileURL,
            title: title,
            text: text,
            presenting: presenting
        )
    }

    @MainActor
    func shareOutput(
        fileURL: URL,
        title: String? = nil,
        text: String? = nil,
        presenting: UIViewController
    ) async throws {
        let shareSheetService = ShareSheetService()
        _ = try await shareSheetService.share(
            fileURL: fileURL,
            title: title,
            text: text,
            presenting: presenting
        )
    }

    func makeBenchmarkCollector(request: Phase0ExportRequestDTO) -> BenchmarkCollector {
        BenchmarkCollector(
            request: request,
            memoryWarningCounter: memoryWarningCounter
        )
    }

    private func runExportSession(
        _ session: FilmtoneExportSession,
        collector: BenchmarkCollector,
        onProgress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws -> Phase0ExportResultDTO {
        var result = try session.run(progress: onProgress)
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
            benchmarkRecord: benchmarkRecord
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
