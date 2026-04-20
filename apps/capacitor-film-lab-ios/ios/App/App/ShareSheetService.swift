import Foundation
import UIKit

@MainActor
final class ShareSheetService {
    func share(
        fileURL: URL,
        title: String?,
        text: String?,
        presenting viewController: UIViewController
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            var items: [Any] = []
            if let title, !title.isEmpty {
                items.append(title)
            }
            if let text, !text.isEmpty {
                items.append(text)
            }
            items.append(fileURL)

            let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
            controller.completionWithItemsHandler = { _, completed, _, error in
                if let error {
                    _ = error
                    continuation.resume(
                        throwing: FilmtoneMediaError.shareFailed(
                            filmtoneLocalized(
                                "filmtone.error.generic.share",
                                defaultValue: "Sharing couldn't be completed.",
                                comment: "Fallback error for sharing."
                            )
                        )
                    )
                    return
                }
                continuation.resume(returning: completed)
            }

            if let popover = controller.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.maxY - 40,
                    width: 1,
                    height: 1
                )
            }

            viewController.present(controller, animated: true)
        }
    }
}
