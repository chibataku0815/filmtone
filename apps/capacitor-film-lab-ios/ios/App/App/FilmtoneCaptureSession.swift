// Filmtone V2 native camera capture — session pipeline (M10).
//
// Single-camera (rear builtInWideAngleCamera) AVCaptureSession with
// AVCaptureMovieFileOutput driving ProRes 422 HQ Apple Log 2 at the
// FilmtoneProductCapture-locked format index 56 + cinematicExtendedEnhanced
// stabilization.  Manual start / stop, variable duration capped by the
// resolved storage policy.  Master output routes to the security-scoped
// external folder when one is selected; otherwise to the local package
// directory under Caches.
//
// Quality invariants are pinned to the `FilmtoneProductCapture` baseline
// validated in M5-A / M7 owner walks.  This file mirrors the same
// stop-condition rubric (stabilization-active-mode-off, Apple Log 2
// downgrade, ProRes downgrade) and lifts them to the typed
// `FilmtoneCaptureFailure` enum so the capture view can route specific
// failures to specific affordances.

import Foundation

#if os(iOS)

import AVFoundation
import Combine
import CoreMedia
import UIKit
import QuartzCore

@MainActor
final class FilmtoneCaptureSession: NSObject, ObservableObject {

    // MARK: - Locked baseline
    //
    // Dimensions / rotation / colorspace / fps are inherited from
    // `FilmtoneProductCapture` (M5-A / M7 walks), but **M10 ships at
    // 4K 24 fps** — cinematic 24p, not the 30 fps used by the older
    // recordClip path.  The format-level lock still holds; only the
    // active min/maxFrameDuration changes.
    //
    // S8-B: the per-lens format index is no longer hardcoded to 56.
    // `FilmtoneCaptureLensCatalog` enumerates rear lenses and resolves
    // a contract-matching format index per device, so non-wide lenses
    // (ultra wide / telephoto) can satisfy the same contract on
    // devices where the matching format sits at a different index.
    // The wide-camera index 56 coincidence is preserved by the
    // catalog's contract scan; we just no longer wire it as a constant.
    private static let lockedWidth: Int32 = 3840
    private static let lockedHeight: Int32 = 2160
    private static let lockedFPS: Double = 24
    private static let lockedRotationAngle: CGFloat = 90
    private static let appleLog2ColorSpaceRaw: Int = 4

    /// Internal-mode product cap.  Explicit, not a hidden fallback.
    static let internalDurationCapSeconds: Double = 10.0

    /// External-mode soft ceiling.  S4 (2026-05-09) raised this from
    /// 60 s to 300 s so the V2 capture surface supports a real 5 min
    /// take on a connected SSD.  No longer keyed to
    /// `FilmtoneProductCapture.maxDurationSeconds` (the legacy
    /// fixed-duration evidence path stays at 60 s; the two paths
    /// intentionally diverge).  ProRes 422 HQ Apple Log 2 thermal
    /// envelope is the owner's responsibility past this ceiling — the
    /// existing `writerInterrupted` failure surface routes any AV
    /// thermal abort visibly to the banner.
    static let externalDurationCapSeconds: Double = 300.0

    // MARK: - Public API

    enum SessionState: Equatable {
        case idle
        case configuring
        case ready
        case recording(startedAt: Date)
        case stopping
        case completed(FilmtoneCapturePackage)
        case failed(FilmtoneCaptureFailure)
    }

    /// Owner-visible session state.  The capture view reads this on
    /// every transition and renders the record / stop / status pill
    /// accordingly.
    @Published private(set) var state: SessionState = .idle

    /// Live elapsed seconds while `state == .recording`.  Updated on a
    /// timer for the countdown / progress ring.
    @Published private(set) var elapsedSeconds: Double = 0

    /// Storage policy resolved at start-of-run.  Pinned to
    /// `.internalDocumentsCapped` until the caller hands us an
    /// external folder URL via `useExternalFolder`.
    @Published private(set) var storagePolicy: FilmtoneCaptureStoragePolicy = .internalDocumentsCapped

    /// Preview layer the capture view embeds via UIViewRepresentable.
    /// `nil` until `prepare()` succeeds.
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "filmtone.capture.session.queue")

    private var device: AVCaptureDevice?
    /// Rear lens that prepare(lens:) configured the session against.
    /// Nil before prepare(); reset by teardown().  Captured into the
    /// FilmtoneCapturePackage at recording-finished time so the
    /// editor / export pipelines can carry the lens identity.
    private var activeLens: FilmtoneCaptureLens?
    private var movieOutput: AVCaptureMovieFileOutput?

    /// S8-F preview-only VDO.  8-bit BGRA frames for live Look preview;
    /// the record path stays on `movieOutput` (ProRes 422 HQ + Apple
    /// Log 2 + cinematicEE).  M2-A constraint (`.appleLog2` does not
    /// deliver 10-bit `x422`/`x420` from VDO on iOS 26.4) is sidestepped
    /// because we only ask BGRA here — the device internally tonemaps
    /// to 8-bit for the VDO connection while the Movie connection keeps
    /// 10-bit Apple Log 2.  Nil if `canAddOutput` rejects coexistence at
    /// `prepare(lens:)` time; in that case live preview falls back to
    /// the raw `AVCaptureVideoPreviewLayer` and the reference thumbnail
    /// strip remains the only graded affordance.
    private var previewVideoDataOutput: AVCaptureVideoDataOutput?
    private var previewSampleDelegate: PreviewSampleDelegate?
    private let previewSampleQueue = DispatchQueue(
        label: "filmtone.capture.preview.vdo.queue",
        qos: .userInteractive
    )

    /// S8-F F2: shared sink between the VDO delegate (writer) and the
    /// SwiftUI `MTKView` live-preview renderer (reader).  Lives on the
    /// session for the session's lifetime so the same sink survives
    /// lens swaps; `teardown()` clears the cached frame so the next
    /// prepare(lens:) starts blank rather than briefly painting a
    /// stale frame from the previous lens.
    let previewFrameSink = FilmtonePreviewFrameSink()

    /// True when `prepare(lens:)` successfully attached the preview
    /// VDO.  Read by `FilmtoneCaptureView` to decide whether to render
    /// the Metal-backed live preview or fall back to the raw
    /// `AVCaptureVideoPreviewLayer`.  Toggles together with `state`
    /// transitions (`.ready` after a successful prepare, `.idle` after
    /// teardown) so SwiftUI body recomputes pick the change up.
    var hasLivePreview: Bool { previewVideoDataOutput != nil }

    /// M12 / S12-C: current EV bias applied to the active device.
    /// Resets to 0 on every `prepare(lens:)` so a lens swap drops back
    /// to neutral exposure (the new lens's auto-exposure baseline is
    /// the right place to re-judge from).  Updated by
    /// `setExposureBias(_:)`; clamped at apply-time to
    /// `exposureBiasRange`.
    @Published private(set) var exposureBiasEV: Float = 0
    /// M12 / S12-C: usable EV range for the slider, clamped to
    /// `[-2, +2]` ∩ `device.minExposureTargetBias …
    /// device.maxExposureTargetBias`.  iPhone wide / tele cameras
    /// typically expose ±8 EV at the device level — the M12 cap keeps
    /// the slider conservative ("もしものため") so an accidental drag
    /// cannot blow the exposure across stops.
    @Published private(set) var exposureBiasRange: ClosedRange<Float> = -2...2
    /// M12 / S12-C: last tap-to-focus point in normalized
    /// AVCaptureDevice POI coordinates ((0,0) = top-left landscape
    /// sensor).  Nil before the first tap; reset to nil on
    /// `prepare(lens:)` so a lens swap drops back to continuous-auto.
    @Published private(set) var lastFocusPointNormalized: CGPoint?
    /// M12 / S12-C: last tap-to-meter point.  Auto-mode runs always
    /// keep this equal to `lastFocusPointNormalized` (a tap binds
    /// focus + metering together by S12-A lock); reserved for nil in
    /// S12-E manual exposure where metering POI does not move.
    @Published private(set) var lastMeteringPointNormalized: CGPoint?

    /// M12 / S12-D: white balance mode for the active session.  Resets
    /// to `.auto` on every `prepare(lens:)` so a lens swap drops back
    /// to continuous auto-WB (the new lens's auto baseline is the
    /// right place to re-judge a lock from).  Updated by
    /// `lockWhiteBalance()` / `unlockWhiteBalance()`.
    enum WhiteBalanceMode: String, Equatable {
        case auto
        case locked
    }
    @Published private(set) var whiteBalanceMode: WhiteBalanceMode = .auto

    /// M12 / S12-E: exposure mode toggle.  `.auto` = continuous-auto
    /// exposure (EV bias slider active, tap-to-meter active); `.manual`
    /// = `setExposureModeCustom` with sampled ISO + shutter (EV bias
    /// has no effect, tap-to-meter no-ops; tap-to-focus stays active).
    /// Resets to `.auto` on every `prepare(lens:)` and `teardown()` so
    /// a lens swap or fresh present drops back to the auto baseline.
    enum ExposureMode: String, Equatable {
        case auto
        case manual
    }
    @Published private(set) var exposureMode: ExposureMode = .auto
    /// M12 / S12-E: ISO held when `exposureMode == .manual`.  Updated
    /// from `enterManualExposure()` (inherited from auto) or from
    /// `setManualISO(_:)` (slider drag).  Clamped at apply-time to
    /// `isoRange`; clamping is an apply-time concern because the
    /// device-side bounds can in theory shift across format changes
    /// even when the slider's binding is mid-drag.
    @Published private(set) var manualISO: Float = 100
    /// M12 / S12-E: shutter duration in seconds held when
    /// `exposureMode == .manual`.  Apply-time clamp to
    /// `shutterDurationRange` (24-fps cap on the slow side).
    @Published private(set) var manualShutterSeconds: Double = 1.0/48
    /// M12 / S12-E: usable ISO range for the slider, derived from the
    /// active format's `minISO` / `maxISO`.  iPhone wide @ 4K24 Apple
    /// Log 2 reports a wide range (~30 … ~6400); narrower formats may
    /// report tighter ranges.  Empty range (`min == max`) means the
    /// slider hides — the UI guards on `range.upperBound >
    /// range.lowerBound` to avoid SwiftUI Slider NaN on a degenerate
    /// `0...0` interval.
    @Published private(set) var isoRange: ClosedRange<Float> = 100...3200
    /// M12 / S12-E: usable shutter duration range in seconds.  Lower
    /// bound = `activeFormat.minExposureDuration` (fastest shutter);
    /// upper bound = `min(activeFormat.maxExposureDuration, 1/24 s)`
    /// (24-fps cap from `lockedFPS`).  The cap is intentional: a
    /// shutter slower than 1/24 s would either drop frames or stop
    /// being a real exposure choice on a 24-fps capture, so we never
    /// expose it in the slider regardless of what the format reports.
    @Published private(set) var shutterDurationRange: ClosedRange<Double> = (1.0/8000)...(1.0/24)
    /// M12 / S12-E: 180° shutter marker position (1/48 s) used by the
    /// view to pin a yellow tick on the shutter slider as a visual
    /// reference.  Nil when the marker would fall outside
    /// `shutterDurationRange` — no shipping iPhone trips this; the
    /// guard keeps the marker honest if a future format excludes
    /// 1/48 s.
    @Published private(set) var shutterDuration180Degrees: Double?
    /// M12 / S12-E: tracks whether the active manual exposure was
    /// entered by inheriting auto exposure (`true`) versus the owner
    /// adjusting a slider after entry (`false`).  Persisted on the
    /// capture package so downstream consumers can distinguish
    /// "owner set ISO/shutter deliberately" from "owner just locked
    /// the auto reading".
    @Published private(set) var manualInheritedFromAuto: Bool = false
    /// M12 / S12-D: gains sampled at the moment the owner tapped
    /// Locked.  Held internally so the record-stop snapshot can carry
    /// them into the capture package; not exposed for UI tweaks
    /// (S12-D does not ship a Kelvin / tint slider — those are
    /// out-of-scope per active.md).  Nil while in `.auto`.
    @Published private(set) var lockedWhiteBalanceGains: AVCaptureDevice.WhiteBalanceGains?
    /// M12 / S12-D: whether the active device + format combination
    /// can lock white balance with custom device gains.  Read at
    /// `prepare(lens:)` from `device.isLockingWhiteBalanceWithCustomDeviceGainsSupported`
    /// AND `device.isWhiteBalanceModeSupported(.locked)`.  False
    /// disables the Locked segment in the UI with a visible reason
    /// rather than failing silently when the owner taps Locked.
    @Published private(set) var canLockWhiteBalance: Bool = true

    /// S1 (2026-05-09): owner-requested stabilization for the next
    /// run.  Default `.on` preserves the M10 / M5-A handheld baseline
    /// (`cinematicExtendedEnhanced`).  `.off` records gimbal-friendly
    /// footage with AVFoundation electronic stabilization fully
    /// disabled.  Mutated only via `setRequestedStabilization(_:)` so
    /// the value is gated on `state == .ready` and applied through
    /// `beginConfiguration` / `commitConfiguration` rather than a raw
    /// connection write that the running session might ignore until
    /// the next configure pass.
    @Published private(set) var requestedStabilization: FilmtoneRequestedStabilization = .on

    private var captureId: String = UUID().uuidString.lowercased()
    private var packageDirURL: URL?
    private var masterURL: URL?
    private var proxyURL: URL?

    private var startedAtBootTime: TimeInterval = 0
    private var recordedDurationSnapshot: Double = 0
    private var pendingFailure: FilmtoneCaptureFailure?

    private var elapsedTimer: Timer?
    private var autoStopTask: Task<Void, Never>?

    private var recordingDelegate: MovieDelegate?

    // MARK: - Setup

    /// Configures the session graph + acquires the preview layer.  Must
    /// be called once before `start()`.  Throws on permission denial,
    /// device lookup failure, or format-lock mismatch — the capture view
    /// surfaces these as a failure banner instead of mounting a dead
    /// preview.
    ///
    /// S8-B: caller passes a `FilmtoneCaptureLens` resolved by
    /// `FilmtoneCaptureLensCatalog.availableRearLenses()`.  The catalog
    /// has already verified format-level contract compliance; we
    /// re-check inside `prepare(lens:)` defensively because the format
    /// index could in theory be stale (e.g. if a future lens swap
    /// happens between enumeration and prepare), and because the
    /// per-format ProRes 422 HQ availability is only knowable after the
    /// session has the input + output wired.
    func prepare(lens: FilmtoneCaptureLens) async throws {
        state = .configuring

        let permission = await Self.requestCameraPermission()
        guard permission == .authorized else {
            let failure: FilmtoneCaptureFailure = (permission == .denied || permission == .restricted)
                ? .permissionDenied : .permissionDenied
            state = .failed(failure)
            throw failure
        }

        let captureDevice = lens.device

        guard captureDevice.formats.indices.contains(lens.formatIndex) else {
            let failure = FilmtoneCaptureFailure.formatLockMismatch(
                reason: "lens \(lens.displayName) (\(lens.deviceTypeRaw)) formats has \(captureDevice.formats.count) entries, need index \(lens.formatIndex)"
            )
            state = .failed(failure)
            throw failure
        }
        let format = captureDevice.formats[lens.formatIndex]
        let supportedRaw = format.supportedColorSpaces.map { $0.rawValue }
        guard supportedRaw.contains(Self.appleLog2ColorSpaceRaw) else {
            let failure = FilmtoneCaptureFailure.formatLockMismatch(
                reason: "lens \(lens.displayName) formats[\(lens.formatIndex)].supportedColorSpaces missing appleLog2 raw=4; have \(supportedRaw)"
            )
            state = .failed(failure)
            throw failure
        }
        let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        guard dim.width == Self.lockedWidth, dim.height == Self.lockedHeight else {
            let failure = FilmtoneCaptureFailure.formatLockMismatch(
                reason: "lens \(lens.displayName) formats[\(lens.formatIndex)] dims \(dim.width)x\(dim.height); need \(Self.lockedWidth)x\(Self.lockedHeight)"
            )
            state = .failed(failure)
            throw failure
        }
        guard let appleLog2 = AVCaptureColorSpace(rawValue: Self.appleLog2ColorSpaceRaw) else {
            let failure = FilmtoneCaptureFailure.appleLog2Unavailable
            state = .failed(failure)
            throw failure
        }
        self.device = captureDevice
        self.activeLens = lens

        do {
            session.beginConfiguration()
            // Idempotent reconfigure: drop any input / output left over
            // from a prior prepare(lens:) call so S8-B lens swaps reuse
            // the same AVCaptureSession instance without duplicating
            // inputs.  teardown() only stops the session — it does not
            // remove inputs/outputs.
            for existingInput in session.inputs {
                session.removeInput(existingInput)
            }
            for existingOutput in session.outputs {
                session.removeOutput(existingOutput)
            }
            session.sessionPreset = .inputPriority
            session.automaticallyConfiguresCaptureDeviceForWideColor = false

            let input = try AVCaptureDeviceInput(device: captureDevice)
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                let failure = FilmtoneCaptureFailure.writerSetupFailed(
                    stage: "INPUT_ADD", reason: "session.canAddInput returned false"
                )
                state = .failed(failure)
                throw failure
            }
            session.addInput(input)

            try captureDevice.lockForConfiguration()
            captureDevice.activeFormat = format
            captureDevice.activeColorSpace = appleLog2
            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(Self.lockedFPS))
            captureDevice.activeVideoMinFrameDuration = frameDuration
            captureDevice.activeVideoMaxFrameDuration = frameDuration
            // M12 / S12-C: reset EV bias + auto-exposure / auto-focus
            // so a lens swap (or first prepare) drops back to neutral.
            // The bias setter is a no-op when the device cannot move
            // off its current target, but calling it inside the
            // already-held configuration lock is the cheapest correct
            // way to re-zero across swaps without a second lock cycle.
            captureDevice.setExposureTargetBias(0, completionHandler: nil)
            if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
                captureDevice.focusMode = .continuousAutoFocus
            }
            if captureDevice.isExposureModeSupported(.continuousAutoExposure) {
                captureDevice.exposureMode = .continuousAutoExposure
            }
            // M12 / S12-D: reset white balance to continuous-auto so
            // a lens swap drops a previously-locked WB.  Calling this
            // inside the same lock cycle as the EV / focus reset.
            if captureDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            captureDevice.unlockForConfiguration()
            // Capture the device-reported bias range and intersect with
            // the M12 `[-2, +2]` cap so the slider exposes only the
            // usable subset.  iPhone wide / tele typically report ±8 EV
            // at the device level — we take the tighter of "device
            // says it can" and "M12 cap allows".
            let deviceMin = captureDevice.minExposureTargetBias
            let deviceMax = captureDevice.maxExposureTargetBias
            let lowerBound = max(deviceMin, Float(-2))
            let upperBound = min(deviceMax, Float(2))
            self.exposureBiasRange = lowerBound <= upperBound
                ? lowerBound...upperBound
                : Float(0)...Float(0)
            self.exposureBiasEV = 0
            self.lastFocusPointNormalized = nil
            self.lastMeteringPointNormalized = nil
            // M12 / S12-E: snapshot ISO + shutter ranges from the
            // active format and pre-seed the manual-mode published
            // values to the 180° baseline.  enterManualExposure() will
            // overwrite these with live device readings on the toggle
            // moment; the pre-seed exists so a degenerate (e.g.
            // mid-prepare) read of `manualISO` / `manualShutterSeconds`
            // before any toggle still returns sensible numbers.
            let isoLower = format.minISO
            let isoUpper = format.maxISO
            self.isoRange = isoLower <= isoUpper
                ? isoLower...isoUpper
                : isoLower...isoLower
            let minDur = CMTimeGetSeconds(format.minExposureDuration)
            let maxDurFromFormat = CMTimeGetSeconds(format.maxExposureDuration)
            let cap24fps = 1.0 / Self.lockedFPS
            let upperShutter = min(maxDurFromFormat, cap24fps)
            self.shutterDurationRange = minDur < upperShutter
                ? minDur...upperShutter
                : minDur...minDur
            let m180 = 1.0 / 48.0
            self.shutterDuration180Degrees =
                (m180 >= self.shutterDurationRange.lowerBound
                    && m180 <= self.shutterDurationRange.upperBound)
                ? m180 : nil
            self.exposureMode = .auto
            self.manualInheritedFromAuto = false
            self.manualISO = min(
                max(captureDevice.iso, self.isoRange.lowerBound),
                self.isoRange.upperBound
            )
            let seedShutter = self.shutterDuration180Degrees
                ?? self.shutterDurationRange.upperBound
            self.manualShutterSeconds = seedShutter
            // M12 / S12-D: snapshot WB lock capability per active
            // device + format.  All shipping iPhone rear lenses
            // satisfy both predicates; the guard exists for future
            // hardware where a lens reports `.locked` unsupported
            // (e.g. a yet-unseen specialty front-facing camera) so
            // the UI can disable Locked with a visible reason rather
            // than failing the apply silently.
            self.canLockWhiteBalance =
                captureDevice.isLockingWhiteBalanceWithCustomDeviceGainsSupported
                && captureDevice.isWhiteBalanceModeSupported(.locked)
            self.whiteBalanceMode = .auto
            self.lockedWhiteBalanceGains = nil

            let output = AVCaptureMovieFileOutput()
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                let failure = FilmtoneCaptureFailure.writerSetupFailed(
                    stage: "MOVIE_OUTPUT_ADD", reason: "session.canAddOutput returned false"
                )
                state = .failed(failure)
                throw failure
            }
            session.addOutput(output)
            self.movieOutput = output

            if let connection = output.connection(with: .video) {
                let availableCodecs = output.availableVideoCodecTypes.map { $0.rawValue }
                guard availableCodecs.contains(AVVideoCodecType.proRes422HQ.rawValue) else {
                    session.commitConfiguration()
                    let failure = FilmtoneCaptureFailure.writerSetupFailed(
                        stage: "PRORES_AVAIL",
                        reason: "AVVideoCodecType.proRes422HQ not in availableVideoCodecTypes: \(availableCodecs)"
                    )
                    state = .failed(failure)
                    throw failure
                }
                output.setOutputSettings(
                    [AVVideoCodecKey: AVVideoCodecType.proRes422HQ],
                    for: connection
                )
                if connection.isVideoRotationAngleSupported(Self.lockedRotationAngle) {
                    connection.videoRotationAngle = Self.lockedRotationAngle
                }
                // S1 (2026-05-09): apply the owner's requested mode
                // exactly.  `.off` is always supported by an
                // AVCaptureDevice.Format, so the format-supported
                // guard only needs to fire on `.on`
                // (`cinematicExtendedEnhanced`).  No fallback —
                // unsupported on this format means the run cannot
                // start at the requested mode, period.
                let preferredMode = Self.avMode(for: requestedStabilization)
                if requestedStabilization == .on,
                   !format.isVideoStabilizationModeSupported(preferredMode) {
                    session.commitConfiguration()
                    let failure = FilmtoneCaptureFailure.stabilizationDowngraded(
                        requested: requestedStabilization.canonicalModeName,
                        active: "unsupported-on-format"
                    )
                    state = .failed(failure)
                    throw failure
                }
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = preferredMode
                }
            }

            // S8-F F1: attach preview-only VDO for live Look preview.
            // Best-effort: if the session refuses coexistence we leave
            // `previewVideoDataOutput` nil and the capture view falls
            // back to the raw `AVCaptureVideoPreviewLayer`.  This is
            // intentionally graceful — we do NOT fail prepare(lens:)
            // here because the record path is the product, not preview
            // grading.
            let vdo = AVCaptureVideoDataOutput()
            vdo.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            vdo.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(vdo) {
                session.addOutput(vdo)
                let delegate = PreviewSampleDelegate(sink: previewFrameSink)
                vdo.setSampleBufferDelegate(delegate, queue: previewSampleQueue)
                if let vdoConnection = vdo.connection(with: .video),
                   vdoConnection.isVideoRotationAngleSupported(Self.lockedRotationAngle) {
                    vdoConnection.videoRotationAngle = Self.lockedRotationAngle
                }
                self.previewVideoDataOutput = vdo
                self.previewSampleDelegate = delegate
            } else {
                self.previewVideoDataOutput = nil
                self.previewSampleDelegate = nil
            }

            session.commitConfiguration()
        } catch let failure as FilmtoneCaptureFailure {
            state = .failed(failure)
            throw failure
        } catch {
            let failure = FilmtoneCaptureFailure.unexpected(reason: error.localizedDescription)
            state = .failed(failure)
            throw failure
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        if let connection = preview.connection,
           connection.isVideoRotationAngleSupported(Self.lockedRotationAngle) {
            connection.videoRotationAngle = Self.lockedRotationAngle
        }
        self.previewLayer = preview

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }

        state = .ready
    }

    /// M11 / S11-D: capture-time Look chip recorded with the run.
    /// Set by `FilmtoneCaptureView` whenever the chip selection
    /// changes (and seeded once on view appear) so the
    /// `FilmtoneCapturePackage` built at record-stop time carries
    /// `selectedLook` without the session knowing about chip UI.
    /// `nil` = Filmtone default chip (no Look) or pre-M11 callers.
    private var pendingSelectedLook: FilmtoneSelectedLookRecord?

    /// View-side setter for the capture-time Look chip.  Idempotent;
    /// safe to call before `prepare(lens:)` and at any point during
    /// `.ready` / `.recording` (the value is only consumed at
    /// record-stop time when the package is built).
    func setSelectedLook(_ record: FilmtoneSelectedLookRecord?) {
        pendingSelectedLook = record
    }

    // MARK: - M12 / S12-C exposure / focus / metering

    /// Apply an EV bias to the active device.  Clamped at apply-time
    /// to `exposureBiasRange` so a slider that drifts past the cap
    /// (e.g. between a lens swap that narrowed the device range and
    /// the next slider repaint) does not push the device past what it
    /// will accept.  Best-effort: a `lockForConfiguration()` failure
    /// silently leaves the published value at its previous reading
    /// rather than fabricating a phantom apply — the slider snaps
    /// back on the next state observation.
    ///
    /// S12-E: no-op when `exposureMode == .manual`.  EV bias has no
    /// effect on a `setExposureModeCustom` exposure (the device-level
    /// bias does not feed into the locked ISO/shutter pair) and the
    /// view hides the slider in manual mode anyway; the guard exists
    /// for defensive callers that did not consult the gate.
    func setExposureBias(_ ev: Float) {
        guard let device else { return }
        guard exposureMode == .auto else { return }
        let clamped = min(
            max(ev, exposureBiasRange.lowerBound),
            exposureBiasRange.upperBound
        )
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(clamped, completionHandler: nil)
            device.unlockForConfiguration()
            exposureBiasEV = clamped
        } catch {
            // Lock contention (e.g. a synchronous reconfigure on
            // another path) — drop the apply silently; the slider
            // will resync from `exposureBiasEV` on the next render.
        }
    }

    /// Reset EV bias to 0.  Wired to the slider's tap-and-hold gesture
    /// (S12-A lock).  Goes through the same clamp + apply path as a
    /// regular set so a 0 reset on a device that cannot represent
    /// exactly 0 (none of the M10-supported lenses fall in this case
    /// today, but the API does not promise it) still produces a clean
    /// apply.
    func resetExposureBias() {
        setExposureBias(0)
    }

    /// Apply tap-to-focus + tap-to-meter at a normalized AVCaptureDevice
    /// POI point.  Caller has already converted from view-local tap
    /// coordinates via
    /// `previewLayer.captureDevicePointConverted(fromLayerPoint:)`.
    ///
    /// S12-C / S12-E: tap-to-focus runs in both auto and manual
    /// exposure (focusing without re-metering is a routine ask).
    /// Tap-to-meter only runs when `exposureMode == .auto`; manual
    /// exposure deliberately skips the metering POI because the
    /// `setExposureModeCustom` lock holds ISO/shutter regardless of
    /// what the device's auto-meter would compute, and writing the POI
    /// would produce metadata (`lastMeteringPointNormalized`) that
    /// suggests a meter was honored when it was not.
    ///
    /// Best-effort on lock failure (same rationale as
    /// `setExposureBias(_:)`).
    func applyTapToFocusAndMeter(devicePoint: CGPoint) {
        guard let device else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported,
               device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
                lastFocusPointNormalized = devicePoint
            }
            if exposureMode == .auto,
               device.isExposurePointOfInterestSupported,
               device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
                lastMeteringPointNormalized = devicePoint
            }
            device.unlockForConfiguration()
        } catch {
            // Lock contention — drop the tap silently; the user can
            // tap again.  Reticle will already have appeared and
            // will fade out on its own timer.
        }
    }

    /// M12 / S12-D: hold WB at the device's current
    /// `deviceWhiteBalanceGains`.  No-op when the active lens did not
    /// report lock support at `prepare(lens:)` time — the UI gates the
    /// tap on `canLockWhiteBalance`, but the guard here keeps the
    /// session safe to call from any caller that did not consult the
    /// gate.  Best-effort on lock contention (same rationale as
    /// `setExposureBias(_:)`).
    func lockWhiteBalance() {
        guard let device, canLockWhiteBalance else { return }
        do {
            try device.lockForConfiguration()
            let currentGains = device.deviceWhiteBalanceGains
            // The device must accept these gains as "in range" for
            // `setWhiteBalanceModeLocked(with:)` to succeed; clamp to
            // `[1.0, maxWhiteBalanceGain]` per channel because the
            // sampled `deviceWhiteBalanceGains` can theoretically
            // sit at exactly `maxWhiteBalanceGain` on edge-case
            // exposures, and the setter rejects anything above.
            let maxGain = device.maxWhiteBalanceGain
            let clamped = AVCaptureDevice.WhiteBalanceGains(
                redGain: min(max(currentGains.redGain, 1.0), maxGain),
                greenGain: min(max(currentGains.greenGain, 1.0), maxGain),
                blueGain: min(max(currentGains.blueGain, 1.0), maxGain)
            )
            device.setWhiteBalanceModeLocked(with: clamped, completionHandler: nil)
            device.unlockForConfiguration()
            self.lockedWhiteBalanceGains = clamped
            self.whiteBalanceMode = .locked
        } catch {
            // Lock contention — leave state on .auto; the UI segment
            // will resync from `whiteBalanceMode` and the owner can
            // tap Locked again.
        }
    }

    /// M12 / S12-D: return WB to continuous-auto.  Idempotent; safe
    /// to call when already on `.auto`.
    func unlockWhiteBalance() {
        guard let device else { return }
        do {
            try device.lockForConfiguration()
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            device.unlockForConfiguration()
            self.lockedWhiteBalanceGains = nil
            self.whiteBalanceMode = .auto
        } catch {
            // Lock contention — leave state where it was.
        }
    }

    // MARK: - M12 / S12-E manual exposure

    /// Switch to manual exposure by inheriting the device's current
    /// auto ISO + shutter duration.  Clamped to the format-derived
    /// `isoRange` / `shutterDurationRange` so a transient auto
    /// reading just outside the slider bounds (e.g. an auto-meter
    /// blip) does not push the device into a setter that
    /// `setExposureModeCustom` would reject.  Idempotent: a second
    /// call while already in `.manual` is a no-op (the contract is
    /// "enter manual" not "re-sample"; explicit re-sample requires
    /// exit + enter).
    func enterManualExposure() {
        guard let device else { return }
        guard exposureMode != .manual else { return }
        do {
            try device.lockForConfiguration()
            let inheritedISO = min(
                max(device.iso, isoRange.lowerBound),
                isoRange.upperBound
            )
            let liveDurSec = CMTimeGetSeconds(device.exposureDuration)
            let inheritedDur = min(
                max(liveDurSec, shutterDurationRange.lowerBound),
                shutterDurationRange.upperBound
            )
            let durCM = CMTime(
                seconds: inheritedDur,
                preferredTimescale: 1_000_000
            )
            device.setExposureModeCustom(
                duration: durCM,
                iso: inheritedISO,
                completionHandler: nil
            )
            device.unlockForConfiguration()
            manualISO = inheritedISO
            manualShutterSeconds = inheritedDur
            manualInheritedFromAuto = true
            exposureMode = .manual
        } catch {
            // Lock contention — leave on auto; the UI segment will
            // resync from `exposureMode`.  Owner can tap Manual again.
        }
    }

    /// Switch back to continuous-auto exposure.  Drops
    /// `manualInheritedFromAuto` because it only has meaning while in
    /// manual.  Idempotent.
    func exitManualExposure() {
        guard let device else { return }
        guard exposureMode != .auto else { return }
        do {
            try device.lockForConfiguration()
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
            exposureMode = .auto
            manualInheritedFromAuto = false
        } catch {
            // Lock contention — leave state where it was.
        }
    }

    /// Apply a new ISO inside manual exposure.  Holds the current
    /// `manualShutterSeconds` constant — the slider is "ISO at fixed
    /// shutter".  No-op outside `.manual` because
    /// `setExposureModeCustom` from auto would jump the exposure
    /// without inheritance bookkeeping; callers go through
    /// `enterManualExposure()` to land in manual.
    func setManualISO(_ iso: Float) {
        guard let device, exposureMode == .manual else { return }
        let clamped = min(
            max(iso, isoRange.lowerBound),
            isoRange.upperBound
        )
        do {
            try device.lockForConfiguration()
            let durCM = CMTime(
                seconds: manualShutterSeconds,
                preferredTimescale: 1_000_000
            )
            device.setExposureModeCustom(
                duration: durCM,
                iso: clamped,
                completionHandler: nil
            )
            device.unlockForConfiguration()
            manualISO = clamped
            manualInheritedFromAuto = false
        } catch {
            // Lock contention — drop the apply silently; the slider
            // will resync from `manualISO` on the next render.
        }
    }

    /// Apply a new shutter duration inside manual exposure.  Holds the
    /// current `manualISO` constant — the slider is "shutter at fixed
    /// ISO".  Same `.manual`-gate as `setManualISO(_:)`.
    func setManualShutter(_ seconds: Double) {
        guard let device, exposureMode == .manual else { return }
        let clamped = min(
            max(seconds, shutterDurationRange.lowerBound),
            shutterDurationRange.upperBound
        )
        do {
            try device.lockForConfiguration()
            let durCM = CMTime(
                seconds: clamped,
                preferredTimescale: 1_000_000
            )
            device.setExposureModeCustom(
                duration: durCM,
                iso: manualISO,
                completionHandler: nil
            )
            device.unlockForConfiguration()
            manualShutterSeconds = clamped
            manualInheritedFromAuto = false
        } catch {
            // Lock contention — same rationale as `setManualISO(_:)`.
        }
    }

    // MARK: - S1 stabilization

    /// S1 (2026-05-09): change the requested stabilization mode for
    /// the next run.  Allowed only while `.ready` so the value cannot
    /// change mid-recording (the capture UI also disables the toggle
    /// while recording, but the gate here keeps the session honest if
    /// a defensive caller missed the UI guard).  When the session is
    /// already configured we re-apply `preferredVideoStabilizationMode`
    /// inside a `beginConfiguration` / `commitConfiguration` window so
    /// the active mode flips before the next `start()` lands; pre-
    /// `prepare(lens:)` callers just stash the value so the first
    /// configure picks it up.
    ///
    /// `.on` requires the active format to support
    /// `cinematicExtendedEnhanced` — the M10 contract format index
    /// already does, but if a future format swap loses support the
    /// call surfaces `.stabilizationDowngraded(requested:, active:)`
    /// loudly instead of silently downshifting to a different mode.
    /// `.off` is universally supported by an AVCaptureDevice.Format,
    /// so the format-supported guard only fires on `.on`.
    @discardableResult
    func setRequestedStabilization(
        _ mode: FilmtoneRequestedStabilization
    ) -> Bool {
        guard case .ready = state else { return false }
        guard mode != requestedStabilization else { return true }
        let preferredMode = Self.avMode(for: mode)
        if mode == .on,
           let device,
           !device.activeFormat.isVideoStabilizationModeSupported(preferredMode) {
            state = .failed(.stabilizationDowngraded(
                requested: mode.canonicalModeName,
                active: "unsupported-on-format"
            ))
            return false
        }
        if let movieOutput,
           let connection = movieOutput.connection(with: .video),
           connection.isVideoStabilizationSupported {
            session.beginConfiguration()
            connection.preferredVideoStabilizationMode = preferredMode
            session.commitConfiguration()
        }
        requestedStabilization = mode
        return true
    }

    /// Caller-supplied external folder URL.  Caller owns the
    /// security-scoped lifetime; we only store the URL and adjust the
    /// resolved policy.  Pass `nil` to clear back to internal mode.
    func useExternalFolder(_ folderURL: URL?) {
        if let folderURL {
            storagePolicy = .externalSecurityScopedFolder(folderURL)
        } else {
            storagePolicy = .internalDocumentsCapped
        }
    }

    /// Begin recording.  Auto-stops at `durationLimit` for the resolved
    /// policy (10 s internal, 60 s external) so the user cannot blow
    /// past the verified ProRes thermal envelope.
    func start() async {
        guard case .ready = state else {
            assertionFailure("FilmtoneCaptureSession.start() called outside .ready (state=\(state))")
            return
        }

        captureId = UUID().uuidString.lowercased()
        do {
            let (dir, master, proxy) = try Self.makePackagePaths(
                captureId: captureId,
                storagePolicy: storagePolicy
            )
            self.packageDirURL = dir
            self.masterURL = master
            self.proxyURL = proxy
        } catch {
            let failure = FilmtoneCaptureFailure.packageDirCreationFailed(
                reason: error.localizedDescription
            )
            state = .failed(failure)
            return
        }

        guard let movieOutput, let masterURL else {
            state = .failed(.writerSetupFailed(stage: "INTERNAL", reason: "missing movieOutput / masterURL"))
            return
        }

        let delegate = MovieDelegate { [weak self] failure in
            Task { @MainActor [weak self] in
                self?.handleMovieFinished(failure: failure)
            }
        }
        self.recordingDelegate = delegate

        startedAtBootTime = ProcessInfo.processInfo.systemUptime
        recordedDurationSnapshot = 0
        pendingFailure = nil
        elapsedSeconds = 0

        let durationLimit = currentDurationLimit()
        state = .recording(startedAt: Date())
        startElapsedTimer()
        startAutoStop(after: durationLimit)

        movieOutput.startRecording(to: masterURL, recordingDelegate: delegate)
    }

    /// User-driven stop.  Idempotent; safe to call once recording has
    /// already auto-stopped.  Returns immediately; the capture view
    /// observes `state` for the resulting `.completed(_)` / `.failed(_)`.
    func stop() {
        guard case .recording = state else { return }
        state = .stopping
        cancelAutoStop()
        stopElapsedTimer()
        if let movieOutput {
            recordedDurationSnapshot = CMTimeGetSeconds(movieOutput.recordedDuration)
            movieOutput.stopRecording()
        }
    }

    /// S3 (2026-05-09): re-arm the live AVCaptureSession for another
    /// take after a `.completed` run.  The session graph (input,
    /// movieOutput, preview VDO, exposure / WB / focus / stab choices)
    /// is intentionally kept hot — only the per-run scratch state
    /// (master / proxy / package URLs, recording duration snapshot,
    /// pending failure) is cleared and `state` returns to `.ready` so
    /// the next `start()` can run.  Does nothing outside `.completed`.
    func rearm() {
        guard case .completed = state else { return }
        masterURL = nil
        proxyURL = nil
        packageDirURL = nil
        recordedDurationSnapshot = 0
        pendingFailure = nil
        elapsedSeconds = 0
        recordingDelegate = nil
        state = .ready
    }

    /// Tear down the session graph + release the preview layer.  Caller
    /// invokes on capture view dismiss.  Safe to call from any state.
    func teardown() async {
        cancelAutoStop()
        stopElapsedTimer()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                if session.isRunning { session.stopRunning() }
                continuation.resume()
            }
        }
        previewLayer = nil
        recordingDelegate = nil
        activeLens = nil
        previewVideoDataOutput = nil
        previewSampleDelegate = nil
        previewFrameSink.clear()
        // M12 / S12-C: drop tap state so a fresh prepare() starts on
        // continuous-auto rather than carrying a stale POI from the
        // previous lens / session.
        exposureBiasEV = 0
        lastFocusPointNormalized = nil
        lastMeteringPointNormalized = nil
        // M12 / S12-D: drop WB lock state for the same reason.
        whiteBalanceMode = .auto
        lockedWhiteBalanceGains = nil
        canLockWhiteBalance = true
        // M12 / S12-E: drop manual-exposure state so a fresh prepare
        // starts on continuous-auto exposure.  The ranges and 180°
        // marker get overwritten on the next prepare(lens:) anyway, so
        // we leave them holding their last values rather than reset to
        // the type defaults — anything that observes them between
        // teardown and the next prepare will at least see the previous
        // run's bounds, which are far closer to the next likely
        // bounds than the type defaults.
        exposureMode = .auto
        manualInheritedFromAuto = false
        if case .ready = state {
            state = .idle
        }
    }

    func currentDurationLimit() -> Double {
        switch storagePolicy {
        case .internalDocumentsCapped:
            return Self.internalDurationCapSeconds
        case .externalSecurityScopedFolder:
            return Self.externalDurationCapSeconds
        }
    }

    // MARK: - Preview VDO delegate (F2 sink writer)

    /// S8-F F2: pushes BGRA sample buffers into `previewFrameSink` as
    /// `CIImage` so the SwiftUI live-preview MTKView can pull them on
    /// the display tick.  Drops buffers with no image buffer (e.g.
    /// audio or sentinel frames — `AVCaptureVideoDataOutput` should
    /// not deliver these but we guard defensively).  F3 will reuse
    /// the same sink and apply the editor's grade chain at the
    /// reader side; this writer stays pass-through.
    private final class PreviewSampleDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let sink: FilmtonePreviewFrameSink

        init(sink: FilmtonePreviewFrameSink) {
            self.sink = sink
            super.init()
        }

        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            sink.push(CIImage(cvPixelBuffer: pixelBuffer))
        }
    }

    // MARK: - Movie delegate plumbing

    private final class MovieDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
        private let onFinish: (FilmtoneCaptureFailure?) -> Void
        init(onFinish: @escaping (FilmtoneCaptureFailure?) -> Void) {
            self.onFinish = onFinish
        }

        func fileOutput(_ output: AVCaptureFileOutput,
                        didStartRecordingTo fileURL: URL,
                        from connections: [AVCaptureConnection]) {
            // No-op: state already flipped to .recording before
            // startRecording() was called.
        }

        func fileOutput(_ output: AVCaptureFileOutput,
                        didFinishRecordingTo outputFileURL: URL,
                        from connections: [AVCaptureConnection],
                        error: Error?) {
            if let error {
                let nsError = error as NSError
                let succeeded = nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool
                if succeeded == true {
                    onFinish(nil)
                } else {
                    onFinish(.writerInterrupted(reason: nsError.localizedDescription))
                }
            } else {
                onFinish(nil)
            }
        }
    }

    private func handleMovieFinished(failure: FilmtoneCaptureFailure?) {
        recordingDelegate = nil

        if let failure {
            state = .failed(failure)
            return
        }

        guard let masterURL, let proxyURL, let packageDirURL else {
            state = .failed(.unexpected(reason: "missing URLs after movie finish"))
            return
        }

        // Verify master existence before kicking off proxy.
        guard FileManager.default.fileExists(atPath: masterURL.path) else {
            state = .failed(.masterFileMissing)
            return
        }

        // Verify post-recording invariants (Apple Log 2 + ProRes 422 HQ
        // + cinematicExtendedEnhanced).  Strict equality — any downgrade
        // surfaces as an explicit failure rather than silently producing
        // a master that violates the M5-A / M7 quality baseline.
        if let device {
            let observedRaw = device.activeColorSpace.rawValue
            if observedRaw != Self.appleLog2ColorSpaceRaw {
                state = .failed(.colorSpaceDowngraded(
                    expectedRaw: Self.appleLog2ColorSpaceRaw,
                    observedRaw: observedRaw
                ))
                return
            }
        }
        // S1 (2026-05-09): exact-mode gate against the run's
        // requested stabilization.  No fallback / silent degrade —
        // each request has exactly one acceptable observed mode, and
        // a missing AV connection is itself a loud failure rather
        // than an "assume requested" pass.
        let observedStabilizationName: String
        guard let movieOutput,
              let connection = movieOutput.connection(with: .video) else {
            state = .failed(.stabilizationDowngraded(
                requested: requestedStabilization.canonicalModeName,
                active: "connection-unavailable"
            ))
            return
        }
        let activeMode = connection.activeVideoStabilizationMode
        let expectedMode = Self.avMode(for: requestedStabilization)
        observedStabilizationName = Self.stabilizationDescription(activeMode)
        if activeMode != expectedMode {
            state = .failed(.stabilizationDowngraded(
                requested: requestedStabilization.canonicalModeName,
                active: observedStabilizationName
            ))
            return
        }

        // Verify the actual encoded master FourCC.  The connection-level
        // codec request can be silently honored by the encoder yet the
        // resulting file rewritten with a different subtype on certain
        // OS / thermal states, so we open the finalized .mov and read the
        // video track's CMFormatDescription mediaSubType.  ProRes 422 HQ
        // FourCC = 'apch' (kCMVideoCodecType_AppleProRes422HQ).
        let observedSubtype = Self.readVideoMediaSubtype(from: masterURL)
        if observedSubtype != kCMVideoCodecType_AppleProRes422HQ {
            state = .failed(.codecDowngraded(
                observed: Self.fourccString(observedSubtype)
            ))
            return
        }

        let durationLimit = currentDurationLimit()
        let recordedDuration = recordedDurationSnapshot
        // S1 (2026-05-09): parameters now reflect the owner's
        // requested stabilization for the run that just finished.
        // `.baseline(...)` keeps the codec / resolution / fps locked
        // and only swaps the stabilization slot.
        let parameters: FilmtoneCaptureParameters = .baseline(
            requestedStabilization: requestedStabilization
        )
        let observedStabilization = observedStabilizationName
        let storagePolicy = self.storagePolicy
        let captureId = self.captureId
        let lensRecord = self.activeLens?.toRecord()
        let selectedLook = self.pendingSelectedLook
        // M12 / S12-C+E: snapshot exposure / focus / metering at
        // record-stop time.  Auto-mode runs persist nil for the
        // manual-only fields; manual-mode runs persist the held ISO /
        // shutter / inheritance flag.  We always emit the record
        // (even at the all-default state) so the package distinguishes
        // "M12 capture, owner did not touch the controls" from "pre-M12
        // capture decoded from disk" — both decode shapes mattered for
        // S12-F's truth-gate verifier.
        let isManual = self.exposureMode == .manual
        let exposureControl = FilmtoneCaptureExposureControlRecord(
            mode: self.exposureMode.rawValue,
            biasEV: Double(self.exposureBiasEV),
            focusPointX: self.lastFocusPointNormalized.map { Double($0.x) },
            focusPointY: self.lastFocusPointNormalized.map { Double($0.y) },
            meteringPointX: self.lastMeteringPointNormalized.map { Double($0.x) },
            meteringPointY: self.lastMeteringPointNormalized.map { Double($0.y) },
            manualISO: isManual ? Double(self.manualISO) : nil,
            manualShutterDurationSeconds: isManual ? self.manualShutterSeconds : nil,
            inheritedFromAuto: isManual ? self.manualInheritedFromAuto : nil
        )
        // M12 / S12-D: WB lock state at record-stop.  Auto-mode
        // snapshots store the gains as nil (see record doc); locked
        // snapshots carry the sampled gains the device was holding.
        let whiteBalance: FilmtoneCaptureWhiteBalanceRecord
        switch self.whiteBalanceMode {
        case .auto:
            whiteBalance = FilmtoneCaptureWhiteBalanceRecord(
                mode: "auto",
                redGain: nil,
                greenGain: nil,
                blueGain: nil
            )
        case .locked:
            whiteBalance = FilmtoneCaptureWhiteBalanceRecord(
                mode: "locked",
                redGain: self.lockedWhiteBalanceGains.map { Double($0.redGain) },
                greenGain: self.lockedWhiteBalanceGains.map { Double($0.greenGain) },
                blueGain: self.lockedWhiteBalanceGains.map { Double($0.blueGain) }
            )
        }

        // Kick off proxy generation off-main; flip state when complete.
        Task.detached(priority: .userInitiated) { [weak self] in
            let proxyResult = await FilmtoneProxyGenerator.export(
                masterURL: masterURL,
                proxyURL: proxyURL
            )
            await MainActor.run {
                guard let self else { return }
                switch proxyResult {
                case .success:
                    // M14-B: snapshot a security-scoped bookmark for the
                    // master file URL when the storage policy is external.
                    // The capture surface still holds folder scope at this
                    // moment (releaseExternalFolderScope runs from the view's
                    // dismiss / .completed branch, which is downstream of
                    // this MainActor.run). Internal masters do not need a
                    // bookmark — the path lives in app Documents and
                    // remains reachable without scope.
                    let masterBookmark: Data?
                    switch storagePolicy {
                    case .externalSecurityScopedFolder:
                        masterBookmark = FilmtoneSecurityScopedBookmark.make(for: masterURL)
                    case .internalDocumentsCapped:
                        masterBookmark = nil
                    }
                    let pkg = FilmtoneCapturePackage(
                        captureId: captureId,
                        storagePolicy: storagePolicy,
                        masterURL: masterURL,
                        proxyURL: proxyURL,
                        packageDirURL: packageDirURL,
                        durationLimitSeconds: durationLimit,
                        recordedDurationSeconds: recordedDuration,
                        parameters: parameters,
                        lens: lensRecord,
                        selectedLook: selectedLook,
                        exposureControl: exposureControl,
                        whiteBalance: whiteBalance,
                        masterBookmark: masterBookmark,
                        observedStabilization: observedStabilization
                    )
                    // Master/proxy linkage is the M10 deliverable; if we
                    // can't write `capture-package.json` next to the
                    // proxy, the relaunch reconnect path is silently
                    // broken.  Surface as a loud failure rather than
                    // letting the editor receive a .completed state with
                    // no on-disk linkage to back it.
                    guard let writtenJSONURL = FilmtoneCapturePackagePersistence
                        .write(package: pkg),
                        FileManager.default.fileExists(atPath: writtenJSONURL.path) else {
                        self.state = .failed(
                            .packagePersistenceFailed(
                                reason: "capture-package.json write failed at \(packageDirURL.path)"
                            )
                        )
                        return
                    }
                    self.state = .completed(pkg)
                case .failure(let reason):
                    self.state = .failed(.proxyExportFailed(reason: reason))
                }
            }
        }
    }

    /// Reads the first video track's CMFormatDescription mediaSubType
    /// (FourCC) from a finalized .mov.  Returns `0` if the asset has no
    /// readable video track / format description; the caller treats `0`
    /// as a downgrade since `apch` is the only acceptable subtype.
    private static func readVideoMediaSubtype(from url: URL) -> CMVideoCodecType {
        let asset = AVURLAsset(url: url)
        let tracks = asset.tracks(withMediaType: .video)
        guard let track = tracks.first else { return 0 }
        let descriptions = track.formatDescriptions
        guard let cm = descriptions.first else { return 0 }
        // formatDescriptions on AVAssetTrack is `[Any]` of CMFormatDescription
        // bridged from Obj-C; cast to the typed CMVideoFormatDescription.
        let fd = cm as! CMFormatDescription
        return CMFormatDescriptionGetMediaSubType(fd)
    }

    /// Pretty-print a FourCC for the failure banner (e.g., 0x68766331
    /// → "hvc1").  Returns "<unread>" on the sentinel `0`.
    private static func fourccString(_ code: CMVideoCodecType) -> String? {
        if code == 0 { return nil }
        let chars: [Character] = (0..<4).map { i in
            let byte = UInt8(truncatingIfNeeded: (UInt32(code) >> ((3 - i) * 8)) & 0xFF)
            return Character(UnicodeScalar(byte))
        }
        return String(chars)
    }

    /// S1 (2026-05-09): map the structured request onto the
    /// AVFoundation enum.  No fallback case — the enum is exhaustive
    /// over what S1 ships, and adding a third request mode is an
    /// active explicit decision (out of scope for S1).
    private static func avMode(
        for request: FilmtoneRequestedStabilization
    ) -> AVCaptureVideoStabilizationMode {
        switch request {
        case .on: return .cinematicExtendedEnhanced
        case .off: return .off
        }
    }

    /// Compact label for AVCaptureVideoStabilizationMode.  Used by the
    /// `.stabilizationDowngraded(requested:active:)` failure to give
    /// the owner a concrete signal (cinematic / standard / off / auto)
    /// instead of "<some integer>".
    private static func stabilizationDescription(_ mode: AVCaptureVideoStabilizationMode) -> String {
        switch mode {
        case .off: return "off"
        case .standard: return "standard"
        case .cinematic: return "cinematic"
        case .cinematicExtended: return "cinematicExtended"
        case .cinematicExtendedEnhanced: return "cinematicExtendedEnhanced"
        case .previewOptimized: return "previewOptimized"
        case .auto: return "auto"
        @unknown default: return "unknown(\(mode.rawValue))"
        }
    }

    // MARK: - Helpers

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard case .recording(let startedAt) = self.state else { return }
                self.elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
            }
        }
        elapsedTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func startAutoStop(after seconds: Double) {
        autoStopTask?.cancel()
        autoStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await MainActor.run {
                guard let self else { return }
                if case .recording = self.state {
                    self.stop()
                }
            }
        }
    }

    private func cancelAutoStop() {
        autoStopTask?.cancel()
        autoStopTask = nil
    }

    // MARK: - Package paths

    private static func makePackagePaths(
        captureId: String,
        storagePolicy: FilmtoneCaptureStoragePolicy
    ) throws -> (packageDir: URL, master: URL, proxy: URL) {
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let captures = caches.appendingPathComponent("Filmtone/captures", isDirectory: true)
        try FileManager.default.createDirectory(at: captures, withIntermediateDirectories: true)
        let packageDir = captures.appendingPathComponent("v2-capture-\(captureId)", isDirectory: true)
        try? FileManager.default.removeItem(at: packageDir)
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)
        let proxyURL = packageDir.appendingPathComponent("proxy.mov", isDirectory: false)

        let masterURL: URL
        switch storagePolicy {
        case .internalDocumentsCapped:
            masterURL = packageDir.appendingPathComponent("master.mov", isDirectory: false)
        case .externalSecurityScopedFolder(let folderURL):
            // Caller has already started security-scoped access on the
            // folder URL.  Filename includes the captureId so multiple
            // runs to the same folder do not collide.
            masterURL = folderURL.appendingPathComponent(
                "filmtone-master-\(captureId).mov",
                isDirectory: false
            )
        }
        return (packageDir, masterURL, proxyURL)
    }

    // MARK: - Permission

    private static func requestCameraPermission() async -> AVAuthorizationStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        }
        return status
    }
}

#endif
