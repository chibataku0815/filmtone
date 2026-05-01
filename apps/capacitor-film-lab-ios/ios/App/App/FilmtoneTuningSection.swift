import SwiftUI

struct FilmtoneTuningSection: View {
    @ObservedObject var store: FilmtoneEditorStore
    @Binding var strengthSheetPresented: Bool
    @Binding var savedLookSheet: SavedLookSheetMode?
    @Binding var lutTermHelpPresented: Bool
    @Binding var lutDeleteConfirmation: LutLibraryEntry?
    @Binding var lookDeleteConfirmation: SavedLookEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FilmtoneSectionHeader(title: store.strings.adjustLabel)
                .accessibilityIdentifier("filmtone.section.tuning")

            Button {
                strengthSheetPresented = true
            } label: {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.strings.adjustOpenLabel)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if let summary = adjustSummaryText {
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "slider.horizontal.3")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.filmtoneAmber.opacity(0.92))
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("filmtone.adjust.open")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("filmtone.adjust.open")

            FilmtoneCameraProfileCard(
                store: store,
                savedLookSheet: $savedLookSheet,
                lutTermHelpPresented: $lutTermHelpPresented,
                lutDeleteConfirmation: $lutDeleteConfirmation,
                lookDeleteConfirmation: $lookDeleteConfirmation
            )
        }
    }

    private var adjustSummaryText: String? {
        guard store.hasAnyAdjustments else {
            return nil
        }
        return store.adjustmentSummaryText
    }
}
