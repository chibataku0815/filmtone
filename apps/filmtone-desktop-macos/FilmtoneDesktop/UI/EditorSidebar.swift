import SwiftUI

// M5-J1: Editing sidebar shell. Splits the right-rail panel stack out of
// `RootWindowView` so the chrome can:
//   1) reserve top inset for the macOS 26 unified toolbar (~52pt) plus a
//      small breathing margin, applied at the call site as 72pt;
//   2) reserve bottom inset for the floating `VideoScrubBar` (capsule
//      ~36pt + .padding(.bottom, 64) + visual breathing room) at 120pt;
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
                        LookLibraryControls(state: state, library: library)
                            .modifier(EditorSidebarPanelGlass())
                        QuickAdjustControls(state: state)
                            .modifier(EditorSidebarPanelGlass())
                        GradeControls(state: state)
                            .modifier(EditorSidebarPanelGlass())
                        ExportInspectorPanel(
                            state: state,
                            onExportTap: {
                                exportCoordinator.presentExportPanel(for: state)
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

// Per-panel glass posture extracted so every panel inside the sidebar
// uses the same Pass 4 dark-tinted .clear Apple Liquid Glass treatment
// the right rail already uses (M5-I.3 8px grid: 16/16 padding,
// cornerRadius 16). Extracted as a ViewModifier (rather than a free
// `View` extension) so the call site reads as a single `.modifier(...)`
// without duplicating the `.glassEffect` invocation across five callers.
private struct EditorSidebarPanelGlass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .glassEffect(
                .clear.tint(.black.opacity(0.30)),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }
}
