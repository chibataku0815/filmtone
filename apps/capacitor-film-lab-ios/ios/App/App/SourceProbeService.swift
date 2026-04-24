import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

final class SourceProbeService {
    private let assumedDiagonalFovDeg = 70.0

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
        let cameraOptics = cameraOptics(
            for: track,
            asset: asset,
            displayWidth: width,
            displayHeight: height
        )

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
            frameRate: frameRate,
            cameraOptics: cameraOptics
        )
    }

    private func cameraOptics(
        for track: AVAssetTrack,
        asset: AVAsset,
        displayWidth: Int,
        displayHeight: Int
    ) -> CameraOpticsDTO {
        let width = safeDimension(displayWidth, fallback: 1920)
        let height = safeDimension(displayHeight, fallback: 1080)
        let make = metadataString(
            in: asset,
            commonKeys: ["make"],
            identifierFragments: ["make"]
        )
        let model = metadataString(
            in: asset,
            commonKeys: ["model"],
            identifierFragments: ["model"]
        )
        let lens = metadataString(
            in: asset,
            commonKeys: [],
            identifierFragments: ["lens"]
        )

        if let horizontalFov = horizontalFieldOfViewDeg(for: track),
           horizontalFov > 0,
           horizontalFov < 179
        {
            let rotated = isRightAngleRotation(track.preferredTransform)
            let focal = focalPxFromFov(
                sizePx: rotated ? height : width,
                fovDeg: horizontalFov
            )
            return cameraOptics(
                source: "metadata",
                width: width,
                height: height,
                focalPx: focal,
                lensModel: lens,
                cameraMake: make,
                cameraModel: model
            )
        }

        let diagonal = hypot(width, height)
        let focal = focalPxFromFov(sizePx: diagonal, fovDeg: assumedDiagonalFovDeg)
        return cameraOptics(
            source: "assumed",
            width: width,
            height: height,
            focalPx: focal,
            lensModel: lens,
            cameraMake: make,
            cameraModel: model
        )
    }

    private func cameraOptics(
        source: String,
        width: Double,
        height: Double,
        focalPx: Double,
        lensModel: String?,
        cameraMake: String?,
        cameraModel: String?
    ) -> CameraOpticsDTO {
        return CameraOpticsDTO(
            source: source,
            fxPx: focalPx,
            fyPx: focalPx,
            cxPx: width / 2,
            cyPx: height / 2,
            fovXDeg: fovFromFocalPx(sizePx: width, focalPx: focalPx),
            fovYDeg: fovFromFocalPx(sizePx: height, focalPx: focalPx),
            focalLength35mm: nil,
            lensModel: lensModel,
            cameraMake: cameraMake,
            cameraModel: cameraModel
        )
    }

    private func horizontalFieldOfViewDeg(for track: AVAssetTrack) -> Double? {
        guard let description = track.formatDescriptions.first else {
            return nil
        }
        let cmDescription = description as! CMFormatDescription
        guard
            let extensions = CMFormatDescriptionGetExtensions(cmDescription) as? [CFString: Any],
            let raw = extensions[kCMFormatDescriptionExtension_HorizontalFieldOfView] as? NSNumber
        else {
            return nil
        }
        let deg = raw.doubleValue / 1000.0
        return deg.isFinite ? deg : nil
    }

    private func metadataString(
        in asset: AVAsset,
        commonKeys: [String],
        identifierFragments: [String]
    ) -> String? {
        let commonKeySet = Set(commonKeys.map { $0.lowercased() })
        let fragments = identifierFragments.map { $0.lowercased() }
        for item in asset.commonMetadata + asset.metadata {
            if let key = item.commonKey {
                let normalizedKey = String(describing: key).lowercased()
                if commonKeySet.contains(where: { normalizedKey.contains($0) }) {
                    return trimmedMetadataString(item.stringValue)
                }
            }
            if let identifier = item.identifier {
                let normalized = String(describing: identifier).lowercased()
                if fragments.contains(where: { normalized.contains($0) }) {
                    return trimmedMetadataString(item.stringValue)
                }
            }
        }
        return nil
    }

    private func trimmedMetadataString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    private func safeDimension(_ value: Int, fallback: Double) -> Double {
        return value > 0 ? Double(value) : fallback
    }

    private func isRightAngleRotation(_ transform: CGAffineTransform) -> Bool {
        return abs(transform.b) > 0.5 && abs(transform.c) > 0.5
    }

    private func focalPxFromFov(sizePx: Double, fovDeg: Double) -> Double {
        return sizePx / (2 * tan((fovDeg * .pi / 180) / 2))
    }

    private func fovFromFocalPx(sizePx: Double, focalPx: Double) -> Double {
        return 2 * atan(sizePx / (2 * focalPx)) * 180 / .pi
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
