import SwiftUI
import UIKit

struct FilmtonePreviewView: View {
    let source: SourceInfoDTO?
    let displayURI: String?
    let emptyMessage: String
    let compareLabel: String
    let isRendering: Bool
    let metaLabel: String?
    let isComparing: Bool
    let onCompareHeld: (Bool) -> Void

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

            if let source, let displayURI, let image = previewImage(from: displayURI) {
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
                            onCompareHeld(isPressing)
                        },
                        perform: {}
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("QUICK PREVIEW")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.36))
                        .tracking(2.2)

                    Rectangle()
                        .fill(Color.filmtoneAmber.opacity(0.72))
                        .frame(width: 28, height: 2)

                    Text(emptyMessage)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white.opacity(0.90))
                        .lineSpacing(2)
                        .frame(maxWidth: 220, alignment: .leading)

                    Text("Looks render here as you grade.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.52))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(28)
            }

            if isComparing {
                Label(compareLabel, systemImage: "square.on.square")
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
                            Text(emptyMessage)
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
    }

    private func previewImage(from uri: String) -> UIImage? {
        guard let url = URL(string: uri), url.isFileURL else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
