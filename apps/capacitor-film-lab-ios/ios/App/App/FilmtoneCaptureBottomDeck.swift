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
    let storagePressure: FilmtoneCaptureStoragePressure?
    let statusText: String
    let isRecordingOrStopping: Bool
    let canToggleRecord: Bool
    let pickFolderIcon: String
    let pickFolderLabel: String
    let lookLabel: String
    let showsExternalClear: Bool
    let onPickFolder: () -> Void
    let onToggleRecord: () -> Void
    let onClearFolder: () -> Void
    let onPickLook: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            preflightSection

            if isRecordingOrStopping, let storagePressure {
                storagePressurePill(storagePressure)
            }

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

    // MARK: Recording storage pressure

    private func storagePressurePill(
        _ pressure: FilmtoneCaptureStoragePressure
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: storagePressureIcon(pressure))
                .font(.system(size: 11, weight: .bold))
            Text(storagePressureText(pressure))
                .font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(storagePressureColor(pressure))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .captureGlassHUD(in: Capsule())
        .accessibilityIdentifier("filmtone.capture.storagePressure")
        .accessibilityLabel(Text(storagePressureAccessibilityText(pressure)))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func storagePressureIcon(
        _ pressure: FilmtoneCaptureStoragePressure
    ) -> String {
        switch pressure.level {
        case .warning:
            return "externaldrive.badge.exclamationmark"
        case .critical:
            return "exclamationmark.triangle.fill"
        case .unreadable:
            return "questionmark.folder.fill"
        }
    }

    private func storagePressureColor(
        _ pressure: FilmtoneCaptureStoragePressure
    ) -> Color {
        switch pressure.level {
        case .warning, .unreadable:
            return .yellow.opacity(0.95)
        case .critical:
            return FilmtoneCaptureChrome.recordRed
        }
    }

    private func storagePressureText(
        _ pressure: FilmtoneCaptureStoragePressure
    ) -> String {
        switch pressure.level {
        case .warning:
            return "Storage low · \(formatBytes(pressure.availableBytes)) left"
        case .critical:
            return "Storage critical · \(formatBytes(pressure.availableBytes)) left"
        case .unreadable:
            return "Storage unknown"
        }
    }

    private func storagePressureAccessibilityText(
        _ pressure: FilmtoneCaptureStoragePressure
    ) -> String {
        switch pressure.level {
        case .warning:
            return "Storage space is getting low. \(formatBytes(pressure.availableBytes)) available."
        case .critical:
            return "Storage space is critical. \(formatBytes(pressure.availableBytes)) available."
        case .unreadable:
            return "Storage space cannot be read while recording."
        }
    }

    private func formatBytes(_ bytes: Int64?) -> String {
        guard let bytes else { return "?" }
        let gib = Double(bytes) / 1_073_741_824.0
        if gib >= 10 {
            return String(format: "%.0f GB", gib)
        }
        return String(format: "%.1f GB", gib)
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
            storageButtonCluster
            Spacer(minLength: 0)
            recordButton
            Spacer(minLength: 0)
            lookButton
        }
        .padding(.top, 4)
    }

    private var sideControlWidth: CGFloat {
        72
    }

    private var storageButtonCluster: some View {
        ZStack(alignment: .topTrailing) {
            pickFolderButton

            if showsExternalClear {
                clearFolderButton
                    .offset(x: 5, y: -5)
            }
        }
        .frame(width: sideControlWidth, height: FilmtoneCaptureChrome.peripheralButtonSize)
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

    private var clearFolderButton: some View {
        Button {
            FilmtoneCaptureHaptics.softImpact()
            onClearFolder()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 22, height: 22)
                .captureGlassControl(in: Circle())
        }
        .accessibilityIdentifier("filmtone.capture.clearFolder")
        .accessibilityLabel(Text("Clear external storage"))
        .disabled(isRecordingOrStopping)
        .opacity(isRecordingOrStopping ? 0.45 : 1)
    }

    private var lookButton: some View {
        Button {
            FilmtoneCaptureHaptics.softImpact()
            onPickLook()
        } label: {
            VStack(spacing: 2) {
                Text("LOOK")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.62))
                Text(lookLabel)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .frame(width: sideControlWidth, height: FilmtoneCaptureChrome.peripheralButtonSize)
            .captureGlassControl(in: FilmtoneCaptureChrome.peripheralShape())
        }
        .disabled(isRecordingOrStopping)
        .opacity(isRecordingOrStopping ? 0.45 : 1)
        .accessibilityIdentifier("filmtone.capture.lookButton")
        .accessibilityLabel(Text("Look \(lookLabel)"))
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
