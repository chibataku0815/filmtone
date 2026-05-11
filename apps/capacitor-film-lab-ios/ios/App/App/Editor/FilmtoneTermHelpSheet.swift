import SwiftUI

/// Compact term-help sheet. Currently used to explain the LUT umbrella concept
/// from the camera profile card. Surface stays pure type — Moving Postcard rule:
/// front-stage stays quiet, the trigger icon is the only chrome.
struct FilmtoneTermHelpSheet: View {
    let title: String
    let bodyText: String
    let primarySubExplanation: String?
    let secondarySubExplanation: String?
    /// Tertiary block (Item 3, v1.3): used to surface the Saved LUTs /
    /// Saved Looks library so users learn that reuse is part of the model.
    /// Optional with a `nil` default to keep older callers source-compatible.
    let tertiarySubExplanation: String?
    let dismissLabel: String
    let onDismiss: () -> Void

    init(
        title: String,
        bodyText: String,
        primarySubExplanation: String?,
        secondarySubExplanation: String?,
        tertiarySubExplanation: String? = nil,
        dismissLabel: String,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.bodyText = bodyText
        self.primarySubExplanation = primarySubExplanation
        self.secondarySubExplanation = secondarySubExplanation
        self.tertiarySubExplanation = tertiarySubExplanation
        self.dismissLabel = dismissLabel
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.filmtoneAmber)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("filmtone.help.sheet.title")

                Spacer(minLength: 12)

                Button(action: onDismiss) {
                    Text(dismissLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.78))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("filmtone.help.sheet.dismiss")
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)

            Text(bodyText)
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .accessibilityIdentifier("filmtone.help.sheet.body")

            if primarySubExplanation != nil
                || secondarySubExplanation != nil
                || tertiarySubExplanation != nil {
                VStack(alignment: .leading, spacing: 12) {
                    if let primarySubExplanation {
                        Text(primarySubExplanation)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("filmtone.help.sheet.subA")
                    }

                    if let secondarySubExplanation {
                        Text(secondarySubExplanation)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("filmtone.help.sheet.subB")
                    }

                    if let tertiarySubExplanation {
                        Text(tertiarySubExplanation)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("filmtone.help.sheet.subC")
                    }
                }
                .padding(.top, 18)
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.fraction(0.42), .medium])
        .presentationDragIndicator(.visible)
    }
}
