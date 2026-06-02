import FilmLabSwiftCore
import SwiftUI

/// Desktop-derived iPad workspace shell.
///
/// Replaces the iPhone fullscreen editor for every iPad session
/// (regular and compact width) with a preview-centered workspace:
/// black canvas, top toolbar, and adaptive inspector.  iPhone targets
/// keep the iPhone fullscreen editor — route owned by
/// `FilmtoneRootView.iPhoneRouteBody`.
///
/// Adaptive layout:
/// - **Regular width** (full-screen iPad or wide Split View): inspector
///   rail sits beside the preview as a side-by-side `HStack`.
/// - **Compact width** (narrow Split View, Slide Over, iPad on
///   external display in a narrow window): inspector is presented as
///   a bottom sheet so the preview gets the full available canvas.
///   The toolbar's Inspector button toggles the sheet instead of the
///   inline rail.
///
/// Source-nil sessions still mount the workspace.  The preview surface
/// owns its own Desktop-style empty state (`emptyPreviewLabel`) and the
/// inspector hides until a source is loaded — Desktop parity with
/// `EditorPanelStack`'s `if state.sourceURL != nil` gate.
struct FilmtonePadWorkspaceView: View {
    @ObservedObject var store: FilmtoneEditorStore
    let onClose: () -> Void
    let onSaveLook: () -> Void
    let onReplaceSource: () -> Void
    let savedLookSheet: Binding<SavedLookSheetMode?>
    let lutDeleteConfirmation: Binding<LutLibraryEntry?>
    let lookDeleteConfirmation: Binding<SavedLookEntry?>
    let activeHelpTopic: Binding<FilmtoneAdjustmentHelpTopic?>

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var inlineInspectorVisible: Bool = true
    @State private var sheetInspectorPresented: Bool = false
    @State private var focusedInspectorPanel: FilmtoneEditorPanelID?
    @State private var compareEnabled: Bool = false
    @State private var compareSplitFraction: Double = 0.5

    private static let inspectorWidth: CGFloat = 340
    private static let toolbarReservedHeight: CGFloat = 64

    var body: some View {
        let compact = horizontalSizeClass == .compact
        let hasSource = store.source != nil

        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            HStack(spacing: compact ? 0 : 16) {
                FilmtonePadPreviewSurface(
                    store: store,
                    compareEnabled: $compareEnabled,
                    compareSplitFraction: $compareSplitFraction
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !compact && inlineInspectorVisible && hasSource {
                    inspectorRail
                        .frame(width: Self.inspectorWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, compact ? 12 : 20)
            .padding(.top, Self.toolbarReservedHeight)
            .padding(.bottom, 20)

            FilmtonePadToolbar(
                store: store,
                compareEnabled: $compareEnabled,
                inspectorVisible: inspectorBinding(compact: compact, hasSource: hasSource),
                onClose: onClose,
                onReplaceSource: onReplaceSource,
                onExport: {
                    focusInspectorPanel(.export, compact: compact, hasSource: hasSource)
                }
            )
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: inlineInspectorVisible)
        .animation(.easeInOut(duration: 0.24), value: hasSource)
        .accessibilityIdentifier("filmtone.pad.workspace")
        .sheet(isPresented: $sheetInspectorPresented) {
            if hasSource {
                inspectorRail
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    /// Compact-vs-regular-aware binding the toolbar uses to read /
    /// toggle the inspector. The toolbar surface stays unchanged; the
    /// workspace decides whether the toggle drives the inline rail or
    /// the bottom sheet.
    ///
    /// When no source is loaded, the toggle is a no-op — the inspector
    /// hides until a source is present (Desktop parity with
    /// `EditorPanelStack`'s `if state.sourceURL != nil` gate).
    private func inspectorBinding(compact: Bool, hasSource: Bool) -> Binding<Bool> {
        Binding(
            get: {
                guard hasSource else { return false }
                return compact ? sheetInspectorPresented : inlineInspectorVisible
            },
            set: { newValue in
                guard hasSource else { return }
                if compact {
                    sheetInspectorPresented = newValue
                } else {
                    inlineInspectorVisible = newValue
                }
            }
        )
    }

    /// Toolbar command adapter for shared Desktop/iPad commands whose
    /// iPad presentation lives inside the inspector. Desktop opens the export
    /// inspector from the window toolbar; iPad reveals the same canonical
    /// Export panel in the side rail or compact bottom sheet.
    private func focusInspectorPanel(
        _ panel: FilmtoneEditorPanelID,
        compact: Bool,
        hasSource: Bool
    ) {
        guard hasSource else { return }
        focusedInspectorPanel = nil
        if compact {
            sheetInspectorPresented = true
        } else {
            inlineInspectorVisible = true
        }
        DispatchQueue.main.async {
            focusedInspectorPanel = panel
        }
    }

    private var inspectorRail: some View {
        FilmtonePadInspectorRail(
            store: store,
            onSaveLook: onSaveLook,
            savedLookSheet: savedLookSheet,
            lutDeleteConfirmation: lutDeleteConfirmation,
            lookDeleteConfirmation: lookDeleteConfirmation,
            activeHelpTopic: activeHelpTopic,
            focusedPanel: $focusedInspectorPanel
        )
    }
}
