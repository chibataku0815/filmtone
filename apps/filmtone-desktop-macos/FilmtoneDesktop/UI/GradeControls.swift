import SwiftUI

// M5-C.2a: GradeControls is now strength-only. The Look picker moved
// out of here into `LookLibraryControls`, which is snapshot-driven and
// hosts both built-in catalog entries and user-saved Looks plus the
// "Save Current Look…" affordance.

struct GradeControls: View {
    @Bindable var state: EditorState

    private var strengthDisabled: Bool {
        // Strength only does work when a Look is active — without one,
        // the bareline pivot has no target to interpolate toward.
        state.lookSlug == nil
    }

    private var strengthPercent: Int {
        Int((state.presetStrength * 100).rounded())
    }

    var body: some View {
        // M5-B Pass 4: explicit white text + Slider tint give guaranteed
        // contrast on the dark-tinted Liquid Glass surface set by
        // RootWindowView.
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Strength")
                    .font(.callout)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(strengthPercent)%")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
            FilmtoneGlassSlider(value: $state.presetStrength, range: 0...1)
                .disabled(strengthDisabled)
        }
        .frame(width: 220)
        .opacity(strengthDisabled ? 0.5 : 1.0)
    }
}
