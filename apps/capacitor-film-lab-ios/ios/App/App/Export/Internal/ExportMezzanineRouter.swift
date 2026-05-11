import FilmLabSwiftCore
import Foundation

/// Phase 2B-9B: mezzanine routing / quality prewarm / route telemetry
/// collaborator lifted out of `FilmtoneExportSession`. Owns the route
/// selection across hdr / sdr / qualityHDR / qualitySDR / source-direct,
/// the quality-prewarm gate that calls `MezzanineService.ensureMezzanineBlocking`,
/// the export-time telemetry block (used-variant detection, invalidated-
/// before-open race guard, valid-status consumed URL / metrics snapshot,
/// and the `disabled-on-ios` validation status), and the
/// `estimatedDataRate` / `qualityMezzanineVariantForExport` private
/// helpers backing the prewarm decision.
///
/// `FilmtoneExportSession` keeps `AVURLAsset` opening, depth reader setup,
/// writer / reader pipeline, the video frame loop, sidecar writing, and
/// session property storage (`didUseMezzanineVariant`,
/// `mezzanineValidationStatus`, `mezzanineConsumedURLLastPathComponent`,
/// `mezzanineConsumedMetrics`, `mezzanineGeneratedDuringExport`); it
/// assigns those properties from the returned `RouteResult` / `Bool?` so
/// the sidecar write site keeps the same truth-snapshot timing.
final class ExportMezzanineRouter {
    struct RouteResult {
        let sourceURL: URL
        let didUseVariant: ProfileVariant?
        let validationStatus: String?
        let consumedURLLastPathComponent: String?
        let consumedMetrics: MezzanineService.MezzanineMetrics?
    }

    private let request: Phase0ExportRequestDTO
    private let sourceURL: URL
    private let mezzanineService: MezzanineService?

    init(
        request: Phase0ExportRequestDTO,
        sourceURL: URL,
        mezzanineService: MezzanineService?
    ) {
        self.request = request
        self.sourceURL = sourceURL
        self.mezzanineService = mezzanineService
    }

    func resolvedPreviewSourceURL() -> URL {
        resolveSourceURL()
    }

    func routeSourceForExport() -> RouteResult {
        var effectiveSourceURL = resolveSourceURL()
        var didUseMezzanineVariant: ProfileVariant? = nil
        var mezzanineValidationStatus: String? = nil
        var mezzanineConsumedURLLastPathComponent: String? = nil
        var mezzanineConsumedMetrics: MezzanineService.MezzanineMetrics? = nil

        if effectiveSourceURL != sourceURL, let mezz = mezzanineService {
            let depthEnabled = request.depthEnabled ?? false
            let candidates: [ProfileVariant] = [.qualityHDR, .qualitySDR, .hdr, .sdr]
            for variant in candidates {
                if effectiveSourceURL == mezz.existingMezzanineURL(
                    for: sourceURL,
                    variant: variant,
                    depthEnabled: depthEnabled
                ) {
                    didUseMezzanineVariant = variant
                    break
                }
            }
            if let v = didUseMezzanineVariant,
               !mezz.isValidMezzaninePublic(
                   at: effectiveSourceURL,
                   sourceURL: sourceURL,
                   variant: v
               ) {
                filmtonePreviewCompositionDebugLog(
                    "Mezzanine race: routed-to URL invalidated before AVURLAsset open, falling back to source-direct"
                )
                didUseMezzanineVariant = nil
                effectiveSourceURL = sourceURL
                mezzanineValidationStatus = "invalidated-before-open"
            } else if didUseMezzanineVariant != nil {
                mezzanineValidationStatus = "valid"
                mezzanineConsumedURLLastPathComponent = effectiveSourceURL.lastPathComponent
                mezzanineConsumedMetrics = mezz.mezzanineMetrics(at: effectiveSourceURL)
            }
        }

        if mezzanineValidationStatus == nil,
           (request.renderMode ?? .quality) == .quality,
           didUseMezzanineVariant == nil {
            mezzanineValidationStatus = "disabled-on-ios"
        }

        return RouteResult(
            sourceURL: effectiveSourceURL,
            didUseVariant: didUseMezzanineVariant,
            validationStatus: mezzanineValidationStatus,
            consumedURLLastPathComponent: mezzanineConsumedURLLastPathComponent,
            consumedMetrics: mezzanineConsumedMetrics
        )
    }

    func prepareQualityMezzanineForExport(
        progress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws -> Bool? {
        guard (request.renderMode ?? .quality) == .quality,
              let variant = qualityMezzanineVariantForExport()
        else {
            return nil
        }
        guard let mezz = mezzanineService else {
            throw FilmtoneMediaError.exportFailed(
                "Quality mezzanine is required for this heavy source, but the cache service is unavailable."
            )
        }

        let depthEnabled = request.depthEnabled ?? false
        if mezz.existingMezzanineURL(for: sourceURL, variant: variant, depthEnabled: depthEnabled) != nil {
            filmtonePreviewCompositionDebugLog("Quality mezzanine ready before export: \(variant.rawValue)")
            return false
        }

        progress(.init(
            stage: .preflight,
            progress: 0.06,
            currentFrame: nil,
            totalFrames: nil,
            message: "Preparing quality cache"
        ))

        do {
            _ = try mezz.ensureMezzanineBlocking(
                sourceURL: sourceURL,
                variant: variant,
                depthEnabled: depthEnabled
            ) { fraction in
                progress(.init(
                    stage: .preflight,
                    progress: 0.06 + min(0.049, max(0.0, fraction) * 0.049),
                    currentFrame: nil,
                    totalFrames: nil,
                    message: "Preparing quality cache"
                ))
            }
            filmtonePreviewCompositionDebugLog("Quality mezzanine generated for export: \(variant.rawValue)")
            return true
        } catch {
            throw FilmtoneMediaError.exportFailed(
                "Quality mezzanine generation failed for this heavy source (\(variant.rawValue)): \(error.localizedDescription)"
            )
        }
    }

    private func resolveSourceURL() -> URL {
        // v1.4: routing covers both Speed (preview-grade mezzanine) and Quality
        // (quality-grade mezzanine, only generated for heavy sources via
        // FilmtoneMezzanineRoutePolicy.qualityPrewarmVariant). Quality export
        // prepares eligible heavy-source mezzanines before reaching this
        // routing point; policy-declined light sources remain source-direct.
        // Preview reads via this same function so preview ↔ export bytes
        // remain symmetric within each renderMode.
        guard let mezz = mezzanineService else {
            filmtonePreviewCompositionDebugLog(
                "Mezzanine routing: service unavailable, source-direct"
            )
            return sourceURL
        }

        let depthEnabled = request.depthEnabled ?? false
        let hdrURL = mezz.existingMezzanineURL(
            for: sourceURL,
            variant: .hdr,
            depthEnabled: depthEnabled
        )
        let sdrURL = mezz.existingMezzanineURL(
            for: sourceURL,
            variant: .sdr,
            depthEnabled: depthEnabled
        )
        let qualityHDRURL = mezz.existingMezzanineURL(
            for: sourceURL,
            variant: .qualityHDR,
            depthEnabled: depthEnabled
        )
        let qualitySDRURL = mezz.existingMezzanineURL(
            for: sourceURL,
            variant: .qualitySDR,
            depthEnabled: depthEnabled
        )
        let colorClass = request.sourceProbe?.sourceVideoMetadata?.colorClass
        let selectedVariant = FilmtoneMezzanineRoutePolicy.selectedVariant(
            renderMode: request.renderMode?.rawValue,
            colorClass: colorClass,
            hasHDRMezzanine: hdrURL != nil,
            hasSDRMezzanine: sdrURL != nil,
            hasQualityHDRMezzanine: qualityHDRURL != nil,
            hasQualitySDRMezzanine: qualitySDRURL != nil
        )

        switch selectedVariant {
        case .hdr:
            filmtonePreviewCompositionDebugLog("Mezzanine routing: hdr (Speed)")
            return hdrURL ?? sourceURL
        case .sdr:
            filmtonePreviewCompositionDebugLog("Mezzanine routing: sdr (Speed)")
            return sdrURL ?? sourceURL
        case .qualityHDR:
            filmtonePreviewCompositionDebugLog("Mezzanine routing: qualityHDR")
            return qualityHDRURL ?? sourceURL
        case .qualitySDR:
            filmtonePreviewCompositionDebugLog("Mezzanine routing: qualitySDR")
            return qualitySDRURL ?? sourceURL
        case nil:
            filmtonePreviewCompositionDebugLog(
                "Mezzanine routing: policy declined for \(colorClass?.rawValue ?? "unknown") at \(request.renderMode?.rawValue ?? "unknown"), source-direct"
            )
            return sourceURL
        }
    }

    private func qualityMezzanineVariantForExport() -> ProfileVariant? {
        guard let probe = request.sourceProbe else {
            return MezzanineColorProbe.qualityPrewarmVariant(sourceURL: sourceURL)
        }

        let colorClass = probe.sourceVideoMetadata?.colorClass
        let codecFamily = probe.sourceVideoMetadata?.codecFamily ?? probe.codecFamily
        let estimatedDataRate = estimatedDataRate(from: probe)
        guard let routeVariant = FilmtoneMezzanineRoutePolicy.qualityPrewarmVariant(
            for: colorClass,
            codecFamily: codecFamily,
            estimatedDataRate: estimatedDataRate
        ) else {
            return nil
        }

        switch routeVariant {
        case .qualitySDR:
            return .qualitySDR
        case .qualityHDR:
            return .qualityHDR
        case .sdr, .hdr:
            return nil
        }
    }

    private func estimatedDataRate(from probe: SourceProbeDTO) -> Double? {
        guard let fileSizeBytes = probe.fileSizeBytes,
              let durationSec = probe.durationSec,
              fileSizeBytes > 0,
              durationSec > 0
        else {
            return nil
        }
        return Double(fileSizeBytes) * 8.0 / durationSec
    }
}
