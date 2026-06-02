import FilmLabSwiftCore
import SwiftUI

/// iPad draggable split overlay (M3).
///
/// iPad equivalent of the Desktop `CompareSplitOverlay`. The handle is
/// constrained to the media's aspect-fit rect inside the preview region
/// so letterbox / pillarbox areas are not draggable and the drag-x maps
/// to the media's own width even when the parent letterboxes.
///
/// Hit target is sized for touch (56pt wide — Apple HIG minimum is 44pt;
/// we oversize so the user does not have to chase a thin grip mid-drag).
/// `NSCursor` from the Desktop overlay is intentionally absent — iPad
/// uses the grip glyph as the entire affordance.
struct FilmtonePadCompareSplitOverlay: View {
    @Binding var fraction: Double
    let mediaAspectRatio: CGFloat

    private static let hitTargetWidth: CGFloat = 56
    private static let gripDiameter: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let mediaRect = Self.aspectFitRect(aspect: mediaAspectRatio, in: geo.size)
            let clamped = FilmtoneCompareSplitMath.clamp(fraction)
            let handleX = mediaRect.minX + mediaRect.width * CGFloat(clamped)

            ZStack(alignment: .topLeading) {
                Color.clear

                Color.clear
                    .frame(width: Self.hitTargetWidth, height: mediaRect.height)
                    .contentShape(Rectangle())
                    .position(x: handleX, y: mediaRect.midY)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                guard mediaRect.width > 0 else { return }
                                let raw = (value.location.x - mediaRect.minX) / mediaRect.width
                                fraction = FilmtoneCompareSplitMath.clamp(Double(raw))
                            }
                    )
                    .accessibilityIdentifier(
                        FilmtoneEditorPreviewCommand.compareSplitHandle.iPadAccessibilityIdentifier
                    )
                    .accessibilityLabel(FilmtoneEditorPreviewCommand.compareSplitHandle.label)

                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 1.5, height: mediaRect.height)
                    .position(x: handleX, y: mediaRect.midY)
                    .allowsHitTesting(false)
                    .shadow(color: .black.opacity(0.45), radius: 1.5, x: 0, y: 0)

                CompareSplitGrip(diameter: Self.gripDiameter)
                    .position(x: handleX, y: mediaRect.midY)
                    .allowsHitTesting(false)
            }
        }
    }

    private static func aspectFitRect(aspect: CGFloat, in size: CGSize) -> CGRect {
        guard aspect > 0, size.width > 0, size.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let containerAspect = size.width / size.height
        if containerAspect > aspect {
            let width = size.height * aspect
            let x = (size.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: size.height)
        } else {
            let height = size.width / aspect
            let y = (size.height - height) / 2
            return CGRect(x: 0, y: y, width: size.width, height: height)
        }
    }
}

private struct CompareSplitGrip: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .frame(width: diameter, height: diameter)
            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.92))
        }
        .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 1)
    }
}
