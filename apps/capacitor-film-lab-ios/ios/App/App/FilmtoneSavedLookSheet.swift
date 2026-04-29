import SwiftUI

/// Modal text-entry sheet for naming a Saved Look. Used both for the
/// "Save current Look…" flow (initialName = suggested default) and the
/// rename-from-long-press flow (initialName = existing entry name).
///
/// The sheet stays visually consistent with the existing `FilmtoneTermHelpSheet`
/// and `FilmtoneStrengthSheet` — same surface fill, same amber accent — so the
/// new modal doesn't introduce a competing visual language.
struct FilmtoneSavedLookSheet: View {
    enum Mode {
        case create
        case rename
    }

    let mode: Mode
    let strings: FilmtoneStrings
    let initialName: String
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    @State private var name: String
    @FocusState private var nameFocused: Bool

    init(
        mode: Mode,
        strings: FilmtoneStrings,
        initialName: String,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (String) -> Void
    ) {
        self.mode = mode
        self.strings = strings
        self.initialName = initialName
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        self._name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.filmtoneBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    Text(headlineText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .accessibilityIdentifier("filmtone.savedLookSheet.headline")

                    Text(bodyText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField(strings.savedLookNamePlaceholder, text: $name)
                        .focused($nameFocused)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .submitLabel(.done)
                        .onSubmit(submitIfValid)
                        .accessibilityIdentifier("filmtone.savedLookSheet.name")

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings.savedLookSheetCancel, action: onCancel)
                        .accessibilityIdentifier("filmtone.savedLookSheet.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitLabel, action: submitIfValid)
                        .disabled(!isValid)
                        .accessibilityIdentifier("filmtone.savedLookSheet.submit")
                }
            }
        }
        .onAppear {
            // Auto-focus so users can start typing immediately on the create
            // path. The rename path keeps the existing name selected so a
            // single keystroke replaces it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                nameFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var navigationTitle: String {
        switch mode {
        case .create:
            return strings.savedLookSheetCreateTitle
        case .rename:
            return strings.savedLookSheetRenameTitle
        }
    }

    private var headlineText: String {
        switch mode {
        case .create:
            return strings.savedLookSheetCreateHeadline
        case .rename:
            return strings.savedLookSheetRenameHeadline
        }
    }

    private var bodyText: String {
        strings.savedLookSheetBody
    }

    private var submitLabel: String {
        switch mode {
        case .create:
            return strings.savedLookSheetSave
        case .rename:
            return strings.savedLookSheetRename
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !trimmedName.isEmpty
    }

    private func submitIfValid() {
        guard isValid else {
            return
        }
        onSubmit(trimmedName)
    }
}
