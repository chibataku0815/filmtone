import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

enum FilmtoneExportRenderSubstage: String, CaseIterable {
    case inputLut = "InputLut"
    case baseGrade = "BaseGrade"
    case toneCompression = "ToneCompression"
    case shadowLatitude = "ShadowLatitude"
    case detailSoftness = "DetailSoftness"
    case edgeOptics = "EdgeOptics"
    case glowFamily = "GlowFamily"
    case vignette = "Vignette"
    case grain = "Grain"
    case creativeLut = "CreativeLut"
    case printStage = "PrintStage"
    case filmDamage = "FilmDamage"
    case motion = "Motion"
}

final class FilmtoneExportRenderStageProfiler {
    struct Configuration {
        let frameStride: Int
        let source: String

        static func current(processInfo: ProcessInfo = .processInfo) -> Configuration? {
            if let argumentConfiguration = fromArguments(processInfo.arguments) {
                return argumentConfiguration
            }
            guard let environmentValue = processInfo.environment[environmentKey] else {
                return nil
            }
            return make(value: environmentValue, source: "env:\(environmentKey)")
        }

        private static let environmentKey = "FILMTONE_EXPORT_RENDER_STAGE_PROFILE"
        private static let argumentPrefix = "--filmtone-export-render-stage-profile"

        private static func fromArguments(_ arguments: [String]) -> Configuration? {
            for (index, argument) in arguments.enumerated() {
                if argument == argumentPrefix {
                    let nextValue = arguments.indices.contains(index + 1)
                        && !arguments[index + 1].hasPrefix("--")
                        ? arguments[index + 1]
                        : nil
                    return make(value: nextValue, source: "argument:\(argumentPrefix)")
                }
                let prefix = "\(argumentPrefix)="
                if argument.hasPrefix(prefix) {
                    let value = String(argument.dropFirst(prefix.count))
                    return make(value: value, source: "argument:\(argumentPrefix)")
                }
            }
            return nil
        }

        private static func make(value: String?, source: String) -> Configuration? {
            let normalized = (value ?? "1")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if normalized.isEmpty || normalized == "1" || normalized == "true" || normalized == "yes" || normalized == "on" {
                return Configuration(frameStride: 1, source: source)
            }
            if normalized == "0" || normalized == "false" || normalized == "no" || normalized == "off" {
                return nil
            }
            guard let parsedStride = Int(normalized), parsedStride > 0 else {
                return Configuration(frameStride: 1, source: source)
            }
            return Configuration(frameStride: parsedStride, source: source)
        }
    }

    private let configuration: Configuration
    private let ciContext: CIContext
    private let colorSpace: CGColorSpace
    private let metrics: FilmtoneExportPerformanceMetrics
    private var frameIndex = 0
    private var shouldProfileCurrentFrame = false
    private var scratchBuffer: CVPixelBuffer?
    private var scratchWidth = 0
    private var scratchHeight = 0

    init(
        configuration: Configuration,
        ciContext: CIContext,
        colorSpace: CGColorSpace,
        metrics: FilmtoneExportPerformanceMetrics
    ) {
        self.configuration = configuration
        self.ciContext = ciContext
        self.colorSpace = colorSpace
        self.metrics = metrics
    }

    func beginFrame() {
        frameIndex += 1
        shouldProfileCurrentFrame = (frameIndex - 1) % configuration.frameStride == 0
        if shouldProfileCurrentFrame {
            metrics.recordRenderStageProfiledFrame()
        }
    }

    func forceRender(
        _ stage: FilmtoneExportRenderSubstage,
        image: CIImage,
        outputSize: CGSize
    ) {
        guard shouldProfileCurrentFrame else {
            return
        }
        let width = max(1, Int(outputSize.width.rounded()))
        let height = max(1, Int(outputSize.height.rounded()))
        guard let scratch = scratchPixelBuffer(width: width, height: height) else {
            metrics.recordRenderSubstageFailure(stage)
            return
        }
        let bounds = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        metrics.measureRenderSubstage(stage) {
            ciContext.render(
                image,
                to: scratch,
                bounds: bounds,
                colorSpace: colorSpace
            )
        }
    }

    private func scratchPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        if let scratchBuffer, scratchWidth == width, scratchHeight == height {
            return scratchBuffer
        }
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
        ]
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else {
            return nil
        }
        scratchBuffer = buffer
        scratchWidth = width
        scratchHeight = height
        return buffer
    }
}

final class FilmtoneExportPerformanceMetrics {
    enum Stage {
        case decode
        case waitEncoder
        case buildGraph
        case render
        case append
        case writerFinish
    }

    private let devicePerformanceAtStart = DevicePerformanceSnapshot.current()
    private let lock = NSLock()
    private var decodeNs: UInt64 = 0
    private var waitEncoderNs: UInt64 = 0
    private var buildGraphNs: UInt64 = 0
    private var renderNs: UInt64 = 0
    private var appendNs: UInt64 = 0
    private var writerFinishNs: UInt64 = 0
    private var mediaPipelineNs: UInt64?
    private var decodeSamples = 0
    private var renderedFrames = 0
    private var renderStageProfileFrameStride: Int?
    private var renderStageProfileSource: String?
    private var renderStageProfiledFrames = 0
    private var renderSubstageNs = Dictionary(
        uniqueKeysWithValues: FilmtoneExportRenderSubstage.allCases.map { ($0, UInt64(0)) }
    )
    private var renderSubstageSamples = Dictionary(
        uniqueKeysWithValues: FilmtoneExportRenderSubstage.allCases.map { ($0, 0) }
    )
    private var renderSubstageFailures = Dictionary(
        uniqueKeysWithValues: FilmtoneExportRenderSubstage.allCases.map { ($0, 0) }
    )

    func measure<T>(_ stage: Stage, _ work: () throws -> T) rethrows -> T {
        let started = DispatchTime.now().uptimeNanoseconds
        defer {
            record(stage, elapsedNs: DispatchTime.now().uptimeNanoseconds - started)
        }
        return try work()
    }

    func recordRenderedFrame() {
        lock.lock()
        renderedFrames += 1
        lock.unlock()
    }

    func enableRenderStageProfiling(frameStride: Int, source: String) {
        lock.lock()
        renderStageProfileFrameStride = frameStride
        renderStageProfileSource = source
        lock.unlock()
    }

    func recordRenderStageProfiledFrame() {
        lock.lock()
        renderStageProfiledFrames += 1
        lock.unlock()
    }

    func measureRenderSubstage(_ stage: FilmtoneExportRenderSubstage, _ work: () -> Void) {
        let started = DispatchTime.now().uptimeNanoseconds
        work()
        let elapsed = DispatchTime.now().uptimeNanoseconds - started
        lock.lock()
        renderSubstageNs[stage, default: 0] += elapsed
        renderSubstageSamples[stage, default: 0] += 1
        lock.unlock()
    }

    func recordRenderSubstageFailure(_ stage: FilmtoneExportRenderSubstage) {
        lock.lock()
        renderSubstageFailures[stage, default: 0] += 1
        lock.unlock()
    }

    func recordMediaPipeline(elapsedSince started: UInt64) {
        let now = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        mediaPipelineNs = now >= started ? now - started : 0
        lock.unlock()
    }

    func sidecarPerformance(
        elapsedMs: Int,
        disabledRenderStages: [String] = [],
        acceleratedRenderStages: [String] = []
    ) -> SidecarPerformance? {
        let snapshot: (
            decodeNs: UInt64,
            waitEncoderNs: UInt64,
            buildGraphNs: UInt64,
            renderNs: UInt64,
            appendNs: UInt64,
            writerFinishNs: UInt64,
            mediaPipelineNs: UInt64?,
            decodeSamples: Int,
            renderedFrames: Int,
            renderStageProfileFrameStride: Int?,
            renderStageProfileSource: String?,
            renderStageProfiledFrames: Int,
            renderSubstages: [RenderSubstageSnapshot]
        )
        lock.lock()
        let renderSubstages = FilmtoneExportRenderSubstage.allCases.map {
            RenderSubstageSnapshot(
                stage: $0,
                elapsedNs: renderSubstageNs[$0, default: 0],
                samples: renderSubstageSamples[$0, default: 0],
                failures: renderSubstageFailures[$0, default: 0]
            )
        }
        snapshot = (
            decodeNs,
            waitEncoderNs,
            buildGraphNs,
            renderNs,
            appendNs,
            writerFinishNs,
            mediaPipelineNs,
            decodeSamples,
            renderedFrames,
            renderStageProfileFrameStride,
            renderStageProfileSource,
            renderStageProfiledFrames,
            renderSubstages
        )
        lock.unlock()

        let hasVideoMetrics = snapshot.renderedFrames > 0 || snapshot.decodeSamples > 0
        guard hasVideoMetrics || snapshot.writerFinishNs > 0 else {
            return nil
        }

        let decodeMs = Self.ms(snapshot.decodeNs)
        let waitEncoderMs = Self.ms(snapshot.waitEncoderNs)
        let buildGraphMs = Self.ms(snapshot.buildGraphNs)
        let renderMs = Self.ms(snapshot.renderNs)
        let appendMs = Self.ms(snapshot.appendNs)
        let writerFinishMs = Self.ms(snapshot.writerFinishNs)
        let mediaPipelineMs = snapshot.mediaPipelineNs.map(Self.ms)
        let mediaPipelineResidualMs = mediaPipelineMs.map {
            max(0, $0 - decodeMs - waitEncoderMs - buildGraphMs - renderMs - appendMs)
        }
        let avgRenderMsPerFrame = snapshot.renderedFrames > 0
            ? renderMs / Double(snapshot.renderedFrames)
            : nil
        let renderShareOfExport = elapsedMs > 0
            ? renderMs / Double(elapsedMs)
            : nil
        let renderShareOfMediaPipeline = mediaPipelineMs.flatMap { value in
            value > 0 ? renderMs / value : nil
        }
        let renderStageProfile = Self.makeRenderStageProfile(
            frameStride: snapshot.renderStageProfileFrameStride,
            source: snapshot.renderStageProfileSource,
            sampledFrames: snapshot.renderStageProfiledFrames,
            totalFrames: snapshot.renderedFrames,
            substages: snapshot.renderSubstages
        )
        let devicePerformanceAtEnd = DevicePerformanceSnapshot.current()

        return SidecarPerformance(
            exportElapsedMs: elapsedMs,
            mediaPipelineMs: mediaPipelineMs,
            decodeMs: decodeMs,
            decodeSamples: snapshot.decodeSamples,
            waitEncoderMs: waitEncoderMs,
            buildGraphMs: buildGraphMs,
            renderMs: renderMs,
            appendMs: appendMs,
            writerFinishMs: writerFinishMs,
            mediaPipelineResidualMs: mediaPipelineResidualMs,
            renderedFrames: snapshot.renderedFrames,
            avgRenderMsPerFrame: avgRenderMsPerFrame,
            renderShareOfExport: renderShareOfExport,
            renderShareOfMediaPipeline: renderShareOfMediaPipeline,
            thermalStateAtStart: devicePerformanceAtStart.thermalState,
            thermalStateAtEnd: devicePerformanceAtEnd.thermalState,
            lowPowerModeEnabledAtStart: devicePerformanceAtStart.lowPowerModeEnabled,
            lowPowerModeEnabledAtEnd: devicePerformanceAtEnd.lowPowerModeEnabled,
            processorCount: devicePerformanceAtStart.processorCount,
            activeProcessorCountAtStart: devicePerformanceAtStart.activeProcessorCount,
            activeProcessorCountAtEnd: devicePerformanceAtEnd.activeProcessorCount,
            physicalMemoryBytes: devicePerformanceAtStart.physicalMemoryBytes,
            disabledRenderStages: disabledRenderStages.isEmpty ? nil : disabledRenderStages,
            acceleratedRenderStages: acceleratedRenderStages.isEmpty ? nil : acceleratedRenderStages,
            renderStageProfile: renderStageProfile
        )
    }

    private func record(_ stage: Stage, elapsedNs: UInt64) {
        lock.lock()
        switch stage {
        case .decode:
            decodeNs += elapsedNs
            decodeSamples += 1
        case .waitEncoder:
            waitEncoderNs += elapsedNs
        case .buildGraph:
            buildGraphNs += elapsedNs
        case .render:
            renderNs += elapsedNs
        case .append:
            appendNs += elapsedNs
        case .writerFinish:
            writerFinishNs += elapsedNs
        }
        lock.unlock()
    }

    private struct RenderSubstageSnapshot {
        let stage: FilmtoneExportRenderSubstage
        let elapsedNs: UInt64
        let samples: Int
        let failures: Int
    }

    private struct DevicePerformanceSnapshot {
        let thermalState: String
        let lowPowerModeEnabled: Bool
        let processorCount: Int
        let activeProcessorCount: Int
        let physicalMemoryBytes: UInt64

        static func current(processInfo: ProcessInfo = .processInfo) -> DevicePerformanceSnapshot {
            DevicePerformanceSnapshot(
                thermalState: thermalStateLabel(processInfo.thermalState),
                lowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
                processorCount: processInfo.processorCount,
                activeProcessorCount: processInfo.activeProcessorCount,
                physicalMemoryBytes: processInfo.physicalMemory
            )
        }

        private static func thermalStateLabel(_ state: ProcessInfo.ThermalState) -> String {
            switch state {
            case .nominal:
                return "nominal"
            case .fair:
                return "fair"
            case .serious:
                return "serious"
            case .critical:
                return "critical"
            @unknown default:
                return "unknown"
            }
        }
    }

    private static func makeRenderStageProfile(
        frameStride: Int?,
        source: String?,
        sampledFrames: Int,
        totalFrames: Int,
        substages: [RenderSubstageSnapshot]
    ) -> SidecarRenderStageProfile? {
        guard let frameStride, let source else {
            return nil
        }

        var previousCumulativeMs: Double?
        var previousCumulativeAvgMs: Double?
        var previousEstimatedCumulativeMs: Double?
        let stages = substages.map { substage -> SidecarRenderStageMetric in
            let cumulativeMs = ms(substage.elapsedNs)
            let cumulativeAvgMs = substage.samples > 0
                ? cumulativeMs / Double(substage.samples)
                : nil
            let estimatedCumulativeMs = cumulativeAvgMs.map { $0 * Double(totalFrames) }
            let incrementalMs = previousCumulativeMs.map { cumulativeMs - $0 }
            let incrementalAvgMs = cumulativeAvgMs.flatMap { currentAvg in
                previousCumulativeAvgMs.map { currentAvg - $0 }
            }
            let estimatedIncrementalMs = estimatedCumulativeMs.flatMap { currentEstimated in
                previousEstimatedCumulativeMs.map { currentEstimated - $0 }
            }

            previousCumulativeMs = cumulativeMs
            previousCumulativeAvgMs = cumulativeAvgMs
            previousEstimatedCumulativeMs = estimatedCumulativeMs

            return SidecarRenderStageMetric(
                stage: substage.stage.rawValue,
                samples: substage.samples,
                failures: substage.failures,
                cumulativeMs: cumulativeMs,
                cumulativeAvgMsPerSample: cumulativeAvgMs,
                estimatedCumulativeMs: estimatedCumulativeMs,
                incrementalMsFromPreviousStage: incrementalMs,
                incrementalAvgMsPerSample: incrementalAvgMs,
                estimatedIncrementalMs: estimatedIncrementalMs
            )
        }

        return SidecarRenderStageProfile(
            mode: "forced-boundary-render",
            source: source,
            frameStride: frameStride,
            sampledFrames: sampledFrames,
            totalFrames: totalFrames,
            forcedRenderMs: substages.reduce(0) { $0 + ms($1.elapsedNs) },
            stages: stages
        )
    }

    private static func ms(_ ns: UInt64) -> Double {
        Double(ns) / 1_000_000.0
    }
}
