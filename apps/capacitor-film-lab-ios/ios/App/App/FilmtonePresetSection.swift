import SwiftUI

struct FilmtonePresetSection: View {
    @ObservedObject var store: FilmtoneEditorStore
    @Binding var strengthSheetPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                FilmtoneSectionHeader(title: store.strings.presetTitle)
                    .accessibilityIdentifier("filmtone.section.presets")

                Spacer(minLength: 12)

                if store.hasPresetCustomValues {
                    Button {
                        store.restoreActivePresetDefaults()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption.weight(.semibold))

                            Text(store.strings.presetDefaultLabel)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.filmtoneAmber.opacity(0.92))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.045))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.filmtoneAmber.opacity(0.16), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("filmtone.preset.default")
                }
            }

            FilmtonePresetRow(
                presets: FilmtonePresetCatalog.all,
                activePresetName: store.project.presetName
            ) { preset, isActive in
                if isActive {
                    strengthSheetPresented = true
                } else {
                    store.selectPreset(preset.name)
                }
            }
        }
    }
}
