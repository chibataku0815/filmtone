// Filmtone V2 native camera capture — AVCaptureVideoPreviewLayer bridge.

import AVFoundation
import SwiftUI
import UIKit

#if os(iOS)

struct FilmtoneCapturePreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewContainer {
        let v = PreviewContainer()
        v.attach(layer: previewLayer)
        return v
    }

    func updateUIView(_ uiView: PreviewContainer, context: Context) {
        uiView.attach(layer: previewLayer)
    }

    final class PreviewContainer: UIView {
        private var attachedLayer: AVCaptureVideoPreviewLayer?

        override class var layerClass: AnyClass { CALayer.self }

        func attach(layer: AVCaptureVideoPreviewLayer) {
            if attachedLayer === layer { return }
            attachedLayer?.removeFromSuperlayer()
            self.attachedLayer = layer
            layer.frame = bounds
            self.layer.addSublayer(layer)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            attachedLayer?.frame = bounds
        }
    }
}

#endif
