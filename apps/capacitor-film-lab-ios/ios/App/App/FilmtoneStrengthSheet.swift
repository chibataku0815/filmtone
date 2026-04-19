import SwiftUI

struct FilmtoneStrengthSheet: View {
    @ObservedObject var store: FilmtoneEditorStore
    let onClose: () -> Void

    @State private var adjustmentsExpanded = false

    var body: some View {
        ZStack {
            Color.filmtoneBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 44, height: 5)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    header
                    strengthCard
                    adjustmentsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            if !adjustmentsExpanded {
                adjustmentsExpanded = hasQuickAdjustments
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(store.activePresetLabel)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)

                CompareHoldButton(label: store.strings.compareLabel) { isHeld in
                    store.setCompareHeld(isHeld)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button(store.strings.resetLabel) {
                    store.resetAdjustments()
                }
                .buttonStyle(FilmtoneSheetSecondaryActionStyle())

                Button(store.strings.doneLabel) {
                    onClose()
                }
                .buttonStyle(FilmtoneChromeActionStyle())
            }
        }
    }

    private var strengthCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.strings.strengthLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)

                    Text(Self.percentLabel(store.project.strength))
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                if hasQuickAdjustments {
                    Text(store.quickSummaryText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                }
            }

            FilmtoneSliderRow(
                label: store.strings.strengthLabel,
                value: store.project.strength,
                range: 0...1,
                format: { Self.percentLabel($0) }
            ) { value in
                store.setStrength(value)
            }
        }
        .padding(22)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var adjustmentsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    adjustmentsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.strings.adjustLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                            .textCase(.uppercase)

                        Text(adjustmentSummaryText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.leading)
                            .lineLimit(adjustmentsExpanded ? nil : 2)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .rotationEffect(.degrees(adjustmentsExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if adjustmentsExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    quickSummaryChips

                    FilmtoneSliderRow(
                        label: store.strings.quickFilmCharacter,
                        value: store.project.quickState.filmCharacter,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) }
                    ) { value in
                        store.setQuickValue(value, for: \.filmCharacter)
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickEra,
                        value: store.project.quickState.era,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) }
                    ) { value in
                        store.setQuickValue(value, for: \.era)
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickDynamics,
                        value: store.project.quickState.dynamics,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) }
                    ) { value in
                        store.setQuickValue(value, for: \.dynamics)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
        .padding(.top, 8)
    }

    private var quickSummaryChips: some View {
        let entries: [(String, Double)] = [
            (store.strings.quickFilmCharacter, store.project.quickState.filmCharacter),
            (store.strings.quickEra, store.project.quickState.era),
            (store.strings.quickDynamics, store.project.quickState.dynamics),
        ]
        .filter { abs($0.1) >= 0.01 }

        return Group {
            if entries.isEmpty {
                Text(store.strings.quickHint)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.56))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entries, id: \.0) { entry in
                            Text("\(entry.0) \(Self.signedPercentLabel(entry.1))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.78))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.03), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var adjustmentSummaryText: String {
        hasQuickAdjustments ? store.quickSummaryText : store.strings.quickHint
    }

    private var hasQuickAdjustments: Bool {
        abs(store.project.quickState.filmCharacter) >= 0.01 ||
            abs(store.project.quickState.era) >= 0.01 ||
            abs(store.project.quickState.dynamics) >= 0.01
    }

    private static func percentLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func signedPercentLabel(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(Int((value * 100).rounded()))%"
    }
}

private struct CompareHoldButton: View {
    let label: String
    let onPressingChanged: (Bool) -> Void

    var body: some View {
        Label(label, systemImage: "square.on.square")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.filmtoneAmber, in: Capsule())
            .contentShape(Capsule())
            .onLongPressGesture(
                minimumDuration: 0.18,
                maximumDistance: 22,
                pressing: { isPressing in
                    onPressingChanged(isPressing)
                },
                perform: {}
            )
    }
}

private struct FilmtoneSliderRow: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))

                Spacer()

                Text(format(value))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white.opacity(0.66))
            }

            Slider(value: Binding(get: { value }, set: onChange), in: range)
                .tint(Color.filmtoneAmber)
        }
    }
}

struct FilmtoneSheetSecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.04), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
