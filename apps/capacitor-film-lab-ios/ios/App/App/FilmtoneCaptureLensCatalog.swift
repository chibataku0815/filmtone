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
    /// Owner-facing label ("Main" / "Ultra Wide" / "Telephoto").
    let displayName: String
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
            deviceType: deviceTypeRaw
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
        var entries: [FilmtoneCaptureLens] = []
        for device in session.devices {
            guard let formatIndex = findContractFormatIndex(on: device) else {
                continue
            }
            entries.append(
                FilmtoneCaptureLens(
                    id: device.uniqueID,
                    displayName: displayName(for: device.deviceType),
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

    private static func displayName(for type: AVCaptureDevice.DeviceType) -> String {
        switch type {
        case .builtInWideAngleCamera: return "Main"
        case .builtInUltraWideCamera: return "Ultra Wide"
        case .builtInTelephotoCamera: return "Telephoto"
        default: return type.rawValue
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

#endif
