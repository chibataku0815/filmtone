import SwiftUI

// M5-J1 / M5-M.3: editing panel container. A single right-rail surface
// (`EditorSidebar`) is reused for both landscape and portrait sources — the
// only difference is which `@AppStorage` key drives its visibility:
//   - Landscape → `editorSidebarOpen` (default true). Rail is present from
//     launch; ⌘\ toggles it.
//   - Portrait → `editorPortraitInspectorOpen` (default false). Rail starts
//     hidden so the loaded portrait clip is fully visible; ⌘\ summons /
//     dismisses it. The summon transition is `.move(edge: .trailing)` so
//     the rail slides in/out from the right edge.
//
// The 4-panel content (`EditorPanelStack`) is shared across both, so Source /
// Look / Quick / Export behave identically regardless of source orientation.
//
// Posture decisions:
//   - Per-panel glass via `EditorSidebarPanelGlass` (RoundedRectangle 16,
//     dark-tinted .clear @ 0.32 opacity). No continuous backing rail —
//     each panel is a discrete glass capsule so the underlying media
//     refracts between panels.
//   - 16pt vertical spacing between panels, 4pt vertical breathing room
//     at the stack edges (M5-I.3 8px grid).
//   - Panels mount only when a source is loaded; the empty launch state
//     never shows the inspector chrome.
struct EditorSidebar: View {
    @Bindable var state: EditorState
    @Bindable var library: LibraryViewModel
    @Bindable var importedGradeLibrary: ImportedGradeLibraryViewModel
    var exportCoordinator: ExportCoordinator

    var body: some View {
        // M8: macOS 26 `GlassEffectContainer` was found to consume hit-test
        // events in the lower portion of the rail when video sources were
        // loaded — the morphing-between-glass-surfaces behavior installs an
        // NSView-backed surface that reads as part of the AppKit responder
        // chain and SwiftUI `.zIndex(2)` cannot reorder past it. Per-panel
        // `.glassEffect` (`EditorSidebarPanelGlass` modifier in
        // `EditorPanelStack` below) is innocent and renders independently.
        // Trade-off: panels no longer morph into adjacent panels, but each
        // remains a discrete Liquid Glass capsule with full hit testing.
        ScrollView(.vertical, showsIndicators: true) {
            EditorPanelStack(
                state: state,
                library: library,
                importedGradeLibrary: importedGradeLibrary,
                exportCoordinator: exportCoordinator
            )
            .frame(maxWidth: .infinity)
        }
        .frame(width: 320)
        .contentShape(Rectangle())
    }
}

struct EditorPanelStack: View {
    @Bindable var state: EditorState
    @Bindable var library: LibraryViewModel
    @Bindable var importedGradeLibrary: ImportedGradeLibraryViewModel
    var exportCoordinator: ExportCoordinator

    var body: some View {
        VStack(spacing: 16) {
            if state.sourceURL != nil {
                SourceProfileControls(state: state)
                    .modifier(EditorSidebarPanelGlass())
                LookLibraryControls(state: state, library: library)
                    .modifier(EditorSidebarPanelGlass())
                ImportedGradeLibraryControls(state: state, library: importedGradeLibrary)
                    .modifier(EditorSidebarPanelGlass())
                QuickAdjustControls(state: state)
                    .modifier(EditorSidebarPanelGlass())
                ExportInspectorPanel(
                    state: state,
                    onExportTap: {
                        exportCoordinator.presentExportPanel(for: state)
                    },
                    onHighlightReelTap: {
                        exportCoordinator.presentHighlightReelPanel(for: state)
                    }
                )
                .modifier(EditorSidebarPanelGlass())
            }
        }
        .padding(.vertical, 4)
    }
}

// Per-panel glass posture: dark-tinted .clear Apple Liquid Glass so each
// panel reads on top of the underlying media without a continuous backing
// rail. Tint stays in the 0.30–0.34 range so text remains readable on
// bright portrait footage while the panels still refract the media beneath.
private struct EditorSidebarPanelGlass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .glassEffect(
                .clear.tint(.black.opacity(0.32)),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }
}
