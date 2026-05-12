// Filmtone V2 native camera capture — session pipeline facade (M10, Phase 4A).
//
// Single-camera AVCaptureSession with AVCaptureMovieFileOutput driving
// ProRes 422 HQ Apple Log 2 at the FilmtoneProductCapture-locked format
// per-lens-resolved index + cinematicExtendedEnhanced stabilization.
// Manual start / stop, variable duration capped by the resolved storage
// policy.  Master output routes to the security-scoped external folder
// when one is selected; otherwise to the local package directory under
// Caches.
//
// Quality invariants are pinned to the `FilmtoneProductCapture` baseline
// validated in M5-A / M7 owner walks.  This file mirrors the same
// stop-condition rubric (stabilization-active-mode-off, Apple Log 2
// downgrade, ProRes downgrade) and lifts them to the typed
// `FilmtoneCaptureFailure` enum so the capture view can route specific
// failures to specific affordances.
//
// Phase 4A split: the facade owns the AVCaptureSession + sessionQueue +
// movieOutput + preview VDO + preview layer + rotation coordinator +
// pending Look chip; the three `Capture/Internal/` collaborators own:
//
//   * `CaptureDeviceManager` — device + lens, EV / focus / WB / manual
//     exposure state and setters, format-derived range snapshots.
//   * `RecordingStateController` — state machine, elapsed timer, auto
//     stop, storage policy + pressure monitor, requested stabilization,
//     per-run scratch state (capture id, package URLs, duration
//     snapshot, recording capture rotation).
//   * `CapturePackageAssembler` — post-record invariant gates (color
//     space / stabilization / rotation / codec FourCC), package
//     construction, security-scoped bookmark, persistence write,
//     proxy export orchestration.

import Foundation

#if os(iOS)

import AVFoundation
import Combine
import CoreMedia
import UIKit
import QuartzCore

struct FilmtoneCaptureStoragePressure: Equatable {
    enum Level: Equatable {
        case warning
        case critical
        case unreadable
    }

    let level: Level
    let availableBytes: Int64?
    let projectedNeedBytes: Int64?
    let secondsRemaining: Double
    let measuredRate: Bool
}

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
    // `FilmtoneCaptureLensCatalog` enumerates capture lenses and
    // resolves a contract-matching format index per device.
    private static let lockedWidth: Int32 = 3840
    private static let lockedHeight: Int32 = 2160
    private static let lockedFPS: Double = 24
    private static let lockedRotationAngle: CGFloat = 90
    private static let appleLog2ColorSpaceRaw: Int = 4

    /// Internal-mode product cap.  Forwarded from
    /// `RecordingStateController` to preserve the existing
    /// `FilmtoneCaptureSession.internalDurationCapSeconds` qualified
    /// path for any external caller that references it.
    static let internalDurationCapSeconds: Double = RecordingStateController.internalDurationCapSeconds
    static let externalDurationCapSeconds: Double = RecordingStateController.externalDurationCapSeconds

    // MARK: - Public type aliases
    //
    // Phase 4A: the enums moved to the collaborators that primarily own
    // them.  These aliases preserve the qualified path used by the
    // view files (`FilmtoneCaptureSession.SessionState`,
    // `FilmtoneCaptureSession.WhiteBalanceMode`,
    // `FilmtoneCaptureSession.ExposureMode`) so SwiftUI view code did
    // not need to change in this bundle.

    typealias SessionState = RecordingStateController.SessionState
    typealias WhiteBalanceMode = CaptureDeviceManager.WhiteBalanceMode
    typealias ExposureMode = CaptureDeviceManager.ExposureMode

    // MARK: - Collaborators

    let recordingState = RecordingStateController()
    let deviceManager = CaptureDeviceManager()
    private(set) lazy var packageAssembler = CapturePackageAssembler(stateController: recordingState)
    private var collaboratorCancellables: Set<AnyCancellable> = []

    // MARK: - Public @Published forwards
    //
    // SwiftUI observation: collaborator changes are bridged into this
    // facade's `objectWillChange` so a single `@StateObject var session`
    // declaration in `FilmtoneCaptureView` continues to repaint on any
    // state mutation.  Concrete property values are forwarded as
    // computed reads from the collaborator that owns the storage.

    /// Owner-visible session state.  The capture view reads this on
    /// every transition.  Storage on `RecordingStateController`.
    var state: SessionState { recordingState.state }

    /// Live elapsed seconds while `state == .recording`.
    var elapsedSeconds: Double { recordingState.elapsedSeconds }

    /// Storage policy resolved at start-of-run.  Storage on
    /// `RecordingStateController`.
    var storagePolicy: FilmtoneCaptureStoragePolicy { recordingState.storagePolicy }

    /// Recording-time capacity warning for the volume receiving the
    /// active master.  Storage on `RecordingStateController`.
    var storagePressure: FilmtoneCaptureStoragePressure? { recordingState.storagePressure }

    /// S1: owner-requested stabilization for the next run.  Storage on
    /// `RecordingStateController`; AV reapply lives on the facade
    /// (`setRequestedStabilization(_:)`).
    var requestedStabilization: FilmtoneRequestedStabilization { recordingState.requestedStabilization }

    /// S6: current preview/capture rotation angles supplied by
    /// `AVCaptureDevice.RotationCoordinator`.  Stayed on the facade in
    /// Phase 4A because the rotation apply path touches both
    /// `previewLayer` (facade-owned) and `movieOutput.connection`
    /// (facade-owned).
    @Published private(set) var orientationState: FilmtoneCaptureOrientationState = .portraitPinned

    // Exposure / focus / WB / manual exposure — storage on
    // `CaptureDeviceManager`.
    var exposureBiasEV: Float { deviceManager.exposureBiasEV }
    var exposureBiasRange: ClosedRange<Float> { deviceManager.exposureBiasRange }
    var lastFocusPointNormalized: CGPoint? { deviceManager.lastFocusPointNormalized }
    var lastMeteringPointNormalized: CGPoint? { deviceManager.lastMeteringPointNormalized }
    var whiteBalanceMode: WhiteBalanceMode { deviceManager.whiteBalanceMode }
    var lockedWhiteBalanceGains: AVCaptureDevice.WhiteBalanceGains? { deviceManager.lockedWhiteBalanceGains }
    var canLockWhiteBalance: Bool { deviceManager.canLockWhiteBalance }
    var exposureMode: ExposureMode { deviceManager.exposureMode }
    var manualISO: Float { deviceManager.manualISO }
    var manualShutterSeconds: Double { deviceManager.manualShutterSeconds }
    var isoRange: ClosedRange<Float> { deviceManager.isoRange }
    var shutterDurationRange: ClosedRange<Double> { deviceManager.shutterDurationRange }
    var shutterDuration180Degrees: Double? { deviceManager.shutterDuration180Degrees }
    var manualInheritedFromAuto: Bool { deviceManager.manualInheritedFromAuto }

    /// Preview layer the capture view embeds via UIViewRepresentable.
    /// `nil` until `prepare()` succeeds.
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    /// True when `prepare(lens:)` successfully attached the preview VDO.
    /// Read by `FilmtoneCaptureView` to decide whether to render the
    /// Metal-backed live preview or fall back to the raw
    /// `AVCaptureVideoPreviewLayer`.
    var hasLivePreview: Bool { previewVideoDataOutput != nil }

    @Published private(set) var livePreviewTelemetry: FilmtoneLivePreviewTelemetry = .unavailable

    // MARK: - AVFoundation graph (facade-owned)

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "filmtone.capture.session.queue")

    private var movieOutput: AVCaptureMovieFileOutput?
    private var recordingDelegate: MovieDelegate?

    /// S8-F / S5 preview-only VDO.  The record path stays on
    /// `movieOutput` (ProRes 422 HQ + Apple Log 2 + requested
    /// stabilization); this output is only a monitor source for the
    /// live preview renderer.
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

    // MARK: - Rotation coordinator

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservations: [NSKeyValueObservation] = []
    private var latestPreviewRotation: FilmtoneCaptureVideoRotation = .portraitPinned
    private var latestCaptureRotation: FilmtoneCaptureVideoRotation = .portraitPinned

    // MARK: - Pending Look chip / Custom LUT

    /// M11 / S11-D: capture-time Look chip recorded with the run.
    /// Set by `FilmtoneCaptureView` whenever the chip selection changes
    /// (and seeded once on view appear) so the `FilmtoneCapturePackage`
    /// built at record-stop time carries `selectedLook` without the
    /// session knowing about chip UI.  `nil` = Filmtone default chip
    /// (no Look) or pre-M11 callers.
    private var pendingSelectedLook: FilmtoneSelectedLookRecord?
    /// S7: user-imported creative LUT selected in the capture LOOK
    /// sheet.  Mutually exclusive with `pendingSelectedLook` in normal
    /// UI flows; kept as a separate record because built-in Looks and
    /// library LUTs have different durable identities.
    private var pendingCustomLut: FilmtoneCaptureCustomLutRecord?
    /// Package-local `.lutbin` payload paired with `pendingCustomLut`.
    /// This is what lets an iOS capture package render the same user LUT on
    /// Desktop without sharing the iOS app's library store.
    private var pendingCustomLutPayload: FilmtoneCaptureCustomLutPayload?

    // MARK: - Init

    override init() {
        super.init()
        wireCollaboratorObservers()
    }

    private func wireCollaboratorObservers() {
        // Collaborators publish `@Published` mutations independently;
        // bridge their `objectWillChange` into this facade so a single
        // `@StateObject var session` declaration in
        // `FilmtoneCaptureView` repaints on any collaborator-side
        // change.  Same pattern as Phase 3A / 3B / 3C in the editor
        // refactor.
        recordingState.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &collaboratorCancellables)
        deviceManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &collaboratorCancellables)
    }

    // MARK: - Preview VDO config

    private static func configurePreviewVideoDataOutput(
        _ output: AVCaptureVideoDataOutput
    ) {
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [:]
        if #available(iOS 13.0, *) {
            output.automaticallyConfiguresOutputBufferDimensions = false
            output.deliversPreviewSizedOutputBuffers = true
        }
    }

    private static func logPreviewVideoOutputConfiguration(
        _ output: AVCaptureVideoDataOutput
    ) {
        #if DEBUG
        let settings = output.videoSettings ?? [:]
        let previewSized: String
        if #available(iOS 13.0, *) {
            previewSized = output.deliversPreviewSizedOutputBuffers ? "Y" : "N"
        } else {
            previewSized = "unavailable"
        }
        NSLog(
            "[S5][LivePreview] VDO configured videoSettings=%@ previewSized=%@ discardsLate=%@",
            String(describing: settings),
            previewSized,
            output.alwaysDiscardsLateVideoFrames ? "Y" : "N"
        )
        #endif
    }

    private func setLivePreviewTelemetry(_ telemetry: FilmtoneLivePreviewTelemetry) {
        guard livePreviewTelemetry != telemetry else { return }
        livePreviewTelemetry = telemetry
        #if DEBUG
        NSLog("[S5][LivePreview] VDO telemetry %@", telemetry.diagnosticSummary)
        #endif
    }

    // MARK: - Setup

    /// Configures the session graph + acquires the preview layer.  Must
    /// be called once before `start()`.  Throws on permission denial,
    /// device lookup failure, or format-lock mismatch — the capture view
    /// surfaces these as a failure banner instead of mounting a dead
    /// preview.
    func prepare(lens: FilmtoneCaptureLens) async throws {
        recordingState.setState(.configuring)

        let permissions = await CaptureSessionPermissions.requestCapturePermissions()
        guard permissions.video == .authorized else {
            let failure: FilmtoneCaptureFailure = .permissionDenied
            recordingState.setState(.failed(failure))
            throw failure
        }
        guard permissions.audio == .authorized else {
            let failure: FilmtoneCaptureFailure = .microphonePermissionDenied
            recordingState.setState(.failed(failure))
            throw failure
        }

        let captureDevice = lens.device

        guard captureDevice.formats.indices.contains(lens.formatIndex) else {
            let failure = FilmtoneCaptureFailure.formatLockMismatch(
                reason: "lens \(lens.displayName) (\(lens.deviceTypeRaw)) formats has \(captureDevice.formats.count) entries, need index \(lens.formatIndex)"
            )
            recordingState.setState(.failed(failure))
            throw failure
        }
        let format = captureDevice.formats[lens.formatIndex]
        let supportedRaw = format.supportedColorSpaces.map { $0.rawValue }
        guard supportedRaw.contains(Self.appleLog2ColorSpaceRaw) else {
            let failure = FilmtoneCaptureFailure.formatLockMismatch(
                reason: "lens \(lens.displayName) formats[\(lens.formatIndex)].supportedColorSpaces missing appleLog2 raw=4; have \(supportedRaw)"
            )
            recordingState.setState(.failed(failure))
            throw failure
        }
        let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        guard dim.width == Self.lockedWidth, dim.height == Self.lockedHeight else {
            let failure = FilmtoneCaptureFailure.formatLockMismatch(
                reason: "lens \(lens.displayName) formats[\(lens.formatIndex)] dims \(dim.width)x\(dim.height); need \(Self.lockedWidth)x\(Self.lockedHeight)"
            )
            recordingState.setState(.failed(failure))
            throw failure
        }
        guard let appleLog2 = AVCaptureColorSpace(rawValue: Self.appleLog2ColorSpaceRaw) else {
            let failure = FilmtoneCaptureFailure.appleLog2Unavailable
            recordingState.setState(.failed(failure))
            throw failure
        }

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

            try deviceManager.attach(
                lens: lens,
                onto: session,
                format: format,
                appleLog2: appleLog2,
                lockedFPS: Self.lockedFPS
            )

            do {
                try CaptureAudioSessionGraph.addMicrophoneInput(to: session)
            } catch let failure as FilmtoneCaptureFailure {
                session.commitConfiguration()
                throw failure
            }

            let output = AVCaptureMovieFileOutput()
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                let failure = FilmtoneCaptureFailure.writerSetupFailed(
                    stage: "MOVIE_OUTPUT_ADD", reason: "session.canAddOutput returned false"
                )
                recordingState.setState(.failed(failure))
                throw failure
            }
            session.addOutput(output)
            self.movieOutput = output

            do {
                try CaptureAudioSessionGraph.validateAudioConnection(on: output)
            } catch let failure as FilmtoneCaptureFailure {
                session.commitConfiguration()
                throw failure
            }

            if let connection = output.connection(with: .video) {
                let availableCodecs = output.availableVideoCodecTypes.map { $0.rawValue }
                guard availableCodecs.contains(AVVideoCodecType.proRes422HQ.rawValue) else {
                    session.commitConfiguration()
                    let failure = FilmtoneCaptureFailure.writerSetupFailed(
                        stage: "PRORES_AVAIL",
                        reason: "AVVideoCodecType.proRes422HQ not in availableVideoCodecTypes: \(availableCodecs)"
                    )
                    recordingState.setState(.failed(failure))
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
                let requested = recordingState.requestedStabilization
                let preferredMode = CapturePackageAssembler.avMode(for: requested)
                if requested == .on,
                   !format.isVideoStabilizationModeSupported(preferredMode) {
                    session.commitConfiguration()
                    let failure = FilmtoneCaptureFailure.stabilizationDowngraded(
                        requested: requested.canonicalModeName,
                        active: "unsupported-on-format"
                    )
                    recordingState.setState(.failed(failure))
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
            Self.configurePreviewVideoDataOutput(vdo)
            if session.canAddOutput(vdo) {
                session.addOutput(vdo)
                let delegate = PreviewSampleDelegate(
                    sink: previewFrameSink,
                    onTelemetry: { [weak self] telemetry in
                        Task { @MainActor in
                            self?.setLivePreviewTelemetry(telemetry)
                        }
                    }
                )
                vdo.setSampleBufferDelegate(delegate, queue: previewSampleQueue)
                if let vdoConnection = vdo.connection(with: .video) {
                    if vdoConnection.isVideoRotationAngleSupported(Self.lockedRotationAngle) {
                        vdoConnection.videoRotationAngle = Self.lockedRotationAngle
                    }
                    if vdoConnection.isVideoStabilizationSupported {
                        vdoConnection.preferredVideoStabilizationMode = .off
                    }
                }
                self.previewVideoDataOutput = vdo
                self.previewSampleDelegate = delegate
                Self.logPreviewVideoOutputConfiguration(vdo)
            } else {
                self.previewVideoDataOutput = nil
                self.previewSampleDelegate = nil
                self.livePreviewTelemetry = .unavailable
            }

            session.commitConfiguration()
        } catch let failure as FilmtoneCaptureFailure {
            recordingState.setState(.failed(failure))
            throw failure
        } catch {
            let failure = FilmtoneCaptureFailure.unexpected(reason: error.localizedDescription)
            recordingState.setState(.failed(failure))
            throw failure
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        if let connection = preview.connection,
           connection.isVideoRotationAngleSupported(Self.lockedRotationAngle) {
            connection.videoRotationAngle = Self.lockedRotationAngle
        }
        self.previewLayer = preview
        pinOrientationToPortrait()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }

        recordingState.setState(.ready)
    }

    /// View-side setter for the capture-time Look chip.  Idempotent;
    /// safe to call before `prepare(lens:)` and at any point during
    /// `.ready` / `.recording` (the value is only consumed at
    /// record-stop time when the package is built).
    func setSelectedLook(_ record: FilmtoneSelectedLookRecord?) {
        pendingSelectedLook = record
    }

    func setCustomLut(
        _ record: FilmtoneCaptureCustomLutRecord?,
        payload: FilmtoneCaptureCustomLutPayload?
    ) {
        pendingCustomLut = record
        pendingCustomLutPayload = record == nil ? nil : payload
    }

    // MARK: - M12 / S12-C / D / E exposure / focus / WB / manual forwards

    func setExposureBias(_ ev: Float) { deviceManager.setExposureBias(ev) }
    func resetExposureBias() { deviceManager.resetExposureBias() }
    func applyTapToFocusAndMeter(devicePoint: CGPoint) { deviceManager.applyTapToFocusAndMeter(devicePoint: devicePoint) }
    func lockWhiteBalance() { deviceManager.lockWhiteBalance() }
    func unlockWhiteBalance() { deviceManager.unlockWhiteBalance() }
    func enterManualExposure() { deviceManager.enterManualExposure() }
    func exitManualExposure() { deviceManager.exitManualExposure() }
    func setManualISO(_ iso: Float) { deviceManager.setManualISO(iso) }
    func setManualShutter(_ seconds: Double) { deviceManager.setManualShutter(seconds) }

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
        guard case .ready = recordingState.state else { return false }
        guard mode != recordingState.requestedStabilization else { return true }
        let preferredMode = CapturePackageAssembler.avMode(for: mode)
        if mode == .on,
           let device = deviceManager.device,
           !device.activeFormat.isVideoStabilizationModeSupported(preferredMode) {
            recordingState.setState(.failed(.stabilizationDowngraded(
                requested: mode.canonicalModeName,
                active: "unsupported-on-format"
            )))
            return false
        }
        if let movieOutput,
           let connection = movieOutput.connection(with: .video),
           connection.isVideoStabilizationSupported {
            session.beginConfiguration()
            connection.preferredVideoStabilizationMode = preferredMode
            session.commitConfiguration()
        }
        recordingState.setRequestedStabilization(mode)
        return true
    }

    /// Caller-supplied external folder URL.  Caller owns the
    /// security-scoped lifetime; we only store the URL and adjust the
    /// resolved policy.  Pass `nil` to clear back to internal mode.
    func useExternalFolder(_ folderURL: URL?) {
        recordingState.useExternalFolder(folderURL)
    }

    // MARK: - Recording lifecycle

    /// Begin recording.  Auto-stops at `durationLimit` for the resolved
    /// policy so the owner cannot blow past the current product
    /// ceiling.
    func start() async {
        guard case .ready = recordingState.state else {
            assertionFailure("FilmtoneCaptureSession.start() called outside .ready (state=\(recordingState.state))")
            return
        }

        let prepared: (master: URL, proxy: URL, packageDir: URL, captureId: String, durationLimit: Double)
        do {
            prepared = try recordingState.prepareForStart(
                makePaths: CapturePackageAssembler.makePackagePaths
            )
        } catch {
            let failure = FilmtoneCaptureFailure.packageDirCreationFailed(
                reason: error.localizedDescription
            )
            recordingState.setState(.failed(failure))
            return
        }

        guard let movieOutput else {
            recordingState.setState(.failed(.writerSetupFailed(stage: "INTERNAL", reason: "missing movieOutput / masterURL")))
            return
        }

        let delegate = MovieDelegate { [weak self] failure in
            Task { @MainActor [weak self] in
                self?.handleMovieFinished(failure: failure)
            }
        }
        self.recordingDelegate = delegate

        let captureRotation = FilmtoneCaptureVideoRotation.portraitPinned
        guard applyMovieRotation(captureRotation, failOnUnsupported: true) else {
            recordingState.setState(.failed(.captureRotationRejected(
                requested: captureRotation.degrees,
                active: currentMovieRotation()?.degrees
            )))
            return
        }
        recordingState.setRecordingCaptureRotation(captureRotation)
        orientationState = .portraitPinned

        recordingState.beginRecording(at: Date())
        recordingState.startAutoStop(after: prepared.durationLimit) { [weak self] in
            self?.stop()
        }
        recordingState.startStoragePressureMonitor(
            volumeURL: prepared.master.deletingLastPathComponent(),
            masterURL: prepared.master,
            durationLimit: prepared.durationLimit
        )

        movieOutput.startRecording(to: prepared.master, recordingDelegate: delegate)
    }

    /// User-driven stop.  Idempotent; safe to call once recording has
    /// already auto-stopped.  Returns immediately; the capture view
    /// observes `state` for the resulting `.completed(_)` / `.failed(_)`.
    func stop() {
        guard case .recording = recordingState.state else { return }
        let recordedDuration = movieOutput.map { CMTimeGetSeconds($0.recordedDuration) } ?? 0
        recordingState.markStopping(recordedDuration: recordedDuration)
        movieOutput?.stopRecording()
    }

    /// S3 (2026-05-09): re-arm the live AVCaptureSession for another
    /// take after a `.completed` run.  The session graph (input,
    /// movieOutput, preview VDO, exposure / WB / focus / stab choices)
    /// is intentionally kept hot — only the per-run scratch state
    /// (master / proxy / package URLs, recording duration snapshot,
    /// pending failure) is cleared and `state` returns to `.ready` so
    /// the next `start()` can run.  Does nothing outside `.completed`.
    func rearm() {
        guard case .completed = recordingState.state else { return }
        recordingDelegate = nil
        recordingState.resetForRearm()
        pinOrientationToPortrait()
    }

    /// Tear down the session graph + release the preview layer.  Caller
    /// invokes on capture view dismiss.  Safe to call from any state.
    func teardown() async {
        recordingState.resetForTeardown()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                if session.isRunning { session.stopRunning() }
                continuation.resume()
            }
        }
        previewLayer = nil
        recordingDelegate = nil
        previewVideoDataOutput = nil
        previewSampleDelegate = nil
        livePreviewTelemetry = .unavailable
        clearRotationCoordinator()
        previewFrameSink.clear()
        deviceManager.resetForTeardown()
    }

    func currentDurationLimit() -> Double {
        recordingState.currentDurationLimit()
    }

    // MARK: - Capture orientation

    private func pinOrientationToPortrait() {
        clearRotationCoordinator(resetState: false)
        latestPreviewRotation = .portraitPinned
        latestCaptureRotation = .portraitPinned
        recordingState.setRecordingCaptureRotation(nil)
        orientationState = .portraitPinned
        applyPreviewRotation(.portraitPinned)
        _ = applyMovieRotation(.portraitPinned, failOnUnsupported: false)
    }

    private var isOrientationFrozenForRecording: Bool {
        switch recordingState.state {
        case .recording, .stopping:
            return true
        default:
            return false
        }
    }

    private func clearRotationCoordinator(resetState: Bool = true) {
        for observation in rotationObservations {
            observation.invalidate()
        }
        rotationObservations.removeAll()
        rotationCoordinator = nil
        if resetState {
            latestPreviewRotation = .portraitPinned
            latestCaptureRotation = .portraitPinned
            recordingState.setRecordingCaptureRotation(nil)
            orientationState = .portraitPinned
        }
    }

    private func applyPreviewRotation(_ rotation: FilmtoneCaptureVideoRotation) {
        if let connection = previewLayer?.connection {
            apply(rotation, to: connection, label: "previewLayer")
        }
    }

    @discardableResult
    private func applyMovieRotation(
        _ rotation: FilmtoneCaptureVideoRotation,
        failOnUnsupported: Bool
    ) -> Bool {
        guard let connection = movieOutput?.connection(with: .video) else {
            return !failOnUnsupported
        }
        return apply(rotation, to: connection, label: "movieOutput")
    }

    private func currentMovieRotation() -> FilmtoneCaptureVideoRotation? {
        guard let connection = movieOutput?.connection(with: .video) else {
            return nil
        }
        return FilmtoneCaptureVideoRotation(degrees: connection.videoRotationAngle)
    }

    @discardableResult
    private func apply(
        _ rotation: FilmtoneCaptureVideoRotation,
        to connection: AVCaptureConnection,
        label: String
    ) -> Bool {
        let angle = rotation.avFoundationAngle
        guard connection.isVideoRotationAngleSupported(angle) else {
            NSLog(
                "[S6][Orientation] %@ rejected videoRotationAngle=%.3f",
                label,
                rotation.degrees
            )
            return false
        }
        connection.videoRotationAngle = angle
        return true
    }

    // MARK: - Preview VDO delegate (monitor sink writer)

    /// S5: pushes preview-only VDO sample buffers into `previewFrameSink`.
    /// The delegate owns no grading and no persistence; it only converts the
    /// current monitor buffer to `CIImage`, reports the actual buffer format
    /// once it is known, and lets the sink drop stale frames under load.
    private final class PreviewSampleDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        private let sink: FilmtonePreviewFrameSink
        private let onTelemetry: (FilmtoneLivePreviewTelemetry) -> Void
        private var lastTelemetry: FilmtoneLivePreviewTelemetry?

        init(
            sink: FilmtonePreviewFrameSink,
            onTelemetry: @escaping (FilmtoneLivePreviewTelemetry) -> Void
        ) {
            self.sink = sink
            self.onTelemetry = onTelemetry
            super.init()
        }

        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            reportTelemetryIfNeeded(
                output: output,
                pixelBuffer: pixelBuffer,
                connection: connection
            )
            sink.push(CIImage(cvPixelBuffer: pixelBuffer))
        }

        private func reportTelemetryIfNeeded(
            output: AVCaptureOutput,
            pixelBuffer: CVPixelBuffer,
            connection: AVCaptureConnection
        ) {
            let vdo = output as? AVCaptureVideoDataOutput
            let previewSized: Bool
            if #available(iOS 13.0, *) {
                previewSized = vdo?.deliversPreviewSizedOutputBuffers ?? false
            } else {
                previewSized = false
            }
            let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
            let telemetry = FilmtoneLivePreviewTelemetry(
                pixelFormat: CapturePackageAssembler.fourccString(pixelFormat) ?? "0x\(String(pixelFormat, radix: 16))",
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer),
                deliversPreviewSizedBuffers: previewSized,
                nativeVideoSettingsRequested: vdo?.videoSettings.isEmpty ?? false,
                activeStabilization: CapturePackageAssembler.stabilizationDescription(
                    connection.activeVideoStabilizationMode
                )
            )
            guard telemetry != lastTelemetry else { return }
            lastTelemetry = telemetry
            onTelemetry(telemetry)
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
        let exposureSnapshot = CapturePackageAssembler.ExposureSnapshot(
            mode: deviceManager.exposureMode,
            biasEV: deviceManager.exposureBiasEV,
            focusPoint: deviceManager.lastFocusPointNormalized,
            meteringPoint: deviceManager.lastMeteringPointNormalized,
            manualISO: deviceManager.manualISO,
            manualShutterSeconds: deviceManager.manualShutterSeconds,
            manualInheritedFromAuto: deviceManager.manualInheritedFromAuto
        )
        let whiteBalanceSnapshot = CapturePackageAssembler.WhiteBalanceSnapshot(
            mode: deviceManager.whiteBalanceMode,
            lockedGains: deviceManager.lockedWhiteBalanceGains
        )
        packageAssembler.handleMovieFinished(
            failure: failure,
            device: deviceManager.device,
            movieOutputConnection: movieOutput?.connection(with: .video),
            appleLog2ColorSpaceRaw: Self.appleLog2ColorSpaceRaw,
            lensRecord: deviceManager.activeLens?.toRecord(),
            selectedLook: pendingSelectedLook,
            customLut: pendingCustomLut,
            customLutPayload: pendingCustomLutPayload,
            exposure: exposureSnapshot,
            whiteBalance: whiteBalanceSnapshot,
            onCleanup: { [weak self] in
                guard let self else { return }
                self.recordingState.cancelStoragePressureMonitor(clear: true)
                self.recordingDelegate = nil
            }
        )
    }

}

#endif
