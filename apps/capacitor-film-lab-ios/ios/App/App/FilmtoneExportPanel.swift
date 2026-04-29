import SwiftUI

struct FilmtoneExportPanel: View {
    @ObservedObject var store: FilmtoneEditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            statePanel
        }
        .padding(.top, 8)
        .accessibilityIdentifier("filmtone.section.export")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.exportResult == nil ? store.strings.exportSectionTitle : store.strings.resultTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text(statusLine)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer(minLength: 12)

            Button(store.strings.exportAndSave) {
                Task { await store.exportAndSave() }
            }
            .buttonStyle(FilmtonePrimaryButtonStyle())
            .disabled(!canExport)
        }
    }

    @ViewBuilder
    private var statePanel: some View {
        if !store.sourceViolations.isEmpty {
            blockedState
        } else if let exportProgress = store.exportProgress {
            progressState(progress: exportProgress)
        } else if let exportResult = store.exportResult {
            finishedState(result: exportResult)
        } else {
            readyState
        }
    }

    private var readyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.source == nil ? store.strings.sourceEmpty : store.strings.exportIdle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))

            if store.source != nil {
                HStack(spacing: 12) {
                    MetricCard(label: store.strings.strengthLabel, value: percentLabel(store.project.strength))
                    MetricCard(label: store.strings.cameraLabel, value: store.cameraProfileLabel)
                }

                if let opticsLabel = store.cameraOpticsLabel {
                    MetricCard(label: store.strings.opticsMetricLabel, value: opticsLabel)
                        .accessibilityLabel(store.cameraOpticsAccessibilityLabel ?? opticsLabel)
                        .accessibilityIdentifier("filmtone.metric.optics.ready")
                }
            }
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) { divider }
    }

    private var blockedState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.strings.exportDisabled)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.86))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.sourceViolations, id: \.self) { violation in
                    Text("• \(violation)")
                        .font(.subheadline)
                        .foregroundStyle(Color.filmtoneAmber.opacity(0.96))
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            Color.filmtoneAmber.opacity(0.05),
            in: RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                .stroke(Color.filmtoneAmber.opacity(0.16), lineWidth: 1)
        )
    }

    private func progressState(progress: Phase0ExportProgressDTO) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                Text("\(Int((progress.progress * 100).rounded()))%")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text(store.strings.stageLabel(for: progress.stage))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                            .fill(Color.filmtoneAmber)
                    )
            }

            ProgressView(value: progress.progress)
                .tint(Color.filmtoneAmber)

            Text(progressLabel(progress: progress))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))

            if progress.stage == .writing {
                Text(store.strings.exportWritingHint)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) { divider }
    }

    private func finishedState(result: Phase0ExportResultDTO) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.strings.elapsedLabel(result.elapsedMs))
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(store.strings.metricsElapsed)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 12)

                Text(store.strings.saveStateLabel(store.saveToPhotosState))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(store.saveToPhotosState == .saved ? .black : .white.opacity(0.76))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                            .fill(saveStateBackground)
                    )
            }

            HStack(spacing: 12) {
                Button(store.strings.saveToPhotos) {
                    Task { await store.saveToPhotos() }
                }
                .buttonStyle(FilmtonePrimaryButtonStyle())
                .disabled(store.isSavingToPhotos || store.saveToPhotosState == .saved)

                Button(store.strings.shareOutput) {
                    Task { await store.shareOutput() }
                }
                .buttonStyle(FilmtoneSecondaryButtonStyle())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    label: store.strings.metricsOutput,
                    value: store.strings.outputSummaryLabel(
                        width: result.outputWidth,
                        height: result.outputHeight,
                        fps: result.outputFps
                    )
                )
                MetricCard(label: store.strings.metricsFileSize, value: store.strings.byteLabel(result.fileSizeBytes))
                    MetricCard(label: store.strings.cameraLabel, value: store.cameraProfileLabel)
                MetricCard(label: store.strings.metricsSaveToPhotos, value: store.strings.saveStateLabel(store.saveToPhotosState))
                if let opticsLabel = store.cameraOpticsLabel {
                    MetricCard(label: store.strings.opticsMetricLabel, value: opticsLabel)
                        .accessibilityLabel(store.cameraOpticsAccessibilityLabel ?? opticsLabel)
                        .accessibilityIdentifier("filmtone.metric.optics.finished")
                }
            }
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) { divider }
    }

    private var canExport: Bool {
        store.source != nil && store.sourceViolations.isEmpty && !store.isBusy && !store.isSavingToPhotos
    }

    private var statusLine: String {
        if store.exportProgress != nil {
            return store.strings.exportRunning
        }
        if store.isSavingToPhotos {
            return store.strings.exportSavingToPhotos
        }
        if store.exportResult != nil {
            return store.strings.resultTitle
        }
        return store.strings.exportIdle
    }

    private var saveStateBackground: Color {
        switch store.saveToPhotosState {
        case .saved:
            return Color.filmtoneAmber
        case .failed:
            return Color.red.opacity(0.18)
        case .notRun:
            return Color.white.opacity(0.06)
        }
    }

    private func progressLabel(progress: Phase0ExportProgressDTO) -> String {
        let percent = Int((progress.progress * 100).rounded())
        if let currentFrame = progress.currentFrame, let totalFrames = progress.totalFrames {
            return "\(percent)% · \(store.strings.stageLabel(for: progress.stage)) · \(currentFrame) / \(totalFrames)"
        }
        return "\(percent)% · \(store.strings.stageLabel(for: progress.stage))"
    }

    private func percentLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }
}

private struct MetricCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(2)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

struct FilmtonePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .fill(Color.filmtoneAmber.opacity(configuration.isPressed ? 0.84 : 1))
            )
            .opacity(configuration.role == .destructive ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct FilmtoneSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
