import Foundation
import SwiftUI

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

/// Onboarding pre-shown before the empty view. Aligned 2026-05-09 to
/// the empty-view's M15-final v6 visual language: cream substrate +
/// `FilmtoneFluidBlobBackdrop` Metal-shader fluid blob backdrop +
/// `.preferredColorScheme(.light)` so adaptive `.primary` colors
/// flip to dark text on the light substrate. Liquid Glass primary
/// CTA + text-link secondary mirrors the empty-view action stack
/// hierarchy.
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
            // v1.3 Item 3 follow-up: 4th slide pitches the reuse loop.
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
            substrate
                .ignoresSafeArea()

            FilmtoneFluidBlobBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(strings.appName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.78))
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
        .preferredColorScheme(.light)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    /// Cream warm-pastel substrate matching the empty view's
    /// `FilmtoneEmptyView.substrate` so the two surfaces feel like one
    /// continuous environment instead of two separate themes.
    private var substrate: some View {
        Color(red: 0.86, green: 0.82, blue: 0.78)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button {
                performPrimaryAction()
            } label: {
                Text(primaryActionLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.94))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .glassEffect(
                        .regular.tint(Color.filmtoneAmber.opacity(0.20)).interactive(),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            Color.filmtoneAmber.opacity(0.32),
                            lineWidth: 0.6
                        )
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(isLastPage ? "filmtone.onboarding.pickMedia" : "filmtone.onboarding.next")

            Button(action: onSkip) {
                Text(strings.onboardingSkip)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("filmtone.onboarding.skip")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 26)
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
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(slide.body)
                        .font(.body)
                        .foregroundStyle(.primary.opacity(0.74))
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

/// Per-slide stylized preview card. Aligned 2026-05-09 to the empty-
/// view Liquid Glass language: glass material body + adaptive
/// `.primary` text bars + amber accent kept for the per-slide
/// "active meter" indicator (amber works on both light and dark
/// substrates). The card no longer paints its own opaque white-low-
/// opacity fill that previously read as a flat gray box on the
/// cream substrate.
private struct FilmtoneOnboardingPreviewCard: View {
    let slide: FilmtoneOnboardingSlide

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: filmtonePreviewCornerRadius,
            style: .continuous
        )
        return ZStack {
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
                            .fill(Color.primary.opacity(0.32))
                            .frame(width: 96, height: 9)
                        Capsule()
                            .fill(Color.primary.opacity(0.22))
                            .frame(width: 118, height: 9)
                        Capsule()
                            .fill(Color.primary.opacity(0.14))
                            .frame(width: 76, height: 9)
                    }
                }

                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 10) {
                            Capsule()
                                .fill(Color.primary.opacity(0.18))
                                .frame(width: 42, height: 8)

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.10))
                                    Capsule()
                                        .fill(index == slide.id
                                              ? Color.filmtoneAmber.opacity(0.86)
                                              : Color.primary.opacity(0.28))
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
        .glassEffect(.regular.interactive(), in: shape)
        .overlay(
            shape.strokeBorder(Color.filmtoneAmber.opacity(0.22), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 16)
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
