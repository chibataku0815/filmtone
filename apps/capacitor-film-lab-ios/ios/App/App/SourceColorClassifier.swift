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

        if isSdrDisplayColor(metadata) {
            return .sdrBt709
        }

        return .unknown
    }

    private static func isSdrDisplayColor(_ metadata: SourceColorMetadataDTO) -> Bool {
        let hasDisplayPrimaries =
            metadata.colorPrimaries == "bt709" ||
            metadata.colorPrimaries == "smpte431" ||
            metadata.colorPrimaries == "smpte432"
        let hasSdrTransfer =
            metadata.colorTransfer == "bt709" ||
            metadata.colorTransfer == "iec61966-2-1" ||
            metadata.colorTransfer == nil
        let hasVideoMatrix =
            metadata.colorSpace == "bt709" ||
            metadata.colorSpace == nil
        return hasDisplayPrimaries && hasSdrTransfer && hasVideoMatrix
    }
}
