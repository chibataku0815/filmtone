import SwiftUI

// M5-C.3a: Quick adjust 3-axis surface (filmCharacter / era / dynamics).
// Each axis is a signed slider in [-1, +1]; the values fold into the
// resolved render params via FilmtonePresetCatalog.applyQuickState. UI
// posture matches GradeControls / LookLibraryControls — explicit white
// text + Slider tint over the dark-tinted Liquid Glass right rail.

struct QuickAdjustControls: View {
    @Bindable var state: EditorState

    private var resetDisabled: Bool {
        !state.quickStateIsActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
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
            HStack {
                Spacer()
                Button("Reset Quick") {
                    state.resetQuickState()
                }
                .controlSize(.small)
                .disabled(resetDisabled)
            }
            .padding(.top, 2)
        }
        .frame(width: 220)
    }

    @ViewBuilder
    private func axisRow(
        title: String,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.white)
                Spacer()
                Text(signedPercent(value.wrappedValue))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
            Slider(
                value: value,
                in: FilmtonePhase0Generated.quickAxisMin...FilmtonePhase0Generated.quickAxisMax,
                step: FilmtonePhase0Generated.quickAxisStep
            )
            .tint(.white)
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
