import Foundation

/// Desktop `classifySourceColorForExport` (apps/desktop-film-lab-batch/electron/
/// video-export-source-metadata.ts:294-326) を Swift に移植.
///
/// 入力は **正規化済み** ffprobe 語彙 (`SourceColorMetadataNormalizer` 経由).
/// Apple CoreMedia identifier を直接渡すと PQ/HLG 判定が外れるので注意.
enum SourceColorClassifier {
    static func classify(_ metadata: SourceColorMetadataDTO) -> SourceColorClassDTO {
        if metadata.logTransferFunction == .appleLog2 ||
            metadata.colorTransfer == "apple-log2" ||
            metadata.colorTransfer == "apple-log-2"
        {
            return .appleLog2
        }
        if metadata.logTransferFunction == .appleLog || metadata.colorTransfer == "apple-log" {
            return .appleLog
        }

        if metadata.colorTransfer == "smpte2084" {
            return .hdrPq
        }
        if metadata.colorTransfer == "arib-std-b67" {
            return .hdrHlg
        }

        let hasBt2020 =
            metadata.colorPrimaries == "bt2020" ||
            metadata.colorSpace == "bt2020" ||
            metadata.colorSpace == "bt2020nc" ||
            metadata.colorSpace == "bt2020c"
        if hasBt2020
            || metadata.hasMasteringDisplayMetadata
            || metadata.hasContentLightMetadata
        {
            return .wideGamutUnknown
        }

        if isStrictSdrBt709(metadata) {
            return .sdrBt709
        }

        return .unknown
    }

    private static func isStrictSdrBt709(_ metadata: SourceColorMetadataDTO) -> Bool {
        let hasBt709Primaries = metadata.colorPrimaries == "bt709"
        let hasSdrTransfer =
            metadata.colorTransfer == "bt709" ||
            metadata.colorTransfer == nil
        let hasVideoMatrix =
            metadata.colorSpace == "bt709" ||
            metadata.colorSpace == nil
        return hasBt709Primaries && hasSdrTransfer && hasVideoMatrix
    }
}

enum FilmtoneMezzanineRoutePolicy {
    enum Variant: String, Equatable {
        case sdr
        case hdr
        case qualitySDR
        case qualityHDR
    }

    static func prewarmVariant(for colorClass: SourceColorClassDTO?) -> Variant? {
        guard let colorClass else {
            return nil
        }

        switch colorClass {
        case .sdrBt709:
            return .sdr
        case .hdrPq, .hdrHlg, .appleLog, .appleLog2, .wideGamutUnknown:
            return .hdr
        case .unsupported, .unknown:
            return nil
        }
    }

    /// Returns the quality-grade variant to prewarm if the source is heavy
    /// enough that re-encoding gains decode-time UX at Quality export.
    ///
    /// v1.4 (2026-05-02): **always returns nil on iOS**. Empirical measurement
    /// on iPhone 17 Pro / A18 Pro showed the qualityHDR HEVC Main10 4K
    /// 120 Mbps mezzanine pre-encode pass costs more than the decode-time
    /// saving recovers (174 s source-direct vs 243 s qualityHDR route on a
    /// 156 s ProRes 422 Apple Log clip — a +69 s net loss matching the ~67 s
    /// HEVC encode of 4680 frames at ~70 fps). On Apple Silicon iOS, ProRes
    /// and HEVC both decode in hardware fast enough that re-encoding to a
    /// different intermediate is pure overhead.
    ///
    /// Quality export therefore stays source-direct on every source class.
    /// `Profile.qualitySDR` / `Profile.qualityHDR` and the `selectedVariant`
    /// dispatch remain in code (with `hasQualitySDRMezzanine` / `…HDR` always
    /// false at the call site) so v1.5+ can re-enable selectively once a
    /// faster intermediate strategy (e.g. 1080p output-oriented cache) is
    /// proven. Speed export's preview-grade `prewarmVariant` (sdr/hdr at
    /// 1920 long edge) is unaffected — it serves a different shape of work.
    static func qualityPrewarmVariant(
        for colorClass: SourceColorClassDTO?,
        codecFamily: SourceCodecFamilyDTO?,
        estimatedDataRate: Double?
    ) -> Variant? {
        _ = colorClass
        _ = codecFamily
        _ = estimatedDataRate
        return nil
    }

    /// v1.4: route mezzanine at export time. Speed picks preview-grade
    /// (sdr/hdr); Quality picks quality-grade if available, otherwise nil so
    /// the caller falls back to source-direct (the source-of-truth path).
    static func selectedVariant(
        renderMode: String?,
        colorClass: SourceColorClassDTO?,
        hasHDRMezzanine: Bool,
        hasSDRMezzanine: Bool,
        hasQualityHDRMezzanine: Bool = false,
        hasQualitySDRMezzanine: Bool = false
    ) -> Variant? {
        switch normalizedRenderMode(renderMode) {
        case "speed":
            for variant in speedVariantPreference(for: colorClass) {
                switch variant {
                case .hdr where hasHDRMezzanine:
                    return .hdr
                case .sdr where hasSDRMezzanine:
                    return .sdr
                default:
                    continue
                }
            }
            return nil
        case "quality":
            for variant in qualityVariantPreference(for: colorClass) {
                switch variant {
                case .qualityHDR where hasQualityHDRMezzanine:
                    return .qualityHDR
                case .qualitySDR where hasQualitySDRMezzanine:
                    return .qualitySDR
                default:
                    continue
                }
            }
            return nil
        default:
            return nil
        }
    }

    private static func speedVariantPreference(for colorClass: SourceColorClassDTO?) -> [Variant] {
        guard let colorClass else {
            return []
        }

        switch colorClass {
        case .sdrBt709:
            return [.sdr]
        case .hdrPq, .hdrHlg, .appleLog, .appleLog2, .wideGamutUnknown:
            return [.hdr]
        case .unsupported, .unknown:
            return []
        }
    }

    private static func qualityVariantPreference(for colorClass: SourceColorClassDTO?) -> [Variant] {
        guard let colorClass else {
            return []
        }

        switch colorClass {
        case .sdrBt709:
            return [.qualitySDR]
        case .hdrPq, .hdrHlg, .appleLog, .appleLog2, .wideGamutUnknown:
            return [.qualityHDR]
        case .unsupported, .unknown:
            return []
        }
    }

    private static func normalizedRenderMode(_ renderMode: String?) -> String {
        renderMode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "quality"
    }
}
