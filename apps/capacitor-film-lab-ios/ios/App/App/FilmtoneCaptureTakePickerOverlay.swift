// Filmtone V2 native camera capture — completed-take picker.

import AVFoundation
import SwiftUI
import UIKit

#if os(iOS)

struct FilmtoneCaptureTakePickerOverlay: View {
    let packages: [FilmtoneCapturePackage]
    let makeGradeProcessor: ((FilmtoneCapturePackage) async -> FilmtoneSharedGradeProcessor?)?
    let onPick: (Int) -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.20)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onCancel)

                panel
                    .frame(maxHeight: min(proxy.size.height * 0.74, 660))
                    .padding(.horizontal, 14)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 12, 18))
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .accessibilityIdentifier("filmtone.capture.takePicker")
    }

    private var panel: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let ordered = Array(packages.indices.reversed())

        return GlassEffectContainer(spacing: 8) {
            VStack(spacing: 0) {
                Capsule()
                    .fill(.white.opacity(0.28))
                    .frame(width: 54, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                    .accessibilityHidden(true)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose take")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.96))
                        Text("\(packages.count) takes")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Spacer(minLength: 0)

                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glass)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Cancel")
                    .accessibilityIdentifier("filmtone.capture.takePicker.cancel")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(ordered, id: \.self) { index in
                            FilmtoneCaptureTakePickerRow(
                                package: packages[index],
                                takeNumber: index + 1,
                                isLatest: index == packages.indices.last,
                                makeGradeProcessor: makeGradeProcessor,
                                onPick: {
                                    FilmtoneCaptureHaptics.selection()
                                    onPick(index)
                                }
                            )
                            .accessibilityIdentifier("filmtone.capture.takePicker.take\(index + 1)")

                            if index != ordered.last {
                                Rectangle()
                                    .fill(.white.opacity(0.12))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, 2)
            .glassEffect(.clear.tint(.white.opacity(0.055)), in: shape)
            .overlay(
                shape.strokeBorder(.white.opacity(0.20), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(0.34), radius: 32, x: 0, y: 18)
        }
    }
}

private struct FilmtoneCaptureTakePickerRow: View {
    let package: FilmtoneCapturePackage
    let takeNumber: Int
    let isLatest: Bool
    let makeGradeProcessor: ((FilmtoneCapturePackage) async -> FilmtoneSharedGradeProcessor?)?
    let onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("Take \(takeNumber)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.96))

                        if isLatest {
                            Text("Latest")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .glassEffect(.clear.tint(.white.opacity(0.07)), in: Capsule())
                        }
                    }

                    Text("\(formatRecordedDuration(package.recordedDurationSeconds)) · \(detailLine)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                Button(action: onPick) {
                    HStack(spacing: 5) {
                        Text("Open")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.94))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Open Take \(takeNumber) in editor")
            }

            FilmtoneCaptureTakeScrubPreview(
                package: package,
                makeGradeProcessor: makeGradeProcessor
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var detailLine: String {
        var parts: [String] = []
        if let lens = package.lens?.magnificationLabel {
            parts.append(lens)
        }
        if let look = package.selectedLook?.englishName {
            parts.append(look)
        } else if let customLut = package.customLut {
            parts.append(customLut.displayName)
        } else {
            parts.append("Filmtone")
        }
        return parts.joined(separator: " · ")
    }

    private var accessibilityLabel: String {
        let latest = isLatest ? ", latest" : ""
        return "Take \(takeNumber)\(latest), \(formatRecordedDuration(package.recordedDurationSeconds)), \(detailLine)"
    }

    private func formatRecordedDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0.0s" }
        if seconds < 10 {
            return String(format: "%.1fs", seconds)
        }
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct FilmtoneCaptureTakeScrubPreview: View {
    let package: FilmtoneCapturePackage
    let makeGradeProcessor: ((FilmtoneCapturePackage) async -> FilmtoneSharedGradeProcessor?)?

    nonisolated private static let sampleFractions: [Double] = [
        0.02, 0.11, 0.20, 0.29, 0.38, 0.47,
        0.56, 0.65, 0.74, 0.83, 0.92, 0.98
    ]
    nonisolated private static let defaultSelectedIndex = 5

    @State private var samples: [FilmtoneCaptureTakeFrameSample] = Self.placeholderSamples(duration: 0)
    @State private var selectedFrameIndex: Int = Self.defaultSelectedIndex

    var body: some View {
        VStack(spacing: 7) {
            selectedPreview
            scrubStrip
        }
        .accessibilityLabel("Take preview scrubber")
        .task(id: package.captureId) {
            samples = Self.placeholderSamples(duration: package.recordedDurationSeconds)
            selectedFrameIndex = Self.defaultSelectedIndex
            let gradeProcessor = await makeGradeProcessor?(package)
            samples = await Self.frames(
                for: package.proxyURL,
                packageDuration: package.recordedDurationSeconds,
                gradeProcessor: gradeProcessor
            )
        }
    }

    private var selectedPreview: some View {
        let sample = selectedSample
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        return ZStack(alignment: .bottomTrailing) {
            shape.fill(.black.opacity(0.28))

            if let image = sample.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 14)
                    .opacity(0.58)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
            } else {
                ProgressView()
                    .tint(.white.opacity(0.64))
            }

            Text(formatTimelinePosition(sample.seconds, total: package.recordedDurationSeconds))
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .glassEffect(.clear.tint(.black.opacity(0.22)), in: Capsule())
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 142)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 0.6))
    }

    private var scrubStrip: some View {
        GeometryReader { proxy in
            HStack(spacing: 3) {
                ForEach(samples) { sample in
                    scrubFrame(
                        image: sample.image,
                        isSelected: sample.index == clampedSelectedIndex
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSelection(atX: value.location.x, width: proxy.size.width)
                    }
            )
        }
        .frame(height: 46)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func scrubFrame(image: UIImage?, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)

        ZStack {
            shape.fill(.black.opacity(0.26))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "video")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.34))
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                isSelected ? .white.opacity(0.90) : .white.opacity(0.12),
                lineWidth: isSelected ? 1.4 : 0.5
            )
        )
    }

    private var clampedSelectedIndex: Int {
        guard !samples.isEmpty else { return 0 }
        return min(max(selectedFrameIndex, 0), samples.count - 1)
    }

    private var selectedSample: FilmtoneCaptureTakeFrameSample {
        samples[clampedSelectedIndex]
    }

    private func updateSelection(atX x: CGFloat, width: CGFloat) {
        guard width > 0, !samples.isEmpty else { return }
        let clampedX = min(max(x, 0), width)
        let rawIndex = Int((clampedX / width) * CGFloat(samples.count))
        let nextIndex = min(max(rawIndex, 0), samples.count - 1)
        guard nextIndex != selectedFrameIndex else { return }
        selectedFrameIndex = nextIndex
        FilmtoneCaptureHaptics.selection()
    }

    nonisolated private static func frames(
        for url: URL,
        packageDuration: Double,
        gradeProcessor: FilmtoneSharedGradeProcessor?
    ) async -> [FilmtoneCaptureTakeFrameSample] {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 360, height: 360)
        generator.requestedTimeToleranceBefore = CMTime.positiveInfinity
        generator.requestedTimeToleranceAfter = CMTime.positiveInfinity

        let durationTime = try? await asset.load(.duration)
        let loadedDuration = durationTime.map(CMTimeGetSeconds) ?? 0
        let duration = packageDuration.isFinite && packageDuration > 0
            ? packageDuration
            : loadedDuration

        var results: [FilmtoneCaptureTakeFrameSample] = []
        for (index, fraction) in sampleFractions.enumerated() {
            let seconds = sampleSeconds(for: fraction, duration: duration)
            let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
            guard let frame = try? await generator.image(at: time) else {
                results.append(
                    FilmtoneCaptureTakeFrameSample(
                        index: index,
                        seconds: seconds,
                        image: nil
                    )
                )
                continue
            }
            results.append(
                FilmtoneCaptureTakeFrameSample(
                    index: index,
                    seconds: seconds,
                    image: renderedImage(from: frame.image, gradeProcessor: gradeProcessor)
                )
            )
        }

        return results
    }

    nonisolated private static func renderedImage(
        from cgImage: CGImage,
        gradeProcessor: FilmtoneSharedGradeProcessor?
    ) -> UIImage {
        guard let gradeProcessor else {
            return UIImage(cgImage: cgImage)
        }
        let input = CIImage(cgImage: cgImage)
        let output = gradeProcessor.applyForLivePreview(input)
        guard let rendered = gradeProcessor.ciContext.createCGImage(
            output,
            from: output.extent
        ) else {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(cgImage: rendered)
    }

    nonisolated private static func placeholderSamples(duration: Double) -> [FilmtoneCaptureTakeFrameSample] {
        sampleFractions.enumerated().map { index, fraction in
            FilmtoneCaptureTakeFrameSample(
                index: index,
                seconds: sampleSeconds(for: fraction, duration: duration),
                image: nil
            )
        }
    }

    nonisolated private static func sampleSeconds(for fraction: Double, duration: Double) -> Double {
        guard duration.isFinite, duration > 0.4 else { return 0 }
        return min(duration * fraction, duration - 0.12)
    }

    private func formatTimelinePosition(_ seconds: Double, total: Double) -> String {
        "\(formatClock(seconds)) / \(formatClock(total))"
    }

    private func formatClock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0s" }
        let total = Int(seconds.rounded())
        if total < 60 {
            return "\(total)s"
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct FilmtoneCaptureTakeFrameSample: Identifiable {
    let index: Int
    let seconds: Double
    let image: UIImage?

    var id: Int { index }
}

#endif
