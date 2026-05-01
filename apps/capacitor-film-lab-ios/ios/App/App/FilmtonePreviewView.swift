import AVFoundation
import SwiftUI
import UIKit

struct FilmtonePreviewView: View {
    let source: SourceInfoDTO?
    let displayURI: String?
    let videoPreview: FilmtoneVideoPreviewState?
    let emptyMessage: String
    let emptyEyebrow: String
    let emptyHint: String
    let loadingMessage: String
    let originalLabel: String
    let gradedLabel: String
    let expandLabel: String
    let isRendering: Bool
    let metaLabel: String?
    let isStillComparing: Bool
    let onStillCompareHeld: (Bool) -> Void
    /// Open the parent-owned fullscreen LUT editor. Replaces the local
    /// `fullScreenCover` (which was video-only via `videoChrome`) so the
    /// expand affordance is available for stills as well — see
    /// `FilmtoneFullscreenLutEditor`.
    let onOpenFullscreen: () -> Void
    let onVideoCompareModeSelected: (FilmtoneVideoCompareMode) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: filmtonePreviewCornerRadius, style: .continuous)
                .fill(Color.black)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.white.opacity(0.01),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: filmtonePreviewCornerRadius, style: .continuous))

            mediaBody

            if let videoPreview {
                videoChrome(videoPreview)
                    .padding(16)
            } else if source != nil {
                stillChrome
                    .padding(16)
            }

            if isStillComparing {
                Text(originalLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.filmtoneAmber)
                    )
                    .padding(16)
            }

            if let metaLabel {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(metaLabel)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.white.opacity(0.48))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.black.opacity(0.24))
                            )
                            .padding(16)
                    }
                }
            }

            if isRendering {
                VStack {
                    Spacer()
                    HStack {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.filmtoneAmber)
                            Text(loadingMessage)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.black.opacity(0.28))
                        )

                        Spacer()
                    }
                    .padding(16)
                }
            }
        }
        .frame(minHeight: 360, maxHeight: 540)
        .overlay(
            RoundedRectangle(cornerRadius: filmtonePreviewCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: filmtonePreviewCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.24), radius: 24, x: 0, y: 18)
    }

    /// Static-image variant of the chrome. Only the "Full Screen" button
    /// — stills don't have Graded / Original toggles (the long-press
    /// gesture handles still compare). Right-aligned via HStack so it sits
    /// in the same visual slot as the video Full Screen button.
    private var stillChrome: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            Button {
                onOpenFullscreen()
            } label: {
                Label(expandLabel, systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(FilmtonePreviewControlButtonStyle())
            .accessibilityIdentifier("filmtone.preview.fullscreen.still")
        }
    }

    @ViewBuilder
    private var mediaBody: some View {
        if let videoPreview {
            FilmtonePreviewPlayerView(player: videoPreview.player)
                .clipShape(RoundedRectangle(cornerRadius: filmtonePreviewCornerRadius, style: .continuous))
        } else if let source, let displayURI, let image = filmtonePreviewImage(from: displayURI) {
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(RoundedRectangle(cornerRadius: filmtonePreviewCornerRadius, style: .continuous))
                    .onLongPressGesture(
                        minimumDuration: 0.18,
                        maximumDistance: 24,
                        pressing: { isPressing in
                            if source.filename.isEmpty {
                                return
                            }
                            onStillCompareHeld(isPressing)
                        },
                        perform: {}
                    )
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text(emptyEyebrow)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.36))

                Rectangle()
                    .fill(Color.filmtoneAmber.opacity(0.72))
                    .frame(width: 28, height: 2)

                Text(emptyMessage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineSpacing(2)
                    .lineLimit(3)
                    .frame(maxWidth: 280, alignment: .leading)

                Text(emptyHint)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(28)
        }
    }

    @ViewBuilder
    private func videoChrome(_ preview: FilmtoneVideoPreviewState) -> some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 6) {
                FilmtonePreviewToggleButton(
                    label: gradedLabel,
                    isActive: preview.compareMode == .graded
                ) {
                    onVideoCompareModeSelected(.graded)
                }

                FilmtonePreviewToggleButton(
                    label: originalLabel,
                    isActive: preview.compareMode == .original
                ) {
                    onVideoCompareModeSelected(.original)
                }
            }

            Spacer(minLength: 12)

            Button {
                onOpenFullscreen()
            } label: {
                Label(expandLabel, systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(FilmtonePreviewControlButtonStyle())
            .accessibilityIdentifier("filmtone.preview.fullscreen.video")
        }
    }
}

// FilmtoneFullscreenPreviewView (the previous video-only fullscreen) was
// removed when the surface migrated to `FilmtoneFullscreenLutEditor`
// (parent-owned via `onOpenFullscreen`). The Full Screen button is now
// available for both still + video and routes to the LUT editor.

private func filmtonePreviewImage(from uri: String) -> UIImage? {
    guard let url = URL(string: uri), url.isFileURL else {
        return nil
    }
    return UIImage(contentsOfFile: url.path)
}

private struct FilmtonePreviewToggleButton: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isActive ? Color.black : .white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                        .fill(isActive ? Color.filmtoneAmber : Color.black.opacity(0.42))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                        .stroke(isActive ? Color.filmtoneAmber : Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FilmtonePreviewControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(configuration.isPressed ? 0.58 : 0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
