// Filmtone V2 native camera capture — focus and metering overlay.

import SwiftUI

#if os(iOS)

struct FilmtoneCaptureInteractionOverlay: View {
    let canAcceptTap: Bool
    let reticlePoint: CGPoint?
    let reticleVisible: Bool
    let onTap: (CGPoint, CGSize) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                onTap(value.location, geo.size)
                            }
                    )
                    .allowsHitTesting(canAcceptTap)

                if let reticlePoint {
                    focusReticle
                        .position(reticlePoint)
                        .opacity(reticleVisible ? 1.0 : 0.0)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("filmtone.capture.focusReticle")
                }
            }
        }
        .ignoresSafeArea()
    }

    private var focusReticle: some View {
        Image(systemName: "viewfinder")
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(.yellow)
            .frame(width: 64, height: 64)
            .shadow(color: .black.opacity(0.45), radius: 1, x: 0, y: 1)
    }
}

#endif
