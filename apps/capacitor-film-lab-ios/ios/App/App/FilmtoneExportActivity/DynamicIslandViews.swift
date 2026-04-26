import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Wave 1 / Stream W1-B — Dynamic Island region views for the Filmtone export
/// Live Activity. The Widget entry point in `FilmtoneExportActivity.swift`
/// dispatches each `DynamicIsland` region to a static func on this namespace,
/// so the seven `func` signatures below are load-bearing.
///
/// Reel motif: stroked Circle + spoke dots, rotated by wall-clock
/// `TimelineView(.animation)` (period varies by stage). Cancel button uses
/// `Button(intent: CancelExportIntent())`; Apple routes the intent into the
/// host App process where `ExportCancelController.shared` is the canonical sink.
@available(iOS 17.0, *)
enum DynamicIslandViews {

    // MARK: - Stage helpers

    /// Japanese stage label shared with Lock Screen (W1-A).
    private static func stageLabelJP(_ stage: String) -> String {
        switch stage {
        case "preflight":  return "準備中"
        case "rendering":  return "書き出し中"
        case "writing":    return "保存中"
        case "completed":  return "完了"
        case "failed":     return "エラー"
        default:           return stage
        }
    }

    private static func isTerminal(_ stage: String) -> Bool {
        stage == "completed" || stage == "failed"
    }

    /// Wall-clock period (seconds) per full reel rotation, by stage.
    /// Terminal stages return nil — caller freezes rotation.
    private static func rotationPeriod(for stage: String, mode: ReelMode) -> Double? {
        if isTerminal(stage) { return nil }
        switch mode {
        case .compact:
            return stage == "rendering" ? 4.0 : 8.0
        case .minimal:
            return 6.0
        case .expanded:
            return stage == "rendering" ? 4.0 : 8.0
        }
    }

    private enum ReelMode { case compact, minimal, expanded }

    /// Compute current rotation degrees from a TimelineView date so the reel
    /// position is a pure function of wall clock — no `@State`, no animation
    /// modifier needed (Live Activity views can't host real-time animation
    /// other than via TimelineView).
    private static func rotationDegrees(date: Date, period: Double) -> Double {
        let secs = date.timeIntervalSince(Date(timeIntervalSince1970: 0))
            .truncatingRemainder(dividingBy: period)
        return (secs / period) * 360.0
    }

    // MARK: - Reel shapes

    /// Stroked circle + N evenly-spaced spoke dots, rotated as a unit.
    private struct ReelShape: View {
        let diameter: CGFloat
        let lineWidth: CGFloat
        let spokeCount: Int        // 0 = no spokes (minimal)
        let spokeRadius: CGFloat   // distance from center
        let spokeDotSize: CGFloat
        let degrees: Double

        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.85), lineWidth: lineWidth)
                    .frame(width: diameter, height: diameter)

                if spokeCount > 0 {
                    ForEach(0..<spokeCount, id: \.self) { i in
                        let angle = Double(i) / Double(spokeCount) * 2.0 * .pi
                        Circle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: spokeDotSize, height: spokeDotSize)
                            .offset(
                                x: CGFloat(cos(angle)) * spokeRadius,
                                y: CGFloat(sin(angle)) * spokeRadius
                            )
                    }
                }
            }
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(degrees))
        }
    }

    // MARK: - Compact island

    static func compactLeading(state: FilmtoneExportAttributes.ContentState) -> some View {
        let stage = state.stage
        return TimelineView(.animation) { ctx in
            let period = rotationPeriod(for: stage, mode: .compact)
            let degrees = period.map { rotationDegrees(date: ctx.date, period: $0) } ?? 0
            ReelShape(
                diameter: 16,
                lineWidth: 1.5,
                spokeCount: 4,
                spokeRadius: 4,
                spokeDotSize: 1.5,
                degrees: degrees
            )
        }
        .frame(width: 24, height: 24)
    }

    static func compactTrailing(state: FilmtoneExportAttributes.ContentState) -> some View {
        Text("\(Int(state.progress * 100))%")
            .font(.caption2.monospacedDigit())
            .foregroundColor(.white)
    }

    // MARK: - Minimal island (single-Activity case)

    static func minimal(state: FilmtoneExportAttributes.ContentState) -> some View {
        let stage = state.stage
        return Group {
            if stage == "completed" {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
            } else if stage == "failed" {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                TimelineView(.animation) { ctx in
                    let period = rotationPeriod(for: stage, mode: .minimal) ?? 6.0
                    let degrees = rotationDegrees(date: ctx.date, period: period)
                    ReelShape(
                        diameter: 12,
                        lineWidth: 1,
                        spokeCount: 0,
                        spokeRadius: 0,
                        spokeDotSize: 0,
                        degrees: degrees
                    )
                }
            }
        }
        .frame(width: 16, height: 16)
    }

    // MARK: - Expanded regions

    static func expandedLeading(state: FilmtoneExportAttributes.ContentState) -> some View {
        let stage = state.stage
        let mode = state.mode
        return VStack(alignment: .leading, spacing: 6) {
            TimelineView(.animation) { ctx in
                let period = rotationPeriod(for: stage, mode: .expanded)
                let degrees = period.map { rotationDegrees(date: ctx.date, period: $0) } ?? 0
                ReelShape(
                    diameter: 32,
                    lineWidth: 2,
                    spokeCount: 6,
                    spokeRadius: 11,
                    spokeDotSize: 2,
                    degrees: degrees
                )
            }
            .frame(width: 32, height: 32)

            Text(mode)
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(
                    Capsule().fill(Color.white.opacity(0.18))
                )
        }
    }

    static func expandedTrailing(state: FilmtoneExportAttributes.ContentState) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(Int(state.progress * 100))%")
                .font(.title3.monospacedDigit().bold())
                .foregroundColor(.white)

            if let remaining = state.estimatedRemainingSeconds, remaining > 0 {
                let total = Int(remaining.rounded())
                let mm = total / 60
                let ss = total % 60
                Text(String(format: "%02d:%02d 残り", mm, ss))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text(" ")
                    .font(.caption2)
                    .foregroundColor(.clear)
            }
        }
    }

    static func expandedCenter(
        state: FilmtoneExportAttributes.ContentState,
        attributes: FilmtoneExportAttributes
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(attributes.sourceFileName)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            ProgressView(value: max(0, min(1, state.progress)))
                .progressViewStyle(.linear)
                .tint(.white)
        }
    }

    static func expandedBottom(state: FilmtoneExportAttributes.ContentState) -> some View {
        let stage = state.stage
        let label = stageLabelJP(stage)
        return HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            if !isTerminal(stage) {
                Button(intent: CancelExportIntent()) {
                    Label("キャンセル", systemImage: "xmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
