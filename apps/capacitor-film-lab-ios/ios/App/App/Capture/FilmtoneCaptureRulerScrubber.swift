// Filmtone V2 native camera capture — horizontal ruler scrubber (M13-M-3).
//
// SwiftUI primitive: a Blackmagic-style horizontal ruler that scrolls
// under a center-pinned indicator. Drag horizontally to change the
// value within `range`; each crossed tick fires a selection haptic.
//
// Pure value-typed surface — no session / model knowledge here. The
// caller (`FilmtoneCaptureCockpitTopBar`) chooses the right
// `range / step / formatter / onChange` tuple per active parameter
// chip and forwards drag values to `FilmtoneCaptureSession`.

import SwiftUI
import UIKit

#if os(iOS)

/// Horizontal ruler scrubber. The visible window represents
/// `pointsPerMinorStep × widthInPoints / minorStep` units of the
/// range; dragging the ruler horizontally translates pan distance
/// into a value delta inside `range`.
///
/// Visual:
///
/// ```
///         ┌─── current value (monospaced) ───┐
///         │              123                  │
///         ├──────────────|──────────────────┤
///         │ │ │ │ │ │ │  │  │ │ │ │ │ │ │ │ │
///         │ │ │ │ │ │ │  │  │ │ │ │ │ │ │ │ │
///         └────────────── center pin ────────┘
///           min                           max
/// ```
///
/// The center pin is fixed; the ruler scrolls. Apple Liquid Glass
/// rail body matches the cockpit's `rulerShape()` (cornerRadius 11pt).
struct FilmtoneCaptureRulerScrubber: View {

    /// Display value. Drives initial scroll position; the caller is
    /// responsible for echoing the latest `onChange` value back so
    /// the indicator stays under the latest reading even while the
    /// caller publishes through a `@Published`.
    let value: Double

    /// Inclusive value range. Drag is clamped to this range.
    let range: ClosedRange<Double>

    /// Major tick spacing in value units. Drawn as a slightly taller
    /// tick + numeric label on the ruler.
    let majorStep: Double

    /// Minor tick spacing in value units. Drawn as a short faint tick.
    /// Used for haptic granularity (1 selection feedback per crossed
    /// minor tick).
    let minorStep: Double

    /// Center indicator readout. Caller-supplied so the ruler can
    /// format ISO as `Int`, EV as `+1.3`, shutter as `1/48s`, etc.
    let valueLabel: (Double) -> String

    /// Optional formatter for major-tick labels. Defaults to
    /// `Int(rounded)` so EV shows `-1 0 +1`, ISO shows `100 200 400`,
    /// and shutter (sub-1 values) needs an explicit override.
    let majorTickLabel: (Double) -> String

    /// Continuous drag callback. Fires every animation tick the value
    /// changes; the caller pushes through to the device.
    let onChange: (Double) -> Void

    /// Optional drag-end callback. Use for "commit on release" calls
    /// that should not run during the gesture (rare on a camera
    /// scrubber — most paths just use `onChange`).
    let onCommit: ((Double) -> Void)?

    init(
        value: Double,
        range: ClosedRange<Double>,
        majorStep: Double,
        minorStep: Double,
        valueLabel: @escaping (Double) -> String,
        majorTickLabel: @escaping (Double) -> String = { String(Int($0.rounded())) },
        onChange: @escaping (Double) -> Void,
        onCommit: ((Double) -> Void)? = nil
    ) {
        self.value = value
        self.range = range
        self.majorStep = majorStep
        self.minorStep = minorStep
        self.valueLabel = valueLabel
        self.majorTickLabel = majorTickLabel
        self.onChange = onChange
        self.onCommit = onCommit
    }

    /// Width occupied by one minor tick on screen. Constant across
    /// the visible window so a 100pt drag = 100pt / `pointsPerMinorTick`
    /// minor steps regardless of where the value currently sits.
    private let pointsPerMinorTick: CGFloat = 8

    /// Drag accumulator: value at gesture start. Captured so the
    /// gesture's `translation.width` is interpreted relative to the
    /// starting reading rather than the latest external publish.
    @State private var dragStartValue: Double?

    /// Last value emitted via `onChange`. Used to count crossed minor
    /// ticks for haptics.
    @State private var lastEmittedValue: Double?

    /// Body. The scrubber is bounded; height matches
    /// `FilmtoneCaptureChrome` ruler region 56pt.
    var body: some View {
        VStack(spacing: 2) {
            valueReadout
            rulerCanvas
            rangeBookends
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .captureGlassRail(in: FilmtoneCaptureChrome.rulerShape())
        .contentShape(FilmtoneCaptureChrome.rulerShape())
        .gesture(scrubGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(valueLabel(value)))
        .accessibilityIdentifier("filmtone.capture.scrubber")
    }

    // MARK: Subviews

    private var valueReadout: some View {
        Text(valueLabel(value))
            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(0.95))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var rulerCanvas: some View {
        Canvas { context, size in
            drawTicks(context: context, size: size)
            drawCenterPin(context: context, size: size)
        }
        .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26)
    }

    private var rangeBookends: some View {
        HStack {
            Text(majorTickLabel(range.lowerBound))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.42))
            Spacer()
            Text(majorTickLabel(range.upperBound))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.42))
        }
    }

    // MARK: Canvas drawing

    private func drawTicks(context: GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        // Snap the displayed value to the nearest minor tick so the
        // ticks slide as discrete units rather than blur sub-pixel.
        let clampedValue = min(max(value, range.lowerBound), range.upperBound)

        // How many minor ticks fit in half the viewport (each side of
        // center). Adds 1 for safety margin on the edge.
        let minorTicksPerHalf = Int(centerX / pointsPerMinorTick) + 1

        for offset in -minorTicksPerHalf...minorTicksPerHalf {
            let tickValue = clampedValue + Double(offset) * minorStep
            // Skip ticks outside the range so the ruler does not draw
            // ticks past the bookends.
            guard tickValue >= range.lowerBound - minorStep / 2,
                  tickValue <= range.upperBound + minorStep / 2 else { continue }

            let x = centerX + CGFloat(offset) * pointsPerMinorTick
            // Major tick test: rounds to the nearest majorStep within
            // a tolerance of half a minorStep so floating-point drift
            // does not occasionally skip a major tick.
            let nearestMajor = (tickValue / majorStep).rounded() * majorStep
            let isMajor = abs(tickValue - nearestMajor) < (minorStep / 2)

            let tickHeight: CGFloat = isMajor ? 18 : 9
            let tickY1 = centerY - tickHeight / 2
            let tickY2 = centerY + tickHeight / 2
            let opacity = isMajor ? 0.78 : 0.34

            var path = Path()
            path.move(to: CGPoint(x: x, y: tickY1))
            path.addLine(to: CGPoint(x: x, y: tickY2))
            context.stroke(
                path,
                with: .color(.white.opacity(opacity)),
                lineWidth: isMajor ? 1.0 : 0.6
            )

            // Major tick numeric label, drawn beneath the tick when
            // the tick is far enough from the center indicator that
            // it does not overlap the value readout above.
            if isMajor && abs(x - centerX) > 22 {
                let label = majorTickLabel(nearestMajor)
                let resolved = context.resolve(
                    Text(label)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                )
                let textSize = resolved.measure(in: CGSize(width: 30, height: 14))
                context.draw(
                    resolved,
                    at: CGPoint(
                        x: x,
                        y: tickY2 + textSize.height / 2 + 1
                    )
                )
            }
        }
    }

    private func drawCenterPin(context: GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        var path = Path()
        path.move(to: CGPoint(x: centerX, y: 1))
        path.addLine(to: CGPoint(x: centerX, y: size.height - 1))
        context.stroke(
            path,
            with: .color(FilmtoneCaptureChrome.amber),
            lineWidth: 2.0
        )
    }

    // MARK: Gesture

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { state in
                let start = dragStartValue ?? value
                if dragStartValue == nil {
                    dragStartValue = value
                    lastEmittedValue = value
                }
                // Drag the ruler left → value increases (the ticks
                // scroll right under a fixed indicator, so a leftward
                // drag points the indicator at a higher value). This
                // matches the Blackmagic / iOS Camera convention.
                let dx = -state.translation.width
                let valueDelta = Double(dx) / Double(pointsPerMinorTick) * minorStep
                let raw = start + valueDelta
                let clamped = min(max(raw, range.lowerBound), range.upperBound)

                // Tick haptic: fire once per crossed minor step.
                if let last = lastEmittedValue {
                    let stepsSinceLast = abs((clamped - last) / minorStep)
                    if stepsSinceLast >= 1.0 {
                        FilmtoneCaptureHaptics.selection()
                        lastEmittedValue = clamped
                    }
                }

                onChange(clamped)
            }
            .onEnded { _ in
                let final = lastEmittedValue ?? value
                dragStartValue = nil
                lastEmittedValue = nil
                if let onCommit {
                    onCommit(final)
                }
            }
    }
}

#endif
