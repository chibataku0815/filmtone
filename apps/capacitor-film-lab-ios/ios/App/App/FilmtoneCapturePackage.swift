// Filmtone V2 native camera capture package — M10 surface.
//
// Holds master / proxy URLs, the storage policy that produced the master,
// duration limit, capture parameters, and any failure reason. Replaces the
// fixed-5s `FilmtoneProductCapture.RecordClipResult` adoption shape with a
// product-loop-shaped struct: editor opens on the proxy, master URL is
// retained for export-time / share-time access against the security-scoped
// external folder.

import Foundation

#if os(iOS)

/// Where the master is being written.
enum FilmtoneCaptureStoragePolicy: Equatable {
    /// Master goes to a user-picked security-scoped external folder
    /// (typically a connected SSD).  Held URL is the folder root; the
    /// caller appends the master filename.
    case externalSecurityScopedFolder(URL)
    /// Master is local-only because no external folder was selected.
    /// Internal mode is capped to 10 s (`durationLimit`); the cap is a
    /// product policy, not a hidden fallback for failed external writes.
    case internalDocumentsCapped

    /// Display tag for the storage status pill on the capture surface.
    var displayTag: String {
        switch self {
        case .externalSecurityScopedFolder(let url):
            return url.lastPathComponent
        case .internalDocumentsCapped:
            return "Internal · 10s"
        }
    }
}

/// Owner-visible identity of the rear lens used for a capture run.
/// Carries only fields that round-trip through `capture-package.json`;
/// the runtime `AVCaptureDevice` reference lives on
/// `FilmtoneCaptureLens` (the catalog-side struct) and is not
/// persisted.  S8-B introduces this so rear-lens selection (M10) and
/// the upcoming capture-parameter readouts (S8-C) can refer to the
/// same lens identity that the catalog enumerated.
struct FilmtoneCaptureLensRecord: Equatable, Codable {
    /// `AVCaptureDevice.uniqueID` of the lens used for the run.
    let identifier: String
    /// Owner-visible display name ("Main" / "Ultra Wide" / "Telephoto").
    let displayName: String
    /// `AVCaptureDevice.DeviceType.rawValue` of the lens.
    let deviceType: String
}

/// Capture parameters resolved for a given run.  M10 ships the
/// 4K 24 fps Apple Log 2 ProRes 422 HQ + cinematicExtendedEnhanced
/// cinematic baseline — kept as a struct so future capture-time
/// toggles slot in here without rewriting the package shape.  The
/// locked format index is inherited from `FilmtoneProductCapture`
/// (M5-A / M7 walks); only the frame rate departs from that path.
struct FilmtoneCaptureParameters: Equatable {
    var widthPx: Int
    var heightPx: Int
    var frameRate: Double
    var codec: String
    var colorSpace: String
    var stabilization: String

    static let baseline: FilmtoneCaptureParameters = .init(
        widthPx: 3840,
        heightPx: 2160,
        frameRate: 24,
        codec: "ProRes 422 HQ",
        colorSpace: "Apple Log 2",
        stabilization: "cinematicExtendedEnhanced"
    )
}

/// Loud-fail reasons surfaced from the capture pipeline.  These are not
/// merged into one opaque string at the boundary so the capture view can
/// route specific paths (preflight vs writer vs proxy) to the right
/// retry / picker affordance.
enum FilmtoneCaptureFailure: Error, Equatable {
    case permissionDenied
    case multiCamUnsupported
    case noWideCamera
    case formatLockMismatch(reason: String)
    case appleLog2Unavailable
    case stabilizationDowngraded(active: String)
    case colorSpaceDowngraded(expectedRaw: Int, observedRaw: Int)
    case codecDowngraded(observed: String?)
    case writerSetupFailed(stage: String, reason: String)
    case writerInterrupted(reason: String)
    case durationLimitExceeded(limitSeconds: Double)
    case externalScopeAcquisitionFailed
    case externalPreflightFailed(notes: [String])
    case externalScopeLost
    case packageDirCreationFailed(reason: String)
    case masterFileMissing
    case proxyExportFailed(reason: String)
    case packagePersistenceFailed(reason: String)
    case unexpected(reason: String)

    /// Human-readable line used by the capture view's status banner
    /// and routed to `FilmtoneEditorStore.recordingError` so the
    /// existing `.alert($store.recordingError)` surfacing in
    /// `FilmtoneRootView` keeps working.
    var displayMessage: String {
        switch self {
        case .permissionDenied:
            return "Camera permission denied."
        case .multiCamUnsupported:
            return "MultiCam capture is not supported on this device."
        case .noWideCamera:
            return "No rear builtInWideAngleCamera available."
        case .formatLockMismatch(let reason):
            return "Capture format mismatch: \(reason)"
        case .appleLog2Unavailable:
            return "Apple Log 2 colorspace is unavailable on this OS."
        case .stabilizationDowngraded(let active):
            return "cinematicExtendedEnhanced was rejected; active mode = \(active)."
        case .colorSpaceDowngraded(let expected, let observed):
            return "Apple Log 2 (raw=\(expected)) was downgraded to raw=\(observed) at capture."
        case .codecDowngraded(let observed):
            return "ProRes 422 HQ was downgraded to \(observed ?? "<unread>")."
        case .writerSetupFailed(let stage, let reason):
            return "\(stage): \(reason)"
        case .writerInterrupted(let reason):
            return "Recording interrupted: \(reason)"
        case .durationLimitExceeded(let limit):
            return "Recording exceeded the \(Int(limit)) s product limit."
        case .externalScopeAcquisitionFailed:
            return "Could not access the selected external folder. Re-pick the SSD folder."
        case .externalPreflightFailed(let notes):
            return "External folder preflight failed: \(notes.joined(separator: "; "))"
        case .externalScopeLost:
            return "External folder access expired mid-run. Re-pick the SSD folder."
        case .packageDirCreationFailed(let reason):
            return "Could not create capture package directory: \(reason)"
        case .masterFileMissing:
            return "Recording finished without producing a master file."
        case .proxyExportFailed(let reason):
            return "Proxy generation failed: \(reason)"
        case .packagePersistenceFailed(let reason):
            return "Could not persist capture package linkage: \(reason)"
        case .unexpected(let reason):
            return "Unexpected capture error: \(reason)"
        }
    }
}

/// Result of a successful capture run.  The editor adopts `proxyURL` as
/// the source; `masterURL` is retained for downstream operations
/// (export to camera roll, share the master, copy back to internal
/// storage on user request) that need the high-quality original.
struct FilmtoneCapturePackage: Equatable {
    /// Stable identifier for the capture run.  Used as the package
    /// directory name and as a key for re-acquiring the master via the
    /// external folder URL on subsequent foregrounds.
    let captureId: String
    /// Storage policy that resolved at start-of-run.
    let storagePolicy: FilmtoneCaptureStoragePolicy
    /// Master file URL.  May live on the external security-scoped
    /// folder or under `Caches/Filmtone/captures/<id>/`.
    let masterURL: URL
    /// Proxy file URL.  Always under `Caches/Filmtone/captures/<id>/`.
    /// Editor probes / previews against this — never the master.
    let proxyURL: URL
    /// Local package directory under `Caches/Filmtone/captures/<id>/`,
    /// useful for diagnostics writes regardless of master location.
    let packageDirURL: URL
    /// Maximum duration the user could record under the resolved
    /// `storagePolicy`.  10 s for internal mode, capped at the
    /// `FilmtoneProductCapture` 60 s soft ceiling for external mode.
    let durationLimitSeconds: Double
    /// Actual recorded master duration (seconds).
    let recordedDurationSeconds: Double
    /// Capture parameters used.  Pinned to `.baseline` for M10.
    let parameters: FilmtoneCaptureParameters
    /// Rear lens used for the run.  Optional only because pre-S8-B
    /// `capture-package.json` snapshots have no lens fields and decode
    /// with `nil`; new runs always set it.
    let lens: FilmtoneCaptureLensRecord?
}

#endif
