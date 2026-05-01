import SwiftUI
import UIKit


struct FilmtoneSheetPreview: View {
    let displayURI: String?
    let compareFrame: FilmtoneComparePreviewFrame?
    let videoPreview: FilmtoneVideoPreviewState?
    let emptyMessage: String
    let loadingMessage: String
    let originalLabel: String
    let gradedLabel: String
    let metaLabel: String?
    let isRendering: Bool

    var body: some View {
        let stillImage = displayURI.flatMap(previewImage(from:))
        let hasVisiblePreview = compareFrame != nil || videoPreview != nil || stillImage != nil

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.black)

            if let compareFrame {
                FilmtoneCompareRevealPreview(
                    frame: compareFrame,
                    originalLabel: originalLabel,
                    gradedLabel: gradedLabel
                )
            } else if let videoPreview {
                FilmtonePreviewPlayerView(player: videoPreview.player)
                    .accessibilityIdentifier("filmtone.sheet.preview.video")
            } else if let image = stillImage {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(Rectangle())
                }
            } else {
                Text(emptyMessage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineSpacing(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(16)
            }

            if let metaLabel {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(metaLabel)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.white.opacity(0.68))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.black.opacity(0.5))
                            )
                            .padding(12)
                    }
                }
            }

            if isRendering {
                if hasVisiblePreview {
                    refreshIndicator
                } else {
                    loadingPanel
                }
            }
        }
        .frame(height: 210)
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipped()
    }

    private func previewImage(from uri: String) -> UIImage? {
        guard let url = URL(string: uri), url.isFileURL else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private var refreshIndicator: some View {
        VStack {
            HStack {
                Spacer()

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.filmtoneAmber)
                    .scaleEffect(0.72)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.46))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(12)
            }

            Spacer()
        }
        .accessibilityIdentifier("filmtone.sheet.preview.refreshing")
        .accessibilityLabel(loadingMessage)
    }

    private var loadingPanel: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.filmtoneAmber)

                Text(loadingMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.6))
            )
        }
        .padding(12)
        .accessibilityIdentifier("filmtone.sheet.preview.loading")
    }
}

private struct FilmtoneCompareRevealPreview: View {
    let frame: FilmtoneComparePreviewFrame
    let originalLabel: String
    let gradedLabel: String

    @State private var revealAmount = 0.58

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let dividerX = min(max(width * revealAmount, 18), width - 18)

            ZStack {
                if let originalImage = previewImage(from: frame.originalURI),
                   let gradedImage = previewImage(from: frame.gradedURI) {
                    Image(uiImage: originalImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: height)

                    Image(uiImage: gradedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: height)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: dividerX, height: height)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                    labelPills
                        .padding(12)

                    Rectangle()
                        .fill(Color.white.opacity(0.84))
                        .frame(width: 2, height: height)
                        .position(x: dividerX, y: height / 2)

                    Image(systemName: "arrow.left.and.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black.opacity(0.82))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(Color.filmtoneAmber)
                        )
                        .shadow(color: Color.black.opacity(0.34), radius: 12, x: 0, y: 4)
                        .position(x: dividerX, y: height / 2)
                } else {
                    Color.black
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        revealAmount = min(max(value.location.x / width, 0), 1)
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("filmtone.sheet.preview.compare.slider")
            .accessibilityLabel("\(gradedLabel) / \(originalLabel)")
            .accessibilityValue("\(Int((revealAmount * 100).rounded()))%")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    revealAmount = min(revealAmount + 0.05, 1)
                case .decrement:
                    revealAmount = max(revealAmount - 0.05, 0)
                @unknown default:
                    break
                }
            }
        }
    }

    private var labelPills: some View {
        VStack {
            HStack {
                Text(gradedLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.filmtoneAmber)
                    )

                Spacer()

                Text(originalLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.56))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }

            Spacer()
        }
    }

    private func previewImage(from uri: String) -> UIImage? {
        guard let url = URL(string: uri), url.isFileURL else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}


