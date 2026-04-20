import Foundation
import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers

enum FilmtoneSourcePickerRoute: String, Codable, Sendable {
    case photoLibrary = "photo-library"
    case files
}

final class AssetPickerService: NSObject {
    private enum DocumentPickerPurpose {
        case source
        case lut
    }

    private let cacheStore: CacheStore
    private var sourceContinuation: CheckedContinuation<SourceInfoDTO?, Error>?
    private var lutContinuation: CheckedContinuation<PickedLutFileDTO?, Error>?
    private var activeDocumentPickerPurpose: DocumentPickerPurpose?

    init(cacheStore: CacheStore) {
        self.cacheStore = cacheStore
        super.init()
    }

    @MainActor
    func pickSource(
        presenting viewController: UIViewController,
        route: FilmtoneSourcePickerRoute = .photoLibrary
    ) async throws -> SourceInfoDTO? {
        guard sourceContinuation == nil, lutContinuation == nil else {
            throw FilmtoneMediaError.pickerUnavailable(
                filmtoneLocalized(
                    "filmtone.error.asset_picker.source_active",
                    defaultValue: "A source picker is already active.",
                    comment: "Error shown when a second source picker is opened while one is already active."
                )
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.sourceContinuation = continuation

            switch route {
            case .photoLibrary:
                var configuration = PHPickerConfiguration(photoLibrary: .shared())
                configuration.filter = .any(of: [.videos, .images])
                configuration.selectionLimit = 1
                configuration.preferredAssetRepresentationMode = .current

                let picker = PHPickerViewController(configuration: configuration)
                picker.delegate = self
                viewController.present(picker, animated: true)
            case .files:
                self.activeDocumentPickerPurpose = .source
                let picker = UIDocumentPickerViewController(
                    forOpeningContentTypes: [.image, .movie, .video],
                    asCopy: true
                )
                picker.delegate = self
                picker.allowsMultipleSelection = false
                viewController.present(picker, animated: true)
            }
        }
    }

    @MainActor
    func pickLutFile(presenting viewController: UIViewController) async throws -> PickedLutFileDTO? {
        guard sourceContinuation == nil, lutContinuation == nil else {
            throw FilmtoneMediaError.pickerUnavailable(
                filmtoneLocalized(
                    "filmtone.error.asset_picker.lut_active",
                    defaultValue: "A camera profile picker is already active.",
                    comment: "Error shown when a second LUT picker is opened while one is already active."
                )
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.lutContinuation = continuation
            self.activeDocumentPickerPurpose = .lut
            let cubeType = UTType(filenameExtension: "cube") ?? .plainText
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [cubeType, .plainText],
                asCopy: true
            )
            picker.delegate = self
            picker.allowsMultipleSelection = false
            viewController.present(picker, animated: true)
        }
    }

    private func importSource(from result: PHPickerResult) async throws -> SourceInfoDTO {
        let provider = result.itemProvider
        let movieType = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .movie) == true || UTType($0)?.conforms(to: .video) == true
        })
        let imageType = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .image) == true
        })

        let selectedType = movieType ?? imageType
        guard let selectedType else {
            throw FilmtoneMediaError.unsupportedSource(
                filmtoneLocalized(
                    "filmtone.error.asset_picker.selected_asset_type",
                    defaultValue: "The selected item isn't a photo or video.",
                    comment: "Error shown when an unsupported asset is selected from the photo picker."
                )
            )
        }

        let type = UTType(selectedType)
        let kind: FilmtoneSourceKind = type?.conforms(to: .image) == true ? .image : .video
        let importedURL: URL

        if kind == .video,
           let originalAssetURL = try await importSelectedVideoAsset(
               from: result,
               fallbackTypeIdentifier: selectedType,
               suggestedName: provider.suggestedName
           ) {
            importedURL = originalAssetURL
        } else {
            importedURL = try await importItemProviderFile(
                provider,
                typeIdentifier: selectedType,
                suggestedName: provider.suggestedName,
                bucket: .sources
            )
        }

        return SourceInfoDTO(
            uri: importedURL.absoluteString,
            filename: provider.suggestedName ?? importedURL.lastPathComponent,
            kind: kind,
            mimeType: type?.preferredMIMEType
        )
    }

    private func importSelectedVideoAsset(
        from result: PHPickerResult,
        fallbackTypeIdentifier: String,
        suggestedName: String?
    ) async throws -> URL? {
        guard let assetIdentifier = result.assetIdentifier else {
            return nil
        }

        let authorizationStatus = await ensurePhotoLibraryReadAuthorization()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return nil
        }

        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier],
            options: nil
        )
        guard let asset = fetchResult.firstObject else {
            return nil
        }

        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = preferredVideoResource(from: resources) else {
            return nil
        }

        let fallbackExtension =
            URL(fileURLWithPath: resource.originalFilename).pathExtension
                .nonEmpty
                ?? UTType(fallbackTypeIdentifier)?.preferredFilenameExtension
                ?? "mov"
        let destinationURL = try cacheStore.stagedItemURL(
            suggestedName: suggestedName ?? resource.originalFilename,
            fallbackExtension: fallbackExtension,
            bucket: .sources
        )

        try await writeAssetResource(resource, to: destinationURL)
        return destinationURL
    }

    private func preferredVideoResource(from resources: [PHAssetResource]) -> PHAssetResource? {
        let preferredTypes: [PHAssetResourceType] = [
            .fullSizeVideo,
            .video,
            .fullSizePairedVideo,
            .pairedVideo,
        ]

        for preferredType in preferredTypes {
            if let resource = resources.first(where: { $0.type == preferredType }) {
                return resource
            }
        }

        return resources.first(where: { resource in
            guard let type = UTType(resource.uniformTypeIdentifier) else {
                return false
            }
            return type.conforms(to: .movie) || type.conforms(to: .video)
        })
    }

    private func writeAssetResource(_ resource: PHAssetResource, to destinationURL: URL) async throws {
        let requestOptions = PHAssetResourceRequestOptions()
        requestOptions.isNetworkAccessAllowed = true

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: destinationURL,
                options: requestOptions
            ) { error in
                if let error {
                    _ = error
                    continuation.resume(
                        throwing: FilmtoneMediaError.cacheFailed(
                            filmtoneLocalized(
                                "filmtone.error.generic.pick_source",
                                defaultValue: "Media selection couldn't be completed.",
                                comment: "Fallback error for source picking."
                            )
                        )
                    )
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func ensurePhotoLibraryReadAuthorization() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return current
    }

    private func importDocumentSource(from url: URL) throws -> SourceInfoDTO {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let type = try sourceType(for: url)
        let kind: FilmtoneSourceKind = type.conforms(to: .image) ? .image : .video
        let importedURL = try cacheStore.importItem(
            from: url,
            suggestedName: url.lastPathComponent,
            bucket: .sources
        )

        return SourceInfoDTO(
            uri: importedURL.absoluteString,
            filename: url.lastPathComponent,
            kind: kind,
            mimeType: type.preferredMIMEType
        )
    }

    private func sourceType(for url: URL) throws -> UTType {
        if let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           isSupportedSourceType(contentType) {
            return contentType
        }

        if let type = UTType(filenameExtension: url.pathExtension),
           isSupportedSourceType(type) {
            return type
        }

        throw FilmtoneMediaError.unsupportedSource(
            filmtoneLocalized(
                "filmtone.error.asset_picker.selected_file_type",
                defaultValue: "The selected file isn't a photo or video.",
                comment: "Error shown when an unsupported file is selected from Files."
            )
        )
    }

    private func isSupportedSourceType(_ type: UTType) -> Bool {
        type.conforms(to: .image) || type.conforms(to: .movie) || type.conforms(to: .video)
    }

    private func importLut(from url: URL) throws -> PickedLutFileDTO {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let importedURL = try cacheStore.importItem(
            from: url,
            suggestedName: url.lastPathComponent,
            bucket: .luts
        )
        let text = try String(contentsOf: importedURL, encoding: .utf8)
        return PickedLutFileDTO(
            filename: importedURL.lastPathComponent,
            text: text,
            uri: importedURL.absoluteString
        )
    }

    private func importItemProviderFile(
        _ provider: NSItemProvider,
        typeIdentifier: String,
        suggestedName: String?,
        bucket: CacheStore.Bucket
    ) async throws -> URL {
        let cacheMessage = genericCacheMessage(for: bucket)
        let cacheStore = self.cacheStore
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    _ = error
                    continuation.resume(
                        throwing: FilmtoneMediaError.cacheFailed(cacheMessage)
                    )
                    return
                }

                guard let url else {
                    continuation.resume(
                        throwing: FilmtoneMediaError.cacheFailed(cacheMessage)
                    )
                    return
                }

                do {
                    let importedURL = try cacheStore.importItem(
                        from: url,
                        suggestedName: suggestedName,
                        bucket: bucket
                    )
                    continuation.resume(returning: importedURL)
                } catch {
                    continuation.resume(
                        throwing: FilmtoneMediaError.cacheFailed(cacheMessage)
                    )
                }
            }
        }
    }

    private func genericCacheMessage(for bucket: CacheStore.Bucket) -> String {
        switch bucket {
        case .luts:
            return filmtoneLocalized(
                "filmtone.error.generic.import_lut",
                defaultValue: "The camera profile couldn't be imported.",
                comment: "Fallback error for LUT import."
            )
        default:
            return filmtoneLocalized(
                "filmtone.error.generic.pick_source",
                defaultValue: "Media selection couldn't be completed.",
                comment: "Fallback error for source picking."
            )
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

extension AssetPickerService: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let continuation = sourceContinuation
        sourceContinuation = nil
        picker.dismiss(animated: true)

        guard let continuation else { return }
        guard let result = results.first else {
            continuation.resume(returning: nil)
            return
        }

        Task {
            do {
                let picked = try await importSource(from: result)
                continuation.resume(returning: picked)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

extension AssetPickerService: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        switch activeDocumentPickerPurpose {
        case .source:
            let continuation = sourceContinuation
            sourceContinuation = nil
            activeDocumentPickerPurpose = nil
            continuation?.resume(returning: nil)
        case .lut:
            let continuation = lutContinuation
            lutContinuation = nil
            activeDocumentPickerPurpose = nil
            continuation?.resume(returning: nil)
        case .none:
            break
        }
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        switch activeDocumentPickerPurpose {
        case .source:
            let continuation = sourceContinuation
            sourceContinuation = nil
            activeDocumentPickerPurpose = nil

            guard let continuation else { return }
            guard let url = urls.first else {
                continuation.resume(returning: nil)
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let picked = try self.importDocumentSource(from: url)
                    continuation.resume(returning: picked)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        case .lut:
            let continuation = lutContinuation
            lutContinuation = nil
            activeDocumentPickerPurpose = nil

            guard let continuation else { return }
            guard let url = urls.first else {
                continuation.resume(returning: nil)
                return
            }

            do {
                let picked = try importLut(from: url)
                continuation.resume(returning: picked)
            } catch {
                continuation.resume(throwing: error)
            }
        case .none:
            break
        }
    }
}
