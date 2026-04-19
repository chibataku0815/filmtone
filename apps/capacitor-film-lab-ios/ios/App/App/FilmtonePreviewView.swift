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
    let onVideoCompareModeSelected: (FilmtoneVideoCompareMode) -> Void

    @State private var fullscreenPresented = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.white.opacity(0.01),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            mediaBody

            if let videoPreview {
                videoChrome(videoPreview)
                    .padding(16)
            } else if isStillComparing {
                Label(originalLabel, systemImage: "square.on.square")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.filmtoneAmber, in: Capsule())
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.22), in: Capsule())
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.26), in: Capsule())

                        Spacer()
                    }
                    .padding(16)
                }
            }
        }
        .frame(minHeight: 360, maxHeight: 540)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.24), radius: 24, x: 0, y: 18)
        .fullScreenCover(isPresented: $fullscreenPresented) {
            FilmtoneFullscreenPreviewView(
                videoPreview: videoPreview,
                displayURI: displayURI,
                emptyMessage: emptyMessage,
                loadingMessage: loadingMessage,
                isRendering: isRendering,
                originalLabel: originalLabel,
                gradedLabel: gradedLabel,
                onVideoCompareModeSelected: onVideoCompareModeSelected
            )
        }
    }

    @ViewBuilder
    private var mediaBody: some View {
        if let videoPreview {
            FilmtonePreviewPlayerView(player: videoPreview.player)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else if let source, let displayURI, let image = filmtonePreviewImage(from: displayURI) {
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                fullscreenPresented = true
            } label: {
                Label(expandLabel, systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(FilmtonePreviewCapsuleButtonStyle())
        }
    }
}

private struct FilmtoneFullscreenPreviewView: View {
    let videoPreview: FilmtoneVideoPreviewState?
    let displayURI: String?
    let emptyMessage: String
    let loadingMessage: String
    let isRendering: Bool
    let originalLabel: String
    let gradedLabel: String
    let onVideoCompareModeSelected: (FilmtoneVideoCompareMode) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            Group {
                if let videoPreview {
                    FilmtonePreviewPlayerView(player: videoPreview.player)
                } else if let displayURI, let image = filmtonePreviewImage(from: displayURI) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text(emptyMessage)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(32)
                }
            }
            .ignoresSafeArea()

            HStack(alignment: .top, spacing: 12) {
                if let videoPreview {
                    HStack(spacing: 6) {
                        FilmtonePreviewToggleButton(
                            label: gradedLabel,
                            isActive: videoPreview.compareMode == .graded
                        ) {
                            onVideoCompareModeSelected(.graded)
                        }

                        FilmtonePreviewToggleButton(
                            label: originalLabel,
                            isActive: videoPreview.compareMode == .original
                        ) {
                            onVideoCompareModeSelected(.original)
                        }
                    }
                }

                Spacer(minLength: 12)

                Button(
                    filmtoneLocalized(
                        "filmtone.action.done",
                        defaultValue: "Done",
                        comment: "Action label to close the full screen preview."
                    )
                ) {
                    dismiss()
                }
                .buttonStyle(FilmtonePreviewCapsuleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.26), in: Capsule())

                        Spacer()
                    }
                    .padding(20)
                }
            }
        }
    }
}

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
                .background(isActive ? Color.filmtoneAmber : Color.black.opacity(0.42), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct FilmtonePreviewCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.black.opacity(configuration.isPressed ? 0.58 : 0.42), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
