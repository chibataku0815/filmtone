import SwiftUI
import UIKit

struct FilmtoneRootView: View {
    @ObservedObject var store: FilmtoneEditorStore
    @State private var strengthSheetPresented = false
    @State private var sourcePickerDialogPresented = false
    @State private var onboardingPresented = false
    @State private var onboardingCompletedThisSession = false
    @State private var shouldOpenSourcePickerAfterOnboarding = false
    @State private var lutTermHelpPresented = false
    @State private var savedLookSheet: SavedLookSheetMode?
    @State private var lutDeleteConfirmation: LutLibraryEntry?
    @State private var lookDeleteConfirmation: SavedLookEntry?
    @State private var fullscreenLutEditorPresented = false

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    FilmtoneHeroSection(
                        store: store,
                        fullscreenLutEditorPresented: $fullscreenLutEditorPresented
                    )
                    .accessibilityIdentifier("filmtone.section.hero")

                    FilmtonePresetSection(
                        store: store,
                        strengthSheetPresented: $strengthSheetPresented
                    )

                    FilmtoneTuningSection(
                        store: store,
                        strengthSheetPresented: $strengthSheetPresented,
                        savedLookSheet: $savedLookSheet,
                        lutTermHelpPresented: $lutTermHelpPresented,
                        lutDeleteConfirmation: $lutDeleteConfirmation,
                        lookDeleteConfirmation: $lookDeleteConfirmation
                    )

                    FilmtoneExportPanel(store: store)
                    messageStack
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, contentBottomPadding)
            }
            .accessibilityIdentifier("filmtone.root.scroll")
        }
        .overlay(alignment: .bottom) { bottomOverlay }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: store.toast?.id)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: shouldShowUnsavedExportPrompt)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                topChrome
                if let sourceLoadState = store.sourceLoadState {
                    sourceLoadBanner(sourceLoadState)
                }
                if store.source != nil, FilmtoneHdrPolicyNotice.shouldSurface(store.hdrPolicy) {
                    FilmtoneHdrPolicyNotice(
                        policy: store.hdrPolicy,
                        strings: store.strings
                    )
                }
            }
        }
        .sheet(isPresented: $strengthSheetPresented) {
            FilmtoneStrengthSheet(store: store) {
                strengthSheetPresented = false
            }
        }
        .sheet(isPresented: $lutTermHelpPresented) {
            FilmtoneTermHelpSheet(
                title: store.strings.helpLutTitle,
                bodyText: store.strings.helpLutBody,
                primarySubExplanation: store.strings.helpLutCameraLut,
                secondarySubExplanation: store.strings.helpLutLookLut,
                tertiarySubExplanation: store.strings.helpLutSavedLibrary,
                dismissLabel: store.strings.helpDismiss
            ) {
                lutTermHelpPresented = false
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
            if FilmtoneSnapshotScene.current == .quick {
                strengthSheetPresented = true
            }
            presentOnboardingIfNeeded()
        }
        .onChange(of: store.source?.uri) { _ in
            if store.source != nil {
                onboardingPresented = false
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
        .fullScreenCover(isPresented: $fullscreenLutEditorPresented) {
            FilmtoneFullscreenLutEditor(store: store) {
                fullscreenLutEditorPresented = false
            }
        }
    }

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

    private var backgroundLayer: some View {
        ZStack {
            Color.filmtoneBackground

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.36),
                    Color.black.opacity(0.72),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var topChrome: some View {
        FilmtoneTopChrome(
            title: store.sourceLabel ?? store.strings.appName,
            actionLabel: store.source == nil ? store.strings.pickSource : store.strings.repickSource,
            isActionDisabled: store.isBusy || store.isSavingToPhotos
        ) {
            sourcePickerDialogPresented = true
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

    @ViewBuilder
    private var messageStack: some View {
        if let notice = store.notice {
            messagePanel(title: store.strings.noticePrefix, message: notice, tint: Color.filmtoneAmber)
        }

        if let error = store.bannerError {
            messagePanel(title: store.strings.errorPrefix, message: error, tint: .red)
        }
    }

    private var contentBottomPadding: CGFloat {
        shouldShowUnsavedExportPrompt ? 172 : 32
    }

    private var shouldShowUnsavedExportPrompt: Bool {
        store.canUseLocalExport && store.saveToPhotosState != .saved && !store.isBusy
    }

    private var bottomOverlay: some View {
        VStack(spacing: 10) {
            if let toast = store.toast {
                FilmtoneToastView(toast: toast)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1000)
            }

            if shouldShowUnsavedExportPrompt {
                UnsavedExportPrompt(
                    message: store.strings.unsavedExportPrompt,
                    saveLabel: store.strings.saveToPhotos,
                    shareLabel: store.strings.shareOutput,
                    isSaving: store.isSavingToPhotos
                ) {
                    Task { await store.saveToPhotos() }
                } onShare: {
                    Task { await store.shareOutput() }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(900)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func messagePanel(title: String, message: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint.opacity(0.92))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.84))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                .fill(tint.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }

    private func percentLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}


/// Stateful identifier for the Saved-Look modal so we can reuse a single
/// `.sheet(item:)` for create / rename-look / rename-LUT.
enum SavedLookSheetMode: Identifiable {
    case createCurrentLook
    case renameLook(SavedLookEntry)
    case renameLut(LutLibraryEntry)

    var id: String {
        switch self {
        case .createCurrentLook:
            return "create"
        case .renameLook(let entry):
            return "renameLook-\(entry.id.uuidString)"
        case .renameLut(let entry):
            return "renameLut-\(entry.id.uuidString)"
        }
    }

    var sheetMode: FilmtoneSavedLookSheet.Mode {
        switch self {
        case .createCurrentLook:
            return .create
        case .renameLook, .renameLut:
            return .rename
        }
    }

    func initialName(defaultIndex: Int) -> String {
        switch self {
        case .createCurrentLook:
            return "Look \(defaultIndex)"
        case .renameLook(let entry):
            return entry.name
        case .renameLut(let entry):
            return entry.title
        }
    }
}

final class FilmtoneRootHostingController: UIHostingController<FilmtoneRootView> {
    private let store: FilmtoneEditorStore

    init(store: FilmtoneEditorStore) {
        self.store = store
        super.init(rootView: FilmtoneRootView(store: store))
        store.attachPresenter(self)
        view.backgroundColor = .black
    }

    @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct FilmtoneSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.5))
    }
}

private struct FilmtoneTopChrome: View {
    let title: String
    let actionLabel: String
    let isActionDisabled: Bool
    let onAction: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                FilmtoneTopChromeTitle(title: title)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .glassEffect(
                        .regular.tint(Color.black.opacity(0.10)),
                        in: .rect(cornerRadius: 18.0)
                    )

                Button(action: onAction) {
                    Text(actionLabel)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.glassProminent)
                .disabled(isActionDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .accessibilityIdentifier("filmtone.topChrome")
    }
}

private struct FilmtoneTopChromeTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .shadow(color: Color.black.opacity(0.26), radius: 4, x: 0, y: 1)
    }
}

struct UnsavedExportPrompt: View {
    let message: String
    let saveLabel: String
    let shareLabel: String
    let isSaving: Bool
    let onSave: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(saveLabel, action: onSave)
                    .buttonStyle(FilmtonePrimaryButtonStyle())
                    .disabled(isSaving)
                    .accessibilityIdentifier("filmtone.export.unsavedPrompt.save")

                Button(shareLabel, action: onShare)
                    .buttonStyle(FilmtoneSecondaryButtonStyle())
                    .disabled(isSaving)
                    .accessibilityIdentifier("filmtone.export.unsavedPrompt.share")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.34))
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.34), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filmtone.export.unsavedPrompt")
    }
}

let filmtonePreviewCornerRadius: CGFloat = 24
let filmtoneSurfaceCornerRadius: CGFloat = 12
let filmtoneControlCornerRadius: CGFloat = 10

extension Color {
    static let filmtoneAmber = Color(red: 1.0, green: 0.72, blue: 0.25)
    static let filmtoneSky = Color(red: 0.45, green: 0.66, blue: 1.0)
    static let filmtoneBackground = Color(red: 0.02, green: 0.02, blue: 0.02)
}

/// Viewport-level toast view rendered as an overlay on the root `ZStack`.
///
/// Visual language is intentionally restrained: a compact rounded
/// rectangle with a thin `.ultraThinMaterial` fill tinted dark, an icon
/// matched to the `FilmtoneToast.Kind`, and text in the existing
/// `white.opacity(0.84)` body color. No new accent colors are introduced
/// (success uses `Color.filmtoneAmber`, info uses `Color.filmtoneSky`,
/// error uses the shared red).
struct FilmtoneToastView: View {
    let toast: FilmtoneToast

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Text(toast.message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(iconColor.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.32), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(toast.message))
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("filmtone.toast")
    }

    private var iconName: String {
        switch toast.kind {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch toast.kind {
        case .success:
            return Color.filmtoneAmber
        case .error:
            return .red
        case .info:
            return Color.filmtoneSky
        }
    }
}
