import Foundation
import AVFoundation
import UIKit

@MainActor
final class FilmtoneEditorFacade {
    private let assetPickerService: AssetPickerService
    private let runtime: FilmtoneMediaRuntime
    private let memoryWarningState = FilmtoneMemoryWarningState()
    private var memoryWarningObserver: NSObjectProtocol?

    weak var presenter: UIViewController?

    init() throws {
        let cacheStore = try CacheStore()
        let mezzanineService = MezzanineService(cacheStore: cacheStore)
        self.assetPickerService = AssetPickerService(
            cacheStore: cacheStore,
            mezzanineService: mezzanineService
        )
        self.runtime = FilmtoneMediaRuntime(
            cacheStore: cacheStore,
            mezzanineService: mezzanineService,
            memoryWarningCounter: { [memoryWarningState] in memoryWarningState.count },
            invalidFileURLError: { _ in
                FilmtoneMediaError.invalidURL(
                    filmtoneLocalized(
                        "filmtone.error.file_url.invalid",
                        defaultValue: "The selected file is invalid or inaccessible.",
                        comment: "Error shown when a file URL cannot be resolved."
                    )
                )
            }
        )
        self.memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.memoryWarningState.count += 1
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

    func pickSource(
        route: FilmtoneSourcePickerRoute = .photoLibrary,
        onImportProgress: (@MainActor (FilmtoneSourceImportProgress) -> Void)? = nil
    ) async throws -> SourceInfoDTO? {
        guard let presenter else {
            throw FilmtoneMediaError.bridgeUnavailable
        }
        return try await assetPickerService.pickSource(
            presenting: presenter,
            route: route,
            onImportProgress: onImportProgress
        )
    }

    func pickCubeLut() async throws -> ParsedCubeLutDTO? {
        guard let presenter else {
            throw FilmtoneMediaError.bridgeUnavailable
        }
        guard let picked = try await assetPickerService.pickLutFile(presenting: presenter) else {
            return nil
        }
        return try FilmtoneCubeParser.parse(text: picked.text, defaultTitle: picked.filename)
    }

    func pickInputLut() async throws -> ParsedCubeLutDTO? {
        try await pickCubeLut()
    }

    func probeSource(_ source: SourceInfoDTO) throws -> SourceProbeDTO {
        try runtime.probeSource(source)
    }

    func renderPreview(
        request: Phase0ExportRequestDTO
    ) async throws -> Phase0PreviewRenderResultDTO {
        try await runtime.renderPreview(request: request)
    }

    func makeOriginalPreviewItem(
        request: Phase0ExportRequestDTO
    ) async throws -> FilmtonePreparedVideoPreviewItem {
        try await runtime.makeOriginalPreviewItem(request: request)
    }

    func makeGradedPreviewItem(
        request: Phase0ExportRequestDTO
    ) async throws -> FilmtonePreparedVideoPreviewItem {
        try await runtime.makeGradedPreviewItem(request: request)
    }

    func makeGradedPreviewComposition(
        request: Phase0ExportRequestDTO,
        asset: AVAsset
    ) async throws -> FilmtonePreparedVideoPreviewComposition {
        try await runtime.makeGradedPreviewComposition(
            request: request,
            asset: asset
        )
    }

    func runExport(
        request: Phase0ExportRequestDTO,
        onProgress: @escaping @MainActor (Phase0ExportProgressDTO) -> Void
    ) async throws -> Phase0ExportResultDTO {
        try await runtime.runExport(request: request) { progress in
            DispatchQueue.main.async {
                Task { @MainActor in
                    onProgress(progress)
                }
            }
        }
    }

    func saveToPhotos(uri: String) async throws {
        try await runtime.saveToPhotos(uri: uri)
    }

    /// Share the exported media and, when present, the v1 sidecar JSON as a
    /// second item. Single-item share targets still receive the primary media
    /// because it's the first entry in `fileURLs`.
    func shareOutput(mediaURI: String, sidecarURI: String? = nil) async throws {
        guard let presenter else {
            throw FilmtoneMediaError.bridgeUnavailable
        }
        try await runtime.shareOutput(
            uri: mediaURI,
            sidecarUri: sidecarURI,
            presenting: presenter
        )
    }

    func fileExists(uri: String) -> Bool {
        runtime.fileExists(uri: uri)
    }
}

private final class FilmtoneMemoryWarningState {
    var count = 0
}
