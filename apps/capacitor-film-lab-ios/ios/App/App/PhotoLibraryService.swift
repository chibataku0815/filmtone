import Foundation
import Photos

final class PhotoLibraryService {
    // Photos saves media only; sidecar stays in app container because Photos assets
    // don't support adjacent arbitrary files. Use share sheet / Files to move
    // the sidecar alongside the exported media.
    func saveToPhotos(fileURL: URL) async throws -> String? {
        let authorization = await requestAuthorizationIfNeeded()
        guard authorization == .authorized || authorization == .limited else {
            throw FilmtoneMediaError.permissionDenied(
                filmtoneLocalized(
                    "filmtone.error.photos.permission_denied",
                    defaultValue: "Photos access was denied.",
                    comment: "Error shown when photo library permission is denied."
                )
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            var localIdentifier: String?
            PHPhotoLibrary.shared().performChanges({
                let pathExtension = fileURL.pathExtension.lowercased()
                if ["mov", "mp4", "m4v"].contains(pathExtension) {
                    let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                    localIdentifier = request?.placeholderForCreatedAsset?.localIdentifier
                } else {
                    let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
                    localIdentifier = request?.placeholderForCreatedAsset?.localIdentifier
                }
            }, completionHandler: { success, error in
                if let error {
                    _ = error
                    continuation.resume(
                        throwing: FilmtoneMediaError.saveFailed(
                            filmtoneLocalized(
                                "filmtone.error.photos.save_failed",
                                defaultValue: "Saving to Photos couldn't be completed.",
                                comment: "Error shown when saving to Photos fails."
                            )
                        )
                    )
                    return
                }
                guard success else {
                    continuation.resume(
                        throwing: FilmtoneMediaError.saveFailed(
                            filmtoneLocalized(
                                "filmtone.error.photos.save_incomplete",
                                defaultValue: "Saving to Photos didn't complete.",
                                comment: "Error shown when Photos reports an incomplete save."
                            )
                        )
                    )
                    return
                }
                continuation.resume(returning: localIdentifier)
            })
        }
    }

    private func requestAuthorizationIfNeeded() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if current == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        return current
    }
}
