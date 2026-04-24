import Foundation

/// iOS 用の HDR preparation policy 導出.
/// Desktop (`video-export-source-metadata.ts:473+`) は ffmpeg capability 前提で
/// `prepare-sdr-mezzanine` / `defer-unknown` を返すが、iOS は ffmpeg を持たず
/// Core Image の暗黙 tone-map 経路のみ. 同じ PolicyDTO shape に iOS strategy enum を入れる.
///
/// Mapping:
///   sdr-bt709          -> strategy=.none,               reason=source-is-sdr-bt709,        fixture=false
///   hdr-pq             -> strategy=.coreImageToneMapSdr, reason=source-is-hdr-pq,           fixture=true
///   hdr-hlg            -> strategy=.coreImageToneMapSdr, reason=source-is-hdr-hlg,          fixture=true
///   wide-gamut-unknown -> strategy=.deferVisibleWarning, reason=wide-gamut-transfer-unknown, fixture=true
///   unknown            -> strategy=.none,               reason=source-color-unknown,        fixture=false
enum HdrPreparationPolicyDeriver {
    static func derive(colorClass: SourceColorClassDTO) -> HdrPreparationPolicyDTO {
        switch colorClass {
        case .sdrBt709:
            return HdrPreparationPolicyDTO(
                strategy: .none,
                reason: "source-is-sdr-bt709",
                requiresFixtureValidation: false,
                warning: nil
            )
        case .hdrPq:
            return HdrPreparationPolicyDTO(
                strategy: .coreImageToneMapSdr,
                reason: "source-is-hdr-pq",
                requiresFixtureValidation: true,
                warning: nil
            )
        case .hdrHlg:
            return HdrPreparationPolicyDTO(
                strategy: .coreImageToneMapSdr,
                reason: "source-is-hdr-hlg",
                requiresFixtureValidation: true,
                warning: nil
            )
        case .wideGamutUnknown:
            return HdrPreparationPolicyDTO(
                strategy: .deferVisibleWarning,
                reason: "wide-gamut-transfer-unknown",
                requiresFixtureValidation: true,
                warning: nil
            )
        case .unknown:
            return HdrPreparationPolicyDTO(
                strategy: .none,
                reason: "source-color-unknown",
                requiresFixtureValidation: false,
                warning: nil
            )
        }
    }
}
