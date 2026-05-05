import FilmLabSwiftCore
import SwiftUI

// M5-C.3a: Quick adjust 3-axis surface (filmCharacter / era / dynamics).
// Each axis is a signed slider in [-1, +1]; the values fold into the
// resolved render params via FilmtonePresetCatalog.applyQuickState. UI
// posture matches GradeControls / LookLibraryControls — explicit white
// text + Slider tint over the dark-tinted Liquid Glass right rail.

struct QuickAdjustControls: View {
    @Bindable var state: EditorState

    @State private var advancedPopoverOpen = false

    private var resetDisabled: Bool {
        !state.quickStateIsActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Quick")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if state.paramOverridesActiveCount > 0 {
                    // M5-C.3b: surface the override count inline so the
                    // user sees that the popover holds active state even
                    // when it's closed.
                    Text("\(state.paramOverridesActiveCount) advanced")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.85), in: Capsule())
                }
            }
            axisRow(
                title: "Film",
                value: $state.quickState.filmCharacter
            )
            axisRow(
                title: "Era",
                value: $state.quickState.era
            )
            axisRow(
                title: "Dynamics",
                value: $state.quickState.dynamics
            )
            HStack(spacing: 8) {
                Spacer()
                Button("Reset Quick") {
                    state.resetQuickState()
                }
                .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
                .disabled(resetDisabled)
                .filmtonePointingHandCursor(!resetDisabled)
                // M5-C.3b: opens the AdvancedAdjustEditor popover with
                // direct per-key access to the 30+ paramOverrides knobs
                // (iOS canonical FilmtoneStrengthSheet advanced section
                // equivalent).
                Button("Adjust…") {
                    advancedPopoverOpen = true
                }
                .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
                .help("Edit advanced per-parameter overrides")
                .filmtonePointingHandCursor()
                .popover(
                    isPresented: $advancedPopoverOpen,
                    arrowEdge: .trailing
                ) {
                    AdvancedAdjustEditor(state: state) {
                        advancedPopoverOpen = false
                    }
                }
            }
            .padding(.top, 0)
        }
        .frame(width: 220)
    }

    @ViewBuilder
    private func axisRow(
        title: String,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.white)
                Spacer()
                Text(signedPercent(value.wrappedValue))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
            FilmtoneGlassSlider(
                value: value,
                range: FilmtonePhase0Generated.quickAxisMin...FilmtonePhase0Generated.quickAxisMax,
                step: FilmtonePhase0Generated.quickAxisStep
            )
        }
    }

    private func signedPercent(_ value: Double) -> String {
        let rounded = (value * 100).rounded()
        let intValue = Int(rounded)
        if intValue > 0 {
            return "+\(intValue)%"
        }
        return "\(intValue)%"
    }
}
