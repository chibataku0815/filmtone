import AVFoundation
import FilmLabSwiftCore
import SwiftUI

/// iPad video timeline rail (M3).
///
/// Sits along the bottom of `FilmtonePadPreviewSurface` when a video
/// source is loaded. Layout left-to-right:
///   [Play/Pause] [00:00] [────●────] [00:00]
///
/// Reuses the iPhone fullscreen editor's `FullscreenVideoController` for
/// AVPlayer time-observer plumbing, play/pause, and seek. Compare stays on
/// the top `FilmtonePadToolbar` so the timeline rail is a pure time-axis
/// control surface that does not cover the subject.
struct FilmtonePadVideoTimelineBar: View {
    @ObservedObject var store: FilmtoneEditorStore
    @ObservedObject var controller: FullscreenVideoController

    var body: some View {
        HStack(spacing: 14) {
            playPauseButton
            timeLabel(controller.currentTime)
            scrubber
            timeLabel(controller.duration)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
        .accessibilityIdentifier("filmtone.pad.timeline")
    }

    private var playPauseButton: some View {
        Button {
            controller.togglePlayPause()
        } label: {
            Image(
                systemName: FilmtoneEditorPreviewCommand.playPause
                    .systemImage(isActive: controller.isPlaying)
            )
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(
                    width: FilmtonePadTouchMetrics.iconControlSize,
                    height: FilmtonePadTouchMetrics.iconControlSize
                )
                .glassEffect(.regular.tint(Color.black.opacity(0.22)), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(FilmtoneEditorPreviewCommand.playPause.iPadAccessibilityIdentifier)
        .accessibilityLabel(
            FilmtoneEditorPreviewCommand.playPause.label(isActive: controller.isPlaying)
        )
    }

    private func timeLabel(_ seconds: Double) -> some View {
        Text(Self.formatTime(seconds))
            .font(.subheadline.monospacedDigit().weight(.medium))
            .foregroundStyle(.white.opacity(0.82))
            .frame(minWidth: 44, alignment: .leading)
    }

    private var scrubber: some View {
        Slider(
            value: Binding(
                get: { controller.currentTime },
                set: { newValue in
                    controller.isScrubbing = true
                    controller.currentTime = newValue
                    controller.seek(to: newValue)
                }
            ),
            in: 0...max(controller.duration, 0.001),
            onEditingChanged: { editing in
                controller.isScrubbing = editing
            }
        )
        .tint(Color.filmtoneAmber)
        .frame(minHeight: FilmtonePadTouchMetrics.sliderTouchHeight)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityIdentifier(FilmtoneEditorPreviewCommand.scrubTimeline.iPadAccessibilityIdentifier)
        .accessibilityLabel(FilmtoneEditorPreviewCommand.scrubTimeline.label)
    }

    private static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
