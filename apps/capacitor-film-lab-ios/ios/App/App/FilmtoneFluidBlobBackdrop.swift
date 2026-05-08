// Filmtone editor empty-view fluid blob backdrop — SwiftUI wrapper.
//
// The shader (`FilmtoneFluidBlobBackdrop.metal`) covers the full
// screen at α=1 with a warm cream base + animated 8-blob pastel
// composite + chromatic aberration + film grain. The wrapper adds
// the グロー / halation pass: a blurred copy with
// `.blendMode(.plusLighter)` composites additively over the sharp
// pass, brightening blob regions and bleeding their color outward
// into the substrate. Blur radius pulses on a slow sin so the glow
// itself is also a dynamic effect (matching the user direction
// "効果自体もランダムアニメーションで変化させる").

import SwiftUI

#if os(iOS)

struct FilmtoneFluidBlobBackdrop: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let timeFloat = Float(t.truncatingRemainder(dividingBy: 1_000.0))

            // v5 glow tune-down. v4 used opacity 0.42 + radius 22-44pt
            // → blob centers blew out to white. The new range is
            // radius 14-22pt + opacity 0.12 so glow is a cinematic
            // refinement at blob edges, not a flashlight on the
            // composition. Frequency 0.067 stays independent from
            // chroma (0.071) and grain (0.083) pulses so the three
            // effects never re-sync.
            let glowRadius = 18.0 + 4.0 * Foundation.sin(t * 0.067)

            ZStack {
                // Sharp shader pass — base layer.
                shaderRect(time: timeFloat)

                // Glow / halation: subtle plusLighter overlay so
                // blob edges bleed warm light into nearby substrate
                // without saturating the centers.
                shaderRect(time: timeFloat)
                    .blur(radius: glowRadius)
                    .blendMode(.plusLighter)
                    .opacity(0.12)
            }
        }
    }

    /// One full-screen evaluation of the shader. The Rectangle is
    /// filled white (opaque) so the SwiftUI rasterizer commits pixels
    /// for `colorEffect` to invoke the shader; the shader ignores the
    /// input color and computes its own pastel pixel.
    private func shaderRect(time: Float) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.white)
                .colorEffect(
                    ShaderLibrary.filmtoneFluidBlobBackdrop(
                        .float2(Float(geometry.size.width),
                                Float(geometry.size.height)),
                        .float(time)
                    )
                )
        }
    }
}

#endif
