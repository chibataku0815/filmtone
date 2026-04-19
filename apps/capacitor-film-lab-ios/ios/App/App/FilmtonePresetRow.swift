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
                    let cardShape = RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)

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
                            cardShape.fill(baseFill(isActive: isActive))
                        )
                        .overlay(
                            cardShape.strokeBorder(
                                isActive ? Color.filmtoneAmber : Color.white.opacity(0.06),
                                lineWidth: isActive ? 1.3 : 1
                            )
                        )
                        .shadow(color: Color.black.opacity(isActive ? 0.14 : 0.08), radius: isActive ? 8 : 4, x: 0, y: isActive ? 5 : 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func baseFill(isActive: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                isActive ? Color.filmtoneAmber.opacity(0.08) : Color.white.opacity(0.035),
                isActive ? Color.white.opacity(0.04) : Color.white.opacity(0.015),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func categoryLabel(for category: FilmtonePresetCategory) -> String {
        FilmtoneStringsCatalog.current.categoryLabel(for: category)
    }
}
