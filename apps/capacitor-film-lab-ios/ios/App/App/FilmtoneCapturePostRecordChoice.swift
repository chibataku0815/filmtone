// Filmtone V2 native camera capture — take commit pill (S3).
//
// After a successful recording the capture surface no longer auto-routes
// to the editor.  The session auto-rearms for the next take (so the
// owner can shoot 3+ clips without modal friction) and a persistent
// commit pill surfaces the implicit "keep shooting" / explicit "open
// editor" decision that the strategy's open question favors.
//
// Why this lives in its own file:
//   - The orchestrator (`FilmtoneCaptureView`) routes session state
//     and lens enumeration; it should not also render the take-commit
//     readout.
//   - The pill is a pure view: take count + onCommit closure.
//     Keeping it pure here lets the orchestrator stay focused on
//     session lifecycle and gives this affordance a single grep-able
//     home.
//
// Material:
//   - Same Liquid Glass HUD family as the close / storage / contract
//     chips so the cockpit reads as one consistent surface.
//   - Selected-tint variant via `captureGlassChip(active: true)` so
//     the commit affordance reads as the actionable choice without
//     screaming.

import SwiftUI

#if os(iOS)

struct FilmtoneCapturePostRecordChoice: View {
    let takeCount: Int
    let isDisabled: Bool
    let onCommit: () -> Void

    var body: some View {
        Button(action: onCommit) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.3)
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .captureGlassChip(active: true, in: FilmtoneCaptureChrome.hudShape())
        }
        .disabled(isDisabled || takeCount == 0)
        .opacity(takeCount == 0 ? 0 : 1)
        .accessibilityIdentifier("filmtone.capture.takeCommit")
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var label: String {
        switch takeCount {
        case 0: return "Editor"
        case 1: return "Editor · 1 take"
        default: return "Editor · \(takeCount) takes"
        }
    }

    private var accessibilityLabel: String {
        switch takeCount {
        case 0: return "Open editor"
        case 1: return "Open editor with 1 take"
        default: return "Open editor with \(takeCount) takes; latest opens"
        }
    }
}

#endif
