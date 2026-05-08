// Filmtone V2 native camera capture — top cockpit composition (M13-M-3).
//
// Owns the top zone of the parameter cockpit: the existing close /
// storage HUD bar, the parameter chip row (ISO / Shutter / EV / WB /
// Look), and the conditional ruler region that expands beneath the
// active scrubber chip.
//
// Why this lives in its own file:
//   - `FilmtoneCaptureView` is the orchestrator; chip-row composition,
//     value formatting, and chip-tap emission belong with the chip
//     surface.
//   - `CaptureParameterChip` enum is a chip-row concept, not an
//     orchestrator concept.
//   - Material rules (`chipShape` / `captureGlassChip`) live in
//     `FilmtoneCaptureChrome` and are consumed here without inlining.
//
// M13-M-3 changes vs. M13-M-2:
//   - The ruler region is no longer a stub — it hosts a real
//     `FilmtoneCaptureRulerScrubber` driven by session ranges.
//   - Chip taps are emitted as `onChipTap(chip)` to the orchestrator
//     so it can run the auto↔manual mode entry logic that the
//     chip-row layer should not know about.
//   - `.ev` chip is filtered out when the session is in `.manual`
//     (EV bias has no effect on `setExposureModeCustom`).

import SwiftUI

#if os(iOS)

/// One chip in the top parameter row.
enum CaptureParameterChip: String, CaseIterable, Identifiable {
    case iso, shutter, ev, wb, look

    var id: String { rawValue }

    var label: String {
        switch self {
        case .iso: return "ISO"
        case .shutter: return "SHUTTER"
        case .ev: return "EV"
        case .wb: return "WB"
        case .look: return "LOOK"
        }
    }

    /// Whether tapping toggles the row's `activeChip` state (true) or
    /// performs a one-shot action (false). M13-M-3: `.iso` / `.shutter`
    /// also enter manual exposure on first tap when in `.auto` —
    /// orchestrator handles that wiring; the chip-row layer just
    /// reports the tap.
    var isScrubberChip: Bool {
        switch self {
        case .iso, .shutter, .ev: return true
        case .wb, .look: return false
        }
    }
}

/// Top cockpit zone: HUD bar + parameter chip row + (conditional)
/// ruler region. The parameter chip row sits inside the parent's
/// `GlassEffectContainer` so adjacent chip shapes can merge as a
/// single material.
struct FilmtoneCaptureCockpitTopBar: View {

    // MARK: HUD inputs (forwarded to FilmtoneCaptureTopStatusBar)
    let isCloseDisabled: Bool
    let storageIcon: String
    let storageLabel: String
    let qualityContractText: String
    let onClose: () -> Void

    // MARK: Chip-row inputs — value sources
    let exposureMode: FilmtoneCaptureSession.ExposureMode
    let manualISO: Float
    let manualShutterSeconds: Double
    let exposureBiasEV: Float
    let whiteBalanceMode: FilmtoneCaptureSession.WhiteBalanceMode
    let captureLookSelection: FilmtoneCaptureLook
    let isRecordingOrStopping: Bool

    // MARK: Chip-row inputs — scrubber ranges
    let isoRange: ClosedRange<Float>
    let shutterDurationRange: ClosedRange<Double>
    let exposureBiasRange: ClosedRange<Float>

    // MARK: Bindings + callbacks
    @Binding var activeChip: CaptureParameterChip?
    let onChipTap: (CaptureParameterChip) -> Void
    let onScrubISO: (Float) -> Void
    let onScrubShutter: (Double) -> Void
    let onScrubEV: (Float) -> Void

    var body: some View {
        VStack(spacing: 10) {
            FilmtoneCaptureTopStatusBar(
                isCloseDisabled: isCloseDisabled,
                storageIcon: storageIcon,
                storageLabel: storageLabel,
                qualityContractText: qualityContractText,
                onClose: onClose
            )

            parameterChipRow

            rulerRegion
        }
    }

    // MARK: Parameter chip row

    /// EV chip is hidden in manual mode — `setExposureBias` is gated
    /// on `exposureMode == .auto` in the session, so a visible EV chip
    /// in manual would advertise a no-op control.
    private var visibleChips: [CaptureParameterChip] {
        CaptureParameterChip.allCases.filter { chip in
            chip != .ev || exposureMode == .auto
        }
    }

    private var parameterChipRow: some View {
        HStack(spacing: FilmtoneCaptureChrome.parameterChipSpacing) {
            ForEach(visibleChips) { chip in
                chipButton(chip)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isRecordingOrStopping ? 0.55 : 1)
        .accessibilityIdentifier("filmtone.capture.parameterRow")
    }

    @ViewBuilder
    private func chipButton(_ chip: CaptureParameterChip) -> some View {
        let isActive = activeChip == chip
        Button {
            FilmtoneCaptureHaptics.selection()
            onChipTap(chip)
        } label: {
            VStack(spacing: 1) {
                Text(chip.label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.62))
                Text(chipValue(chip))
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(
                minWidth: FilmtoneCaptureChrome.parameterChipMinWidth,
                minHeight: FilmtoneCaptureChrome.parameterChipMinHeight
            )
            .captureGlassChip(active: isActive, in: FilmtoneCaptureChrome.chipShape())
        }
        .disabled(isRecordingOrStopping)
        .accessibilityIdentifier("filmtone.capture.chip.\(chip.id)")
        .accessibilityLabel(Text("\(chip.label) \(chipValue(chip))"))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// Live value string shown beneath the chip label.
    private func chipValue(_ chip: CaptureParameterChip) -> String {
        switch chip {
        case .iso:
            return exposureMode == .manual
                ? "\(Int(manualISO.rounded()))"
                : "Auto"
        case .shutter:
            return exposureMode == .manual ? shutterDisplayLabel(manualShutterSeconds) : "Auto"
        case .ev:
            return exposureMode == .auto
                ? String(format: "%+.1f", exposureBiasEV)
                : "—"
        case .wb:
            return whiteBalanceMode == .locked ? "Lock" : "Auto"
        case .look:
            return captureLookSelection.displayName
        }
    }

    private func shutterDisplayLabel(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        let denom = 1.0 / seconds
        if denom >= 1 {
            return "1/\(Int(denom.rounded()))s"
        }
        return String(format: "%.2fs", seconds)
    }

    // MARK: Ruler region

    @ViewBuilder
    private var rulerRegion: some View {
        if let chip = activeChip, chip.isScrubberChip {
            scrubberFor(chip)
                .transition(
                    .move(edge: .top)
                        .combined(with: .opacity)
                        .combined(with: .scale(scale: 0.96, anchor: .top))
                )
        }
    }

    /// Selects the right ruler scrubber configuration for the active
    /// chip. Each branch reads its range / step / formatter from the
    /// session range publisher and forwards drag values to the
    /// matching `onScrub*` callback.
    @ViewBuilder
    private func scrubberFor(_ chip: CaptureParameterChip) -> some View {
        switch chip {
        case .iso:
            FilmtoneCaptureRulerScrubber(
                value: Double(manualISO),
                range: Double(isoRange.lowerBound)...Double(isoRange.upperBound),
                majorStep: 100,
                minorStep: 25,
                valueLabel: { "\(Int($0.rounded()))" },
                majorTickLabel: { "\(Int($0.rounded()))" },
                onChange: { onScrubISO(Float($0)) }
            )
            .accessibilityIdentifier("filmtone.capture.scrubber.iso")
        case .shutter:
            FilmtoneCaptureRulerScrubber(
                value: manualShutterSeconds,
                range: shutterDurationRange.lowerBound...shutterDurationRange.upperBound,
                // Major / minor steps in shutter seconds are awkward
                // because the range is logarithmic-feeling
                // (1/8000 → 1/24). Use a linear seconds value with
                // small minor steps so finger drag motion translates
                // ~1 ms per minor tick.
                majorStep: 0.005,
                minorStep: 0.001,
                valueLabel: { shutterReadout($0) },
                majorTickLabel: { shutterReadout($0) },
                onChange: { onScrubShutter($0) }
            )
            .accessibilityIdentifier("filmtone.capture.scrubber.shutter")
        case .ev:
            FilmtoneCaptureRulerScrubber(
                value: Double(exposureBiasEV),
                range: Double(exposureBiasRange.lowerBound)...Double(exposureBiasRange.upperBound),
                majorStep: 1.0,
                minorStep: 0.1,
                valueLabel: { String(format: "%+.1f", $0) },
                majorTickLabel: { String(format: "%+.0f", $0) },
                onChange: { onScrubEV(Float($0)) }
            )
            .accessibilityIdentifier("filmtone.capture.scrubber.ev")
        case .wb, .look:
            // Defensive: these chips never enter the active-scrubber
            // branch (`isScrubberChip == false`), but the switch needs
            // exhaustive coverage.
            EmptyView()
        }
    }

    private func shutterReadout(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        let denom = 1.0 / seconds
        if denom >= 1 {
            return "1/\(Int(denom.rounded()))"
        }
        return String(format: "%.3fs", seconds)
    }
}

#endif
