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

    /// External-mode soft ceiling.  Matches `FilmtoneProductCapture.maxDurationSeconds`
    /// so internal sandbox writes do not blow past the verified ProRes
    /// thermal envelope.
    static let externalDurationCapSeconds: Double = 60.0

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
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .cinematicExtendedEnhanced
                }
                let supported = format.isVideoStabilizationModeSupported(.cinematicExtendedEnhanced)
                if !supported {
                    session.commitConfiguration()
                    let failure = FilmtoneCaptureFailure.stabilizationDowngraded(active: "unsupported-on-format")
                    state = .failed(failure)
                    throw failure
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
    func setExposureBias(_ ev: Float) {
        guard let device else { return }
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
    /// POI point.  M12 / S12-C only — caller has already converted from
    /// view-local tap coordinates via
    /// `previewLayer.captureDevicePointConverted(fromLayerPoint:)`.
    /// Both POIs land on the same point because the S12-A lock keeps
    /// tap-to-focus and tap-to-meter bound together in auto exposure;
    /// S12-E will split metering off when manual exposure lands.
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
            if device.isExposurePointOfInterestSupported,
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
        if let movieOutput,
           let connection = movieOutput.connection(with: .video) {
            let activeMode = connection.activeVideoStabilizationMode
            if activeMode != .cinematicExtendedEnhanced {
                state = .failed(.stabilizationDowngraded(
                    active: Self.stabilizationDescription(activeMode)
                ))
                return
            }
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
        let parameters: FilmtoneCaptureParameters = .baseline
        let storagePolicy = self.storagePolicy
        let captureId = self.captureId
        let lensRecord = self.activeLens?.toRecord()
        let selectedLook = self.pendingSelectedLook
        // M12 / S12-C: snapshot exposure / focus / metering at
        // record-stop time.  M12 is auto-only; S12-E will widen `mode`
        // and add the manual-only fields.  We always emit the record
        // (even at the all-default state) so the package distinguishes
        // "M12 capture, owner did not touch the controls" from "pre-M12
        // capture decoded from disk" — both decode shapes mattered for
        // S12-F's truth-gate verifier.
        let exposureControl = FilmtoneCaptureExposureControlRecord(
            mode: "auto",
            biasEV: Double(self.exposureBiasEV),
            focusPointX: self.lastFocusPointNormalized.map { Double($0.x) },
            focusPointY: self.lastFocusPointNormalized.map { Double($0.y) },
            meteringPointX: self.lastMeteringPointNormalized.map { Double($0.x) },
            meteringPointY: self.lastMeteringPointNormalized.map { Double($0.y) }
        )

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
                        exposureControl: exposureControl
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

    /// Compact label for AVCaptureVideoStabilizationMode.  Used by the
    /// `.stabilizationDowngraded(active:)` failure to give the owner a
    /// concrete signal (cinematic / standard / off / auto) instead of
    /// "<some integer>".
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
