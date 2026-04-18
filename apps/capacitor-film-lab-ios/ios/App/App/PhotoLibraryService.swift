import Foundation
import Photos

final class PhotoLibraryService {
    func saveToPhotos(fileURL: URL) async throws -> String? {
        let authorization = await requestAuthorizationIfNeeded()
        guard authorization == .authorized || authorization == .limited else {
            throw FilmtoneMediaError.permissionDenied("Photos access was denied.")
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
                    continuation.resume(throwing: FilmtoneMediaError.saveFailed(error.localizedDescription))
                    return
                }
                guard success else {
                    continuation.resume(throwing: FilmtoneMediaError.saveFailed("Photos save did not complete."))
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
