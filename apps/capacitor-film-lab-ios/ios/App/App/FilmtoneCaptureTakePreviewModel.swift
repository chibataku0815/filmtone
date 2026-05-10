// Filmtone V2 native camera capture — focused take preview state.

import SwiftUI
import UIKit

#if os(iOS)

@MainActor
final class FilmtoneCaptureTakePreviewModel: ObservableObject {
    @Published private(set) var samples: [FilmtoneCaptureTakeFrameSample] =
        FilmtoneCaptureTakePreviewLoader.placeholderSamples(
            duration: 0,
            isCompactHeight: false
        )
    @Published private(set) var selectedFrameIndex: Int =
        FilmtoneCaptureTakePreviewLoader.defaultSelectedIndex(isCompactHeight: false)
    @Published private(set) var selectedImage: UIImage?
    @Published private(set) var isLoadingSamples = false
    @Published private(set) var isRenderingExactLook = false

    private var activePackage: FilmtoneCapturePackage?
    private var activeCompact = false
    private var gradeProcessor: FilmtoneSharedGradeProcessor?
    private var makeGradeProcessor: ((FilmtoneCapturePackage) async -> FilmtoneSharedGradeProcessor?)?
    private var sampleTask: Task<Void, Never>?
    private var renderTask: Task<Void, Never>?

    var selectedSeconds: Double {
        selectedSample?.seconds ?? 0
    }

    var selectedSample: FilmtoneCaptureTakeFrameSample? {
        guard samples.indices.contains(selectedFrameIndex) else { return nil }
        return samples[selectedFrameIndex]
    }

    func focus(
        package: FilmtoneCapturePackage,
        isCompactHeight: Bool,
        makeGradeProcessor: ((FilmtoneCapturePackage) async -> FilmtoneSharedGradeProcessor?)?
    ) {
        if activePackage?.captureId == package.captureId,
           activeCompact == isCompactHeight {
            return
        }

        cancel()
        activePackage = package
        activeCompact = isCompactHeight
        self.makeGradeProcessor = makeGradeProcessor
        gradeProcessor = nil

        let placeholder = FilmtoneCaptureTakePreviewLoader.placeholderSamples(
            duration: package.recordedDurationSeconds,
            isCompactHeight: isCompactHeight
        )
        samples = placeholder
        selectedFrameIndex = min(
            FilmtoneCaptureTakePreviewLoader.defaultSelectedIndex(isCompactHeight: isCompactHeight),
            max(placeholder.count - 1, 0)
        )
        selectedImage = selectedSample?.image
        isLoadingSamples = true
        isRenderingExactLook = false

        sampleTask = Task { @MainActor [weak self, package, isCompactHeight] in
            let loaded = await FilmtoneCaptureTakePreviewLoader.shared.loadSamples(
                for: package,
                isCompactHeight: isCompactHeight
            )
            guard !Task.isCancelled else { return }
            self?.receiveLoadedSamples(
                loaded,
                package: package,
                isCompactHeight: isCompactHeight
            )
        }
    }

    func selectFrame(atX x: CGFloat, width: CGFloat) {
        guard width > 0, !samples.isEmpty else { return }
        let clampedX = min(max(x, 0), width)
        let rawIndex = Int((clampedX / width) * CGFloat(samples.count))
        let nextIndex = min(max(rawIndex, 0), samples.count - 1)
        guard nextIndex != selectedFrameIndex else { return }

        selectedFrameIndex = nextIndex
        selectedImage = selectedSample?.image
        FilmtoneCaptureHaptics.selection()
        scheduleExactLookRender()
    }

    func cancel() {
        sampleTask?.cancel()
        renderTask?.cancel()
        sampleTask = nil
        renderTask = nil
        isLoadingSamples = false
        isRenderingExactLook = false
    }

    deinit {
        sampleTask?.cancel()
        renderTask?.cancel()
    }

    private func receiveLoadedSamples(
        _ loaded: [FilmtoneCaptureTakeFrameSample],
        package: FilmtoneCapturePackage,
        isCompactHeight: Bool
    ) {
        guard activePackage?.captureId == package.captureId,
              activeCompact == isCompactHeight else {
            return
        }

        let fallback = FilmtoneCaptureTakePreviewLoader.placeholderSamples(
            duration: package.recordedDurationSeconds,
            isCompactHeight: isCompactHeight
        )
        samples = loaded.isEmpty ? fallback : loaded
        selectedFrameIndex = min(
            FilmtoneCaptureTakePreviewLoader.defaultSelectedIndex(isCompactHeight: isCompactHeight),
            max(samples.count - 1, 0)
        )
        selectedImage = selectedSample?.image
        isLoadingSamples = false
        scheduleExactLookRender()
    }

    private func scheduleExactLookRender() {
        renderTask?.cancel()
        renderTask = nil

        guard let package = activePackage,
              package.selectedLook != nil || package.customLut != nil,
              let sample = selectedSample,
              sample.image != nil else {
            isRenderingExactLook = false
            return
        }

        isRenderingExactLook = true
        renderTask = Task { @MainActor [weak self, package, sample, isCompactHeight = activeCompact] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            let processor = await self?.resolveGradeProcessor(for: package)
            guard !Task.isCancelled else { return }

            let image = await FilmtoneCaptureTakePreviewLoader.shared.gradedSelectedImage(
                for: package,
                sample: sample,
                isCompactHeight: isCompactHeight,
                gradeProcessor: processor
            )
            guard !Task.isCancelled else { return }
            self?.receiveRenderedImage(
                image,
                package: package,
                sampleIndex: sample.index
            )
        }
    }

    private func resolveGradeProcessor(
        for package: FilmtoneCapturePackage
    ) async -> FilmtoneSharedGradeProcessor? {
        if let gradeProcessor {
            return gradeProcessor
        }
        let processor = await makeGradeProcessor?(package)
        gradeProcessor = processor
        return processor
    }

    private func receiveRenderedImage(
        _ image: UIImage?,
        package: FilmtoneCapturePackage,
        sampleIndex: Int
    ) {
        guard activePackage?.captureId == package.captureId,
              selectedFrameIndex == sampleIndex else {
            return
        }
        selectedImage = image ?? selectedSample?.image
        isRenderingExactLook = false
    }
}

#endif
