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

enum FilmtoneOnboardingLaunchArguments {
    static let force = "-filmtoneForceOnboarding"
    static let reset = "-filmtoneResetOnboarding"
    static let seedRestoredSource = "-filmtoneSeedRestoredSource"
}

enum FilmtoneOnboardingState {
    private static let seenKey = "filmtone-ios/onboarding/seen/v1"
    private static var didApplyLaunchArguments = false

    static func applyLaunchArgumentsIfNeeded() {
        guard !didApplyLaunchArguments else {
            return
        }
        didApplyLaunchArguments = true

        if ProcessInfo.processInfo.arguments.contains(FilmtoneOnboardingLaunchArguments.reset) {
            UserDefaults.standard.removeObject(forKey: seenKey)
        }
    }

    static func shouldPresent(source: SourceInfoDTO?) -> Bool {
        guard FilmtoneSnapshotScene.current == nil else {
            return false
        }
        guard source == nil else {
            return false
        }
        return isForceRequested || !hasSeen
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: seenKey)
    }

    private static var hasSeen: Bool {
        UserDefaults.standard.bool(forKey: seenKey)
    }

    private static var isForceRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(FilmtoneOnboardingLaunchArguments.force)
    }
}

private struct FilmtoneOnboardingSlide: Identifiable {
    let id: Int
    let title: String
    let body: String
    let symbolName: String
}

struct FilmtoneOnboardingView: View {
    let strings: FilmtoneStrings
    let onSkip: () -> Void
    let onPickMedia: () -> Void

    @State private var page = 0

    private var slides: [FilmtoneOnboardingSlide] {
        [
            .init(
                id: 0,
                title: strings.onboardingChooseTitle,
                body: strings.onboardingChooseBody,
                symbolName: "photo.on.rectangle"
            ),
            .init(
                id: 1,
                title: strings.onboardingShapeTitle,
                body: strings.onboardingShapeBody,
                symbolName: "slider.horizontal.3"
            ),
            .init(
                id: 2,
                title: strings.onboardingFinishTitle,
                body: strings.onboardingFinishBody,
                symbolName: "square.and.arrow.up"
            ),
            // v1.3 Item 3 follow-up: 4th slide pitches the reuse loop. Sits
            // after the export slide because the narrative beat is "you've
            // shipped your first piece — and now the same look survives to
            // the next one." Symbol is `square.stack.fill` for the library
            // metaphor (saved LUTs + saved Looks stack together).
            .init(
                id: 3,
                title: strings.onboardingReuseTitle,
                body: strings.onboardingReuseBody,
                symbolName: "square.stack.fill"
            ),
        ]
    }

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 0) {
                HStack {
                    Text(strings.appName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 8)

                TabView(selection: $page) {
                    ForEach(slides) { slide in
                        FilmtoneOnboardingPage(slide: slide)
                            .tag(slide.id)
                            .accessibilityIdentifier("filmtone.onboarding.page.\(slide.id)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .accessibilityIdentifier("filmtone.onboarding.pages")

                controls
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var onboardingBackground: some View {
        ZStack {
            Color.filmtoneBackground

            LinearGradient(
                colors: [
                    Color.filmtoneAmber.opacity(0.16),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.78),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.34),
                    Color.black.opacity(0.82),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Button {
                performPrimaryAction()
            } label: {
                Text(primaryActionLabel)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilmtonePrimaryButtonStyle())
            .accessibilityIdentifier(isLastPage ? "filmtone.onboarding.pickMedia" : "filmtone.onboarding.next")

            Button(action: onSkip) {
                Text(strings.onboardingSkip)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilmtoneSecondaryButtonStyle())
            .accessibilityIdentifier("filmtone.onboarding.skip")
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 26)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.78),
                    Color.black.opacity(0.94),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var isLastPage: Bool {
        page == slides.count - 1
    }

    private var primaryActionLabel: String {
        isLastPage ? strings.onboardingPickMedia : strings.onboardingNext
    }

    private func performPrimaryAction() {
        if isLastPage {
            onPickMedia()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                page = min(page + 1, slides.count - 1)
            }
        }
    }
}

private struct FilmtoneOnboardingPage: View {
    let slide: FilmtoneOnboardingSlide

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                FilmtoneOnboardingPreviewCard(slide: slide)
                    .frame(maxWidth: 420)

                VStack(alignment: .leading, spacing: 12) {
                    Text(slide.title)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(slide.body)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 420, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 46)
        }
    }
}

private struct FilmtoneOnboardingPreviewCard: View {
    let slide: FilmtoneOnboardingSlide

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: filmtonePreviewCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.035))

            RoundedRectangle(cornerRadius: filmtonePreviewCornerRadius, style: .continuous)
                .stroke(Color.filmtoneAmber.opacity(0.16), lineWidth: 1)

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: slide.symbolName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 72, height: 72)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.filmtoneAmber)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 10) {
                        Capsule()
                            .fill(Color.white.opacity(0.30))
                            .frame(width: 96, height: 9)
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 118, height: 9)
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 76, height: 9)
                    }
                }

                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 10) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 42, height: 8)

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                    Capsule()
                                        .fill(index == slide.id ? Color.filmtoneAmber.opacity(0.86) : Color.white.opacity(0.24))
                                        .frame(width: proxy.size.width * meterWidth(for: index))
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
            .padding(22)
        }
        .aspectRatio(1.18, contentMode: .fit)
        .shadow(color: Color.black.opacity(0.32), radius: 24, x: 0, y: 16)
        .accessibilityHidden(true)
    }

    private func meterWidth(for index: Int) -> CGFloat {
        switch (slide.id + index) % 3 {
        case 0:
            return 0.72
        case 1:
            return 0.46
        default:
            return 0.86
        }
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
