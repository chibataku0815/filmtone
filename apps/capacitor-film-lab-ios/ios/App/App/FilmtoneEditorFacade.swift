import Foundation
import AVFoundation
import FilmLabSwiftCore
import UIKit

@MainActor
final class FilmtoneEditorFacade {
    private let cacheStore: CacheStore
    private let assetPickerService: AssetPickerService
    private let runtime: FilmtoneMediaRuntime
    private let cacheMaintenanceQueue = DispatchQueue(
        label: "FilmtoneEditorFacade.cacheMaintenance",
        qos: .utility
    )
    private let memoryWarningState = FilmtoneMemoryWarningState()
    private var memoryWarningObserver: NSObjectProtocol?

    weak var presenter: UIViewController?

    init() throws {
        let cacheStore = try CacheStore()
        self.cacheStore = cacheStore
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

    /// Walk `presentedViewController` from the attached root hosting controller
    /// down to the topmost live controller. UIKit refuses to `present()` on a
    /// controller that already has a `presentedViewController`, so when a
    /// picker is invoked from inside a sheet (Source Profile sheet, etc.) we
    /// must hand UIKit the sheet's host instead of the root.
    private var topPresentingViewController: UIViewController? {
        var top: UIViewController? = presenter
        while let next = top?.presentedViewController, !next.isBeingDismissed {
            top = next
        }
        return top
    }

    func pickSource(
        route: FilmtoneSourcePickerRoute = .photoLibrary,
        protectedCacheURIs: [String] = [],
        onImportProgress: (@MainActor (FilmtoneSourceImportProgress) -> Void)? = nil
    ) async throws -> SourceInfoDTO? {
        guard let host = topPresentingViewController else {
            throw FilmtoneMediaError.bridgeUnavailable
        }
        return try await assetPickerService.pickSource(
            presenting: host,
            route: route,
            protectedCacheURLs: protectedCacheURIs.compactMap { try? runtime.resolveFileURL($0) },
            onImportProgress: onImportProgress
        )
    }

    func pickCubeLut() async throws -> ParsedCubeLutDTO? {
        guard let host = topPresentingViewController else {
            throw FilmtoneMediaError.bridgeUnavailable
        }
        guard let picked = try await assetPickerService.pickLutFile(presenting: host) else {
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

    func prewarmMezzanines(for source: SourceInfoDTO) {
        runtime.prewarmMezzanines(for: source)
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
        protectedCacheURIs: [String] = [],
        appliedSavedLook: SavedLookEntry? = nil,
        cameraProfile: CameraProfileSelection? = nil,
        highlightMarkers: FilmtoneHighlightMarkers? = nil,
        onProgress: @escaping @MainActor (Phase0ExportProgressDTO) -> Void
    ) async throws -> Phase0ExportResultDTO {
        let protectedCacheURLs = protectedCacheURIs.compactMap { try? runtime.resolveFileURL($0) }
        return try await runtime.runExport(
            request: request,
            protectedCacheURLs: protectedCacheURLs,
            appliedSavedLook: appliedSavedLook,
            cameraProfile: cameraProfile,
            highlightMarkers: highlightMarkers
        ) { progress in
            DispatchQueue.main.async {
                Task { @MainActor in
                    onProgress(progress)
                }
            }
        }
    }

    func runHighlightReel(
        request: Phase0ExportRequestDTO,
        protectedCacheURIs: [String] = [],
        appliedSavedLook: SavedLookEntry? = nil,
        cameraProfile: CameraProfileSelection? = nil,
        highlightMarkers: FilmtoneHighlightMarkers?,
        onProgress: @escaping @MainActor (Phase0ExportProgressDTO) -> Void
    ) async throws -> Phase0ExportResultDTO {
        let protectedCacheURLs = protectedCacheURIs.compactMap { try? runtime.resolveFileURL($0) }
        return try await runtime.runHighlightReel(
            request: request,
            protectedCacheURLs: protectedCacheURLs,
            appliedSavedLook: appliedSavedLook,
            cameraProfile: cameraProfile,
            highlightMarkers: highlightMarkers
        ) { progress in
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

    /// Share the exported media and, when present, the full Filmtone Connect
    /// companion set. Single-item share targets still receive the primary media
    /// because it's the first entry in `fileURLs`.
    ///
    /// When `packageFileURIs` is non-empty (DaVinci Connect package export
    /// path), every URI in the package is offered for sharing so the user can
    /// hand off the bundle as a single unit.
    @discardableResult
    func shareOutput(
        mediaURI: String,
        sidecarURI: String? = nil,
        packageFileURIs: [String]? = nil
    ) async throws -> Bool {
        guard let host = topPresentingViewController else {
            throw FilmtoneMediaError.bridgeUnavailable
        }
        if let packageFileURIs, !packageFileURIs.isEmpty {
            let urls = packageFileURIs.compactMap { try? runtime.resolveFileURL($0) }
            guard !urls.isEmpty else {
                throw FilmtoneMediaError.invalidURL(
                    filmtoneLocalized(
                        "filmtone.error.share.empty_package",
                        defaultValue: "No package files available to share.",
                        comment: "Error shown when DaVinci package share has no resolvable URIs."
                    )
                )
            }
            return try await runtime.shareOutput(
                fileURLs: urls,
                presenting: host
            )
        }
        return try await runtime.shareOutput(
            uri: mediaURI,
            sidecarUri: sidecarURI,
            packageFileUris: packageFileURIs,
            presenting: host
        )
    }

    func fileExists(uri: String) -> Bool {
        runtime.fileExists(uri: uri)
    }

    func reclaimCache(protecting uris: [String]) {
        let urls = uris.compactMap { try? runtime.resolveFileURL($0) }
        cacheMaintenanceQueue.async { [cacheStore] in
            _ = try? cacheStore.pruneStandard(protecting: urls)
        }
    }

    func cacheInventory() async -> CacheInventoryDTO? {
        await withCheckedContinuation { (continuation: CheckedContinuation<CacheInventoryDTO?, Never>) in
            cacheMaintenanceQueue.async { [runtime] in
                let snapshot = try? runtime.cacheInventorySnapshot()
                continuation.resume(returning: snapshot)
            }
        }
    }

    func releaseCache(protecting uris: [String]) async -> CacheReleaseResultDTO? {
        await withCheckedContinuation { (continuation: CheckedContinuation<CacheReleaseResultDTO?, Never>) in
            cacheMaintenanceQueue.async { [runtime] in
                let result = try? runtime.releaseCache(protectedURIs: uris)
                continuation.resume(returning: result)
            }
        }
    }

    @discardableResult
    func removeLocalFiles(uris: [String]) -> Bool {
        let urls = uris.compactMap { try? runtime.resolveFileURL($0) }
        guard !urls.isEmpty else {
            return false
        }
        let result = try? cacheStore.removeGeneratedFiles(urls)
        return (result?.removedCount ?? 0) > 0
    }
}

private final class FilmtoneMemoryWarningState {
    var count = 0
}
