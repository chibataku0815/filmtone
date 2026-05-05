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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Look", selection: selectionBinding) {
                Text("None").tag(Selection.none)
                let bundled = library.snapshot.looks.filter { $0.bundled }
                let user = library.snapshot.looks.filter { !$0.bundled }
                if !bundled.isEmpty {
                    Section("Built-in") {
                        ForEach(bundled, id: \.id) { entry in
                            Text(entry.name).tag(Selection.saved(entry.id))
                        }
                    }
                }
                if !user.isEmpty {
                    Section(savedLooksHeader ?? "Saved") {
                        ForEach(user, id: \.id) { entry in
                            Text(entry.name).tag(Selection.saved(entry.id))
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .colorScheme(.dark)
            .frame(width: 220)

            Button {
                presentSavePrompt()
            } label: {
                Label("Save Current Look…", systemImage: "square.and.arrow.down")
                    .font(.callout)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderless)
            .frame(width: 220, alignment: .leading)
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
}
