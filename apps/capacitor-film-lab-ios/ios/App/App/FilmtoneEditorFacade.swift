import Foundation
import UIKit

@MainActor
final class FilmtoneEditorFacade {
    private let cacheStore: CacheStore
    private let assetPickerService: AssetPickerService
    private let sourceProbeService = SourceProbeService()
    private let photoLibraryService = PhotoLibraryService()
    private let shareSheetService = ShareSheetService()
    private var memoryWarningObserver: NSObjectProtocol?
    private var memoryWarningCount = 0
    private var idleTimerDisabledBeforeExport = false
    private var exportIdleTimerActive = false

    weak var presenter: UIViewController?

    init() throws {
        let cacheStore = try CacheStore()
        self.cacheStore = cacheStore
        self.assetPickerService = AssetPickerService(cacheStore: cacheStore)
        self.memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.memoryWarningCount += 1
            }
        }
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    func attachPresenter(_ presenter: UIViewController) {
        self.presenter = presenter
    }

    func pickSource(route: FilmtoneSourcePickerRoute = .photoLibrary) async throws -> SourceInfoDTO? {
        guard let presenter else {
            throw FilmtoneMediaError.bridgeUnavailable
        }
        return try await assetPickerService.pickSource(
            presenting: presenter,
            route: route
        )
    }

    func pickInputLut() async throws -> ParsedCubeLutDTO? {
        guard let presenter else {
            throw FilmtoneMediaError.bridgeUnavailable
        }
        guard let picked = try await assetPickerService.pickLutFile(presenting: presenter) else {
            return nil
        }
        return try FilmtoneCubeParser.parse(text: picked.text, defaultTitle: picked.filename)
    }

    func probeSource(_ source: SourceInfoDTO) throws -> SourceProbeDTO {
        let sourceURL = try resolveFileURL(source.uri)
        return try sourceProbeService.probeSource(at: sourceURL, fallback: source)
    }

    func renderPreview(
        request: Phase0ExportRequestDTO
    ) async throws -> Phase0PreviewRenderResultDTO {
        let sourceURL = try resolveFileURL(request.sourceUri)
        let session = try FilmtoneExportSession(
            request: request,
            sourceURL: sourceURL,
            cacheStore: cacheStore
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

    func runExport(
        request: Phase0ExportRequestDTO,
        onProgress: @escaping @MainActor (Phase0ExportProgressDTO) -> Void
    ) async throws -> Phase0ExportResultDTO {
        let sourceURL = try resolveFileURL(request.sourceUri)
        let collector = BenchmarkCollector(
            request: request,
            memoryWarningCounter: { [weak self] in self?.memoryWarningCount ?? 0 }
        )
        let session = try FilmtoneExportSession(
            request: request,
            sourceURL: sourceURL,
            cacheStore: cacheStore
        )

        beginForegroundExportActivity()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    var result = try session.run { progress in
                        DispatchQueue.main.async {
                            Task { @MainActor in
                                onProgress(progress)
                            }
                        }
                    }

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

                    DispatchQueue.main.async {
                        self.endForegroundExportActivity()
                        continuation.resume(returning: result)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.endForegroundExportActivity()
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func saveToPhotos(uri: String) async throws {
        let fileURL = try resolveFileURL(uri)
        _ = try await photoLibraryService.saveToPhotos(fileURL: fileURL)
    }

    func shareOutput(uri: String) async throws {
        guard let presenter else {
            throw FilmtoneMediaError.bridgeUnavailable
        }
        let fileURL = try resolveFileURL(uri)
        _ = try await shareSheetService.share(
            fileURL: fileURL,
            title: nil,
            text: nil,
            presenting: presenter
        )
    }

    func fileExists(uri: String) -> Bool {
        guard let url = try? resolveFileURL(uri) else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func resolveFileURL(_ uri: String) throws -> URL {
        if let fileURL = URL(string: uri), fileURL.isFileURL {
            return fileURL
        }

        if FileManager.default.fileExists(atPath: uri) {
            return URL(fileURLWithPath: uri)
        }

        throw FilmtoneMediaError.invalidURL("The file URL '\(uri)' is invalid or inaccessible.")
    }

    private func beginForegroundExportActivity() {
        guard !exportIdleTimerActive else {
            return
        }
        idleTimerDisabledBeforeExport = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        exportIdleTimerActive = true
    }

    private func endForegroundExportActivity() {
        guard exportIdleTimerActive else {
            return
        }
        UIApplication.shared.isIdleTimerDisabled = idleTimerDisabledBeforeExport
        exportIdleTimerActive = false
    }
}
