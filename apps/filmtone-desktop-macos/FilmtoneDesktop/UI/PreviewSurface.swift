import AppKit
import SwiftUI

struct PreviewSurface: View {
    let imageURL: URL?

    var body: some View {
        Color.black
            .overlay {
                if let imageURL {
                    PreviewImageView(imageURL: imageURL)
                } else {
                    EmptyPreviewLabel()
                }
            }
    }
}

private struct PreviewImageView: NSViewRepresentable {
    let imageURL: URL

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.imageFrameStyle = .none
        view.isEditable = false
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSImage(contentsOf: imageURL)
    }
}

private struct EmptyPreviewLabel: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("Open a still image to preview")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PreviewSurface(imageURL: nil)
        .frame(width: 600, height: 400)
}
