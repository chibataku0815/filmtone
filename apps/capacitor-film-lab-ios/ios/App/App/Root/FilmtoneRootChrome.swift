import SwiftUI


struct FilmtoneSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.5))
    }
}

struct FilmtoneTopChrome: View {
    let title: String
    let actionLabel: String
    let isActionDisabled: Bool
    let onAction: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                FilmtoneTopChromeTitle(title: title)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .glassEffect(
                        .regular.tint(Color.black.opacity(0.10)),
                        in: .rect(cornerRadius: 18.0)
                    )

                Button(action: onAction) {
                    Text(actionLabel)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.glassProminent)
                .disabled(isActionDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .accessibilityIdentifier("filmtone.topChrome")
    }
}

struct FilmtoneTopChromeTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .shadow(color: Color.black.opacity(0.26), radius: 4, x: 0, y: 1)
    }
}

struct UnsavedExportPrompt: View {
    let message: String
    let saveLabel: String
    let shareLabel: String
    let isSaving: Bool
    let onSave: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(saveLabel, action: onSave)
                    .buttonStyle(FilmtonePrimaryButtonStyle())
                    .disabled(isSaving)
                    .accessibilityIdentifier("filmtone.export.unsavedPrompt.save")

                Button(shareLabel, action: onShare)
                    .buttonStyle(FilmtoneSecondaryButtonStyle())
                    .disabled(isSaving)
                    .accessibilityIdentifier("filmtone.export.unsavedPrompt.share")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular.tint(Color.black.opacity(0.18)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filmtone.export.unsavedPrompt")
    }
}

let filmtonePreviewCornerRadius: CGFloat = 24
let filmtoneSurfaceCornerRadius: CGFloat = 12
let filmtoneControlCornerRadius: CGFloat = 10

extension Color {
    static let filmtoneAmber = Color(red: 1.0, green: 0.72, blue: 0.25)
    static let filmtoneSky = Color(red: 0.45, green: 0.66, blue: 1.0)
    static let filmtoneBackground = Color(red: 0.02, green: 0.02, blue: 0.02)
}

/// Viewport-level toast view rendered as an overlay on the root `ZStack`.
///
/// Visual language is intentionally restrained: a compact rounded
/// rectangle with a thin `.ultraThinMaterial` fill tinted dark, an icon
/// matched to the `FilmtoneToast.Kind`, and text in the existing
/// `white.opacity(0.84)` body color. No new accent colors are introduced
/// (success uses `Color.filmtoneAmber`, info uses `Color.filmtoneSky`,
/// error uses the shared red).
struct FilmtoneToastView: View {
    let toast: FilmtoneToast

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Text(toast.message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(
            .regular.tint(iconColor.opacity(0.14)),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(toast.message))
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("filmtone.toast")
    }

    private var iconName: String {
        switch toast.kind {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch toast.kind {
        case .success:
            return Color.filmtoneAmber
        case .error:
            return .red
        case .info:
            return Color.filmtoneSky
        }
    }
}
