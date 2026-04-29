import AVFoundation
import CoreMedia
import Foundation

/// Resolves whether a selected source is safe to prewarm as an SDR or HDR
/// mezzanine by inspecting its CMFormatDescription extensions.
///
/// Decision rule (plan §6.2):
/// - BT.2020 / Rec.2020 primaries → `.hdr` (covers HLG, PQ, Apple Log)
/// - HLG, PQ, or Apple Log transfer (with any primaries) → `.hdr`
/// - Strict BT.709 SDR → `.sdr`
/// - Display P3 SDR, unknown, and missing metadata → no prewarm.
enum MezzanineColorProbe {
    static func prewarmVariant(track: AVAssetTrack) -> ProfileVariant? {
        guard let colorClass = sourceColorClass(track: track),
              let routeVariant = FilmtoneMezzanineRoutePolicy.prewarmVariant(for: colorClass)
        else {
            return nil
        }

        return profileVariant(for: routeVariant)
    }

    /// Convenience: probe the first video track of an asset URL.
    static func prewarmVariant(sourceURL: URL) -> ProfileVariant? {
        let asset = AVURLAsset(url: sourceURL)
        guard let track = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        return prewarmVariant(track: track)
    }

    private static func sourceColorClass(track: AVAssetTrack) -> SourceColorClassDTO? {
        guard let firstDescription = track.formatDescriptions.first else {
            return nil
        }
        let cmDescription = firstDescription as! CMFormatDescription
        let extensions = (CMFormatDescriptionGetExtensions(cmDescription) as? [CFString: Any]) ?? [:]

        let rawTransfer = FormatExtensionReader.string(
            in: extensions,
            cfKey: kCMFormatDescriptionExtension_TransferFunction,
            stringKey: "TransferFunction"
        )
        let rawPrimaries = FormatExtensionReader.string(
            in: extensions,
            cfKey: kCMFormatDescriptionExtension_ColorPrimaries,
            stringKey: "ColorPrimaries"
        )
        let rawMatrix = FormatExtensionReader.string(
            in: extensions,
            cfKey: kCMFormatDescriptionExtension_YCbCrMatrix,
            stringKey: "YCbCrMatrix"
        )
        let rawLogTransfer: String? = {
            if #available(iOS 17.2, *) {
                return FormatExtensionReader.string(
                    in: extensions,
                    cfKey: kCMFormatDescriptionExtension_LogTransferFunction,
                    stringKey: "LogTransferFunction"
                )
            }
            return FormatExtensionReader.string(
                in: extensions,
                cfKey: nil,
                stringKey: "LogTransferFunction"
            )
        }()
        let normalizedLogTransfer = SourceColorMetadataNormalizer.normalizeLogTransferFunction(rawLogTransfer)

        let metadata = SourceColorMetadataDTO(
            colorRange: nil,
            colorSpace: SourceColorMetadataNormalizer.normalizeMatrix(rawMatrix),
            colorTransfer: SourceColorMetadataNormalizer.normalizeTransfer(rawTransfer)
                ?? normalizedLogTransfer?.rawValue,
            colorPrimaries: SourceColorMetadataNormalizer.normalizePrimaries(rawPrimaries),
            logTransferFunction: normalizedLogTransfer,
            hasMasteringDisplayMetadata: FormatExtensionReader.hasKey(
                in: extensions,
                cfKey: nil,
                stringKey: "MasteringDisplayColorVolume"
            ),
            hasContentLightMetadata: FormatExtensionReader.hasKey(
                in: extensions,
                cfKey: nil,
                stringKey: "ContentLightLevelInfo"
            )
        )
        return SourceColorClassifier.classify(metadata)
    }

    private static func profileVariant(for routeVariant: FilmtoneMezzanineRoutePolicy.Variant) -> ProfileVariant {
        switch routeVariant {
        case .sdr:
            return .sdr
        case .hdr:
            return .hdr
        }
    }
}
