import SwiftUI

struct GradeControls: View {
    @Bindable var state: EditorState

    var body: some View {
        Picker("Look", selection: $state.presetName) {
            ForEach(FilmtonePresetCatalog.orderedNames, id: \.self) { name in
                Text(FilmtonePresetCatalog.displayName(for: name)).tag(name)
            }
        }
        .pickerStyle(.menu)
    }
}
