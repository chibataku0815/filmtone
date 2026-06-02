//
//  EditorPreviewCommands.swift
//  FilmLabSwiftCore
//
//  Shared preview command vocabulary for native Desktop and iPad.
//

import Foundation

/// Canonical preview command vocabulary shared by native Desktop and iPad.
///
/// Dispatch stays in each platform adapter: Desktop routes through
/// `EditorState` / `FilmtoneDesktopVideoSession`, while iPad routes through
/// `FullscreenVideoController` and `FilmtoneEditorStore`.
public enum FilmtoneEditorPreviewCommand: String, CaseIterable, Identifiable, Sendable {
    case compareSplitHandle
    case playPause
    case scrubTimeline
    case playbackRate

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .compareSplitHandle: return "Compare split"
        case .playPause:          return "Play / Pause"
        case .scrubTimeline:      return "Timeline scrub"
        case .playbackRate:       return "Playback speed"
        }
    }

    public func label(isActive: Bool) -> String {
        switch self {
        case .playPause:
            return isActive ? "Pause" : "Play"
        case .compareSplitHandle, .scrubTimeline, .playbackRate:
            return label
        }
    }

    public func systemImage(isActive: Bool = false) -> String {
        switch self {
        case .compareSplitHandle: return "rectangle.split.2x1"
        case .playPause:          return isActive ? "pause.fill" : "play.fill"
        case .scrubTimeline:      return "slider.horizontal.3"
        case .playbackRate:       return "speedometer"
        }
    }

    public var commandIdentifier: String {
        "filmtone.editor.preview.\(rawValue)"
    }

    public var desktopAccessibilityIdentifier: String {
        switch self {
        case .compareSplitHandle: return "filmtone.desktop.preview.compareHandle"
        case .playPause:          return "filmtone.desktop.preview.playPause"
        case .scrubTimeline:      return "filmtone.desktop.preview.scrubber"
        case .playbackRate:       return "filmtone.desktop.preview.playbackRate"
        }
    }

    public var iPadAccessibilityIdentifier: String {
        switch self {
        case .compareSplitHandle: return "filmtone.pad.compare.handle"
        case .playPause:          return "filmtone.pad.timeline.playPause"
        case .scrubTimeline:      return "filmtone.pad.timeline.scrubber"
        case .playbackRate:       return "filmtone.pad.timeline.rate2x"
        }
    }

    public func helpText(isActive: Bool = false, shortcut: String? = nil) -> String {
        let base: String
        switch self {
        case .compareSplitHandle:
            base = "Drag to change the compare split"
        case .playPause:
            base = isActive ? "Pause" : "Play"
        case .scrubTimeline:
            base = "Scrub the video timeline"
        case .playbackRate:
            base = "Playback speed"
        }
        guard let shortcut, !shortcut.isEmpty else { return base }
        return "\(base) (\(shortcut))"
    }
}

public enum FilmtonePreviewPlaybackRatePreset: Double, CaseIterable, Identifiable, Sendable {
    case oneX = 1.0
    case twoX = 2.0
    case threeX = 3.0

    public var id: Double { rawValue }

    public var label: String {
        Self.label(for: rawValue)
    }

    public static let desktopOptions: [FilmtonePreviewPlaybackRatePreset] = [
        .oneX,
        .twoX,
        .threeX,
    ]

    public static func label(for rate: Double) -> String {
        if abs(rate.rounded() - rate) < 0.01 {
            return "\(Int(rate))×"
        }
        return String(format: "%.1f×", rate)
    }
}
