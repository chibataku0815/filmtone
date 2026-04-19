import Foundation
import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class AssetPickerService: NSObject {
    private let cacheStore: CacheStore
    private var sourceContinuation: CheckedContinuation<SourceInfoDTO?, Error>?
    private var lutContinuation: CheckedContinuation<PickedLutFileDTO?, Error>?

    init(cacheStore: CacheStore) {
        self.cacheStore = cacheStore
        super.init()
    }

    @MainActor
    func pickSource(presenting viewController: UIViewController) async throws -> SourceInfoDTO? {
        guard sourceContinuation == nil else {
            throw FilmtoneMediaError.pickerUnavailable("A source picker is already active.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.sourceContinuation = continuation

            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = .any(of: [.videos, .images])
            configuration.selectionLimit = 1
            configuration.preferredAssetRepresentationMode = .current

            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            viewController.present(picker, animated: true)
        }
    }

    @MainActor
    func pickLutFile(presenting viewController: UIViewController) async throws -> PickedLutFileDTO? {
        guard lutContinuation == nil else {
            throw FilmtoneMediaError.pickerUnavailable("A LUT picker is already active.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.lutContinuation = continuation
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
            throw FilmtoneMediaError.unsupportedSource("The selected asset is not an image or video.")
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
                    continuation.resume(
                        throwing: FilmtoneMediaError.cacheFailed(error.localizedDescription)
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
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: FilmtoneMediaError.cacheFailed(error.localizedDescription))
                    return
                }

                guard let url else {
                    continuation.resume(
                        throwing: FilmtoneMediaError.cacheFailed("The selected file could not be staged.")
                    )
                    return
                }

                do {
                    let importedURL = try self.cacheStore.importItem(
                        from: url,
                        suggestedName: suggestedName,
                        bucket: bucket
                    )
                    continuation.resume(returning: importedURL)
                } catch {
                    continuation.resume(
                        throwing: FilmtoneMediaError.cacheFailed(error.localizedDescription)
                    )
                }
            }
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
        let continuation = lutContinuation
        lutContinuation = nil
        continuation?.resume(returning: nil)
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        let continuation = lutContinuation
        lutContinuation = nil

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
    }
}
