import SwiftUI


struct FilmtoneHelpIconButton: View {
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.filmtoneAmber.opacity(0.84))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct FilmtoneDisclosureSection<Content: View>: View {
    let title: String
    let summary: String
    let accessibilityIdentifier: String
    let contentSpacing: CGFloat
    let helpAccessibilityLabel: String?
    @Binding var isExpanded: Bool
    let helpAction: (() -> Void)?
    let content: Content

    private var disclosureAnimation: Animation {
        .smooth(duration: 0.24, extraBounce: 0)
    }

    init(
        title: String,
        summary: String,
        accessibilityIdentifier: String,
        isExpanded: Binding<Bool>,
        contentSpacing: CGFloat = 16,
        helpAccessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            summary: summary,
            accessibilityIdentifier: accessibilityIdentifier,
            isExpanded: isExpanded,
            contentSpacing: contentSpacing,
            helpAccessibilityLabel: helpAccessibilityLabel,
            helpAction: nil,
            content: content
        )
    }

    init(
        title: String,
        summary: String,
        accessibilityIdentifier: String,
        isExpanded: Binding<Bool>,
        contentSpacing: CGFloat = 16,
        helpAccessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content,
        helpAction: @escaping () -> Void
    ) {
        self.title = title
        self.summary = summary
        self.accessibilityIdentifier = accessibilityIdentifier
        self._isExpanded = isExpanded
        self.contentSpacing = contentSpacing
        self.helpAccessibilityLabel = helpAccessibilityLabel
        self.helpAction = helpAction
        self.content = content()
    }

    private init(
        title: String,
        summary: String,
        accessibilityIdentifier: String,
        isExpanded: Binding<Bool>,
        contentSpacing: CGFloat,
        helpAccessibilityLabel: String?,
        helpAction: (() -> Void)?,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.summary = summary
        self.accessibilityIdentifier = accessibilityIdentifier
        self._isExpanded = isExpanded
        self.contentSpacing = contentSpacing
        self.helpAccessibilityLabel = helpAccessibilityLabel
        self.helpAction = helpAction
        self.content = content()
    }

    var body: some View {
        let sectionShape = RoundedRectangle(
            cornerRadius: filmtoneSurfaceCornerRadius,
            style: .continuous
        )

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Button {
                    withAnimation(disclosureAnimation) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(isExpanded ? 0.64 : 0.52))

                            if !summary.isEmpty {
                                Text(summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(isExpanded ? 0.84 : 0.76))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                        }

                        Spacer(minLength: 12)

                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(isExpanded ? 0.88 : 0.62))
                            .frame(width: 28, height: 28)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(accessibilityIdentifier)

                if let helpAction, let helpAccessibilityLabel {
                    FilmtoneHelpIconButton(
                        accessibilityLabel: helpAccessibilityLabel,
                        accessibilityIdentifier: "\(accessibilityIdentifier).help",
                        action: helpAction
                    )
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .opacity(isExpanded ? 1 : 0)

            if isExpanded {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
        .glassEffect(.regular, in: sectionShape)
        .clipShape(sectionShape)
        .animation(disclosureAnimation, value: isExpanded)
    }
}

