import SwiftUI

/// Compact term-help sheet. Currently used to explain the LUT umbrella concept
/// from the camera profile card. Surface stays pure type — Moving Postcard rule:
/// front-stage stays quiet, the trigger icon is the only chrome.
struct FilmtoneTermHelpSheet: View {
    let title: String
    let bodyText: String
    let primarySubExplanation: String?
    let secondarySubExplanation: String?
    let dismissLabel: String
    let onDismiss: () -> Void

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

            if primarySubExplanation != nil || secondarySubExplanation != nil {
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
                }
                .padding(.top, 18)
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.filmtoneBackground.ignoresSafeArea())
        .presentationDetents([.fraction(0.42), .medium])
        .presentationDragIndicator(.visible)
    }
}
