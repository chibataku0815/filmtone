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
