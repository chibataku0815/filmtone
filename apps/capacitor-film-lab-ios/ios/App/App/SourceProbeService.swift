import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

final class SourceProbeService {
    func probeSource(at url: URL, fallback: SourceInfoDTO?) throws -> SourceProbeDTO {
        let filename = fallback?.filename ?? url.lastPathComponent
        let kind = fallback?.kind ?? inferKind(for: url)
        let mimeType = fallback?.mimeType ?? UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
        let fileSizeBytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize

        switch kind {
        case .image:
            return try probeImage(
                at: url,
                filename: filename,
                mimeType: mimeType,
                fileSizeBytes: fileSizeBytes
            )
        case .video:
            return try probeVideo(
                at: url,
                filename: filename,
                mimeType: mimeType,
                fileSizeBytes: fileSizeBytes
            )
        }
    }

    private func inferKind(for url: URL) -> FilmtoneSourceKind {
        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .image) == true {
            return .image
        }
        return .video
    }

    private func probeImage(
        at url: URL,
        filename: String,
        mimeType: String?,
        fileSizeBytes: Int?
    ) throws -> SourceProbeDTO {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            throw FilmtoneMediaError.unsupportedSource(
                filmtoneLocalized(
                    "filmtone.error.source.image_metadata",
                    defaultValue: "This image couldn't be read.",
                    comment: "Error shown when image metadata cannot be read from the selected source."
                )
            )
        }

        let width = properties[kCGImagePropertyPixelWidth] as? Int
        let height = properties[kCGImagePropertyPixelHeight] as? Int

        return SourceProbeDTO(
            uri: url.absoluteString,
            filename: filename,
            kind: .image,
            mimeType: mimeType,
            width: width,
            height: height,
            durationSec: nil,
            fileSizeBytes: fileSizeBytes,
            codec: nil,
            frameRate: nil
        )
    }

    private func probeVideo(
        at url: URL,
        filename: String,
        mimeType: String?,
        fileSizeBytes: Int?
    ) throws -> SourceProbeDTO {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw FilmtoneMediaError.unsupportedSource(
                filmtoneLocalized(
                    "filmtone.error.source.no_video_track",
                    defaultValue: "No video track was found in the selected source.",
                    comment: "Error shown when the selected video file has no video track."
                )
            )
        }

        let transformedSize = track.naturalSize.applying(track.preferredTransform)
        let width = Int(abs(transformedSize.width).rounded())
        let height = Int(abs(transformedSize.height).rounded())
        let durationSec = CMTimeGetSeconds(asset.duration)
        let frameRate = track.nominalFrameRate > 0 ? Double(track.nominalFrameRate) : nil
        let codec = codecLabel(for: track)

        return SourceProbeDTO(
            uri: url.absoluteString,
            filename: filename,
            kind: .video,
            mimeType: mimeType,
            width: width,
            height: height,
            durationSec: durationSec.isFinite ? durationSec : nil,
            fileSizeBytes: fileSizeBytes,
            codec: codec,
            frameRate: frameRate
        )
    }

    private func codecLabel(for track: AVAssetTrack) -> String? {
        guard let description = track.formatDescriptions.first else {
            return nil
        }
        let mediaSubType = CMFormatDescriptionGetMediaSubType(description as! CMFormatDescription)
        return fourCCString(mediaSubType)
    }

    private func fourCCString(_ value: FourCharCode) -> String {
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
}
