import SwiftUI

// M5-J1: Editing sidebar shell. Splits the right-rail panel stack out of
// `RootWindowView` so the chrome can:
//   1) reserve top inset for the macOS 26 unified toolbar plus a small
//      breathing margin, applied at the call site;
//   2) reserve bottom inset for the floating `VideoScrubBar`, with portrait
//      using a tighter overlay inset than landscape;
//   3) clip vertical overflow into a ScrollView so a tall stack of
//      source / library / quick / grade / inspector panels never spills
//      past the window's bottom edge regardless of source state;
//   4) collapse cleanly so the preview can use the full window width
//      when the user is just viewing.
//
// Spacing follows the M5-I.3 8px grid that the right rail already uses:
// per-panel padding 16/16, container spacing 16, RoundedRectangle
// cornerRadius 16. Width is fixed at 320pt — narrow enough to keep the
// preview generous on a 1080-wide minimum window, wide enough that the
// iOS-canonical recipe rows in the panels do not wrap.
struct EditorSidebar: View {
    @Bindable var state: EditorState
    @Bindable var library: LibraryViewModel
    var exportCoordinator: ExportCoordinator

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .trailing, spacing: 16) {
                    if state.sourceURL != nil {
                        SourceProfileControls(state: state)
                            .modifier(EditorSidebarPanelGlass())
                        // M5-K2: Look + strength now live as one block
                        // inside `LookLibraryControls`. The standalone
                        // `GradeControls` panel was removed.
                        LookLibraryControls(state: state, library: library)
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
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 320)
    }
}

// Per-panel glass posture: dark-tinted .clear Apple Liquid Glass so each
// panel reads on top of the underlying media without a continuous backing
// rail that would feel like a fixed sidebar column. The tint stays in the
// 0.30–0.34 range so text remains readable on bright portrait footage
// while the panels still refract the media beneath.
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
