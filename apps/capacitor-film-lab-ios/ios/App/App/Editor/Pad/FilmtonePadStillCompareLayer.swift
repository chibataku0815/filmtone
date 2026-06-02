import FilmLabSwiftCore
import SwiftUI
import UIKit

/// iPad still preview compare layer (M3).
///
/// iPad equivalent of the Desktop `StillCompareLayer` in
/// `apps/filmtone-desktop-macos/.../PreviewSurface.swift`. Loads the graded
/// poster and the pre-grade original poster from the URIs the iOS
/// preview orchestrator already publishes through
/// `FilmtoneComparePreviewFrame`. Aspect-fits both at the same extent so
/// the leading mask divides exactly along the media's own width even when
/// the parent letterboxes inside the iPad workspace canvas.
///
/// SwiftUI invalidation only — dragging the split fraction never triggers
/// a re-render of the grade pipeline. The iPhone fullscreen editor and
/// the Desktop preview are not touched.
///
/// URI → UIImage decoding is cached in `@State`. `UIImage(contentsOfFile:)`
/// is invoked exactly once per URI per appearance — drag updates to
/// `compareSplitFraction` only retrigger SwiftUI mask geometry, never the
/// file decode.
struct FilmtonePadStillCompareLayer: View {
    let frame: FilmtoneComparePreviewFrame
    let compareEnabled: Bool
    let compareSplitFraction: Double

    @State private var gradedImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var cachedGradedURI: String?
    @State private var cachedOriginalURI: String?

    var body: some View {
        ZStack {
            if let gradedImage {
                Image(uiImage: gradedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .accessibilityIdentifier("filmtone.pad.preview.still")
            }

            if compareEnabled, let originalImage {
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle()
                                .frame(
                                    width: geo.size.width
                                        * CGFloat(
                                            FilmtoneCompareSplitMath.clamp(compareSplitFraction)
                                        ),
                                    height: geo.size.height,
                                    alignment: .leading
                                )
                        }
                    }
                    .accessibilityIdentifier("filmtone.pad.preview.still.compareOriginal")
            }
        }
        .onAppear { reloadIfNeeded() }
        .onChange(of: frame.gradedURI) { _, _ in reloadIfNeeded() }
        .onChange(of: frame.originalURI) { _, _ in reloadIfNeeded() }
    }

    private func reloadIfNeeded() {
        if cachedGradedURI != frame.gradedURI {
            gradedImage = Self.loadImage(from: frame.gradedURI)
            cachedGradedURI = frame.gradedURI
        }
        if cachedOriginalURI != frame.originalURI {
            originalImage = Self.loadImage(from: frame.originalURI)
            cachedOriginalURI = frame.originalURI
        }
    }

    private static func loadImage(from uri: String) -> UIImage? {
        guard let url = URL(string: uri), url.isFileURL else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
