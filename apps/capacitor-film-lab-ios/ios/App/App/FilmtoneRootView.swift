import SwiftUI
import UIKit

struct FilmtoneRootView: View {
    @ObservedObject var store: FilmtoneEditorStore
    @State private var strengthSheetPresented = false
    @State private var sourcePickerDialogPresented = false

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    presetSection
                    tuningSection
                    FilmtoneExportPanel(store: store)
                    messageStack
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 32)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topChrome
        }
        .sheet(isPresented: $strengthSheetPresented) {
            FilmtoneStrengthSheet(store: store) {
                strengthSheetPresented = false
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

            Button(store.strings.pickFromFiles) {
                Task { await store.pickSource(route: .files) }
            }
        }
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
                    Color.filmtoneSky.opacity(0.16),
                    Color.filmtoneSky.opacity(0.03),
                    .clear,
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 300
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
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                HStack(spacing: 8) {
                    if store.source != nil {
                        Capsule()
                            .fill(Color.filmtoneAmber)
                            .frame(width: 12, height: 3)
                    }

                    Text(store.sourceLabel ?? store.strings.appName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.90))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 12)

                Button(store.source == nil ? store.strings.pickSource : store.strings.repickSource) {
                    sourcePickerDialogPresented = true
                }
                .buttonStyle(FilmtoneTopBarActionStyle())
                .disabled(store.isBusy)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.08),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.source != nil {
                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.filmtoneAmber)
                                .frame(width: 7, height: 7)

                            Text(store.activePresetLabel)
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }

                        Text(store.adjustmentSummaryText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    strengthBadge
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

            Button {
                strengthSheetPresented = true
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.activePresetLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.5))

                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text(strengthValueLabel)
                                    .font(.system(size: 58, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .tracking(-1.4)

                                Text("%")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .offset(y: -6)
                            }
                        }

                        Spacer(minLength: 12)

                        Text(store.strings.strengthLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.46))
                    }

                    Text(adjustSummaryText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.74))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            Color.filmtoneAmber.opacity(0.34),
                            Color.white.opacity(0.06),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                }
            }
            .buttonStyle(.plain)

            cameraProfileCard
        }
    }

    private var cameraProfileCard: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.strings.cameraLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.52))

                Text(store.project.inputLut?.title ?? store.strings.cameraAuto)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Menu {
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
            } label: {
                Label(store.strings.cameraImport, systemImage: "camera.filters")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.05), in: Capsule())
            }
        }
        .padding(.top, 4)
    }

    private var strengthBadge: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(percentLabel(store.project.strength))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.black)

            Text(store.strings.strengthLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.black.opacity(0.74))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.filmtoneAmber, in: Capsule())
    }

    @ViewBuilder
    private var messageStack: some View {
        if let notice = store.notice {
            messagePanel(title: store.strings.noticePrefix, message: notice, tint: Color.filmtoneSky)
        }

        if let error = store.bannerError {
            messagePanel(title: store.strings.errorPrefix, message: error, tint: .red)
        }
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
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func percentLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var strengthValueLabel: String {
        "\(Int((store.project.strength * 100).rounded()))"
    }

    private var adjustSummaryText: String {
        if store.source == nil {
            return store.strings.quickHint
        }
        return store.adjustmentSummaryText
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

struct FilmtoneChromeActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.filmtoneAmber.opacity(configuration.isPressed ? 0.84 : 1), in: Capsule())
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
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.05), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension Color {
    static let filmtoneAmber = Color(red: 1.0, green: 0.72, blue: 0.25)
    static let filmtoneSky = Color(red: 0.45, green: 0.66, blue: 1.0)
    static let filmtoneBackground = Color(red: 0.02, green: 0.02, blue: 0.02)
}
