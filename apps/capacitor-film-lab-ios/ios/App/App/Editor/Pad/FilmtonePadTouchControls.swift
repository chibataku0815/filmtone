import SwiftUI

enum FilmtonePadTouchMetrics {
    static let minimumControlHeight: CGFloat = 48
    static let prominentControlHeight: CGFloat = 52
    static let iconControlSize: CGFloat = 48
    static let sliderTouchHeight: CGFloat = 46
    static let controlCornerRadius: CGFloat = 12
    static let controlHorizontalPadding: CGFloat = 12
    static let controlVerticalPadding: CGFloat = 10
    static let gridSpacing: CGFloat = 10
    static let rowSpacing: CGFloat = 10
    static let sectionSpacing: CGFloat = 18
}

struct FilmtonePadTouchButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var isActive = false
    var activeFill = Color.filmtoneAmber.opacity(0.86)
    var inactiveFill = Color.white.opacity(0.06)
    var activeStroke = Color.clear
    var inactiveStroke = Color.white.opacity(0.12)
    var activeForeground = Color.black
    var inactiveForeground = Color.white.opacity(0.86)
    var minHeight = FilmtonePadTouchMetrics.minimumControlHeight

    init(
        isActive: Bool = false,
        activeFill: Color = Color.filmtoneAmber.opacity(0.86),
        inactiveFill: Color = Color.white.opacity(0.06),
        activeStroke: Color = Color.clear,
        inactiveStroke: Color = Color.white.opacity(0.12),
        activeForeground: Color = Color.black,
        inactiveForeground: Color = Color.white.opacity(0.86),
        minHeight: CGFloat = FilmtonePadTouchMetrics.minimumControlHeight
    ) {
        self.isActive = isActive
        self.activeFill = activeFill
        self.inactiveFill = inactiveFill
        self.activeStroke = activeStroke
        self.inactiveStroke = inactiveStroke
        self.activeForeground = activeForeground
        self.inactiveForeground = inactiveForeground
        self.minHeight = minHeight
    }

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: FilmtonePadTouchMetrics.controlCornerRadius,
            style: .continuous
        )

        configuration.label
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, FilmtonePadTouchMetrics.controlHorizontalPadding)
            .foregroundStyle(foregroundColor)
            .background(shape.fill(fillColor(isPressed: configuration.isPressed)))
            .overlay(shape.stroke(strokeColor, lineWidth: 0.75))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.42)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }

    private var foregroundColor: Color {
        isActive ? activeForeground : inactiveForeground
    }

    private var strokeColor: Color {
        isActive ? activeStroke : inactiveStroke
    }

    private func fillColor(isPressed: Bool) -> Color {
        let base = isActive ? activeFill : inactiveFill
        return isPressed ? base.opacity(0.78) : base
    }
}

struct FilmtonePadSliderControl: View {
    let title: String
    let valueText: String
    let valueAccessibilityIdentifier: String?
    let sliderAccessibilityIdentifier: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    var isActive = false
    var leadingIndicatorColor: Color?
    var resetAccessibilityIdentifier: String?
    var resetEnabled = false
    var resetAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: FilmtonePadTouchMetrics.rowSpacing) {
            HStack(spacing: 10) {
                if let leadingIndicatorColor {
                    Circle()
                        .fill(leadingIndicatorColor)
                        .frame(width: 8, height: 8)
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                valueLabel

                if let resetAction {
                    resetButton(action: resetAction)
                }
            }

            Slider(value: value, in: range)
                .tint(Color.filmtoneAmber)
                .frame(minHeight: FilmtonePadTouchMetrics.sliderTouchHeight)
                .contentShape(Rectangle())
                .accessibilityIdentifier(sliderAccessibilityIdentifier)
        }
        .padding(.horizontal, FilmtonePadTouchMetrics.controlHorizontalPadding)
        .padding(.vertical, FilmtonePadTouchMetrics.controlVerticalPadding)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(isActive ? 0.065 : 0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(isActive ? 0.12 : 0.07), lineWidth: 0.75)
        )
    }

    private var titleColor: Color {
        isActive ? Color.filmtoneAmber.opacity(0.92) : Color.white.opacity(0.88)
    }

    @ViewBuilder
    private var valueLabel: some View {
        let label = Text(valueText)
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(
                isActive ? Color.filmtoneAmber.opacity(0.82) : Color.white.opacity(0.62)
            )

        if let valueAccessibilityIdentifier {
            label.accessibilityIdentifier(valueAccessibilityIdentifier)
        } else {
            label
        }
    }

    private func resetButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.caption.weight(.semibold))
                .foregroundStyle(resetEnabled ? Color.white.opacity(0.78) : Color.white.opacity(0.24))
                .frame(
                    width: FilmtonePadTouchMetrics.iconControlSize,
                    height: FilmtonePadTouchMetrics.iconControlSize
                )
                .background(
                    Circle()
                        .fill(Color.white.opacity(resetEnabled ? 0.07 : 0.025))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!resetEnabled)
        .accessibilityIdentifier(resetAccessibilityIdentifier ?? "")
    }
}
