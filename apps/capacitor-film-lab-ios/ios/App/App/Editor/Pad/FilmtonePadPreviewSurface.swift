import AVKit
import SwiftUI
import UIKit

/// iPad Workspace preview canvas.
///
/// Mirrors the Desktop preview posture: black bezel-free canvas with the
/// graded media aspect-fit at the center. M3 (iPad Preview Optimization)
/// adds iPad-native draggable split compare on stills and reuses the
/// existing iOS compare-mode toggle on video.
///
/// Source state is read directly from `FilmtoneEditorStore`. Video sources
/// surface the existing `FilmtonePreviewPlayerView` with native chrome
/// disabled (timeline bar lives outside this view in M3). Stills consume
/// `comparePreviewFrame` when available so the same URIs that drive the
/// iPhone press-and-hold full swap can drive the iPad split mask. When
/// `comparePreviewFrame` is not yet populated the single-URI fallback
/// path matches the M1 baseline.
struct FilmtonePadPreviewSurface: View {
    @ObservedObject var store: FilmtoneEditorStore
    @Binding var compareEnabled: Bool
    @Binding var compareSplitFraction: Double
    @StateObject private var videoController = FullscreenVideoController()

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {
                content
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if store.videoPreviewState != nil {
                    FilmtonePadVideoTimelineBar(
                        store: store,
                        controller: videoController
                    )
                }
            }
        }
        .accessibilityIdentifier("filmtone.pad.preview")
        .onAppear {
            if let player = store.videoPreviewState?.player {
                videoController.attach(player)
                videoController.setTimingPolicy(store.videoTimingPolicy)
            }
        }
        .onChange(of: store.videoPreviewState?.player) { _, newPlayer in
            if let newPlayer {
                videoController.attach(newPlayer)
                videoController.setTimingPolicy(store.videoTimingPolicy)
            } else {
                videoController.detach()
            }
        }
        .onChange(of: store.videoTimingPolicy) { _, newPolicy in
            videoController.setTimingPolicy(newPolicy)
        }
        .onDisappear {
            videoController.detach()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let video = store.videoPreviewState {
            videoPreview(video)
        } else if let frame = store.comparePreviewFrame {
            stillSplitPreview(frame: frame)
        } else if let stillURI = store.previewOrchestrator.selectedPreviewURI,
                  let image = Self.previewImage(from: stillURI) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .accessibilityIdentifier("filmtone.pad.preview.still")
        } else if store.preview.isRendering {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.4)
        } else if store.source == nil {
            emptyPreviewLabel
        }
    }

    @ViewBuilder
    private func stillSplitPreview(frame: FilmtoneComparePreviewFrame) -> some View {
        ZStack {
            FilmtonePadStillCompareLayer(
                frame: frame,
                compareEnabled: compareEnabled,
                compareSplitFraction: compareSplitFraction
            )
            if compareEnabled, let aspect = Self.aspectRatio(for: frame) {
                FilmtonePadCompareSplitOverlay(
                    fraction: $compareSplitFraction,
                    mediaAspectRatio: aspect
                )
            }
        }
    }

    private static func aspectRatio(for frame: FilmtoneComparePreviewFrame) -> CGFloat? {
        guard let w = frame.width, let h = frame.height, w > 0, h > 0 else {
            return nil
        }
        return CGFloat(w) / CGFloat(h)
    }

    private var emptyPreviewLabel: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.white.opacity(0.32))
            Text("素材を読み込んで開始")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.62))
            Text("ツールバーの「Open」からフォトライブラリまたはファイルを選択")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .accessibilityIdentifier("filmtone.pad.preview.empty")
    }

    @ViewBuilder
    private func videoPreview(_ video: FilmtoneVideoPreviewState) -> some View {
        let aspect = Self.aspect(for: video)
        let player = FilmtonePreviewPlayerView(
            player: video.player,
            showsPlaybackControls: false
        )
        .accessibilityIdentifier("filmtone.pad.preview.video")

        if let aspect {
            player.aspectRatio(aspect, contentMode: .fit)
        } else {
            player
        }
    }

    private static func aspect(for video: FilmtoneVideoPreviewState) -> CGFloat? {
        guard let width = video.width, let height = video.height,
              width > 0, height > 0 else {
            return nil
        }
        return CGFloat(width) / CGFloat(height)
    }

    private static func previewImage(from uri: String) -> UIImage? {
        guard let url = URL(string: uri), url.isFileURL else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
