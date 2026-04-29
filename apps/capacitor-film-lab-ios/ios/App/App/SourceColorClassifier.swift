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

    static func selectedVariant(
        renderMode: String?,
        colorClass: SourceColorClassDTO?,
        hasHDRMezzanine: Bool,
        hasSDRMezzanine: Bool
    ) -> Variant? {
        guard normalizedRenderMode(renderMode) == "speed" else {
            return nil
        }

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

    private static func normalizedRenderMode(_ renderMode: String?) -> String {
        renderMode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "quality"
    }
}
