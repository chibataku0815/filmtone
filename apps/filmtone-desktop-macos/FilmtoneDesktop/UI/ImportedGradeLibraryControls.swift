import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImportedGradeLibraryControls: View {
    @Bindable var state: EditorState
    @Bindable var library: ImportedGradeLibraryViewModel

    private enum Selection: Hashable {
        case none
        case imported(UUID)
    }

    private var selectionBinding: Binding<Selection> {
        Binding(
            get: {
                if let id = state.selectedImportedGradeId {
                    return .imported(id)
                }
                return .none
            },
            set: { next in
                switch next {
                case .none:
                    state.clearImportedGradeSelection()
                case .imported(let id):
                    Task { @MainActor in
                        if let look = await library.loadLook(id: id) {
                            let sidecarURL = await library.sidecarURL(id: id)
                            state.applyImportedGrade(look, sidecarURL: sidecarURL)
                        }
                    }
                }
            }
        )
    }

    private var selectedLabel: String {
        guard let look = state.selectedImportedGrade else { return "None" }
        return look.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Menu {
                Button {
                    selectionBinding.wrappedValue = .none
                } label: {
                    menuRow("None", selected: selectionBinding.wrappedValue == .none)
                }
                if !library.snapshot.looks.isEmpty {
                    Section("Imported") {
                        ForEach(library.snapshot.looks, id: \.id) { look in
                            Button {
                                selectionBinding.wrappedValue = .imported(look.id)
                            } label: {
                                menuRow(
                                    look.title,
                                    selected: selectionBinding.wrappedValue == .imported(look.id),
                                    source: look.source.sourceKindLabel
                                )
                            }
                        }
                    }
                }
            } label: {
                FilmtoneGlassMenuTrigger(
                    title: "Imported Grade",
                    value: selectedLabel,
                    systemImage: "square.stack.3d.up",
                    accent: Color(red: 0.62, green: 0.86, blue: 1.0)
                )
            }
            .filmtoneGlassMenuChrome()

            HStack(spacing: 8) {
                Button {
                    presentImportPanel()
                } label: {
                    Label("Import…", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(FilmtoneGlassSecondaryButtonStyle(compact: true))
                .filmtonePointingHandCursor()

                Button {
                    guard let id = state.selectedImportedGradeId else { return }
                    Task { @MainActor in
                        if await library.deleteLook(id: id) {
                            state.clearImportedGradeSelection()
                        }
                    }
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(FilmtoneGlassIconButtonStyle(isActive: false))
                .disabled(state.selectedImportedGradeId == nil)
                .filmtonePointingHandCursor(state.selectedImportedGradeId != nil)
            }
            .frame(width: 220)

            if let look = state.selectedImportedGrade,
               let sourceGraph = look.sourceGraph,
               !sourceGraph.unsupportedNotes.isEmpty {
                Text(sourceGraph.unsupportedNotes.joined(separator: " / "))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(3)
                    .frame(width: 220, alignment: .leading)
            }
        }
        .alert(
            "Imported Grade error",
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
    private func menuRow(_ title: String, selected: Bool, source: String? = nil) -> some View {
        HStack {
            if selected {
                Image(systemName: "checkmark")
            }
            VStack(alignment: .leading) {
                Text(title)
                if let source {
                    Text(source)
                }
            }
        }
    }

    private func presentImportPanel() {
        let panel = NSOpenPanel()
        var contentTypes: [UTType] = [.json]
        if let drxType = UTType(filenameExtension: "drx") {
            contentTypes.append(drxType)
        }
        panel.allowedContentTypes = contentTypes
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose a DaVinci .drx or Filmtone Imported Grade package"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { @MainActor in
            if let look = await library.importGrade(from: url) {
                let sidecarURL = await library.sidecarURL(id: look.id)
                state.applyImportedGrade(look, sidecarURL: sidecarURL)
            }
        }
    }
}
