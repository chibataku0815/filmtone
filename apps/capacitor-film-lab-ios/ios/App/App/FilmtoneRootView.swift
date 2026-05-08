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
    @State private var activeHelpTopic: FilmtoneAdjustmentHelpTopic?
    @State private var captureSurfacePresented = false

    var body: some View {
        ZStack {
            if store.source == nil {
                FilmtoneEmptyView(
                    store: store,
                    onPickPhotoLibrary: { Task { await store.pickSource(route: .photoLibrary) } },
                    onPickFiles: { Task { await store.pickSource(route: .files) } },
                    onRecordProductClip: { captureSurfacePresented = true },
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
                    onAdvancedTap: { advancedSheetPresented = true },
                    // S8-A: re-record entry from the editor. Cancel keeps the
                    // current source (existing `.fullScreenCover` cancel
                    // handler only flips the cover state); success replaces
                    // the source via `adoptCaptureResult`. Old package /
                    // unsaved-edit confirmation are out of scope for S8-A.
                    onRecord: { captureSurfacePresented = true }
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

            adjustmentHelpOverlay

            recordingOverlay
        }
        // Backward-compat alias for XCUITest snapshot suite which uses
        // `filmtone.root.scroll` as a "main app loaded" sentinel. The legacy
        // ScrollView is gone, but the sentinel is harmless on the router root.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filmtone.root.scroll")
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: activeHelpTopic?.id)
        .animation(.easeInOut(duration: 0.2), value: store.recordingState != nil)
        .alert(
            store.strings.recordProductClipFailed,
            isPresented: Binding(
                get: { store.recordingError != nil },
                set: { isPresented in
                    if !isPresented {
                        store.recordingError = nil
                    }
                }
            ),
            presenting: store.recordingError
        ) { _ in
            Button(role: .cancel) {
                store.recordingError = nil
            } label: {
                Text("OK")
            }
            .accessibilityIdentifier("filmtone.recording.alert.dismiss")
        } message: { detail in
            Text(detail)
        }
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
            FilmtoneStrengthSheet(
                store: store,
                activeHelpTopic: $activeHelpTopic
            ) {
                advancedSheetPresented = false
            }
        }
        .sheet(isPresented: $exportSheetPresented) {
            FilmtoneExportPanel(store: store) {
                exportSheetPresented = false
            }
        }
        .sheet(isPresented: $store.desktopHandoffPromptPresented) {
            FilmtoneDesktopHandoffSheet(strings: store.strings) {
                store.desktopHandoffPromptPresented = false
            }
        }
        .fullScreenCover(isPresented: $captureSurfacePresented) {
            // S8-D: snapshot the editor's current Look state at the
            // moment the capture surface is presented.  The capture
            // surface is a fullScreenCover so editor controls are not
            // reachable while it is up — a single snapshot is correct
            // and avoids re-binding to a published store inside the
            // capture view (which would couple recording UI ticks to
            // editor publishers).
            FilmtoneCaptureView(
                lookReference: FilmtoneCaptureLookReference(
                    displayURI: store.selectedPreviewURI,
                    lookLabel: store.lookProfileLabel
                ),
                onCompleted: { package in
                    captureSurfacePresented = false
                    Task { await store.adoptCaptureResult(package) }
                },
                onCancelled: {
                    captureSurfacePresented = false
                },
                onFailed: { failure in
                    captureSurfacePresented = false
                    store.recordingError = failure.displayMessage
                }
            )
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
        .onChange(of: store.desktopHandoffPromptPresented) { isPresented in
            if isPresented {
                pendingLookOnPickComplete = nil
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

    // MARK: Recording overlay (M8 — fixed-duration product capture feedback)

    /// Owner-visible recording surface for `recordProductClip`. Shows a
    /// translucent backdrop, a circular progress ring driven by elapsed
    /// time vs `durationSeconds`, the integer seconds remaining, and a
    /// pulsing red dot with the localized "recording…" label. Mounted
    /// above every other view in `body` so picker CTAs underneath are
    /// occluded for the recording window. The capture surface is
    /// fixed-duration (M7 owner-locked), so this overlay intentionally
    /// has no stop button.
    @ViewBuilder
    private var recordingOverlay: some View {
        if let state = store.recordingState {
            ZStack {
                Color.black.opacity(0.62)
                    .ignoresSafeArea()

                TimelineView(.periodic(from: state.startedAt, by: 0.05)) { context in
                    let elapsed = max(0, context.date.timeIntervalSince(state.startedAt))
                    let total = max(0.001, state.durationSeconds)
                    let progress = min(1, elapsed / total)
                    let remaining = max(0, state.durationSeconds - elapsed)
                    let secondsLabel = "\(Int(ceil(remaining)))"
                    let pulseOpacity = 0.45 + 0.55 * abs(sin(elapsed * .pi))

                    VStack(spacing: 22) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.18), lineWidth: 5)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    Color(red: 0.96, green: 0.32, blue: 0.32),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            Text(secondsLabel)
                                .font(.system(size: 56, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .accessibilityIdentifier("filmtone.recording.countdown")
                        }
                        .frame(width: 132, height: 132)

                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(red: 0.96, green: 0.32, blue: 0.32))
                                .frame(width: 10, height: 10)
                                .opacity(pulseOpacity)
                            Text(store.strings.recordProductClipRunning)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "\(store.strings.recordProductClipRunning) \(secondsLabel)"
                        )
                    }
                }
            }
            .transition(.opacity)
            .accessibilityIdentifier("filmtone.recording.overlay")
            .zIndex(30)
        }
    }

    // MARK: Source load banner (overlay during pick → loaded transition)

    @ViewBuilder
    private var adjustmentHelpOverlay: some View {
        if let topic = activeHelpTopic {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()
                        .onTapGesture(perform: dismissAdjustmentHelp)

                    FilmtoneAdjustmentHelpSheet(
                        topic: topic,
                        beforeLabel: store.strings.adjustmentHelpBeforeLabel,
                        afterLabel: store.strings.adjustmentHelpAfterLabel,
                        effectLabel: store.strings.adjustmentHelpEffectLabel,
                        guidanceLabel: store.strings.adjustmentHelpGuidanceLabel,
                        dismissLabel: store.strings.helpDismiss,
                        onDismiss: dismissAdjustmentHelp
                    )
                    .frame(
                        width: max(0, proxy.size.width - 16),
                        height: min(proxy.size.height * 0.58, 520),
                        alignment: .top
                    )
                    .glassEffect(
                        .regular.tint(Color.black.opacity(0.10)),
                        in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("filmtone.help.adjustment.overlay")
                }
            }
            .ignoresSafeArea()
            .transition(.opacity)
            .zIndex(20)
        }
    }

    private func dismissAdjustmentHelp() {
        activeHelpTopic = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            advancedSheetPresented = true
        }
    }

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

/// Sheet presented when the user picks a video longer than the iOS source
/// duration cap (`PHASE0_MAX_SOURCE_DURATION_SEC`, 300s). Routes the user to
/// Filmtone Desktop instead of accepting the clip into the editor — there is
/// intentionally no "continue anyway" affordance, because iPhone preview /
/// export quality is tuned for short clips. Does not mutate source state on
/// dismiss; the picker import has already been reclaimed by the store.
struct FilmtoneDesktopHandoffSheet: View {
    let strings: FilmtoneStrings
    let onDismiss: () -> Void

    private static let desktopDownloadURL = URL(
        string: "https://www.chibatakumi.studio/film-lab/download"
    )!

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "desktopcomputer.and.arrow.down")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(strings.desktopHandoffTitle)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("filmtone.desktopHandoff.title")

                    Text(strings.desktopHandoffBody)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("filmtone.desktopHandoff.body")
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 8)

                VStack(spacing: 12) {
                    Button {
                        openURL(Self.desktopDownloadURL)
                        onDismiss()
                    } label: {
                        Text(strings.desktopHandoffPrimaryAction)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("filmtone.desktopHandoff.primary")

                    Button(role: .cancel) {
                        onDismiss()
                    } label: {
                        Text(strings.desktopHandoffSecondaryAction)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("filmtone.desktopHandoff.secondary")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(false)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("filmtone.desktopHandoff.sheet")
    }
}
