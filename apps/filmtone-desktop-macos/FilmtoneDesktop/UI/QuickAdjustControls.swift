import FilmLabSwiftCore
import SwiftUI

// M5-C.3a: Quick adjust 3-axis surface (filmCharacter / era / dynamics).
// Each axis is a signed slider in [-1, +1]; the values fold into the
// resolved render params via FilmtonePresetCatalog.applyQuickState. UI
// posture matches LookLibraryControls — explicit white text + Slider tint
// over the dark-tinted Liquid Glass right rail.

struct QuickAdjustControls: View {
    @Bindable var state: EditorState

    @State private var advancedPopoverOpen = false

    private var resetDisabled: Bool {
        !state.quickStateIsActive
    }

    private var selectedOpticalFilterId: String {
        state.opticalFilterProfileId ?? FilmtoneOpticalFilterCatalog.noneIdentifier
    }

    private var selectedOpticalFilterLabel: String {
        FilmtoneOpticalFilterCatalog.profile(for: state.opticalFilterProfileId)?.shortLabel ?? "None"
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
            opticalFilterSection
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

    private var opticalFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Backlight Veil")
                    .font(.callout)
                    .foregroundStyle(.white)
                Spacer()
                Text(selectedOpticalFilterLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
            HStack(spacing: 6) {
                ForEach(Self.opticalFilterOptions, id: \.id) { option in
                    opticalFilterChip(option)
                }
            }
        }
    }

    private func opticalFilterChip(_ option: OpticalFilterOption) -> some View {
        let active = option.id == selectedOpticalFilterId
        return Button {
            state.opticalFilterProfileId = option.id == FilmtoneOpticalFilterCatalog.noneIdentifier
                ? nil
                : option.id
        } label: {
            Text(option.label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .foregroundStyle(active ? .black : .white.opacity(0.88))
                .background(
                    active ? Color.white.opacity(0.92) : Color.white.opacity(0.12),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(active ? 0 : 0.24), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(option.help)
        .filmtonePointingHandCursor()
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

    private static let opticalFilterOptions: [OpticalFilterOption] = [
        .init(
            id: FilmtoneOpticalFilterCatalog.noneIdentifier,
            label: "None",
            help: "Clear Backlight Veil"
        ),
    ] + FilmtoneOpticalFilterCatalog.profiles.map {
        .init(id: $0.id, label: $0.shortLabel, help: "Apply \($0.displayName)")
    }
}

private struct OpticalFilterOption {
    let id: String
    let label: String
    let help: String
}
