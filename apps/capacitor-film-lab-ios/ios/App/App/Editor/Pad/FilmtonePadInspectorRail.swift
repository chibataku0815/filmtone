import FilmLabSwiftCore
import SwiftUI

/// iPad Workspace right inspector rail.
///
/// Persistent right rail with the four Desktop panels in Desktop order:
/// Source, Look, Adjust, Export.  Each panel now mounts its real
/// content inline instead of dispatching into a sheet — the iPhone
/// sheets only present when the iPhone fullscreen editor is the active
/// route.  Source uses an iPad/Desktop Source Profile adapter instead
/// of the iPhone source sheet's LUT/storage stack. Modal text entry
/// (saved-Look naming, LUT rename) still uses `FilmtoneSavedLookSheet`;
/// naming, LUT rename) still uses `FilmtoneSavedLookSheet`.
struct FilmtonePadInspectorRail: View {
    @ObservedObject var store: FilmtoneEditorStore
    let onSaveLook: () -> Void
    let savedLookSheet: Binding<SavedLookSheetMode?>
    let lutDeleteConfirmation: Binding<LutLibraryEntry?>
    let lookDeleteConfirmation: Binding<SavedLookEntry?>
    let activeHelpTopic: Binding<FilmtoneAdjustmentHelpTopic?>
    @Binding var focusedPanel: FilmtoneEditorPanelID?

    var body: some View {
        VStack(spacing: 0) {
            railHeader

            ScrollViewReader { proxy in
                ScrollView {
                    // M7 / Desktop parity: panels mount only when a source
                    // is loaded. Matches `EditorPanelStack`'s
                    // `if state.sourceURL != nil` gate so the empty-launch
                    // posture across both platforms is "no inspector
                    // chrome on top of a source-less preview".
                    if store.source != nil {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(FilmtoneEditorPanelContract.canonicalOrder) { panelId in
                                panel(for: panelId)
                                    .id(panelId)
                            }
                        }
                        .padding(16)
                    } else {
                        inspectorEmptyState
                            .padding(24)
                    }
                }
                .onAppear {
                    scrollToFocusedPanel(proxy)
                }
                .onChange(of: focusedPanel) { _, _ in
                    scrollToFocusedPanel(proxy)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.46))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .accessibilityIdentifier("filmtone.pad.inspector")
    }

    private func scrollToFocusedPanel(_ proxy: ScrollViewProxy) {
        guard let focusedPanel, store.source != nil else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(focusedPanel, anchor: .top)
            }
        }
    }

    private var inspectorEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.strings.usesJapaneseTypography
                 ? "素材を読み込むと表示されます"
                 : "Inspector appears after you load a source")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("filmtone.pad.inspector.empty")
    }

    private var railHeader: some View {
        HStack {
            Text("Inspector")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func panel(for id: FilmtoneEditorPanelID) -> some View {
        switch id {
        case .source: sourcePanel
        case .look:   lookPanel
        case .adjust: adjustPanel
        case .export: exportPanel
        }
    }

    private var sourcePanel: some View {
        panel(
            title: "Source",
            accessibility: "filmtone.pad.inspector.source"
        ) {
            FilmtonePadSourcePanel(store: store)
        }
    }

    private var lookPanel: some View {
        panel(
            title: "Look",
            accessibility: "filmtone.pad.inspector.look"
        ) {
            FilmtonePadLookPanel(
                store: store,
                savedLookSheet: savedLookSheet,
                lookDeleteConfirmation: lookDeleteConfirmation,
                onSaveCurrentLook: onSaveLook
            )
        }
    }

    private var adjustPanel: some View {
        panel(
            title: "Adjust",
            accessibility: "filmtone.pad.inspector.adjust"
        ) {
            FilmtonePadAdjustPanel(store: store)
        }
    }

    private var exportPanel: some View {
        panel(
            title: "Export",
            accessibility: "filmtone.pad.inspector.export"
        ) {
            FilmtoneExportPanel(store: store)
        }
    }

    @ViewBuilder
    private func panel<Content: View>(
        title: String,
        accessibility: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .accessibilityIdentifier(accessibility)
    }
}

/// iPad Source panel adapter.
///
/// This intentionally does not reuse `FilmtoneSourceProfilePanelSections`:
/// that view is still the iPhone sheet body and includes input LUT library,
/// Look LUT import, and storage/cache controls. The iPad workspace Source
/// panel follows the Desktop Source panel contract: Source Profile selection
/// only, rendered from `FilmtoneSourcePanelContract`.
private struct FilmtonePadSourcePanel: View {
    @ObservedObject var store: FilmtoneEditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(FilmtoneSourcePanelContract.canonicalOrder) { section in
                sectionView(section)
            }
        }
        .accessibilityIdentifier("filmtone.pad.inspector.source.profileOnly")
    }

    @ViewBuilder
    private func sectionView(_ section: FilmtoneSourcePanelSectionID) -> some View {
        switch section {
        case .sourceProfile:
            cameraProfileSection
        }
    }

    private var cameraProfileSection: some View {
        FilmtoneLutControls.profileRow(
            title: store.strings.cameraLabel,
            value: store.cameraProfileLabel,
            menuTitle: store.strings.cameraChange,
            systemImage: "camera.filters",
            menuIdentifier: "filmtone.pad.inspector.source.profile.menu"
        ) {
            Button(store.strings.cameraAuto) {
                store.applyCameraProfile(.auto)
            }
            ForEach(FilmtoneSourceProfileCatalog.allProfiles, id: \.id) { entry in
                Button(store.strings.builtInSourceProfileName(for: entry.id) ?? entry.englishName) {
                    store.applyCameraProfile(.builtIn(catalogId: entry.id))
                }
            }
        }
    }
}
