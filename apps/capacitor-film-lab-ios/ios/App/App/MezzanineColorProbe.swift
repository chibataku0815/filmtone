import AVFoundation
import CoreMedia
import Foundation

/// Classifies a video source as SDR or HDR by inspecting its CMFormatDescription
/// extensions for color primaries and transfer function.
///
/// Decision rule (plan §6.2):
/// - BT.2020 / Rec.2020 primaries → `.hdr` (covers HLG, PQ, Apple Log)
/// - HLG, PQ, or Apple Log transfer (with any primaries) → `.hdr`
/// - P3 D65 primaries alone stay `.sdr`; common iPhone Display P3 SDR is not HDR.
/// - Anything else, or missing metadata → `.sdr` (conservative)
///
/// Conservative default keeps Quality-mode color science intact when metadata is unknown:
/// a misclassified HDR source falls through to source-direct read in `resolvedVideoSourceURL`.
enum MezzanineColorProbe {
    static func classify(track: AVAssetTrack) -> ProfileVariant {
        guard let firstDescription = track.formatDescriptions.first else {
            return .sdr
        }
        let cmDescription = firstDescription as! CMFormatDescription

        let primaries = CMFormatDescriptionGetExtension(
            cmDescription,
            extensionKey: kCMFormatDescriptionExtension_ColorPrimaries
        ) as? String
        let transfer = CMFormatDescriptionGetExtension(
            cmDescription,
            extensionKey: kCMFormatDescriptionExtension_TransferFunction
        ) as? String

        if let primaries, isWideGamutPrimaries(primaries) {
            return .hdr
        }
        if let transfer, isHdrTransfer(transfer) {
            return .hdr
        }
        return .sdr
    }

    /// Convenience: probe the first video track of an asset URL.
    static func classify(sourceURL: URL) -> ProfileVariant {
        let asset = AVURLAsset(url: sourceURL)
        guard let track = asset.tracks(withMediaType: .video).first else {
            return .sdr
        }
        return classify(track: track)
    }

    private static func isWideGamutPrimaries(_ primaries: String) -> Bool {
        // CFString constants compare by value when bridged to Swift String.
        primaries == (kCMFormatDescriptionColorPrimaries_ITU_R_2020 as String)
    }

    private static func isHdrTransfer(_ transfer: String) -> Bool {
        if transfer == (kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG as String) ||
            transfer == (kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ as String) {
            return true
        }

        let token = transfer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return token.contains("apple") && token.contains("log")
    }
}
