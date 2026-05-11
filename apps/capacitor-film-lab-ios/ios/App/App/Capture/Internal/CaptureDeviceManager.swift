// Phase 4A: CaptureSession split — device + lens + format + exposure/focus/WB/manual exposure.
//
// Owns the AVCaptureDevice lifecycle, the device-side AVCaptureDeviceInput
// wiring, and the @Published state read by FilmtoneCaptureView for the
// top-bar exposure / focus / WB / manual exposure HUDs.  The AVCaptureSession,
// movieOutput, preview VDO, and preview layer remain on the facade
// (`FilmtoneCaptureSession`) so the AVFoundation session graph keeps a
// single owner per the active.md Queue / Ownership Rule.
//
// Configuration contract (`attach(lens:onto:format:appleLog2:lockedFPS:)`):
// the facade brackets the call with `session.beginConfiguration()` /
// `commitConfiguration()` and supplies a pre-validated lens + format pair
// (dimensions + colour-space contract checks already gated upstream).
// The device manager then owns: input creation, device lock-for-config,
// active format / colour-space / frame-duration pin, EV / focus / WB reset,
// and the format-derived range snapshots (EV / ISO / shutter / 180° marker
// / WB lock capability) that seed the M12 manual-exposure HUD.

import Foundation

#if os(iOS)

import AVFoundation
import Combine
import CoreMedia
import UIKit

@MainActor
final class CaptureDeviceManager: ObservableObject {

    enum WhiteBalanceMode: String, Equatable {
        case auto
        case locked
    }

    enum ExposureMode: String, Equatable {
        case auto
        case manual
    }

    // MARK: - Device-side @Published state

    @Published private(set) var exposureBiasEV: Float = 0
    @Published private(set) var exposureBiasRange: ClosedRange<Float> = -2...2
    @Published private(set) var lastFocusPointNormalized: CGPoint?
    @Published private(set) var lastMeteringPointNormalized: CGPoint?

    @Published private(set) var whiteBalanceMode: WhiteBalanceMode = .auto
    @Published private(set) var lockedWhiteBalanceGains: AVCaptureDevice.WhiteBalanceGains?
    @Published private(set) var canLockWhiteBalance: Bool = true

    @Published private(set) var exposureMode: ExposureMode = .auto
    @Published private(set) var manualISO: Float = 100
    @Published private(set) var manualShutterSeconds: Double = 1.0/48
    @Published private(set) var isoRange: ClosedRange<Float> = 100...3200
    @Published private(set) var shutterDurationRange: ClosedRange<Double> = (1.0/8000)...(1.0/24)
    @Published private(set) var shutterDuration180Degrees: Double?
    @Published private(set) var manualInheritedFromAuto: Bool = false

    // MARK: - Device handle

    private(set) var device: AVCaptureDevice?
    private(set) var activeLens: FilmtoneCaptureLens?

    // MARK: - Attach / detach

    /// Add the lens's AVCaptureDeviceInput to the supplied session, then
    /// device-lock and pin the active format, colour space, and frame
    /// duration.  Resets EV / focus / WB and snapshots the format-derived
    /// ranges so the M12 manual-exposure HUD has fresh bounds on every
    /// prepare / lens-swap.
    ///
    /// Caller is responsible for the surrounding
    /// `session.beginConfiguration()` /
    /// `commitConfiguration()` bracket and for input/output removal of
    /// any prior configuration.  This method throws
    /// `FilmtoneCaptureFailure.writerSetupFailed(stage:reason:)` when
    /// `canAddInput` rejects the input.  `lockForConfiguration()` failure
    /// surfaces as the underlying error (the facade re-wraps).
    func attach(
        lens: FilmtoneCaptureLens,
        onto session: AVCaptureSession,
        format: AVCaptureDevice.Format,
        appleLog2: AVCaptureColorSpace,
        lockedFPS: Double
    ) throws {
        let captureDevice = lens.device

        let input = try AVCaptureDeviceInput(device: captureDevice)
        guard session.canAddInput(input) else {
            throw FilmtoneCaptureFailure.writerSetupFailed(
                stage: "INPUT_ADD",
                reason: "session.canAddInput returned false"
            )
        }
        session.addInput(input)

        try captureDevice.lockForConfiguration()
        captureDevice.activeFormat = format
        captureDevice.activeColorSpace = appleLog2
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(lockedFPS))
        captureDevice.activeVideoMinFrameDuration = frameDuration
        captureDevice.activeVideoMaxFrameDuration = frameDuration
        // M12 / S12-C: reset EV bias + auto-exposure / auto-focus so a
        // lens swap (or first prepare) drops back to neutral.  The bias
        // setter is a no-op when the device cannot move off its current
        // target, but calling it inside the already-held configuration
        // lock is the cheapest correct way to re-zero across swaps
        // without a second lock cycle.
        captureDevice.setExposureTargetBias(0, completionHandler: nil)
        if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
            captureDevice.focusMode = .continuousAutoFocus
        }
        if captureDevice.isExposureModeSupported(.continuousAutoExposure) {
            captureDevice.exposureMode = .continuousAutoExposure
        }
        // M12 / S12-D: reset white balance to continuous-auto so a lens
        // swap drops a previously-locked WB.
        if captureDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        captureDevice.unlockForConfiguration()

        self.device = captureDevice
        self.activeLens = lens

        // Capture the device-reported bias range and intersect with the
        // M12 `[-2, +2]` cap so the slider exposes only the usable
        // subset.  iPhone wide / tele typically report ±8 EV at the
        // device level — we take the tighter of "device says it can"
        // and "M12 cap allows".
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

        // M12 / S12-E: snapshot ISO + shutter ranges from the active
        // format and pre-seed the manual-mode published values to the
        // 180° baseline.  enterManualExposure() will overwrite these
        // with live device readings on the toggle moment; the pre-seed
        // exists so a degenerate (e.g. mid-prepare) read of `manualISO`
        // / `manualShutterSeconds` before any toggle still returns
        // sensible numbers.
        let isoLower = format.minISO
        let isoUpper = format.maxISO
        self.isoRange = isoLower <= isoUpper
            ? isoLower...isoUpper
            : isoLower...isoLower
        let minDur = CMTimeGetSeconds(format.minExposureDuration)
        let maxDurFromFormat = CMTimeGetSeconds(format.maxExposureDuration)
        let cap24fps = 1.0 / lockedFPS
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

        // M12 / S12-D: snapshot WB lock capability per active device +
        // format.  All shipping lenses that have passed the Filmtone
        // contract should satisfy both predicates; the guard exists
        // for future hardware where a lens reports `.locked`
        // unsupported so the UI can disable Locked with a visible
        // reason rather than failing the apply silently.
        self.canLockWhiteBalance =
            captureDevice.isLockingWhiteBalanceWithCustomDeviceGainsSupported
            && captureDevice.isWhiteBalanceModeSupported(.locked)
        self.whiteBalanceMode = .auto
        self.lockedWhiteBalanceGains = nil
    }

    /// Drop the device handle and reset EV / focus / WB / manual
    /// exposure flags on teardown.  Ranges and seeds are left at their
    /// last values (per the M12 / S12-E rationale in the original
    /// teardown: anything that observes them between teardown and the
    /// next prepare sees the previous run's bounds, which are closer to
    /// the next likely bounds than the type defaults).
    func resetForTeardown() {
        device = nil
        activeLens = nil
        exposureBiasEV = 0
        lastFocusPointNormalized = nil
        lastMeteringPointNormalized = nil
        whiteBalanceMode = .auto
        lockedWhiteBalanceGains = nil
        canLockWhiteBalance = true
        exposureMode = .auto
        manualInheritedFromAuto = false
    }

    // MARK: - M12 / S12-C exposure / focus / metering

    /// Apply an EV bias to the active device.  Clamped at apply-time to
    /// `exposureBiasRange` so a slider that drifts past the cap (e.g.
    /// between a lens swap that narrowed the device range and the next
    /// slider repaint) does not push the device past what it will
    /// accept.  Best-effort: a `lockForConfiguration()` failure silently
    /// leaves the published value at its previous reading rather than
    /// fabricating a phantom apply — the slider snaps back on the next
    /// state observation.
    ///
    /// S12-E: no-op when `exposureMode == .manual`.  EV bias has no
    /// effect on a `setExposureModeCustom` exposure (the device-level
    /// bias does not feed into the locked ISO/shutter pair) and the
    /// view hides the slider in manual mode anyway.
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
            // Lock contention — drop the apply silently; the slider
            // will resync from `exposureBiasEV` on the next render.
        }
    }

    /// Reset EV bias to 0.  Wired to the slider's tap-and-hold gesture
    /// (S12-A lock).
    func resetExposureBias() {
        setExposureBias(0)
    }

    /// Apply tap-to-focus + tap-to-meter at a normalized AVCaptureDevice
    /// POI point.
    ///
    /// S12-C / S12-E: tap-to-focus runs in both auto and manual exposure
    /// (focusing without re-metering is a routine ask).  Tap-to-meter
    /// only runs when `exposureMode == .auto`; manual exposure
    /// deliberately skips the metering POI because the
    /// `setExposureModeCustom` lock holds ISO/shutter regardless of
    /// what the device's auto-meter would compute.
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
            // Lock contention — drop the tap silently.
        }
    }

    // MARK: - M12 / S12-D white balance

    /// Hold WB at the device's current `deviceWhiteBalanceGains`.  No-op
    /// when the active lens did not report lock support at attach time
    /// — the UI gates the tap on `canLockWhiteBalance`, but the guard
    /// here keeps the manager safe to call from any caller that did not
    /// consult the gate.
    func lockWhiteBalance() {
        guard let device, canLockWhiteBalance else { return }
        do {
            try device.lockForConfiguration()
            let currentGains = device.deviceWhiteBalanceGains
            // The device must accept these gains as "in range" for
            // `setWhiteBalanceModeLocked(with:)` to succeed; clamp to
            // `[1.0, maxWhiteBalanceGain]` per channel because the
            // sampled `deviceWhiteBalanceGains` can theoretically sit
            // at exactly `maxWhiteBalanceGain` on edge-case exposures,
            // and the setter rejects anything above.
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
            // Lock contention — leave state on .auto.
        }
    }

    /// Return WB to continuous-auto.  Idempotent.
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

    /// Switch to manual exposure by inheriting the device's current auto
    /// ISO + shutter duration.  Clamped to the format-derived `isoRange`
    /// / `shutterDurationRange` so a transient auto reading just outside
    /// the slider bounds does not push the device into a setter that
    /// `setExposureModeCustom` would reject.  Idempotent: a second call
    /// while already in `.manual` is a no-op.
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
            // Lock contention — leave on auto.
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
    /// `manualShutterSeconds` constant.  No-op outside `.manual`.
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
            // Lock contention — drop the apply silently.
        }
    }

    /// Apply a new shutter duration inside manual exposure.  Holds the
    /// current `manualISO` constant.
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
}

#endif
