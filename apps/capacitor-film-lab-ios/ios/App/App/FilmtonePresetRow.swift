import SwiftUI

struct FilmtonePresetRow: View {
    let presets: [FilmtonePresetDescriptor]
    let activePresetName: String
    let onTap: (FilmtonePresetDescriptor, Bool) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(presets) { preset in
                    let isActive = preset.name == activePresetName

                    Button {
                        onTap(preset, isActive)
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(categoryLabel(for: preset.category))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(accentColor(for: preset.category).opacity(isActive ? 0.86 : 0.58))
                                .tracking(1.4)

                            Spacer(minLength: 22)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(preset.label)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)

                                Text(preset.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.58))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(15)
                        .frame(width: 136, height: 136, alignment: .bottomLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(baseFill(isActive: isActive))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isActive ? Color.filmtoneAmber : Color.white.opacity(0.08),
                                    lineWidth: isActive ? 1.6 : 1
                                )
                        )
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(isActive ? accentColor(for: preset.category) : Color.white.opacity(0.10))
                                .frame(height: isActive ? 2 : 1)
                        }
                        .shadow(color: Color.black.opacity(isActive ? 0.16 : 0.10), radius: isActive ? 12 : 6, x: 0, y: isActive ? 8 : 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func accentColor(for category: FilmtonePresetCategory) -> Color {
        switch category {
        case .filmStock:
            return Color.filmtoneAmber
        case .look:
            return Color.filmtoneSky
        case .utility:
            return .white.opacity(0.68)
        }
    }

    private func baseFill(isActive: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(isActive ? 0.09 : 0.035),
                Color.white.opacity(isActive ? 0.045 : 0.015),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func categoryLabel(for category: FilmtonePresetCategory) -> String {
        switch category {
        case .filmStock:
            return "FILM"
        case .look:
            return "LOOK"
        case .utility:
            return "UTILITY"
        }
    }
}
