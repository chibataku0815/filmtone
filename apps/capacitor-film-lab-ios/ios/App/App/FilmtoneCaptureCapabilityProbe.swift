import AVFoundation
import CoreMedia
import Foundation
import UIKit

/// M1 Capability Probe (V2 capture / Gyroflow lane).
///
/// Read-only enumeration of `AVCaptureDevice` formats. Never starts a capture
/// session, never mutates `activeFormat` / `activeColorSpace`, and never
/// requests camera authorization. Apple Log / Apple Log 2 entries appear only
/// when the runtime reports them via `AVCaptureDevice.Format.supportedColorSpaces`.
/// Unknown enum raw values are emitted by raw value only — never inferred.
///
/// Hidden / debug-only. Production UI never invokes this.
enum FilmtoneCaptureCapabilityProbe {
    static let schemaVersion = 1

    struct Result {
        let payload: [String: Any]
        let jsonString: String
        let fileURL: URL
    }

    static func run() throws -> Result {
        let payload = makePayload()
        let jsonData = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(
                domain: "FilmtoneCaptureCapabilityProbe",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode capability JSON as UTF-8."]
            )
        }
        let fileURL = try writeArtifact(jsonData: jsonData)
        return Result(payload: payload, jsonString: jsonString, fileURL: fileURL)
    }

    // MARK: - Payload assembly

    private static func makePayload() -> [String: Any] {
        let devices = discoverDevices()
        let deviceDicts = devices.map(encodeDevice(_:))
        let recommendation = recommendM2Mode(devices: devices)

        var payload: [String: Any] = [
            "schemaVersion": schemaVersion,
            "generatedAt": ISO8601DateFormatter.shared.string(from: Date()),
            "runtime": runtimeInfo(),
            "devices": deviceDicts,
        ]
        payload["m2Recommendation"] = recommendation
        return payload
    }

    private static func runtimeInfo() -> [String: Any] {
        let device = UIDevice.current
        return [
            "iosVersion": device.systemVersion,
            "systemName": device.systemName,
            "deviceModel": deviceMachineModel(),
            "deviceName": device.name,
        ]
    }

    private static func deviceMachineModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine
    }

    // MARK: - Device discovery

    private static func discoverDevices() -> [AVCaptureDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: knownDeviceTypes(),
            mediaType: .video,
            position: .unspecified
        )
        return session.devices
    }

    private static func knownDeviceTypes() -> [AVCaptureDevice.DeviceType] {
        var types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera,
            .builtInDualCamera,
            .builtInDualWideCamera,
            .builtInTripleCamera,
            .builtInTrueDepthCamera,
            .builtInLiDARDepthCamera,
        ]
        if #available(iOS 17.0, *) {
            types.append(.external)
            types.append(.continuityCamera)
        }
        return types
    }

    // MARK: - Device encoding

    private static func encodeDevice(_ device: AVCaptureDevice) -> [String: Any] {
        var dict: [String: Any] = [
            "uniqueID": device.uniqueID,
            "localizedName": device.localizedName,
            "modelID": device.modelID,
            "manufacturer": device.manufacturer,
            "deviceType": device.deviceType.rawValue,
            "position": positionLabel(device.position),
            "hasFlash": device.hasFlash,
            "hasTorch": device.hasTorch,
            "isVirtualDevice": device.isVirtualDevice,
            "formats": device.formats.enumerated().map { encodeFormat($1, index: $0) },
        ]
        if device.isVirtualDevice {
            dict["constituentDevices"] = device.constituentDevices.map { sub in
                [
                    "uniqueID": sub.uniqueID,
                    "deviceType": sub.deviceType.rawValue,
                    "position": positionLabel(sub.position),
                ]
            }
        }
        return dict
    }

    private static func positionLabel(_ position: AVCaptureDevice.Position) -> String {
        switch position {
        case .back: return "back"
        case .front: return "front"
        case .unspecified: return "unspecified"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Format encoding

    private static func encodeFormat(_ format: AVCaptureDevice.Format, index: Int) -> [String: Any] {
        let formatDescription = format.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)

        var dict: [String: Any] = [
            "index": index,
            "mediaType": fourCC(CMFormatDescriptionGetMediaType(formatDescription)),
            "mediaSubType": fourCC(mediaSubType),
            "dimensions": [
                "width": Int(dimensions.width),
                "height": Int(dimensions.height),
            ],
            "isVideoBinned": format.isVideoBinned,
            "isVideoHDRSupported": format.isVideoHDRSupported,
            "videoFieldOfView": format.videoFieldOfView,
            "videoMaxZoomFactor": format.videoMaxZoomFactor,
            "frameRateRanges": format.videoSupportedFrameRateRanges.map(encodeFrameRateRange(_:)),
            "supportedColorSpaces": format.supportedColorSpaces.map(encodeColorSpace(_:)),
            "supportedVideoStabilizationModes": probeStabilizationModes(format: format),
        ]

        if let codecLabel = codecLabel(forMediaSubType: mediaSubType) {
            dict["codecLabel"] = codecLabel
        }

        let photoDimensions = format.supportedMaxPhotoDimensions
        if !photoDimensions.isEmpty {
            dict["supportedMaxPhotoDimensions"] = photoDimensions.map { dim in
                [
                    "width": Int(dim.width),
                    "height": Int(dim.height),
                ]
            }
        }

        if let extensions = encodeFormatExtensions(formatDescription) {
            dict["formatDescriptionExtensions"] = extensions
        }

        return dict
    }

    private static func encodeFrameRateRange(_ range: AVFrameRateRange) -> [String: Any] {
        [
            "minFPS": range.minFrameRate,
            "maxFPS": range.maxFrameRate,
            "minDurationSeconds": CMTimeGetSeconds(range.minFrameDuration),
            "maxDurationSeconds": CMTimeGetSeconds(range.maxFrameDuration),
        ]
    }

    private static func encodeColorSpace(_ colorSpace: AVCaptureColorSpace) -> [String: Any] {
        let raw = colorSpace.rawValue
        var dict: [String: Any] = ["rawValue": raw]
        if let name = colorSpaceName(forRawValue: raw) {
            dict["name"] = name
        }
        return dict
    }

    /// Mapping is by raw value — we never reference symbols like `.appleLog2`
    /// directly so the probe compiles on SDKs that introduce the case later.
    /// Only entries the runtime actually reports are emitted.
    private static func colorSpaceName(forRawValue raw: Int) -> String? {
        switch raw {
        case 0: return "sRGB"
        case 1: return "P3_D65"
        case 2: return "HLG_BT2020"
        case 3: return "appleLog"
        case 4: return "appleLog2"
        default: return nil
        }
    }

    private static let probedStabilizationRawValues: [Int] = Array(-1...5)

    private static func probeStabilizationModes(
        format: AVCaptureDevice.Format
    ) -> [[String: Any]] {
        var entries: [[String: Any]] = []
        for raw in probedStabilizationRawValues {
            guard let mode = AVCaptureVideoStabilizationMode(rawValue: raw) else { continue }
            guard format.isVideoStabilizationModeSupported(mode) else { continue }
            var entry: [String: Any] = ["rawValue": raw]
            if let name = stabilizationName(forRawValue: raw) {
                entry["name"] = name
            }
            entries.append(entry)
        }
        return entries
    }

    private static func stabilizationName(forRawValue raw: Int) -> String? {
        switch raw {
        case -1: return "auto"
        case 0: return "off"
        case 1: return "standard"
        case 2: return "cinematic"
        case 3: return "cinematicExtended"
        case 4: return "previewOptimized"
        case 5: return "cinematicExtendedEnhanced"
        default: return nil
        }
    }

    private static let codecLabelByFourCC: [String: String] = [
        "ap4h": "ProRes422HQ",
        "apch": "ProRes422",
        "apcn": "ProRes422",
        "apcs": "ProRes422LT",
        "apco": "ProRes422Proxy",
        "ap4x": "ProRes4444XQ",
        "ap4n": "ProRes4444",
        "hvc1": "HEVC",
        "avc1": "H264",
    ]

    private static func codecLabel(forMediaSubType subType: FourCharCode) -> String? {
        codecLabelByFourCC[fourCC(subType)]
    }

    private static func encodeFormatExtensions(
        _ description: CMFormatDescription
    ) -> [String: Any]? {
        guard let raw = CMFormatDescriptionGetExtensions(description) as? [String: Any] else {
            return nil
        }
        let interesting: [(CFString, String)] = [
            (kCMFormatDescriptionExtension_FullRangeVideo, "fullRangeVideoFlag"),
            (kCMFormatDescriptionExtension_TransferFunction, "transferFunction"),
            (kCMFormatDescriptionExtension_YCbCrMatrix, "ycbcrMatrix"),
            (kCMFormatDescriptionExtension_ColorPrimaries, "colorPrimaries"),
        ]
        var out: [String: Any] = [:]
        for (cfKey, jsonKey) in interesting {
            let key = cfKey as String
            if let value = raw[key] {
                out[jsonKey] = jsonStringifySafe(value)
            }
        }
        return out.isEmpty ? nil : out
    }

    private static func jsonStringifySafe(_ value: Any) -> Any {
        if JSONSerialization.isValidJSONObject([value]) {
            return value
        }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number }
        return String(describing: value)
    }

    // MARK: - M2 recommendation

    /// Picks the format M2's video-only writer should lock. Scoring uses the
    /// format's pixel layout (the canonical signal at the format level —
    /// ProRes vs HEVC is chosen at AVAssetWriter time, not here):
    /// - `x422` (10-bit 4:2:2) → ProRes 422 / 422 HQ writer candidate
    /// - `x420` (10-bit 4:2:0) → HEVC 10-bit Log writer candidate
    /// Combined with the strongest color space the format actually reports
    /// (Apple Log 2 > Apple Log > HLG > default), 4K-class resolution, and
    /// a frame-rate range that includes 30fps.
    private static func recommendM2Mode(devices: [AVCaptureDevice]) -> [String: Any] {
        let backDevices = devices.filter { $0.position == .back }
        var best: (score: Int, payload: [String: Any], reasoning: String)?

        for device in backDevices {
            for (index, format) in device.formats.enumerated() {
                let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let width = Int(dim.width)
                let height = Int(dim.height)
                guard width >= 1920, height >= 1080 else { continue }

                let supportsThirty = format.videoSupportedFrameRateRanges.contains { range in
                    range.minFrameRate <= 30.0 && range.maxFrameRate >= 30.0
                }
                guard supportsThirty else { continue }

                let subType = CMFormatDescriptionGetMediaSubType(format.formatDescription)
                let subTypeFourCC = fourCC(subType)

                let pixelScore: Int
                let writerCandidate: String
                switch subTypeFourCC {
                case "x422":
                    pixelScore = 1000
                    writerCandidate = "ProRes422HQ"
                case "x420":
                    pixelScore = 400
                    writerCandidate = "HEVC10bitLog"
                default:
                    continue
                }

                let colorSpaceRaws = format.supportedColorSpaces.map { Int($0.rawValue) }
                let colorScore: Int
                let colorName: String
                if colorSpaceRaws.contains(4) {
                    colorScore = 200
                    colorName = "appleLog2"
                } else if colorSpaceRaws.contains(3) {
                    colorScore = 100
                    colorName = "appleLog"
                } else if colorSpaceRaws.contains(2) {
                    colorScore = 50
                    colorName = "HLG_BT2020"
                } else {
                    colorScore = 0
                    colorName = "default"
                }

                let isFourK = (width == 3840 && height == 2160)
                let resolutionScore: Int
                if isFourK {
                    resolutionScore = 100
                } else if width > 3840 {
                    resolutionScore = 50
                } else {
                    resolutionScore = max(0, (width * height) / 200_000)
                }

                let nonWideAnglePenalty = device.deviceType == .builtInWideAngleCamera ? 0 : -25
                let totalScore = pixelScore + colorScore + resolutionScore + nonWideAnglePenalty

                let payload: [String: Any] = [
                    "deviceUniqueID": device.uniqueID,
                    "deviceLocalizedName": device.localizedName,
                    "deviceType": device.deviceType.rawValue,
                    "formatIndex": index,
                    "pixelFormat": subTypeFourCC,
                    "writerCandidate": writerCandidate,
                    "colorSpace": colorName,
                    "dimensions": ["width": width, "height": height],
                    "fps": 30,
                    "score": totalScore,
                ]
                let reasoning = "pixel=\(subTypeFourCC)(+\(pixelScore)) color=\(colorName)(+\(colorScore)) res=\(width)x\(height)(+\(resolutionScore)) wideAngle=\(nonWideAnglePenalty == 0)"

                if best == nil || totalScore > best!.score {
                    best = (totalScore, payload, reasoning)
                }
            }
        }

        if let best {
            return [
                "candidate": best.payload,
                "reasoning": best.reasoning,
            ]
        }
        return [
            "candidate": NSNull(),
            "reasoning": "No back-camera format with x422 / x420 pixel format and 30fps in range was reported.",
        ]
    }

    // MARK: - Artifact persistence

    private static func writeArtifact(jsonData: Data) throws -> URL {
        let cachesURL = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = cachesURL
            .appendingPathComponent("Filmtone", isDirectory: true)
            .appendingPathComponent("diagnostics", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let fileURL = directory.appendingPathComponent("m1-capability-probe.json")
        try jsonData.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    // MARK: - FourCC helpers

    private static func fourCC(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF),
        ]
        if bytes.allSatisfy({ $0 >= 0x20 && $0 < 0x7F }) {
            return String(bytes: bytes, encoding: .ascii) ?? String(format: "0x%08x", code)
        }
        return String(format: "0x%08x", code)
    }

}

private extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
