import AVFoundation
import AVKit
import AppKit
import SwiftUI

// M5-I.2 AVPlayer preview route — SwiftUI host.
//
// Wraps `AVPlayerView` so SwiftUI's `PreviewSurface` can mount the AVPlayer
// produced by `FilmtoneDesktopVideoSession`. AVKit's built-in chrome is
// suppressed (`controlsStyle = .none`) because the Liquid Glass scrub bar
// + rate menu in `RootWindowView` drives playback. `videoGravity =
// .resizeAspect` keeps the source aspect ratio; the surrounding
// `PreviewSurface` paints a `Color.black` backdrop so any letterbox bars
// stay neutral and don't bleed warmth into color judgment.

struct FilmtoneDesktopPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = false
        view.allowsPictureInPicturePlayback = false
        // The black layer behind the video makes the letterbox neutral
        // even before SwiftUI's outer Color.black catches edge cases at
        // window-resize time.
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
