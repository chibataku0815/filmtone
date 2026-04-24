import Foundation

/// Desktop `classifySourceColorForExport` (apps/desktop-film-lab-batch/electron/
/// video-export-source-metadata.ts:294-326) を Swift に移植.
///
/// 入力は **正規化済み** ffprobe 語彙 (`SourceColorMetadataNormalizer` 経由).
/// Apple CoreMedia identifier を直接渡すと PQ/HLG 判定が外れるので注意.
enum SourceColorClassifier {
    static func classify(_ metadata: SourceColorMetadataDTO) -> SourceColorClassDTO {
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

        let isBt709 =
            metadata.colorPrimaries == "bt709" &&
            (metadata.colorSpace == "bt709" || metadata.colorSpace == nil) &&
            (metadata.colorTransfer == "bt709" || metadata.colorTransfer == nil)
        if isBt709 {
            return .sdrBt709
        }

        return .unknown
    }
}
