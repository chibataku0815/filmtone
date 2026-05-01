import SwiftUI

/// Root router. Source-less = empty picker view, source-loaded = fullscreen
/// Liquid Glass editor. The legacy scroll-based main flow (Hero / Preset /
/// Tuning / CameraProfileCard / Library cards) was deleted as part of the
/// IA pivot to fullscreen-first. UnsavedExportPrompt / Toast / HdrPolicyNotice
/// now live inside `FilmtoneFullscreenLutEditor` as overlays.
struct FilmtoneRootView: View {
    @ObservedObject var store: FilmtoneEditorStore
    @State private var sourcePickerDialogPresented = false
    @State private var onboardingPresented = false
    @State private var onboardingCompletedThisSession = false
    @State private var shouldOpenSourcePickerAfterOnboarding = false
    @State private var savedLookSheet: SavedLookSheetMode?
    @State private var lutDeleteConfirmation: LutLibraryEntry?
    @State private var lookDeleteConfirmation: SavedLookEntry?
    @State private var sourceSheetPresented = false
    @State private var advancedSheetPresented = false
    @State private var exportSheetPresented = false
    @State private var pendingLookOnPickComplete: SavedLookEntry?

    var body: some View {
        ZStack {
            if store.source == nil {
                FilmtoneEmptyView(
                    store: store,
                    onPickPhotoLibrary: { Task { await store.pickSource(route: .photoLibrary) } },
                    onPickFiles: { Task { await store.pickSource(route: .files) } },
                    onPickWithLook: { entry in
                        pendingLookOnPickComplete = entry
                        Task { await store.pickSource(route: .photoLibrary) }
                    }
                )
            } else {
                FilmtoneFullscreenLutEditor(
                    store: store,
                    onClose: { sourcePickerDialogPresented = true },
                    onSaveLook: { savedLookSheet = .createCurrentLook },
                    onExport: { exportSheetPresented = true },
                    onSourceTap: { sourceSheetPresented = true },
                    onAdvancedTap: { advancedSheetPresented = true }
                )
            }

            if let sourceLoadState = store.sourceLoadState {
                VStack(spacing: 0) {
                    sourceLoadBanner(sourceLoadState)
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }
        }
        // Backward-compat alias for XCUITest snapshot suite which uses
        // `filmtone.root.scroll` as a "main app loaded" sentinel. The legacy
        // ScrollView is gone, but the sentinel is harmless on the router root.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filmtone.root.scroll")
        .sheet(isPresented: $sourceSheetPresented) {
            FilmtoneSourceProfileSheet(
                store: store,
                savedLookSheet: $savedLookSheet,
                lutDeleteConfirmation: $lutDeleteConfirmation
            ) {
                sourceSheetPresented = false
            }
        }
        .sheet(isPresented: $advancedSheetPresented) {
            FilmtoneStrengthSheet(store: store) {
                advancedSheetPresented = false
            }
        }
        .sheet(isPresented: $exportSheetPresented) {
            FilmtoneExportPanel(store: store) {
                exportSheetPresented = false
            }
        }
        .fullScreenCover(isPresented: $onboardingPresented, onDismiss: openSourcePickerIfNeeded) {
            FilmtoneOnboardingView(
                strings: store.strings,
                onSkip: dismissOnboarding,
                onPickMedia: finishOnboardingAndPickMedia
            )
        }
        .onAppear {
            FilmtoneOnboardingState.applyLaunchArgumentsIfNeeded()
            presentOnboardingIfNeeded()
        }
        .onChange(of: store.source?.uri) { _ in
            if store.source != nil {
                onboardingPresented = false
                if let pending = pendingLookOnPickComplete {
                    pendingLookOnPickComplete = nil
                    Task { await store.applySavedLook(id: pending.id) }
                }
            } else {
                presentOnboardingIfNeeded()
            }
        }
        .confirmationDialog(
            store.strings.sourcePickerTitle,
            isPresented: $sourcePickerDialogPresented,
            titleVisibility: .visible
        ) {
            Button(store.strings.pickFromPhotoLibrary) {
                Task { await store.pickSource(route: .photoLibrary) }
            }
            .accessibilityIdentifier("filmtone.source.photoLibrary")

            Button(store.strings.pickFromFiles) {
                Task { await store.pickSource(route: .files) }
            }
            .accessibilityIdentifier("filmtone.source.files")
        }
        .sheet(item: $savedLookSheet) { mode in
            FilmtoneSavedLookSheet(
                mode: mode.sheetMode,
                strings: store.strings,
                initialName: mode.initialName(defaultIndex: store.library.looks.count + 1),
                onCancel: { savedLookSheet = nil },
                onSubmit: { name in
                    let dispatched = mode
                    savedLookSheet = nil
                    Task {
                        switch dispatched {
                        case .createCurrentLook:
                            _ = await store.saveCurrentLook(name: name)
                        case .renameLook(let entry):
                            await store.renameSavedLook(id: entry.id, name: name)
                        case .renameLut(let entry):
                            await store.renameLibraryLut(id: entry.id, title: name)
                        }
                    }
                }
            )
        }
        .confirmationDialog(
            lutDeleteConfirmation?.title ?? "",
            isPresented: Binding(
                get: { lutDeleteConfirmation != nil },
                set: { if !$0 { lutDeleteConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let entry = lutDeleteConfirmation {
                Button(store.strings.libraryDeleteAction, role: .destructive) {
                    Task { await store.deleteLibraryLut(id: entry.id) }
                }
                .accessibilityIdentifier("filmtone.library.lut.delete.confirm")
            }
            Button(store.strings.savedLookSheetCancel, role: .cancel) {}
        }
        .confirmationDialog(
            lookDeleteConfirmation?.name ?? "",
            isPresented: Binding(
                get: { lookDeleteConfirmation != nil },
                set: { if !$0 { lookDeleteConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let entry = lookDeleteConfirmation {
                Button(store.strings.libraryDeleteAction, role: .destructive) {
                    Task { await store.deleteSavedLook(id: entry.id) }
                }
                .accessibilityIdentifier("filmtone.library.look.delete.confirm")
            }
            Button(store.strings.savedLookSheetCancel, role: .cancel) {}
        }
    }

    // MARK: Source load banner (overlay during pick → loaded transition)

    private func sourceLoadBanner(_ state: FilmtoneSourceLoadState) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.strings.sourceLoadTitle(for: state.stage))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.filmtoneAmber.opacity(0.95))

                    Text(state.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(2)
                        .accessibilityIdentifier("filmtone.banner.sourceLoad.label")
                }

                Spacer(minLength: 12)

                if state.isDeterminate, let progress = state.clampedProgress {
                    Text(percentLabel(progress))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .monospacedDigit()
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.filmtoneAmber)
                }
            }

            if state.isDeterminate, let progress = state.clampedProgress {
                ProgressView(value: progress)
                    .tint(Color.filmtoneAmber)
                    .padding(.top, 12)
                    .accessibilityIdentifier("filmtone.banner.sourceLoad.progress")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.62),
                    Color.black.opacity(0.38),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .accessibilityIdentifier("filmtone.banner.sourceLoad")
    }

    // MARK: Onboarding helpers

    private func presentOnboardingIfNeeded() {
        guard !onboardingCompletedThisSession else {
            return
        }
        onboardingPresented = FilmtoneOnboardingState.shouldPresent(source: store.source)
    }

    private func dismissOnboarding() {
        FilmtoneOnboardingState.markSeen()
        onboardingCompletedThisSession = true
        onboardingPresented = false
    }

    private func finishOnboardingAndPickMedia() {
        FilmtoneOnboardingState.markSeen()
        onboardingCompletedThisSession = true
        shouldOpenSourcePickerAfterOnboarding = true
        onboardingPresented = false
    }

    private func openSourcePickerIfNeeded() {
        guard shouldOpenSourcePickerAfterOnboarding else {
            return
        }
        shouldOpenSourcePickerAfterOnboarding = false
        sourcePickerDialogPresented = true
    }

    private func percentLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
