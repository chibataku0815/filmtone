import AppKit
import SwiftUI

// M5-C.2a: snapshot-driven Look Picker + "Save Current Look…" button.
// Replaces the hardcoded `lookOptions` array previously baked into
// `GradeControls`. Built-in Stone / Urban appear ahead of user-saved
// looks because the store prepends them in `currentSnapshot()`.
//
// Visual posture matches `GradeControls` and `SourceProfileControls`
// (Pass 4 readability fix): white labels on dark-tinted `.clear` Liquid
// Glass with `.colorScheme(.dark)` on the AppKit-bridged Picker.

struct LookLibraryControls: View {
    @Bindable var state: EditorState
    @Bindable var library: LibraryViewModel

    /// Picker tag. `.none` clears the look, `.saved(uuid)` dispatches
    /// through the store's built-in / user routing.
    private enum Selection: Hashable {
        case none
        case saved(UUID)
    }

    private var selectionBinding: Binding<Selection> {
        Binding(
            get: {
                if let id = state.selectedSavedLookId {
                    return .saved(id)
                }
                return .none
            },
            set: { newValue in
                switch newValue {
                case .none:
                    state.clearSavedLookSelection()
                case .saved(let id):
                    Task { @MainActor in
                        if let entry = await library.loadLook(id: id) {
                            state.applySavedLook(entry)
                        }
                    }
                }
            }
        )
    }

    private var savedLooksHeader: String? {
        let userCount = library.snapshot.looks.filter { !$0.bundled }.count
        return userCount == 0 ? nil : "Saved"
    }

    /// Currently-selected user (non-bundled) Saved Look, or nil when the
    /// selection is None / built-in. Drives the rename / delete buttons'
    /// enabled state — bundled entries refuse those mutations at the
    /// actor layer, so we grey them out before the user even tries.
    private var selectedUserLook: SavedLookEntry? {
        guard let id = state.selectedSavedLookId,
              let entry = library.snapshot.lookEntry(id: id),
              !entry.bundled else {
            return nil
        }
        return entry
    }

    /// Currently-selected Saved Look regardless of bundled status.
    /// Drives the favorite button — built-ins persist favorite via the
    /// store's UserDefaults map (M5-H.2 parity with iOS), so favoriting
    /// stays available even when rename / delete cannot be.
    private var selectedAnyLook: SavedLookEntry? {
        guard let id = state.selectedSavedLookId else { return nil }
        return library.snapshot.lookEntry(id: id)
    }

    private var selectedLookLabel: String {
        guard let entry = selectedAnyLook else { return "None" }
        return "\(entry.favorite ? "★ " : "")\(entry.name)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Menu {
                Button {
                    selectionBinding.wrappedValue = .none
                } label: {
                    menuRow("None", selected: selectionBinding.wrappedValue == .none)
                }
                let bundled = library.snapshot.looks.filter { $0.bundled }
                let user = library.snapshot.looks.filter { !$0.bundled }
                if !bundled.isEmpty {
                    Section("Built-in") {
                        ForEach(bundled, id: \.id) { entry in
                            Button {
                                selectionBinding.wrappedValue = .saved(entry.id)
                            } label: {
                                menuRow(
                                    entry.name,
                                    selected: selectionBinding.wrappedValue == .saved(entry.id),
                                    favorite: entry.favorite
                                )
                            }
                        }
                    }
                }
                if !user.isEmpty {
                    Section(savedLooksHeader ?? "Saved") {
                        ForEach(user, id: \.id) { entry in
                            Button {
                                selectionBinding.wrappedValue = .saved(entry.id)
                            } label: {
                                menuRow(
                                    entry.name,
                                    selected: selectionBinding.wrappedValue == .saved(entry.id),
                                    favorite: entry.favorite
                                )
                            }
                        }
                    }
                }
            } label: {
                FilmtoneGlassMenuTrigger(
                    title: "Look",
                    value: selectedLookLabel,
                    systemImage: selectedAnyLook?.favorite == true ? "star.fill" : "sparkles",
                    accent: selectedAnyLook?.favorite == true ? Color.yellow : Color(red: 0.84, green: 0.72, blue: 1.0)
                )
            }
            .filmtoneGlassMenuChrome()

            // M5-H.2: inline favorite / rename / delete row. Always
            // visible so the controls are discoverable; disabled when
            // the selection is None or a built-in (Stone / Urban). This
            // is the Mac-native equivalent of iOS's per-row context menu.
            libraryActionRow

            Button {
                presentSavePrompt()
            } label: {
                Label("Save Current Look…", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
            .frame(width: 220)
            .filmtonePointingHandCursor()
        }
        .alert(
            "Library error",
            isPresented: Binding(
                get: { library.lastError != nil },
                set: { if !$0 { library.lastError = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) { library.lastError = nil }
            },
            message: {
                Text(library.lastError ?? "")
            }
        )
    }

    @ViewBuilder
    private var libraryActionRow: some View {
        let target = selectedUserLook
        let favoriteTarget = selectedAnyLook
        let isFavorite = favoriteTarget?.favorite ?? false
        HStack(spacing: 8) {
            Button {
                guard let favoriteTarget else { return }
                Task { @MainActor in
                    _ = await library.toggleFavorite(id: favoriteTarget.id)
                }
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(FilmtoneGlassIconButtonStyle(isActive: isFavorite))
            .help(isFavorite ? "Remove from favorites" : "Mark as favorite")
            .disabled(favoriteTarget == nil)
            .filmtonePointingHandCursor(favoriteTarget != nil)

            Button {
                guard let target else { return }
                presentRenamePrompt(for: target)
            } label: {
                Label("Rename", systemImage: "pencil")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
            .help("Rename Look")
            .disabled(target == nil)
            .filmtonePointingHandCursor(target != nil)

            Button {
                guard let target else { return }
                presentDeleteConfirm(for: target)
            } label: {
                Label("Delete", systemImage: "trash")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
            .help("Delete Look")
            .disabled(target == nil)
            .filmtonePointingHandCursor(target != nil)

            Spacer(minLength: 0)
        }
        .frame(width: 220, alignment: .leading)
    }

    @ViewBuilder
    private func menuRow(_ title: String, selected: Bool, favorite: Bool = false) -> some View {
        let displayTitle = "\(favorite ? "★ " : "")\(title)"
        if selected {
            Label(displayTitle, systemImage: "checkmark")
        } else {
            Text(displayTitle)
        }
    }

    private func presentSavePrompt() {
        let alert = NSAlert()
        alert.messageText = "Save current Look"
        alert.informativeText = "Name this Look so you can recall it later."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        textField.placeholderString = defaultName(for: library.snapshot)
        alert.accessoryView = textField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let typed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = typed.isEmpty ? defaultName(for: library.snapshot) : typed

        Task { @MainActor in
            // M5-G.1: pass the payload directly so LibraryViewModel
            // does not depend on the whole EditorState surface.
            let payload = state.currentLookSavePayload()
            if let saved = await library.saveCurrentLook(name: name, payload: payload) {
                state.selectedSavedLookId = saved.id
            }
        }
    }

    private func defaultName(for snapshot: LibrarySnapshot) -> String {
        let userCount = snapshot.looks.filter { !$0.bundled }.count
        return "Look \(userCount + 1)"
    }

    private func presentRenamePrompt(for entry: SavedLookEntry) {
        let alert = NSAlert()
        alert.messageText = "Rename Look"
        alert.informativeText = "Choose a new name for \"\(entry.name)\"."
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        textField.stringValue = entry.name
        textField.placeholderString = entry.name
        alert.accessoryView = textField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let typed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty, typed != entry.name else { return }

        Task { @MainActor in
            _ = await library.renameLook(id: entry.id, newName: typed)
        }
    }

    private func presentDeleteConfirm(for entry: SavedLookEntry) {
        let alert = NSAlert()
        alert.messageText = "Delete Look?"
        alert.informativeText = "\"\(entry.name)\" will be removed from your library. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        Task { @MainActor in
            let ok = await library.deleteLook(id: entry.id)
            if ok, state.selectedSavedLookId == entry.id {
                state.clearSavedLookSelection()
            }
        }
    }
}
