import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RootWindowView: View {
    @State private var imageURL: URL?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PreviewSurface(imageURL: imageURL)
            GlassControlGroup()
                .padding(20)
        }
        .frame(minWidth: 880, minHeight: 560)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Image(systemName: "camera.aperture")
                    .symbolRenderingMode(.hierarchical)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentOpenPanel()
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .keyboardShortcut("o", modifiers: .command)
                .help("Open a still image")
            }
        }
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Open"
        panel.message = "Choose a still image to preview"
        if panel.runModal() == .OK, let url = panel.url {
            imageURL = url
        }
    }
}

#Preview {
    RootWindowView()
}
