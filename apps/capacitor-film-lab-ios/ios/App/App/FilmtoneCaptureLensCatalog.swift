// Filmtone V2 native camera capture — rear lens enumeration (M10 / S8-B).
//
// Probes the rear-facing physical lenses (ultra wide / wide / telephoto) and
// filters them down to those that expose a format[] entry satisfying the M10
// capture contract:
//
//   - 3840×2160 dimensions
//   - 24 fps inside the format's videoSupportedFrameRateRanges
//   - Apple Log 2 (rawValue 4) in supportedColorSpaces
//   - cinematicExtendedEnhanced supported on the format
//
// ProRes 422 HQ availability is a session-level (input + output combined)
// property and is verified at `FilmtoneCaptureSession.prepare(lens:)` time on
// the selected lens.  Passing the catalog-level filter is necessary but not
// sufficient — if a lens passes here but the session prep cannot configure
// ProRes, the existing `.writerSetupFailed(stage: "PRORES_AVAIL", …)` failure
// surface routes the error visibly to the owner instead of silently downgrading.

import Foundation

#if os(iOS)

import AVFoundation
import CoreMedia

/// Owner-visible record of a rear lens that satisfies the M10 capture
/// contract.  Held in @State on the capture surface; the selected entry
/// drives `FilmtoneCaptureSession.prepare(lens:)`.
struct FilmtoneCaptureLens: Identifiable, Equatable {
    /// Stable identifier (`AVCaptureDevice.uniqueID`).  Used as the
    /// SwiftUI `Identifiable.id` for the selector row and recorded
    /// verbatim into `FilmtoneCaptureLensRecord` for the capture package.
    let id: String
    /// Legacy canonical label ("Main" / "Ultra Wide" / "Telephoto").
    /// Kept as the JSON-stable identity for `capture-package.json` —
    /// the M12 magnification label lives on `magnificationLabel`
    /// instead so existing downstream readers keep parsing the field
    /// they were designed against.
    let displayName: String
    /// M12: capture-time UI primary label ("0.5×" / "1×" / "2×" / "5×").
    /// Ultra wide / wide are hardcoded at canonical 0.5× / 1×; tele is
    /// computed from the wide reference's `videoFieldOfView` so iPhone
    /// 17 Pro reads "5×", iPhone 15 Pro reads "3×", older Pros "2×",
    /// without per-model tables.
    let magnificationLabel: String
    /// M12: capture-time UI subtext ("Ultra Wide" / "Wide" / "Tele").
    /// Slightly different vocabulary than `displayName` ("Wide" not
    /// "Main", "Tele" not "Telephoto") so the subtext reads as a hint
    /// next to the magnification rather than as a name with its own
    /// weight.  Empty string for unrecognized device types.
    let canonicalSubtext: String
    /// `AVCaptureDevice.DeviceType.rawValue` of the underlying device.
    let deviceTypeRaw: String
    /// Index into `device.formats` of the contract-matching format.
    /// Resolved once at enumeration time so `prepare(lens:)` does not
    /// re-scan formats on every selection switch.
    let formatIndex: Int
    /// Resolved AVCaptureDevice.  Held so the capture session can reuse
    /// the same instance without re-running discovery.  Excluded from
    /// `Equatable` (see custom `==`) so AVCaptureDevice's reference
    /// identity does not perturb diff-based UI updates.
    let device: AVCaptureDevice

    static func == (lhs: FilmtoneCaptureLens, rhs: FilmtoneCaptureLens) -> Bool {
        lhs.id == rhs.id && lhs.formatIndex == rhs.formatIndex
    }
}

extension FilmtoneCaptureLens {
    /// Serializable shape of a lens for `capture-package.json`.  The
    /// runtime `FilmtoneCaptureLens` holds an `AVCaptureDevice` reference
    /// that cannot round-trip through JSON; this record carries only the
    /// owner-visible identity fields.
    func toRecord() -> FilmtoneCaptureLensRecord {
        FilmtoneCaptureLensRecord(
            identifier: id,
            displayName: displayName,
            deviceType: deviceTypeRaw,
            magnificationLabel: magnificationLabel,
            formatIndex: formatIndex
        )
    }
}

enum FilmtoneCaptureLensCatalog {

    // M10 contract — must match `FilmtoneCaptureSession`'s locked baseline.
    private static let lockedWidth: Int32 = 3840
    private static let lockedHeight: Int32 = 2160
    private static let lockedFPS: Double = 24
    private static let appleLog2ColorSpaceRaw: Int = 4

    /// Discover rear lenses and return only those whose `formats[]`
    /// include an entry satisfying the M10 contract.  Sorted with the
    /// wide lens first so it can be picked as the default in the
    /// selector row.
    ///
    /// M12 / S12-B: enumerate in two passes so the wide lens's contract
    /// format `videoFieldOfView` can be used as the magnification
    /// baseline for tele labels.  Without the baseline, tele's "5×"
    /// vs "3×" vs "2×" cannot be derived from runtime alone — and a
    /// per-model lookup table would drift for every new iPhone.
    static func availableRearLenses() -> [FilmtoneCaptureLens] {
        let candidateTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera,
        ]
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: candidateTypes,
            mediaType: .video,
            position: .back
        )
        // Pass 1: collect (device, contractFormatIndex) for qualifying
        // lenses.  We materialise this into an array up-front so the
        // wide-lens FOV baseline can be discovered before label
        // generation runs in pass 2.
        var qualified: [(device: AVCaptureDevice, formatIndex: Int)] = []
        for device in session.devices {
            guard let formatIndex = findContractFormatIndex(on: device) else {
                continue
            }
            qualified.append((device, formatIndex))
        }
        let wideBaselineFOV: Float? = qualified.first(where: {
            $0.device.deviceType == .builtInWideAngleCamera
        }).map { $0.device.formats[$0.formatIndex].videoFieldOfView }

        // Pass 2: build entries with magnification labels resolved
        // against the wide baseline (when available) and canonical
        // subtexts assigned per device type.
        var entries: [FilmtoneCaptureLens] = []
        for (device, formatIndex) in qualified {
            let magLabel = magnificationLabel(
                for: device,
                formatIndex: formatIndex,
                wideBaselineFOV: wideBaselineFOV
            )
            entries.append(
                FilmtoneCaptureLens(
                    id: device.uniqueID,
                    displayName: legacyDisplayName(for: device.deviceType),
                    magnificationLabel: magLabel,
                    canonicalSubtext: canonicalSubtext(for: device.deviceType),
                    deviceTypeRaw: device.deviceType.rawValue,
                    formatIndex: formatIndex,
                    device: device
                )
            )
        }
        return entries.sorted { lhs, rhs in
            order(lhs.deviceTypeRaw) < order(rhs.deviceTypeRaw)
        }
    }

    /// Default lens for a freshly-presented capture surface.  Wide if
    /// present (the M5-A / M7 validated path), otherwise the first
    /// qualified entry.  Returns nil only when zero rear lenses pass
    /// the contract — the capture surface treats that as
    /// `.noWideCamera` and surfaces a failure overlay.
    static func defaultLens(in lenses: [FilmtoneCaptureLens]) -> FilmtoneCaptureLens? {
        if let wide = lenses.first(where: {
            $0.deviceTypeRaw == AVCaptureDevice.DeviceType.builtInWideAngleCamera.rawValue
        }) {
            return wide
        }
        return lenses.first
    }

    // MARK: - Helpers

    private static func findContractFormatIndex(
        on device: AVCaptureDevice
    ) -> Int? {
        for (idx, format) in device.formats.enumerated() {
            let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard dim.width == lockedWidth, dim.height == lockedHeight else {
                continue
            }
            let supports24fps = format.videoSupportedFrameRateRanges.contains { range in
                range.minFrameRate <= lockedFPS && range.maxFrameRate >= lockedFPS
            }
            guard supports24fps else { continue }
            let supportedRaw = format.supportedColorSpaces.map { $0.rawValue }
            guard supportedRaw.contains(appleLog2ColorSpaceRaw) else { continue }
            guard format.isVideoStabilizationModeSupported(.cinematicExtendedEnhanced) else {
                continue
            }
            return idx
        }
        return nil
    }

    /// Legacy canonical name written into `capture-package.json`'s
    /// `lensDisplayName` since S8-B.  Kept verbatim so existing
    /// downstream readers that key off "Main" / "Ultra Wide" /
    /// "Telephoto" continue to match.  The owner-facing capture-time
    /// label lives on `FilmtoneCaptureLens.magnificationLabel` /
    /// `canonicalSubtext` and is not the same string.
    private static func legacyDisplayName(
        for type: AVCaptureDevice.DeviceType
    ) -> String {
        switch type {
        case .builtInWideAngleCamera: return "Main"
        case .builtInUltraWideCamera: return "Ultra Wide"
        case .builtInTelephotoCamera: return "Telephoto"
        default: return type.rawValue
        }
    }

    /// M12 / S12-B: capture-time pill primary label.  Ultra-wide and
    /// wide are pinned to consumer-conventional labels (0.5× / 1×) —
    /// computing them from FOV would round to 0.6× / 1.0× and confuse
    /// the owner.  Telephoto magnification is computed from the wide
    /// lens's `videoFieldOfView` as `wideFOV / teleFOV` and rounded to
    /// the nearest integer when within 0.3 of it (typical iPhone tele
    /// magnifications are 2× / 3× / 5× — fractional outputs round to
    /// the nearest 0.5×).  Falls back to the canonical name when the
    /// baseline is missing or the format reports a non-positive FOV.
    private static func magnificationLabel(
        for device: AVCaptureDevice,
        formatIndex: Int,
        wideBaselineFOV: Float?
    ) -> String {
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return "0.5×"
        case .builtInWideAngleCamera:
            return "1×"
        case .builtInTelephotoCamera:
            guard let baseline = wideBaselineFOV, baseline > 0 else {
                return canonicalSubtext(for: device.deviceType)
            }
            let teleFOV = device.formats[formatIndex].videoFieldOfView
            guard teleFOV > 0 else {
                return canonicalSubtext(for: device.deviceType)
            }
            let ratio = baseline / teleFOV
            let rounded = ratio.rounded()
            if abs(ratio - rounded) <= 0.3 {
                return "\(Int(rounded))×"
            }
            return String(format: "%.1f×", ratio)
        default:
            return device.localizedName
        }
    }

    /// M12 / S12-B: capture-time pill subtext.  Slightly different
    /// vocabulary than `legacyDisplayName` ("Wide" not "Main", "Tele"
    /// not "Telephoto") so the subtext reads as a hint next to the
    /// magnification rather than competing with it for weight.
    private static func canonicalSubtext(
        for type: AVCaptureDevice.DeviceType
    ) -> String {
        switch type {
        case .builtInWideAngleCamera: return "Wide"
        case .builtInUltraWideCamera: return "Ultra Wide"
        case .builtInTelephotoCamera: return "Tele"
        default: return ""
        }
    }

    private static func order(_ deviceTypeRaw: String) -> Int {
        switch deviceTypeRaw {
        case AVCaptureDevice.DeviceType.builtInWideAngleCamera.rawValue: return 0
        case AVCaptureDevice.DeviceType.builtInUltraWideCamera.rawValue: return 1
        case AVCaptureDevice.DeviceType.builtInTelephotoCamera.rawValue: return 2
        default: return 99
        }
    }
}

struct FilmtoneCaptureAvailability: Equatable {
    let isSupported: Bool

    static func evaluate() -> FilmtoneCaptureAvailability {
        FilmtoneCaptureAvailability(
            isSupported: !FilmtoneCaptureLensCatalog.availableRearLenses().isEmpty
        )
    }
}

#endif
