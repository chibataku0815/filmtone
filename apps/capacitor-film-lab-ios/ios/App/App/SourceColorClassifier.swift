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

    /// v1.4: explicit eligibility threshold for quality-grade prewarm. Sources
    /// below this bitrate (typical iPhone HEVC ~50 Mbps) are already
    /// efficiently encoded — re-encoding to a quality mezzanine costs disk
    /// without a meaningful UX win, so Quality export stays source-direct.
    /// 100 Mbps catches most external-camera HEVC + all ProRes/DNxHD.
    static let qualityBitrateThreshold: Double = 100_000_000

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
    /// Codec strong condition (ProRes / DNxHD): always generate.
    /// Bitrate condition (>= qualityBitrateThreshold): generate.
    /// Otherwise: nil (Quality export reads source directly).
    static func qualityPrewarmVariant(
        for colorClass: SourceColorClassDTO?,
        codecFamily: SourceCodecFamilyDTO?,
        estimatedDataRate: Double?
    ) -> Variant? {
        guard let colorClass else {
            return nil
        }

        let baseVariant: Variant?
        switch colorClass {
        case .sdrBt709:
            baseVariant = .qualitySDR
        case .hdrPq, .hdrHlg, .appleLog, .appleLog2, .wideGamutUnknown:
            baseVariant = .qualityHDR
        case .unsupported, .unknown:
            baseVariant = nil
        }
        guard let variant = baseVariant else { return nil }

        if isHeavyCodec(codecFamily) { return variant }
        if let rate = estimatedDataRate, rate >= qualityBitrateThreshold {
            return variant
        }
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

    private static func isHeavyCodec(_ family: SourceCodecFamilyDTO?) -> Bool {
        guard let family else { return false }
        switch family {
        case .prores422, .prores4444, .proresRaw:
            return true
        case .h264, .hevc, .other:
            return false
        }
    }

    private static func normalizedRenderMode(_ renderMode: String?) -> String {
        renderMode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "quality"
    }
}
