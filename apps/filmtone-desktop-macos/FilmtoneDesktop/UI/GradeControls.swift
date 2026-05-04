import SwiftUI

struct GradeControls: View {
    @Bindable var state: EditorState

    // M5-A.2: Look (the high layer) is the only user-facing color choice.
    // `state.presetName` stays pinned to `defaultName` (= reset) — the
    // Look's paramOverrides + cube are the SSOT, matching iOS
    // basePreset = "reset". Strength interpolates bareline ↔ Look.
    private static let lookOptions: [(label: String, slug: String?)] = [
        ("None", nil),
        ("Stone", "filmtone-creative-pack-01-stone"),
        ("Urban", "filmtone-creative-pack-01-urban"),
    ]

    private var strengthDisabled: Bool {
        // Strength only does work when a Look is active — without one,
        // the bareline pivot has no target to interpolate toward.
        state.lookSlug == nil
    }

    private var strengthPercent: Int {
        Int((state.presetStrength * 100).rounded())
    }

    private var lookBinding: Binding<String> {
        Binding(
            get: { state.lookSlug ?? "" },
            set: { newValue in
                let slug = newValue.isEmpty ? nil : newValue
                state.lookSlug = slug
                state.presetName = FilmtonePresetCatalog.defaultName
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Look", selection: lookBinding) {
                ForEach(Self.lookOptions, id: \.label) { option in
                    Text(option.label).tag(option.slug ?? "")
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
