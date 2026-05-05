import AppKit
import SwiftUI

struct FilmtoneGlassMenuTrigger: View {
    let title: String
    let value: String
    let systemImage: String
    var accent: Color = Color(red: 0.60, green: 0.95, blue: 1.0)

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.callout.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18)
                    .foregroundStyle(.white.opacity(0.82))
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            Spacer(minLength: 10)
            HStack(spacing: 8) {
                Text(value)
                    .font(.callout.weight(.bold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .contentShape(Capsule())
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.16))
            )
            .glassEffect(
                .clear.tint(Color.white.opacity(0.16)),
                in: Capsule()
            )
            .overlay(alignment: .trailing) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.58, blue: 0.94).opacity(0.34),
                                accent.opacity(0.54)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 58, height: 22)
                    .blur(radius: 7)
                    .padding(.trailing, 4)
                    .allowsHitTesting(false)
            }
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
        }
        .frame(width: 220)
        .frame(minHeight: 40)
        .contentShape(Rectangle())
    }
}

struct FilmtoneGlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil

    private let trackHeight: CGFloat = 8
    private let knobSize: CGFloat = 32
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let ratio = normalizedRatio
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.60),
                                Color.white.opacity(0.26)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: trackHeight)
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: max(knobSize / 2, width * ratio), height: trackHeight)
                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: Color.black.opacity(0.20), radius: 8, x: 0, y: 4)
                    .offset(x: min(max(width * ratio - knobSize / 2, 0), width - knobSize))
            }
            .frame(height: knobSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }
                        updateValue(at: gesture.location.x, width: width)
                    }
                    .onEnded { gesture in
                        updateValue(at: gesture.location.x, width: width)
                        if isDragging {
                            isDragging = false
                            onEditingChanged?(false)
                        }
                    }
            )
            .filmtonePointingHandCursor()
            .onDisappear {
                if isDragging {
                    isDragging = false
                    onEditingChanged?(false)
                }
            }
        }
        .frame(height: knobSize)
    }

    private var normalizedRatio: CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        let clamped = min(range.upperBound, max(range.lowerBound, value))
        return CGFloat((clamped - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private func updateValue(at locationX: CGFloat, width: CGFloat) {
        let ratio = min(1.0, max(0.0, Double(locationX / max(width, 1))))
        var nextValue = range.lowerBound + (range.upperBound - range.lowerBound) * ratio
        if let step, step > 0 {
            nextValue = (nextValue / step).rounded() * step
        }
        value = min(range.upperBound, max(range.lowerBound, nextValue))
    }
}

struct FilmtoneGlassPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .foregroundStyle(.white.opacity(isEnabled ? 1.0 : 0.42))
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 36)
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 0.13 : 0.05))
            )
            .glassEffect(
                .clear.tint(Color.white.opacity(isEnabled ? 0.18 : 0.05)),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay(alignment: .trailing) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.92).opacity(0.42),
                                Color(red: 0.55, green: 1.0, blue: 0.98).opacity(0.58)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 64, height: 24)
                    .blur(radius: 10)
                    .opacity(isEnabled ? 1.0 : 0.18)
                    .padding(.trailing, 8)
                    .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.34 : 0.08), lineWidth: 1)
            )
            .shadow(color: Color(red: 0.55, green: 1.0, blue: 0.98).opacity(isEnabled ? 0.20 : 0.0), radius: 14, x: 0, y: 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.55)
    }
}

struct FilmtoneGlassSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font((compact ? Font.caption : Font.callout).weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .foregroundStyle(.white.opacity(isEnabled ? 0.92 : 0.38))
            .padding(.horizontal, compact ? 9 : 11)
            .padding(.vertical, compact ? 5 : 7)
            .frame(minHeight: compact ? 24 : 30)
            .contentShape(Capsule())
            .background(
                Capsule()
                    .fill(Color.white.opacity(isEnabled ? 0.10 : 0.04))
            )
            .glassEffect(
                .clear.tint(Color.white.opacity(isEnabled ? 0.10 : 0.03)),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isEnabled ? 0.16 : 0.06), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.48)
    }
}

struct FilmtoneGlassIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? Color.yellow.opacity(isEnabled ? 1.0 : 0.42) : Color.white.opacity(isEnabled ? 0.92 : 0.36))
            .frame(width: 28, height: 24)
            .contentShape(Capsule())
            .background(
                Capsule()
                    .fill(isActive ? Color.white.opacity(0.18) : Color.white.opacity(isEnabled ? 0.09 : 0.04))
            )
            .glassEffect(
                .clear.tint(Color.white.opacity(isEnabled ? 0.08 : 0.03)),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isEnabled ? 0.15 : 0.05), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.46)
    }
}

struct FilmtoneGlassSegmentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .foregroundStyle(isSelected ? Color.black.opacity(isEnabled ? 0.88 : 0.32) : Color.white.opacity(isEnabled ? 0.78 : 0.34))
            .frame(minWidth: 46, minHeight: 26)
            .contentShape(Capsule())
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(isEnabled ? 0.82 : 0.24) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.white.opacity(0.42) : Color.white.opacity(0.0), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.52)
    }
}

extension View {
    func filmtonePointingHandCursor(_ isActive: Bool = true) -> some View {
        modifier(FilmtonePointingHandCursorModifier(isActive: isActive))
    }

    func filmtoneGlassMenuChrome(isEnabled: Bool = true) -> some View {
        self
            .menuStyle(.button)
            .buttonStyle(.plain)
            .filmtonePointingHandCursor(isEnabled)
    }
}

private struct FilmtonePointingHandCursorModifier: ViewModifier {
    @Environment(\.isEnabled) private var environmentEnabled

    let isActive: Bool
    @State private var cursorPushed = false

    private var shouldShowCursor: Bool {
        environmentEnabled && isActive
    }

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering && shouldShowCursor {
                    pushCursorIfNeeded()
                } else {
                    popCursorIfNeeded()
                }
            }
            .onChange(of: environmentEnabled) { _, _ in
                if !shouldShowCursor {
                    popCursorIfNeeded()
                }
            }
            .onChange(of: isActive) { _, active in
                if !active {
                    popCursorIfNeeded()
                }
            }
            .onDisappear {
                popCursorIfNeeded()
            }
    }

    private func pushCursorIfNeeded() {
        guard !cursorPushed else { return }
        NSCursor.pointingHand.push()
        cursorPushed = true
    }

    private func popCursorIfNeeded() {
        guard cursorPushed else { return }
        NSCursor.pop()
        cursorPushed = false
    }
}
