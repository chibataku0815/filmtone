// Filmtone V2 native camera capture — bottom shutter cluster.
//
// M13-M-2 invariants:
//   - **No shelf glass slab.** Each control owns its own Liquid Glass
//     primitive on its own shape. Glass-on-glass (the M13-M-1 trap)
//     is gone, so each rim catches light and refraction at its own
//     edge instead of collapsing into a single flat haze.
//   - Status text floats above the cluster as its own small
//     `captureGlassHUD` capsule (Capsule is the one place a pill
//     silhouette reads as a pro camera HUD timecode).
//   - Peripheral buttons (folder pick / clear) use the angular
//     `peripheralShape` (cornerRadius 11) — pro camera consoles use
//     square-ish buttons, not pills.
//   - Record button stays a `Circle()` (shutter convention).

import SwiftUI

#if os(iOS)

struct FilmtoneCaptureBottomDeck: View {
    let preflightError: String?
    let preflightWarnings: [String]
    let statusText: String
    let isRecordingOrStopping: Bool
    let canToggleRecord: Bool
    let pickFolderIcon: String
    let pickFolderLabel: String
    let showsExternalClear: Bool
    let onPickFolder: () -> Void
    let onToggleRecord: () -> Void
    let onClearFolder: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            preflightSection

            if isRecordingOrStopping {
                statusPill
            }

            shutterCluster
        }
        .animation(.easeInOut(duration: 0.2), value: isRecordingOrStopping)
    }

    // MARK: Preflight (error + warnings)

    @ViewBuilder
    private var preflightSection: some View {
        if let preflightError {
            Text(preflightError)
                .font(.footnote.weight(.medium))
                .foregroundStyle(FilmtoneCaptureChrome.recordRed)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }

        if !preflightWarnings.isEmpty {
            ForEach(preflightWarnings, id: \.self) { line in
                Text(line)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Status timecode pill

    /// Floats above the cluster with its own small Liquid Glass surface
    /// so the timecode reads as a HUD readout instead of being baked
    /// into a slab beneath the controls.
    private var statusPill: some View {
        Text(statusText)
            .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(0.94))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .captureGlassHUD(in: Capsule())
            .accessibilityIdentifier("filmtone.capture.status")
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: Shutter cluster

    private var shutterCluster: some View {
        HStack(alignment: .center, spacing: 0) {
            pickFolderButton
            Spacer(minLength: 0)
            recordButton
            Spacer(minLength: 0)
            clearFolderButton
        }
        .padding(.top, 4)
    }

    private var pickFolderButton: some View {
        Button {
            FilmtoneCaptureHaptics.softImpact()
            onPickFolder()
        } label: {
            Image(systemName: pickFolderIcon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(
                    width: FilmtoneCaptureChrome.peripheralButtonSize,
                    height: FilmtoneCaptureChrome.peripheralButtonSize
                )
                .captureGlassControl(in: FilmtoneCaptureChrome.peripheralShape())
        }
        .disabled(isRecordingOrStopping)
        .opacity(isRecordingOrStopping ? 0.45 : 1)
        .accessibilityIdentifier("filmtone.capture.pickFolder")
        .accessibilityLabel(Text(pickFolderLabel))
    }

    @ViewBuilder
    private var clearFolderButton: some View {
        if showsExternalClear {
            Button {
                FilmtoneCaptureHaptics.softImpact()
                onClearFolder()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(
                        width: FilmtoneCaptureChrome.peripheralButtonSize,
                        height: FilmtoneCaptureChrome.peripheralButtonSize
                    )
                    .captureGlassControl(in: FilmtoneCaptureChrome.peripheralShape())
            }
            .accessibilityIdentifier("filmtone.capture.clearFolder")
            .accessibilityLabel(Text("Clear external storage"))
            .disabled(isRecordingOrStopping)
            .opacity(isRecordingOrStopping ? 0.45 : 1)
        } else {
            Color.clear
                .frame(
                    width: FilmtoneCaptureChrome.peripheralButtonSize,
                    height: FilmtoneCaptureChrome.peripheralButtonSize
                )
        }
    }

    private var recordButton: some View {
        Button {
            FilmtoneCaptureHaptics.recordImpact()
            onToggleRecord()
        } label: {
            ZStack {
                Color.clear
                    .frame(
                        width: FilmtoneCaptureChrome.recordDiameter,
                        height: FilmtoneCaptureChrome.recordDiameter
                    )
                    .captureGlassControl(in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                Color.white.opacity(isRecordingOrStopping ? 0.36 : 0.46),
                                lineWidth: 1.5
                            )
                    )

                innerCore
            }
            .animation(
                .spring(response: 0.32, dampingFraction: 0.78),
                value: isRecordingOrStopping
            )
        }
        .disabled(!canToggleRecord)
        .opacity(canToggleRecord ? 1 : 0.45)
        .accessibilityIdentifier("filmtone.capture.record")
        .accessibilityLabel(
            isRecordingOrStopping ? "Stop recording" : "Start recording"
        )
    }

    @ViewBuilder
    private var innerCore: some View {
        if isRecordingOrStopping {
            TimelineView(.animation) { context in
                let phase = (sin(context.date.timeIntervalSinceReferenceDate * 2.4) + 1) / 2
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                FilmtoneCaptureChrome.recordRed,
                                FilmtoneCaptureChrome.recordRedDeep,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: FilmtoneCaptureChrome.recordCoreStopSide,
                        height: FilmtoneCaptureChrome.recordCoreStopSide
                    )
                    .scaleEffect(0.96 + CGFloat(phase) * 0.04)
                    .opacity(0.85 + Double(phase) * 0.15)
            }
        } else {
            Circle()
                .fill(Color.white.opacity(0.94))
                .frame(
                    width: FilmtoneCaptureChrome.recordCoreDiameter,
                    height: FilmtoneCaptureChrome.recordCoreDiameter
                )
        }
    }
}

#endif
