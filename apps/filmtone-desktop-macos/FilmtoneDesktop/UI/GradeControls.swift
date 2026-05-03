import SwiftUI

struct GradeControls: View {
    @Bindable var state: EditorState

    private var strengthDisabled: Bool {
        state.presetName == FilmtonePresetCatalog.defaultName
    }

    private var strengthPercent: Int {
        Int((state.presetStrength * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Look", selection: $state.presetName) {
                ForEach(FilmtonePresetCatalog.orderedNames, id: \.self) { name in
                    Text(FilmtonePresetCatalog.displayName(for: name)).tag(name)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Strength")
                        .font(.callout)
                    Spacer()
                    Text("\(strengthPercent)%")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $state.presetStrength, in: 0...1)
                    .disabled(strengthDisabled)
            }
            .frame(width: 220)
            .opacity(strengthDisabled ? 0.5 : 1.0)
        }
    }
}
