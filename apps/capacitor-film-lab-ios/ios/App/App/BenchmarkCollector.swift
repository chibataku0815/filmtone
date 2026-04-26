import Foundation
import UIKit

final class BenchmarkCollector {
    private let request: Phase0ExportRequestDTO
    private let thermalStateAtStart: String
    private let memoryWarningsAtStart: Int
    private let memoryWarningCounter: () -> Int
    private let appVersion: String
    private let buildNumber: String
    private let deviceModel: String
    private let iosVersion: String

    init(
        request: Phase0ExportRequestDTO,
        memoryWarningCounter: @escaping () -> Int
    ) {
        self.request = request
        self.thermalStateAtStart = ProcessInfo.processInfo.thermalState.filmtoneLabel
        self.memoryWarningsAtStart = memoryWarningCounter()
        self.memoryWarningCounter = memoryWarningCounter
        self.appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        self.buildNumber = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "unknown"
        self.deviceModel = UIDevice.current.filmtoneModelIdentifier
        self.iosVersion = UIDevice.current.systemVersion
    }

    private(set) var exportUsedMezzanine: Bool?
    private(set) var mezzanineGenerationMs: Int?
    private(set) var renderMode: String?
    private(set) var mezzanineProfileVariant: String?
    // v1.3 (D3.4): depth prefilter telemetry.
    private(set) var depthUsed: Bool?
    private(set) var depthSource: String?
    private(set) var depthRenderer: String?
    private(set) var depthPrefilterMs: Double?
    // v1.3 Phase B: video depth-track telemetry.
    private(set) var depthFramesProcessed: Int?
    private(set) var videoDepthDecodeMs: Double?

    func recordMezzanineUsage(
        used: Bool,
        generationMs: Int? = nil,
        variant: ProfileVariant? = nil
    ) {
        exportUsedMezzanine = used
        if let generationMs {
            mezzanineGenerationMs = generationMs
        }
        if let variant {
            mezzanineProfileVariant = variant.rawValue
        }
    }

    func recordRenderMode(_ mode: Phase0RenderMode) {
        renderMode = mode.rawValue
    }

    /// v1.3 (D3.4): record depth prefilter usage. `used: false` is a meaningful
    /// signal — the export ran without depth on purpose (no aux data, depth
    /// disabled, or unsupported source). Source/renderer are nil when not used.
    func recordDepthUsage(
        used: Bool,
        source: String? = nil,
        renderer: String? = nil
    ) {
        depthUsed = used
        depthSource = used ? source : nil
        depthRenderer = used ? renderer : nil
    }

    /// v1.3 (D3.4): accumulator for depth prefilter wall-clock cost (sum across
    /// the three glow stages). Pass nil to clear.
    func recordDepthPrefilterMs(_ ms: Double?) {
        depthPrefilterMs = ms
    }

    /// v1.3 Phase B: per-frame depth telemetry for video export. Increments
    /// `depthFramesProcessed` and adds the supplied decode wall-clock to
    /// `videoDepthDecodeMs`. Both fields stay nil for still-image exports.
    func recordVideoDepthFrame(decodeMs: Double) {
        depthFramesProcessed = (depthFramesProcessed ?? 0) + 1
        videoDepthDecodeMs = (videoDepthDecodeMs ?? 0) + decodeMs
    }

    /// v1.3 Phase B: bulk-set the totals after the export session has aggregated
    /// them per-frame internally (FilmtoneMediaRuntime calls this once at the
    /// end of a video export). Either value may be nil — passing nil clears.
    func recordVideoDepthTotals(frames: Int?, decodeMs: Double?) {
        depthFramesProcessed = frames
        videoDepthDecodeMs = decodeMs
    }

    func makeSuccessRecord(
        result: Phase0ExportResultDTO,
        saveToPhotosOk: Bool? = nil
    ) -> Phase0ExportBenchmarkRecordDTO {
        return Phase0ExportBenchmarkRecordDTO(
            appVersion: appVersion,
            buildNumber: buildNumber,
            deviceModel: deviceModel,
            iosVersion: iosVersion,
            sourceCodec: request.sourceProbe?.codec,
            sourceResolution: makeSourceResolution(),
            sourceDurationSec: request.sourceProbe?.durationSec,
            outputFileSizeBytes: result.fileSizeBytes,
            elapsedMs: result.elapsedMs,
            realtimeRatio: result.realtimeRatio,
            thermalState: makeThermalRange(),
            memoryWarningCount: deltaMemoryWarnings(),
            permissionResult: saveToPhotosOk == true ? "granted" : (saveToPhotosOk == false ? "denied" : "save-not-run"),
            saveToPhotosOk: saveToPhotosOk,
            errorDomain: nil,
            errorCode: nil,
            exportUsedMezzanine: exportUsedMezzanine,
            mezzanineGenerationMs: mezzanineGenerationMs,
            renderMode: renderMode,
            mezzanineProfileVariant: mezzanineProfileVariant,
            depthUsed: depthUsed,
            depthSource: depthSource,
            depthRenderer: depthRenderer,
            depthPrefilterMs: depthPrefilterMs,
            depthFramesProcessed: depthFramesProcessed,
            videoDepthDecodeMs: videoDepthDecodeMs
        )
    }

    func makeFailureRecord(error: Error) -> Phase0ExportBenchmarkRecordDTO {
        let nsError = error as NSError
        let mediaError = error as? FilmtoneMediaError
        return Phase0ExportBenchmarkRecordDTO(
            appVersion: appVersion,
            buildNumber: buildNumber,
            deviceModel: deviceModel,
            iosVersion: iosVersion,
            sourceCodec: request.sourceProbe?.codec,
            sourceResolution: makeSourceResolution(),
            sourceDurationSec: request.sourceProbe?.durationSec,
            outputFileSizeBytes: nil,
            elapsedMs: 0,
            realtimeRatio: nil,
            thermalState: makeThermalRange(),
            memoryWarningCount: deltaMemoryWarnings(),
            permissionResult: nil,
            saveToPhotosOk: nil,
            errorDomain: nsError.domain,
            errorCode: mediaError?.code ?? "FILMTONE_NATIVE_ERROR",
            exportUsedMezzanine: exportUsedMezzanine,
            mezzanineGenerationMs: mezzanineGenerationMs,
            renderMode: renderMode,
            mezzanineProfileVariant: mezzanineProfileVariant,
            depthUsed: depthUsed,
            depthSource: depthSource,
            depthRenderer: depthRenderer,
            depthPrefilterMs: depthPrefilterMs,
            depthFramesProcessed: depthFramesProcessed,
            videoDepthDecodeMs: videoDepthDecodeMs
        )
    }

    private func makeSourceResolution() -> String? {
        guard let width = request.sourceProbe?.width, let height = request.sourceProbe?.height else {
            return nil
        }
        return "\(width)x\(height)"
    }

    private func makeThermalRange() -> String {
        return "\(thermalStateAtStart)->\(ProcessInfo.processInfo.thermalState.filmtoneLabel)"
    }

    private func deltaMemoryWarnings() -> Int {
        return max(memoryWarningCounter() - memoryWarningsAtStart, 0)
    }
}
