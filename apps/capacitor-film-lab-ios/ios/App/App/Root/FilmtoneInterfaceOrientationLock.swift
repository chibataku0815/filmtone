// Filmtone iOS scene orientation policy.
//
// Capture owns a tighter orientation contract than the editor.  The
// AppDelegate asks this object for the current supported mask; capture
// surfaces can temporarily change it without embedding scene policy in
// the SwiftUI view tree.

import UIKit

#if os(iOS)

@MainActor
enum FilmtoneInterfaceOrientationLock {
    private static let defaultMask: UIInterfaceOrientationMask = [
        .portrait,
        .landscapeLeft,
        .landscapeRight,
    ]

    private(set) static var currentMask: UIInterfaceOrientationMask = defaultMask

    static func allowDefaultOrientations() {
        currentMask = defaultMask
        requestGeometryUpdate(mask: defaultMask)
    }

    static func lockToPortrait() {
        currentMask = .portrait
        requestGeometryUpdate(mask: .portrait)
    }

    static func restoreDefault() {
        allowDefaultOrientations()
    }

    private static func requestGeometryUpdate(mask: UIInterfaceOrientationMask) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                markNeedsOrientationUpdate(window.rootViewController)
            }
            windowScene.requestGeometryUpdate(
                .iOS(interfaceOrientations: mask)
            ) { error in
                NSLog("[FilmtoneOrientation] geometry update failed: %@", error.localizedDescription)
            }
        }
    }

    private static func markNeedsOrientationUpdate(_ viewController: UIViewController?) {
        guard let viewController else { return }
        viewController.setNeedsUpdateOfSupportedInterfaceOrientations()
        for child in viewController.children {
            markNeedsOrientationUpdate(child)
        }
        markNeedsOrientationUpdate(viewController.presentedViewController)
    }
}

#endif
