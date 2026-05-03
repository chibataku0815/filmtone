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

    /// v1.4: quality-grade prewarm variant. Returns nil for typical iPhone
    /// HEVC sources (already efficiently encoded) so no quality mezzanine is
    /// generated — Quality export reads source directly. Returns
    /// qualitySDR / qualityHDR for ProRes / DNxHD / >=100 Mbps sources where
    /// re-encoding pays off in decode-time UX.
    static func qualityPrewarmVariant(track: AVAssetTrack) -> ProfileVariant? {
        guard let colorClass = sourceColorClass(track: track) else {
            return nil
        }
        let codecFamily = codecFamily(for: track)
        let dataRate = Double(track.estimatedDataRate)
        guard let routeVariant = FilmtoneMezzanineRoutePolicy.qualityPrewarmVariant(
            for: colorClass,
            codecFamily: codecFamily,
            estimatedDataRate: dataRate > 0 ? dataRate : nil
        ) else {
            return nil
        }
        return profileVariant(for: routeVariant)
    }

    static func qualityPrewarmVariant(sourceURL: URL) -> ProfileVariant? {
        let asset = AVURLAsset(url: sourceURL)
        guard let track = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        return qualityPrewarmVariant(track: track)
    }

    private static func codecFamily(for track: AVAssetTrack) -> SourceCodecFamilyDTO? {
        guard let description = track.formatDescriptions.first else {
            return nil
        }
        let mediaSubType = CMFormatDescriptionGetMediaSubType(description as! CMFormatDescription)
        let codec = fourCCString(mediaSubType)
        switch codec {
        case "avc1", "avc3", "h264":
            return .h264
        case "hvc1", "hev1", "hevc":
            return .hevc
        case "apco", "apcs", "apcn", "apch":
            return .prores422
        case "ap4h", "ap4x":
            return .prores4444
        case "aprn", "aprh":
            return .proresRaw
        default:
            return .other
        }
    }

    private static func fourCCString(_ value: FourCharCode) -> String {
        let bytes: [CChar] = [
            CChar((value >> 24) & 0xff),
            CChar((value >> 16) & 0xff),
            CChar((value >> 8) & 0xff),
            CChar(value & 0xff),
            0,
        ]
        return String(cString: bytes)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
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
        case .qualitySDR:
            return .qualitySDR
        case .qualityHDR:
            return .qualityHDR
        }
    }
}
