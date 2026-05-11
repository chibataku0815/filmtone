import SwiftUI

enum FilmtoneLutControls {
    static func profileRow<MenuContent: View>(
        title: String,
        value: String,
        menuTitle: String,
        systemImage: String,
        menuIdentifier: String,
        helpAction: (() -> Void)? = nil,
        helpAccessibilityLabel: String? = nil,
        helpButtonIdentifier: String? = nil,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.52))

                    if let helpAction, let helpAccessibilityLabel {
                        Button {
                            helpAction()
                        } label: {
                            Label(helpAccessibilityLabel, systemImage: "info.circle")
                                .labelStyle(.iconOnly)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.filmtoneAmber.opacity(0.82))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(helpAccessibilityLabel))
                        .accessibilityIdentifier(helpButtonIdentifier ?? "filmtone.help.button")
                    }
                }

                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Menu(content: menuContent) {
                Label(menuTitle, systemImage: systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(menuIdentifier)
            }
            .accessibilityIdentifier(menuIdentifier)
        }
    }

    static func intensityControl(
        title: String,
        value: Double,
        valueIdentifier: String,
        sliderIdentifier: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        let clampedValue = FilmtonePhase0Math.clampLutIntensity(value)
        let percentLabel = intensityPercentLabel(clampedValue)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))

                Spacer()

                Text(percentLabel)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.filmtoneAmber.opacity(0.86))
                    .accessibilityIdentifier(valueIdentifier)
            }

            Slider(
                value: Binding(
                    get: { clampedValue },
                    set: { onChange($0) }
                ),
                in: 0...1
            )
            .tint(Color.filmtoneAmber)
            .accessibilityIdentifier(sliderIdentifier)
            .accessibilityLabel(title)
            .accessibilityValue(percentLabel)
        }
    }

    static func intensityPercentLabel(_ value: Double) -> String {
        "\(Int((FilmtonePhase0Math.clampLutIntensity(value) * 100).rounded()))%"
    }
}
