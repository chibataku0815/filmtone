// Filmtone V2 native camera capture — bottom-zone lens chip row (M13-M-2).
//
// Horizontal pill row of available capture lenses. Each chip is its own
// Liquid Glass surface inside the parent's `GlassEffectContainer`, so
// adjacent chips merge as one material and the selected highlight
// uses the same clip path as the chip itself (no overflow).

import SwiftUI

#if os(iOS)

struct FilmtoneCaptureLensChipRow: View {
    let lenses: [FilmtoneCaptureLens]
    let selectedLens: FilmtoneCaptureLens?
    let isRecordingOrStopping: Bool
    let lensSwitchInFlight: Bool
    let onSelect: (FilmtoneCaptureLens) -> Void

    var body: some View {
        HStack(spacing: FilmtoneCaptureChrome.parameterChipSpacing) {
            ForEach(lenses) { lens in
                lensChip(lens)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isRecordingOrStopping ? 0.55 : 1)
        .accessibilityIdentifier("filmtone.capture.lensSelector")
    }

    @ViewBuilder
    private func lensChip(_ lens: FilmtoneCaptureLens) -> some View {
        let isSelected = lens == selectedLens
        Button {
            FilmtoneCaptureHaptics.selection()
            onSelect(lens)
        } label: {
            Text(lens.magnificationLabel)
                .font(
                    .system(
                        size: 12,
                        weight: isSelected ? .bold : .semibold,
                        design: .rounded
                    ).monospacedDigit()
                )
                .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(
                    minWidth: FilmtoneCaptureChrome.lensChipMinWidth,
                    minHeight: FilmtoneCaptureChrome.lensChipMinHeight
                )
                .captureGlassChip(
                    active: isSelected,
                    in: FilmtoneCaptureChrome.lensChipShape()
                )
        }
        .disabled(isRecordingOrStopping || lensSwitchInFlight || isSelected)
        .accessibilityIdentifier("filmtone.capture.lens.\(accessibilityPosition(for: lens)).\(lens.deviceTypeRaw)")
        .accessibilityLabel(Text("\(lens.magnificationLabel) \(lens.canonicalSubtext)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityPosition(for lens: FilmtoneCaptureLens) -> String {
        switch lens.device.position {
        case .back: return "back"
        case .front: return "front"
        case .unspecified: return "unspecified"
        @unknown default: return "unknown"
        }
    }
}

#endif
