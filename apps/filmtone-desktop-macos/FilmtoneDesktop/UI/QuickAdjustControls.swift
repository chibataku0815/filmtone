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
            // M5-M (CC-B) / M8 follow-up: continuous intensity cursor (0…1).
            // Only mounted when a profile chip (1/8 / 1/4 / 1/2) is selected.
            // Earlier behavior kept the row visible-but-disabled when None
            // was selected; the dim slider read as broken hardware (visible
            // 100% number with an unmovable track). Removing the row when
            // there is nothing to scale leaves the panel with no inactive
            // widgets — chips alone communicate "off" by selection state.
            if state.opticalFilterProfileId != nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Intensity")
                            .font(.callout)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(intensityPercent(state.opticalFilterIntensity))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    FilmtoneGlassSlider(
                        value: $state.opticalFilterIntensity,
                        range: 0...1,
                        step: 0.01
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: state.opticalFilterProfileId)
    }

    private func intensityPercent(_ value: Double) -> String {
        let intValue = Int((value * 100).rounded())
        return "\(intValue)%"
    }

    private func opticalFilterChip(_ option: OpticalFilterOption) -> some View {
        let active = option.id == selectedOpticalFilterId
        return Button {
            let newProfileId: String? = option.id == FilmtoneOpticalFilterCatalog.noneIdentifier
                ? nil
                : option.id
            // M5-M (CC-B): when a density chip is selected for the first time
            // (or switched to a different density), reset intensity to 1.0 so
            // the chip-select experience matches the M5-L3 baseline. When
            // clearing to None, leave intensity intact (it has no effect when
            // profileId is nil) so re-selecting a chip restores a natural 1.0.
            if newProfileId != state.opticalFilterProfileId, newProfileId != nil {
                state.opticalFilterIntensity = 1.0
            }
            state.opticalFilterProfileId = newProfileId
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
                // M5-M (CC-B): align hit-test + hover region with the
                // visible capsule. Without an explicit contentShape the
                // chip's click + cursor area snaps to the rectangular
                // bounds of the Text frame, so the rounded capsule edges
                // sit outside the hit shape and the pointing-hand cursor
                // never engages over those bands.
                .contentShape(Capsule())
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
