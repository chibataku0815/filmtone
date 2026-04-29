import SwiftUI
import UIKit

struct FilmtoneRootView: View {
    @ObservedObject var store: FilmtoneEditorStore
    @State private var strengthSheetPresented = false
    @State private var sourcePickerDialogPresented = false
    @State private var onboardingPresented = false
    @State private var onboardingCompletedThisSession = false
    @State private var shouldOpenSourcePickerAfterOnboarding = false

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                        .accessibilityIdentifier("filmtone.section.hero")
                    presetSection
                        .accessibilityIdentifier("filmtone.section.presets")
                    tuningSection
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

            RadialGradient(
                colors: [
                    Color.filmtoneAmber.opacity(0.20),
                    Color.filmtoneAmber.opacity(0.05),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 18,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Color.filmtoneAmber.opacity(0.10),
                    Color.filmtoneAmber.opacity(0.02),
                    .clear,
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 280
            )

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

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.source != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.activePresetLabel)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if store.hasAnyAdjustments {
                        Text(store.adjustmentSummaryText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(2)
                    }
                }
            }

            FilmtonePreviewView(
                source: store.source,
                displayURI: store.selectedPreviewURI,
                videoPreview: store.videoPreviewState,
                emptyMessage: previewEmptyMessage,
                emptyEyebrow: store.strings.previewEmptyEyebrow,
                emptyHint: store.strings.previewEmptyHint,
                loadingMessage: store.strings.previewRendering,
                originalLabel: store.strings.compareLabel,
                gradedLabel: store.strings.previewGradedLabel,
                expandLabel: store.strings.previewExpandLabel,
                isRendering: store.preview.isRendering,
                metaLabel: store.previewMetaLabel,
                isStillComparing: store.isCompareHeld,
                onStillCompareHeld: store.setCompareHeld
            ) { mode in
                Task { await store.setVideoCompareMode(mode) }
            }
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            FilmtoneSectionHeader(title: store.strings.presetTitle)

            FilmtonePresetRow(
                presets: FilmtonePresetCatalog.all,
                activePresetName: store.project.presetName
            ) { preset, isActive in
                if isActive {
                    strengthSheetPresented = true
                } else {
                    store.selectPreset(preset.name)
                }
            }
        }
    }

    private var tuningSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            FilmtoneSectionHeader(title: store.strings.adjustLabel)
                .accessibilityIdentifier("filmtone.section.tuning")

            Button {
                strengthSheetPresented = true
            } label: {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.strings.adjustOpenLabel)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if let summary = adjustSummaryText {
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "slider.horizontal.3")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.filmtoneAmber.opacity(0.92))
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("filmtone.adjust.open")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("filmtone.adjust.open")

            cameraProfileCard
        }
    }

    private var cameraProfileCard: some View {
        VStack(spacing: 14) {
            lutProfileRow(
                title: store.strings.cameraLabel,
                value: store.cameraProfileLabel,
                menuTitle: store.strings.cameraImport,
                systemImage: "camera.filters",
                menuIdentifier: "filmtone.lut.input.menu"
            ) {
                Button(store.strings.cameraAuto) {
                    store.clearInputLut()
                }
                Button(store.strings.cameraImport) {
                    Task { await store.importInputLut() }
                }
                if store.project.inputLut != nil {
                    Button(store.strings.clearLut, role: .destructive) {
                        store.clearInputLut()
                    }
                }
            }

            if let inputLut = store.project.inputLut {
                lutIntensityControl(
                    title: store.strings.inputLutAmountLabel,
                    value: inputLut.intensity,
                    valueIdentifier: "filmtone.lut.input.intensity.value",
                    sliderIdentifier: "filmtone.lut.input.intensity.slider"
                ) { nextValue in
                    store.setInputLutIntensity(nextValue)
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            lutProfileRow(
                title: store.strings.lookLabel,
                value: store.lookProfileLabel,
                menuTitle: store.strings.lookImport,
                systemImage: "camera.aperture",
                menuIdentifier: "filmtone.lut.creative.menu"
            ) {
                Button(store.strings.lookFilmtone) {
                    store.clearCreativeLut()
                }
                Button(store.strings.lookImport) {
                    Task { await store.importCreativeLut() }
                }
                if store.project.creativeLut != nil {
                    Button(store.strings.clearLut, role: .destructive) {
                        store.clearCreativeLut()
                    }
                }
            }

            if let creativeLut = store.project.creativeLut {
                lutIntensityControl(
                    title: store.strings.lookLutAmountLabel,
                    value: creativeLut.intensity,
                    valueIdentifier: "filmtone.lut.creative.intensity.value",
                    sliderIdentifier: "filmtone.lut.creative.intensity.slider"
                ) { nextValue in
                    store.setCreativeLutIntensity(nextValue)
                }
            }
        }
        .accessibilityIdentifier("filmtone.card.cameraProfile")
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func lutProfileRow<MenuContent: View>(
        title: String,
        value: String,
        menuTitle: String,
        systemImage: String,
        menuIdentifier: String,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.52))

                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Menu(content: menuContent) {
                Label(menuTitle, systemImage: systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(menuIdentifier)
            }
            .accessibilityIdentifier(menuIdentifier)
        }
    }

    private func lutIntensityControl(
        title: String,
        value: Double,
        valueIdentifier: String,
        sliderIdentifier: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        let clampedValue = FilmtonePhase0Math.clampLutIntensity(value)
        let percentLabel = lutIntensityPercentLabel(clampedValue)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))

                Spacer()

                Text(percentLabel)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.filmtoneAmber.opacity(0.86))
                    .accessibilityIdentifier(valueIdentifier)
            }

            Slider(
                value: Binding(
                    get: { clampedValue },
                    set: { onChange($0) }
                ),
                in: 0...1
            )
            .tint(Color.filmtoneAmber)
            .accessibilityIdentifier(sliderIdentifier)
            .accessibilityLabel(title)
            .accessibilityValue(percentLabel)
        }
    }

    private func lutIntensityPercentLabel(_ value: Double) -> String {
        "\(Int((FilmtonePhase0Math.clampLutIntensity(value) * 100).rounded()))%"
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

    private var previewEmptyMessage: String {
        if store.source == nil {
            return store.strings.sourceEmpty
        }
        if let error = store.previewError {
            return error
        }
        return store.strings.previewRendering
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

    private var adjustSummaryText: String? {
        guard store.hasAnyAdjustments else {
            return nil
        }
        return store.adjustmentSummaryText
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
        Group {
            if #available(iOS 26.0, *) {
                FilmtoneLiquidGlassTopChrome(
                    title: title,
                    actionLabel: actionLabel,
                    isActionDisabled: isActionDisabled,
                    onAction: onAction
                )
            } else {
                FilmtoneFallbackTopChrome(
                    title: title,
                    actionLabel: actionLabel,
                    isActionDisabled: isActionDisabled,
                    onAction: onAction
                )
            }
        }
        .accessibilityIdentifier("filmtone.topChrome")
    }
}

@available(iOS 26.0, *)
private struct FilmtoneLiquidGlassTopChrome: View {
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
                .buttonStyle(.glass)
                .tint(Color.filmtoneAmber)
                .disabled(isActionDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
    }
}

private struct FilmtoneFallbackTopChrome: View {
    let title: String
    let actionLabel: String
    let isActionDisabled: Bool
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            FilmtoneTopChromeTitle(title: title)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.22))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 10)

            Button(actionLabel, action: onAction)
                .buttonStyle(FilmtoneTopBarActionStyle())
                .disabled(isActionDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
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

struct FilmtoneChromeActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .fill(Color.filmtoneAmber.opacity(configuration.isPressed ? 0.84 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct FilmtoneTopBarActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.filmtoneAmber)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(configuration.isPressed ? 0.26 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .stroke(Color.filmtoneAmber.opacity(configuration.isPressed ? 0.26 : 0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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
                    .foregroundStyle(Color.filmtoneAmber)
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
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.filmtoneAmber.opacity(0.18), lineWidth: 1)
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
