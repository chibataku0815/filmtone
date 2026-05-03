import SwiftUI

struct GradeControls: View {
    @Bindable var state: EditorState

    // M5-A.2: 2-tier picker. Look (top) is the high layer — None means
    // "no Creative LUT", picking a Look forces the underlying preset to
    // `reset` so the cube + paramOverrides are the only color expression.
    // Preset (bottom) is the low layer, only enabled when Look = None.
    private static let lookOptions: [(label: String, slug: String?)] = [
        ("None", nil),
        ("Stone", "filmtone-creative-pack-01-stone"),
        ("Urban", "filmtone-creative-pack-01-urban"),
    ]

    private var presetDisabled: Bool {
        state.lookSlug != nil
    }

    private var strengthDisabled: Bool {
        // Enabled when a Look is selected (Look strength controls the
        // bareline ↔ Look interpolation) OR when a non-reset preset is
        // selected. Pure reset has nothing to interpolate.
        state.lookSlug == nil && state.presetName == FilmtonePresetCatalog.defaultName
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
                if slug != nil {
                    // Pin the underlying preset to reset so the Look's
                    // paramOverrides + cube are the SSOT for color
                    // expression — matches iOS basePreset = "reset".
                    state.presetName = FilmtonePresetCatalog.defaultName
                }
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

            Picker("Preset", selection: $state.presetName) {
                ForEach(FilmtonePresetCatalog.orderedNames, id: \.self) { name in
                    Text(FilmtonePresetCatalog.displayName(for: name)).tag(name)
                }
            }
            .pickerStyle(.menu)
            .disabled(presetDisabled)
            .opacity(presetDisabled ? 0.5 : 1.0)

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
