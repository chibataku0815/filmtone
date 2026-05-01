import SwiftUI

struct FilmtonePresetRow: View {
    let presets: [FilmtonePresetDescriptor]
    let activePresetName: String
    let onTap: (FilmtonePresetDescriptor, Bool) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets) { preset in
                    let isActive = preset.name == activePresetName

                    Button {
                        onTap(preset, isActive)
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(categoryLabel(for: preset.category))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isActive ? Color.filmtoneAmber.opacity(0.92) : Color.white.opacity(0.38))

                            Spacer(minLength: 18)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(preset.label)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(isActive ? .white : .white.opacity(0.92))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.92)

                                Text(preset.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(isActive ? 0.62 : 0.48))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(14)
                        .frame(width: 146, height: 136, alignment: .bottomLeading)
                        .background(
                            FilmtonePresetCardSurface(
                                palette: presetGlowPalette(for: preset),
                                isActive: isActive
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(isActive ? "Selected" : "")
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                    .accessibilityIdentifier("filmtone.preset.card.\(preset.name)")
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func categoryLabel(for category: FilmtonePresetCategory) -> String {
        FilmtoneStringsCatalog.current.categoryLabel(for: category)
    }
}

private struct FilmtonePresetGlowPalette {
    let primary: Color
    let secondary: Color
    let baseLift: Color
    let bottomOpacity: Double
}

private func presetGlowPalette(for preset: FilmtonePresetDescriptor) -> FilmtonePresetGlowPalette {
    switch preset.name {
    case "iphone":
        return FilmtonePresetGlowPalette(
            primary: Color.filmtoneSky,
            secondary: Color.filmtoneAmber,
            baseLift: Color.filmtoneSky,
            bottomOpacity: 0.82
        )
    case "softBlue":
        return FilmtonePresetGlowPalette(
            primary: Color.filmtoneSky,
            secondary: Color(red: 0.58, green: 0.86, blue: 1.0),
            baseLift: Color.filmtoneSky,
            bottomOpacity: 0.92
        )
    case "amberGlow":
        return FilmtonePresetGlowPalette(
            primary: Color.filmtoneAmber,
            secondary: Color(red: 1.0, green: 0.46, blue: 0.18),
            baseLift: Color.filmtoneAmber,
            bottomOpacity: 0.98
        )
    default:
        return FilmtonePresetGlowPalette(
            primary: Color.filmtoneAmber,
            secondary: Color.filmtoneSky,
            baseLift: Color.filmtoneAmber,
            bottomOpacity: 0.60
        )
    }
}

private struct FilmtonePresetCardSurface: View {
    let palette: FilmtonePresetGlowPalette
    let isActive: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)

        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                shape
                    .fill(baseFill)

                bottomGlow(in: proxy.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                shape
                    .strokeBorder(
                        palette.primary.opacity(isActive ? 0.22 : 0.08),
                        lineWidth: isActive ? 1.2 : 0.8
                    )
                    .blur(radius: 0.6)
                    .opacity(isActive ? 0.82 : 0.48)

                shape
                    .strokeBorder(
                        isActive ? palette.primary.opacity(0.74) : Color.white.opacity(0.075),
                        lineWidth: isActive ? 1.3 : 1
                    )
            }
            .clipShape(shape)
            .overlay(
                topSpecular(shape: shape)
            )
            .shadow(
                color: palette.primary.opacity(isActive ? 0.18 : 0.07),
                radius: isActive ? 12 : 7,
                x: 0,
                y: isActive ? 6 : 3
            )
            .shadow(
                color: Color.black.opacity(isActive ? 0.22 : 0.10),
                radius: isActive ? 14 : 7,
                x: 0,
                y: isActive ? 8 : 3
            )
        }
    }

    private var intensity: Double {
        isActive ? 1.0 : 0.48
    }

    private var baseFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.filmtoneBackground.opacity(0.98),
                palette.baseLift.opacity(isActive ? 0.085 : 0.040),
                Color.black.opacity(0.76),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .shadow(.inner(color: Color.black.opacity(isActive ? 0.76 : 0.62), radius: isActive ? 14 : 11, x: 0, y: 8))
        .shadow(.inner(color: palette.primary.opacity((isActive ? 0.36 : 0.16) * palette.bottomOpacity), radius: isActive ? 18 : 12, x: 0, y: -10))
        .shadow(.inner(color: Color.white.opacity(isActive ? 0.10 : 0.045), radius: 5, x: 0, y: -3))
    }

    private func bottomGlow(in size: CGSize) -> some View {
        let glowHeight = max(size.height * 0.35, 1)

        return VStack(spacing: 0) {
            Spacer(minLength: 0)

            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.secondary.opacity((isActive ? 0.48 : 0.18) * palette.bottomOpacity),
                                palette.primary.opacity((isActive ? 0.34 : 0.14) * palette.bottomOpacity),
                                Color.clear,
                            ],
                            center: .bottom,
                            startRadius: 0,
                            endRadius: size.width * (isActive ? 0.74 : 0.62)
                        )
                    )
                    .frame(width: size.width * 1.16, height: glowHeight * 1.18)
                    .offset(y: glowHeight * 0.16)
                    .blur(radius: isActive ? 6 : 4)

                LinearGradient(
                    colors: [
                        Color.clear,
                        palette.primary.opacity((isActive ? 0.34 : 0.11) * intensity),
                        palette.secondary.opacity((isActive ? 0.30 : 0.08) * intensity),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: size.width, height: glowHeight)
                .blur(radius: isActive ? 3 : 2)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.primary.opacity((isActive ? 0.50 : 0.16) * palette.bottomOpacity),
                                palette.secondary.opacity((isActive ? 0.42 : 0.13) * palette.bottomOpacity),
                                palette.primary.opacity((isActive ? 0.46 : 0.15) * palette.bottomOpacity),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size.width * (isActive ? 0.82 : 0.64), height: isActive ? 2.4 : 1.4)
                    .blur(radius: isActive ? 2.4 : 1.6)
                    .offset(y: -1)
            }
            .frame(width: size.width, height: glowHeight)
        }
        .frame(width: size.width, height: size.height)
        .mask(
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.38),
                        Color.black,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: glowHeight)
            }
        )
        .allowsHitTesting(false)
    }

    private func topSpecular(shape: RoundedRectangle) -> some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isActive ? 0.10 : 0.055),
                        Color.white.opacity(0.012),
                        Color.clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}
