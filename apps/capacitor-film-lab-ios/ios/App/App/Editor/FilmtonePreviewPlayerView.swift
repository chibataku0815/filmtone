import AVKit
import SwiftUI

struct FilmtonePreviewPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    var showsPlaybackControls = true

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = showsPlaybackControls
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        controller.allowsPictureInPicturePlayback = false
        controller.updatesNowPlayingInfoCenter = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
        controller.showsPlaybackControls = showsPlaybackControls
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
    }
}
