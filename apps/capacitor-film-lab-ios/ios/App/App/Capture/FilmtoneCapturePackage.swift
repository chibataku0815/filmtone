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

/// Owner-visible identity of the lens used for a capture run.
/// Carries only fields that round-trip through `capture-package.json`;
/// the runtime `AVCaptureDevice` reference lives on
/// `FilmtoneCaptureLens` (the catalog-side struct) and is not
/// persisted.  S8-B introduces this so lens selection (M10) and
/// the upcoming capture-parameter readouts (S8-C) can refer to the
/// same lens identity that the catalog enumerated.
struct FilmtoneCaptureLensRecord: Equatable, Codable {
    /// `AVCaptureDevice.uniqueID` of the lens used for the run.
    let identifier: String
    /// Legacy canonical display name ("Main" / "Ultra Wide" /
    /// "Telephoto" / "Front").  Kept verbatim for backward compatibility with
    /// pre-M12 `capture-package.json` consumers; the M12 capture-time
    /// label lives on `magnificationLabel`.
    let displayName: String
    /// `AVCaptureDevice.DeviceType.rawValue` of the lens.
    let deviceType: String
    /// M12 / S12-B: owner-visible magnification label ("0.5×" / "1×" /
    /// "2×" / "5×").  Optional so pre-M12 packages decode cleanly with
    /// `magnificationLabel = nil`; new runs always set this together
    /// with `formatIndex`.
    let magnificationLabel: String?
    /// M12 / S12-B: index into the lens device's `formats` array of
    /// the contract-matching format selected at `prepare(lens:)` time.
    /// Persisted so a relaunch reading the package can verify which
    /// format the master was actually written through (the M10
    /// truth-gate verifier uses this to assert per-lens parity).
    let formatIndex: Int?
}

/// M12 / S12-C+E: capture-time exposure / focus / metering control state
/// snapshotted at record-stop time.  All values reflect the resolved
/// state on `AVCaptureDevice` at the moment recording finished — not
/// any in-flight tap that arrived after `stop()` was called.
///
/// `mode` is `"auto"` for continuous-auto runs (EV bias slider active,
/// tap-to-meter active) and `"manual"` for runs locked to a fixed ISO
/// + shutter duration (`setExposureModeCustom` since S12-E).  The
/// manual-only fields (`manualISO` / `manualShutterDurationSeconds` /
/// `inheritedFromAuto`) ride on this same record so downstream
/// consumers can switch on `mode` without reaching into a separate
/// nested record.
///
/// Focus / metering points are normalized to AVCaptureDevice POI
/// coordinates (landscape sensor space; (0,0) = top-left when held in
/// the M10-locked landscape sensor orientation).  Nil = continuous-auto
/// from session start, never tapped.  Auto-mode metering point follows
/// focus point on a tap; in manual exposure the metering point stays
/// nil because the M12 lock keeps tap-to-meter auto-only — even though
/// tap-to-focus continues to fire in manual.
struct FilmtoneCaptureExposureControlRecord: Equatable, Codable {
    /// `"auto"` (continuous-auto) or `"manual"` (S12-E
    /// `setExposureModeCustom` lock with sampled ISO + shutter).
    let mode: String
    /// EV bias at record-stop time, clamped at apply-time to
    /// `[-2, +2]` ∩ `device.minExposureTargetBias …
    /// device.maxExposureTargetBias`.  Always written (including the
    /// 0.0 baseline) so the package distinguishes "explicit zero" from
    /// "field absent on a pre-M12 snapshot".  Manual-mode runs persist
    /// whatever bias was held at the moment of switch (the device-level
    /// bias has no effect on a `setExposureModeCustom` exposure, but
    /// dropping the field would lose the "owner had biased before
    /// flipping to manual" signal).
    let biasEV: Double
    /// Last tap-to-focus point, normalized to AVCaptureDevice POI
    /// coordinates.  Nil = no tap during the run (focus stayed on
    /// continuous-auto from prepare(lens:)).  Active in both auto and
    /// manual exposure modes — S12-A explicitly keeps tap-to-focus
    /// available under manual exposure.
    let focusPointX: Double?
    let focusPointY: Double?
    /// Last tap-to-meter point, normalized to AVCaptureDevice POI
    /// coordinates.  Nil = either no tap during the run, or the run
    /// was in manual exposure (metering POI is auto-only by S12-A
    /// lock).  Auto-mode runs always set this to the same value as
    /// `focusPoint*` because tap-to-focus and tap-to-meter are bound
    /// together in auto mode; manual-mode runs leave it nil because
    /// the metering POI has no consumer once exposure is locked.
    let meteringPointX: Double?
    let meteringPointY: Double?
    /// S12-E: ISO sampled at record-stop time when `mode == "manual"`.
    /// Nil for auto-mode runs because the device's auto-ISO drifts
    /// continuously and persisting a snapshot value would invite the
    /// same misreading the auto-WB-gains decision flagged (see
    /// `FilmtoneCaptureWhiteBalanceRecord`).
    let manualISO: Double?
    /// S12-E: shutter duration in seconds when `mode == "manual"`,
    /// clamped at apply-time to the active format's
    /// `min/maxExposureDuration` ∩ 24-fps cap (1/24 s).  Nil for
    /// auto-mode runs.
    let manualShutterDurationSeconds: Double?
    /// S12-E: `true` when the manual exposure was entered by inheriting
    /// the auto-exposure state at the toggle moment and the owner did
    /// not subsequently move either the ISO or shutter slider.  `false`
    /// when the owner adjusted at least one of the two (the current
    /// values are deliberate, not just whatever auto reported at lock
    /// time).  Nil for auto-mode runs — the question does not apply.
    let inheritedFromAuto: Bool?
}

/// M12 / S12-D: capture-time white balance lock state.  M12 ships
/// only the two-mode contract (auto-continuous vs locked-with-sampled-
/// gains); custom Kelvin / tint sliders are out-of-scope (active.md
/// "Out of scope").  When `mode == "locked"`, all three gains are
/// required and reflect what the device reported via
/// `deviceWhiteBalanceGains` at the moment the owner tapped Locked —
/// not what was applied later if the device's auto-WB had drifted.
/// `mode == "auto"` snapshots leave gains nil (the gains the device
/// happened to have at record-stop are not stable enough to be useful
/// as metadata, and including them would invite consumers to treat
/// auto runs as "captured at gains x/y/z" which is misleading).
struct FilmtoneCaptureWhiteBalanceRecord: Equatable, Codable {
    /// `"auto"` — continuous-auto WB, owner did not lock.
    /// `"locked"` — owner held a fixed reference set at lock time.
    let mode: String
    /// Sampled gains at lock time.  Nil when `mode == "auto"`.
    let redGain: Double?
    let greenGain: Double?
    let blueGain: Double?
}

/// M11 / S11-D: capture-time Look chip recorded with a successful
/// run.  Stone / Urban populate this record so the editor adoption
/// path (S11-E) can re-apply the same Look against the proxy without
/// re-asking the owner.  The Filmtone (default) chip leaves
/// `FilmtoneCapturePackage.selectedLook` as `nil` — that is the
/// "no Look applied / preserve editor's pre-capture state" semantics
/// agreed in S11-A's Design Locks.  Master encoding is unaffected;
/// this is only metadata next to the proxy.
struct FilmtoneSelectedLookRecord: Equatable, Codable {
    /// `BuiltInLook.canonicalUUID` of the chip's Look.  Required so
    /// `applySavedLook(id:)` (S11-E) routes through the existing
    /// catalog-resolution path without reopening the materialization
    /// logic.
    let canonicalUUID: UUID
    /// `BuiltInLook.slug` for diagnostics / future bundled-only
    /// resolution paths (e.g. `filmtone-creative-pack-01-stone`).
    /// Optional only because future non-bundled Looks may not have a
    /// slug.
    let slug: String?
    /// Owner-readable name carried alongside the UUID so a stale /
    /// removed catalog entry still produces a labeled badge in the
    /// editor instead of an opaque UUID.
    let englishName: String
    /// M11 ships `1.0`.  Reserved for the intensity slider lane noted
    /// in active.md "Out of scope".
    let intensity: Double
}

/// S7 - Capture Custom LUT Intake: user-imported creative LUT selected
/// from the capture LOOK sheet. This is intentionally separate from
/// `FilmtoneSelectedLookRecord`, whose UUID path is for built-in /
/// saved Look records. Capture custom LUTs use the library LUT as SSOT
/// and carry enough identity to audit conversion and warning state
/// without embedding the large cube payload into every package.
struct FilmtoneCaptureCustomLutRecord: Equatable, Codable {
    static let captureConversionPolicy = "apple-log2-to-rec709-before-creative-lut"

    let libraryId: UUID?
    let title: String
    let size: Int
    let sourceHash: String?
    let intensity: Double
    let conversionPolicy: String
    let transformWarningReason: String?
    let transformWarningKind: String?
    let transformWarningSignal: String?
    let transformWarningAccepted: Bool

    var displayName: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Custom LUT"
            : title
    }
}

/// S1 - Capture Stabilization Toggle: owner-visible request.  `.on`
/// drives `cinematicExtendedEnhanced` exact, `.off` drives `.off`
/// exact.  No fallback / silent degrade: post-record gate fails loudly
/// when the active mode does not match the request (see
/// `FilmtoneCaptureFailure.stabilizationDowngraded`).  Default for new
/// runs is `.on` so handheld continues to ship at the cinematicEE
/// baseline established in M5-A / M7 owner walks.
enum FilmtoneRequestedStabilization: String, Equatable, Codable {
    case on
    case off

    /// Owner-visible label for the capture chip / accessibility line.
    var displayName: String {
        switch self {
        case .on: return "On"
        case .off: return "Off"
        }
    }

    /// Name persisted on `FilmtoneCaptureParameters.stabilization` and
    /// emitted into `capture-package.json`.  Mirrors the
    /// `AVCaptureVideoStabilizationMode` casename so downstream
    /// importers (sidecar, DaVinci) read a familiar token rather than
    /// `on` / `off`.
    var canonicalModeName: String {
        switch self {
        case .on: return "cinematicExtendedEnhanced"
        case .off: return "off"
        }
    }
}

/// Capture parameters resolved for a given run.  M10 ships the
/// 4K 24 fps Apple Log 2 ProRes 422 HQ + cinematicExtendedEnhanced
/// cinematic baseline.  S1 (2026-05-09) adds
/// `requestedStabilization` so handheld (On = cinematicEE) and gimbal
/// (Off = .off) shooting both ship through the same parameters
/// shape; the `stabilization` field continues to carry the canonical
/// AVFoundation mode name so existing importers do not need to read
/// the new field to recover the request.
struct FilmtoneCaptureParameters: Equatable {
    var widthPx: Int
    var heightPx: Int
    var frameRate: Double
    var codec: String
    var colorSpace: String
    /// AVFoundation-style canonical name for the requested mode
    /// (`cinematicExtendedEnhanced` when On, `off` when Off).  Kept as
    /// a string so pre-S1 importers continue to consume it without a
    /// rebuild.  Always equals `requestedStabilization.canonicalModeName`.
    var stabilization: String
    /// S1: structured request for the run.  Default `.on` preserves the
    /// handheld baseline.  `.off` skips electronic stabilization
    /// entirely so gimbal footage records without AVFoundation crop /
    /// temporal smoothing.
    var requestedStabilization: FilmtoneRequestedStabilization

    static let baseline: FilmtoneCaptureParameters = .baseline(
        requestedStabilization: .on
    )

    /// S1: factory used by the capture session to build a parameter
    /// snapshot for the requested mode.  The struct stays Equatable
    /// over both the canonical name and the structured request so an
    /// older snapshot decoded without `requestedStabilization` is not
    /// silently equal to a new On/Off request.
    static func baseline(
        requestedStabilization: FilmtoneRequestedStabilization
    ) -> FilmtoneCaptureParameters {
        .init(
            widthPx: 3840,
            heightPx: 2160,
            frameRate: 24,
            codec: "ProRes 422 HQ",
            colorSpace: "Apple Log 2",
            stabilization: requestedStabilization.canonicalModeName,
            requestedStabilization: requestedStabilization
        )
    }
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
    /// S1: post-record stabilization gate failed.  `requested` is the
    /// canonical mode name the owner asked for (cinematicExtendedEnhanced
    /// when On, off when Off); `active` is what AVFoundation reported on
    /// the connection at record-finish time.  Carrying both makes the
    /// banner honest about which gate fired ("Off was requested but
    /// active = cinematic" reads very differently from "On rejected").
    case stabilizationDowngraded(requested: String, active: String)
    case colorSpaceDowngraded(expectedRaw: Int, observedRaw: Int)
    case codecDowngraded(observed: String?)
    case captureRotationRejected(requested: Double, active: Double?)
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
            return "No camera satisfies the Filmtone capture contract."
        case .formatLockMismatch(let reason):
            return "Capture format mismatch: \(reason)"
        case .appleLog2Unavailable:
            return "Apple Log 2 colorspace is unavailable on this OS."
        case .stabilizationDowngraded(let requested, let active):
            return "Stabilization \(requested) was rejected; active mode = \(active)."
        case .colorSpaceDowngraded(let expected, let observed):
            return "Apple Log 2 (raw=\(expected)) was downgraded to raw=\(observed) at capture."
        case .codecDowngraded(let observed):
            return "ProRes 422 HQ was downgraded to \(observed ?? "<unread>")."
        case .captureRotationRejected(let requested, let active):
            let activeText = active.map { String(format: "%.3f", $0) } ?? "<unread>"
            return "Capture rotation \(String(format: "%.3f", requested))° was rejected; active angle = \(activeText)°."
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
    /// M11 / S11-D: capture-time Look chip selected at record-stop time.
    /// `nil` for the Filmtone default chip (no override) and for pre-M11
    /// captures decoded from disk.  Stone / Urban populate this so the
    /// editor adoption path (S11-E) can re-apply the same Look against
    /// the proxy.
    let selectedLook: FilmtoneSelectedLookRecord?
    /// S7: user-imported capture creative LUT. Nil for built-in Looks,
    /// Filmtone default, and pre-S7 captures.
    let customLut: FilmtoneCaptureCustomLutRecord?
    /// M12 / S12-C: exposure / focus / metering state at record-stop
    /// time.  `nil` for pre-M12 captures decoded from disk; new runs
    /// always populate this with at least the M12 baseline (`mode:
    /// "auto"`, `biasEV: 0.0`, focus / metering points nil if the run
    /// stayed on continuous-auto throughout).
    let exposureControl: FilmtoneCaptureExposureControlRecord?
    /// M12 / S12-D: white balance lock state at record-stop time.
    /// `nil` for pre-M12 captures decoded from disk; new runs always
    /// populate this with at least `mode: "auto"` so the package
    /// distinguishes "M12 capture, owner stayed on auto-WB" from
    /// "pre-M12 capture, no WB metadata exists".
    let whiteBalance: FilmtoneCaptureWhiteBalanceRecord?
    /// M14-B: security-scoped bookmark for `masterURL`, generated at
    /// capture-finalize time when `storagePolicy ==
    /// .externalSecurityScopedFolder`. Editor uses this at export
    /// start to re-acquire scope on the master file across capture-
    /// view dismissal and app relaunch. `nil` for internal-Documents
    /// masters (no scope needed) and for pre-M14-B captures decoded
    /// from disk (resolveExportSource falls back to fileExists +
    /// proxy fallback per M14-A).
    let masterBookmark: Data?
    /// S1 (2026-05-09): canonical AVFoundation mode name observed on
    /// the movie connection at record-finish time.  Equals the
    /// requested mode (`parameters.stabilization`) on a clean run; the
    /// post-record gate would have failed the run if they diverged, so
    /// in practice this is always equal.  Persisting it explicitly
    /// keeps the package + sidecar honest about both halves of
    /// "requested vs observed" instead of inferring the observed value
    /// from the absence of a failure.  `nil` for pre-S1 captures
    /// decoded from disk.
    let observedStabilization: String?
    /// S6 (2026-05-10): movie-connection rotation angle selected at
    /// record start, in AVFoundation `videoRotationAngle` degrees.
    /// `nil` for pre-S6 captures decoded from disk.
    let requestedCaptureRotationDegrees: Double?
    /// S6: movie-connection rotation angle observed at record-finish
    /// time.  The post-record gate fails if this differs from the
    /// requested value, so clean S6 runs carry matching values.
    let observedCaptureRotationDegrees: Double?
}

#endif
