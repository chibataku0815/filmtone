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
    let userLuts: [LutLibraryEntry]
    let isImportingUserLut: Bool
    let onImportUserLut: () -> Void
    let onSelectUserLut: (LutLibraryEntry) -> Void
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
                Section {
                    Button(action: onImportUserLut) {
                        HStack(spacing: 12) {
                            Image(systemName: isImportingUserLut ? "hourglass" : "square.and.arrow.down")
                                .frame(width: 22)
                            Text(isImportingUserLut ? "Importing..." : "Import .cube LUT")
                                .foregroundStyle(.primary)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(isImportingUserLut)
                    .accessibilityIdentifier("filmtone.capture.lookSheet.importUserLut")

                    ForEach(userLuts, id: \.id) { entry in
                        userLutRow(entry)
                    }
                } header: {
                    Text("User LUT")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Filmtone handles Apple Log 2 conversion before this creative LUT slot.")
                        .font(.footnote)
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

    @ViewBuilder
    private func userLutRow(_ entry: LutLibraryEntry) -> some View {
        Button {
            FilmtoneCaptureHaptics.selection()
            onSelectUserLut(entry)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .foregroundStyle(.primary)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                    Text("\(entry.size)^3 creative LUT")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                Spacer()
                if selection.libraryLutId == entry.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("filmtone.capture.lookSheet.userLut.\(entry.id.uuidString)")
        .accessibilityAddTraits(selection.libraryLutId == entry.id ? .isSelected : [])
    }
}

#endif
