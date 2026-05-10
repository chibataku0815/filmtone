// Filmtone V2 native camera capture — Look picker sheet (M13-M-2).
//
// Sheet presented when the LOOK chip is tapped. Lists the built-in
// catalog (Filmtone / Stone / Urban / Noir) today; the sheet container is the
// long-term home for saved Looks and user-loaded LUT entries — those
// will append as additional sections without rewriting the picker.

import SwiftUI

#if os(iOS)

struct FilmtoneCaptureLookSheet: View {
    @Binding var selection: FilmtoneCaptureLook
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(FilmtoneCaptureLook.allCases) { look in
                        lookRow(look)
                    }
                } header: {
                    Text("Built-in")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                        .accessibilityIdentifier("filmtone.capture.lookSheet.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func lookRow(_ look: FilmtoneCaptureLook) -> some View {
        Button {
            FilmtoneCaptureHaptics.selection()
            selection = look
            onDismiss()
        } label: {
            HStack {
                Text(look.displayName)
                    .foregroundStyle(.primary)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                Spacer()
                if look == selection {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("filmtone.capture.lookSheet.\(look.id)")
        .accessibilityAddTraits(look == selection ? .isSelected : [])
    }
}

#endif
