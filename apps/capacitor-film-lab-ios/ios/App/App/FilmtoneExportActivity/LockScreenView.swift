import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity Lock Screen view for Filmtone exports.
///
/// Stream W1-A (Wave 2) implementation. Renders three rows:
///   1. Header — source filename + Postcard/Master pill.
///   2. Center — フィルム巻き取りミニ MG: two reels (source / take-up) connected
///      by a perforation strip. Reels rotate deterministically off
///      `attributes.startedAt` so updates stay consistent without animation state.
///   3. Footer — localized stage label, remaining time + percent, Cancel button.
///
/// Animation is driven exclusively by `TimelineView(.animation)` consuming the
/// timeline's `context.date`. No `@State` is held — Live Activity views must
/// re-render deterministically from `(state, attributes)` only.
@available(iOS 17.0, *)
struct LockScreenView: View {
    let state: FilmtoneExportAttributes.ContentState
    let attributes: FilmtoneExportAttributes

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow
            centerRow
            footerRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text(attributes.sourceFileName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(state.mode)
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    Capsule().fill(Color.white.opacity(0.18))
                )
        }
    }

    // MARK: - Center (フィルム巻き取りミニ MG)

    private var centerRow: some View {
        TimelineView(.animation) { timeline in
            let secs = timeline.date.timeIntervalSince(attributes.startedAt)
            let stageMultiplier: Double = (state.stage == "rendering") ? 1.0 : 0.4
            let baseDegrees = secs * 90.0 * stageMultiplier

            HStack(spacing: 0) {
                filmReel(diameter: 28, rotation: baseDegrees)
                perforationStrip()
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)
                filmReel(diameter: 20, rotation: baseDegrees * 1.4)
            }
            .frame(height: 32)
        }
        .padding(.vertical, 2)
    }

    /// Single film reel: outer ring + 6 spoke dots arranged inside.
    /// Rotated as a unit so spokes track with the rim.
    private func filmReel(diameter: CGFloat, rotation: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 2)

            // 6 spoke dots at radius = 0.55 of the disc (0.275 * diameter from center).
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) * (360.0 / 6.0)
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 3, height: 3)
                    .offset(y: -diameter * 0.275)
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(rotation))
    }

    /// Static perforation strip: thin horizontal rail with periodic notches.
    private func perforationStrip() -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)

                let notchCount = max(1, Int(geo.size.width / 8.0))
                HStack(spacing: 5) {
                    ForEach(0..<notchCount, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 3, height: 6)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack(spacing: 8) {
            Text(stageLabel)
                .font(.caption2)
                .foregroundColor(.white)

            Spacer(minLength: 8)

            Text(progressText)
                .font(.caption2.monospacedDigit())
                .foregroundColor(.white)

            if state.stage != "completed" && state.stage != "failed" {
                Button(intent: CancelExportIntent()) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundColor(Color.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stageLabel: String {
        switch state.stage {
        case "preflight": return "準備中"
        case "rendering": return "書き出し中"
        case "writing":   return "保存中"
        case "completed": return "完了"
        case "failed":    return "エラー"
        default:          return state.stage
        }
    }

    private var progressText: String {
        let percent = Int((state.progress * 100).rounded())
        if let remaining = state.estimatedRemainingSeconds, remaining > 0 {
            let total = Int(remaining.rounded())
            let mm = total / 60
            let ss = total % 60
            return String(format: "%02d:%02d 残り · %d%%", mm, ss, percent)
        }
        return "\(percent)%"
    }
}
