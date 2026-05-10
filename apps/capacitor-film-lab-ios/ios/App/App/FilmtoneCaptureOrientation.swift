// Filmtone capture video rotation contract (S6).
//
// AVFoundation now exposes `videoRotationAngle` as the non-deprecated
// rotation surface.  This file keeps those angles typed, normalized,
// and separate from SwiftUI scene orientation or cockpit layout.

import Foundation

#if os(iOS)

import CoreGraphics

struct FilmtoneCaptureVideoRotation: Equatable, Codable {
    /// Normalized AVFoundation rotation angle in degrees.
    /// Values are kept in [0, 360) and rounded to a small decimal
    /// precision so KVO noise does not churn package/sidecar truth.
    let degrees: Double

    static let identity = FilmtoneCaptureVideoRotation(degrees: Double(0))
    static let portraitPinned = FilmtoneCaptureVideoRotation(degrees: Double(90))

    init(degrees: CGFloat) {
        self.init(degrees: Double(degrees))
    }

    init(degrees: Double) {
        self.degrees = Self.normalize(degrees)
    }

    var avFoundationAngle: CGFloat {
        CGFloat(degrees)
    }

    var sidecarValue: String {
        if degrees.rounded() == degrees {
            return String(format: "%.0f", degrees)
        }
        return String(format: "%.3f", degrees)
    }

    private static func normalize(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 90 }
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        let positive = wrapped < 0 ? wrapped + 360 : wrapped
        return (positive * 1000).rounded() / 1000
    }
}

struct FilmtoneCaptureOrientationState: Equatable {
    var previewRotation: FilmtoneCaptureVideoRotation
    var captureRotation: FilmtoneCaptureVideoRotation

    static let portraitPinned = FilmtoneCaptureOrientationState(
        previewRotation: .portraitPinned,
        captureRotation: .portraitPinned
    )
}

#endif
