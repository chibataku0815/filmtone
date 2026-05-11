import CoreGraphics
import FilmLabSwiftCore
import Foundation
import UIKit

/// Phase 2B-8C: filmtone-ios-export-session-v1 sidecar writer lifted out of
/// `FilmtoneExportSession`. Owns `SidecarDeviceIdentity` assembly,
/// HDR-policy forwarding, depth / Saved Look / Camera Profile sidecar
/// blocks, `SidecarBuildInputs` construction, the
/// `FilmtoneExportSidecarBuilder.build` + atomic write, and the
/// log-and-return-nil fallback. `FilmtoneExportSidecarBuilder` is the
/// schema source of truth and stays untouched.
///
/// The session retains all telemetry state (`degradedDecodePath`,
/// depth counters, mezzanine truth fields) and passes a `Telemetry`
/// snapshot at write time so an eviction between routing and sidecar
/// write cannot silently drop fields. `exportedAtIso`, `appVersion`,
/// `buildNumber`, `deviceModel`, and `iosVersion` are resolved inside
/// `write(...)` so identity remains write-time behavior.
final class ExportSidecarWriter {
    struct Telemetry {
        let degradedDecodePath: Bool
        let depthResolution: (width: Int, height: Int)?
        let videoDepthFramesProcessed: Int?
        let videoDepthSourceLabel: String?
        let didUseMezzanineVariant: ProfileVariant?
        let mezzanineConsumedURLLastPathComponent: String?
        let mezzanineConsumedMetrics: MezzanineService.MezzanineMetrics?
        let mezzanineGeneratedDuringExport: Bool?
        let mezzanineValidationStatus: String?
    }

    private let request: Phase0ExportRequestDTO
    private let outputURL: URL
    private let colorPipeline: FilmtoneColorPipelineContract
    private let appliedSavedLook: SavedLookEntry?
    private let cameraProfileSelection: CameraProfileSelection?
    private let highlightMarkers: FilmtoneHighlightMarkers?
    private let captureProvenance: SidecarCaptureProvenance?

    init(
        request: Phase0ExportRequestDTO,
        outputURL: URL,
        colorPipeline: FilmtoneColorPipelineContract,
        appliedSavedLook: SavedLookEntry?,
        cameraProfileSelection: CameraProfileSelection?,
        highlightMarkers: FilmtoneHighlightMarkers?,
        captureProvenance: SidecarCaptureProvenance?
    ) {
        self.request = request
        self.outputURL = outputURL
        self.colorPipeline = colorPipeline
        self.appliedSavedLook = appliedSavedLook
        self.cameraProfileSelection = cameraProfileSelection
        self.highlightMarkers = highlightMarkers
        self.captureProvenance = captureProvenance
    }

    func write(
        outputSize: CGSize,
        fileSizeBytes: Int?,
        elapsedMs: Int,
        realtimeRatio: Double?,
        audioPreserved: Bool?,
        audioDiagnostics: ExportAudioDiagnostics? = nil,
        package: SidecarPackage?,
        performance: SidecarPerformance?,
        telemetry: Telemetry
    ) -> String? {
        let identity = SidecarDeviceIdentity(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            deviceModel: UIDevice.current.filmtoneModelIdentifier,
            iosVersion: UIDevice.current.systemVersion,
            exportedAtIso: ISO8601DateFormatter.filmtoneSidecar.string(from: Date())
        )

        let hdrPolicy = request.sourceProbe?.sourceVideoMetadata?.hdrPreparationPolicy

        // v1.3 (D3.5): depth block. Always emitted — `used: false` is the
        // explicit signal that depth was not consumed (vs. absent field which
        // would mean "v1.2 sidecar / unknown"). Renderer is "ci" by default
        // (Phase A ships only the Core Image kernel; the contract reserves
        // "metal" for Phase B).
        let depthSidecar: SidecarDepthInfo
        if let res = telemetry.depthResolution {
            depthSidecar = SidecarDepthInfo(
                used: true,
                source: "avDepthData",
                resolutionWidth: res.width,
                resolutionHeight: res.height,
                renderer: request.depthRenderer ?? DepthRenderer.ci.rawValue,
                framesWithDepth: telemetry.videoDepthFramesProcessed,
                videoDepthSource: telemetry.videoDepthSourceLabel
            )
        } else {
            // Video that opened a depth reader but never matched a frame
            // (asset began before first depth pts, or every pull failed) still
            // owes the importer `used: false` plus the diagnostic block —
            // `framesWithDepth: 0` distinguishes "asset had a track" from "no
            // track at all" (still / no-opt-in path keeps both nil).
            depthSidecar = SidecarDepthInfo(
                used: false,
                source: nil,
                resolutionWidth: nil,
                resolutionHeight: nil,
                renderer: nil,
                framesWithDepth: telemetry.videoDepthSourceLabel != nil
                    ? (telemetry.videoDepthFramesProcessed ?? 0)
                    : nil,
                videoDepthSource: telemetry.videoDepthSourceLabel
            )
        }

        // v1.3 Item 2 Phase E: convert the resolved Saved Look entry (if any)
        // into the builder-local `SidecarSavedLookRef`. Built-in entries
        // surface `bundled: true` + `bundledSlug`; user-saved entries omit
        // both via `encodeIfPresent`. The sidecar block itself is `nil` when
        // no Saved Look was applied at export time.
        let savedLookRef: SidecarSavedLookRef? = appliedSavedLook.map { entry in
            SidecarSavedLookRef(
                id: entry.id.uuidString,
                name: entry.name,
                updatedAtIso: ISO8601DateFormatter.filmtoneSidecar.string(from: entry.updatedAt),
                bundled: entry.bundled ? true : nil,
                bundledSlug: entry.bundledSlug
            )
        }

        // v1.3 Camera Profiles Phase G: flatten the active CameraProfileSelection
        // (+ resolved catalog entry if any) into stringly-typed sidecar
        // fields. Auto + no probe match → selectionKind="auto", no catalog
        // entry. Auto + match → catalog id and resolvedFromAutoVia set so
        // downstream readers can tell user-explicit picks from auto picks.
        let cameraProfileBlock: SidecarCameraProfile? = ExportSourceProfileResolver.makeCameraProfileSidecar(
            for: cameraProfileSelection,
            probeColorClass: request.sourceProbe?.sourceVideoMetadata?.colorClass
        )

        let inputs = SidecarBuildInputs(
            request: request,
            sourceProbe: request.sourceProbe,
            hdrPolicy: hdrPolicy,
            degradedDecodePath: telemetry.degradedDecodePath,
            outputURL: outputURL,
            outputSize: outputSize,
            fileSizeBytes: fileSizeBytes,
            elapsedMs: elapsedMs,
            realtimeRatio: realtimeRatio,
            audioPreserved: audioPreserved,
            identity: identity,
            // v1.2: render-mode + mezzanine variant + profile-version for sidecar truth.
            // Stream D owns the field declarations on SidecarBuildInputs; this call site
            // populates them per the cross-stream contract.
            renderMode: (request.renderMode ?? .quality).rawValue,
            mezzanineUsedVariant: telemetry.didUseMezzanineVariant?.rawValue,
            mezzanineProfileVersion: telemetry.didUseMezzanineVariant != nil
                ? MezzanineService.Profile.version
                : nil,
            // v1.4 truth fields. All nil when no mezzanine was consumed; populated
            // from the snapshot we captured in exportVideo (so an eviction between
            // routing and sidecar write cannot strip them).
            mezzanineUrlLastPathComponent: telemetry.mezzanineConsumedURLLastPathComponent,
            mezzanineFileSizeBytes: telemetry.mezzanineConsumedMetrics?.fileSizeBytes,
            mezzanineDurationSec: telemetry.mezzanineConsumedMetrics?.durationSec,
            mezzanineWidth: telemetry.mezzanineConsumedMetrics?.width,
            mezzanineHeight: telemetry.mezzanineConsumedMetrics?.height,
            mezzanineCodec: telemetry.mezzanineConsumedMetrics?.codec,
            mezzaninePrewarmHit: telemetry.mezzanineGeneratedDuringExport.map { !$0 },
            mezzanineGeneratedDuringExport: telemetry.mezzanineGeneratedDuringExport,
            mezzanineValidationStatus: telemetry.mezzanineValidationStatus,
            colorPipeline: colorPipeline,
            package: package,
            depth: depthSidecar,
            appliedSavedLook: savedLookRef,
            cameraProfile: cameraProfileBlock,
            performance: performance,
            highlightMarkers: highlightMarkers,
            captureProvenance: captureProvenance,
            audioDiagnostics: audioDiagnostics?.sidecarDiagnostics
        )

        let sidecarURL = FilmtoneExportSidecarBuilder.sidecarURL(for: outputURL)
        do {
            let payload = try FilmtoneExportSidecarBuilder.build(inputs)
            try payload.write(to: sidecarURL, options: [.atomic])
            return sidecarURL.absoluteString
        } catch {
            filmtonePreviewCompositionDebugLog(
                "sidecar write failed at \(sidecarURL.path): \(error.localizedDescription)"
            )
            return nil
        }
    }
}
