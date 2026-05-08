// Filmtone V2 native camera capture — top status chrome.
//
// M13-M-2: Apple Liquid Glass primitives only, angular shape vocabulary.
// The HUD readout uses `hudShape` (RoundedRectangle 10pt) instead of a
// pill so it reads as a pro camera strip; the close button stays a
// `Circle()` (camera convention).

import SwiftUI

#if os(iOS)

struct FilmtoneCaptureTopStatusBar: View {
    let isCloseDisabled: Bool
    let storageIcon: String
    let storageLabel: String
    let qualityContractText: String
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 36, height: 36)
                    .captureGlassControl(in: Circle())
            }
            .accessibilityIdentifier("filmtone.capture.close")
            .disabled(isCloseDisabled)

            Spacer(minLength: 8)

            hudReadout
        }
    }

    private var hudReadout: some View {
        HStack(spacing: 8) {
            Image(systemName: storageIcon)
                .font(.system(size: 11, weight: .bold))
            Text(storageLabel)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("filmtone.capture.storagePill")
            Rectangle()
                .fill(.white.opacity(0.22))
                .frame(width: 1, height: 11)
            Text(qualityContractText)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("filmtone.capture.qualityContractChip")
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .captureGlassHUD(in: FilmtoneCaptureChrome.hudShape())
    }
}

#endif
