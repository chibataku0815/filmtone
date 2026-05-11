// Filmtone V2 capture / Gyroflow lane — M5-A Gyroflow `.gcsv` smoke.
//
// Forks M4 `FilmtoneCombinedTimingSmoke` rather than refactoring it: the
// M4 archive evidence (`f8e7db15`) is frozen, and any restructuring of the
// M4 file would require re-running the truth-script-checked PASS state to
// keep the M4 archive valid. M5-A copies the M4 session / movie-file /
// VDO / motion-manager scaffolding verbatim and adds:
//   - per-sample array capture survives untouched (M4 already kept these
//     in `gyroSamples` / `accelSamples`),
//   - Strategy C resampling onto the gyro timeline via `FilmtoneGcsvWriter`,
//   - a `m5-package-<UUID>/` directory that holds {`m5-master.mov`,
//     `m5-motion.gcsv`, `m5-combined-timing.json`, `m5-debug.log`},
//     emitted via a staging→rename so the final dir is only visible
//     once all artifacts exist,
//   - run-local sync offsets computed against THIS run's
//     `movieFile.startPTSSeconds` / first VDO PTS / first gyro / first
//     accel — these are the seeds M5-B feeds into Gyroflow's sync slider.
//     M4 offsets are baseline expected range only (`±200ms` drift gate),
//     never seeds.
//
// Hard invariants (M5-A boundary, mirrors M4):
//   - DEBUG-only entry. AppDelegate runs `runSmoke()` under `#if DEBUG`
//     only, and only when `FILMTONE_SMOKE_LANE=m5` (env-var dispatcher)
//     so the smoke stays mutually exclusive with M1 / M2-B / M3 / M4.
//   - Format pinned to M2-B-validated `device.formats[56]` (no search).
//   - ProRes 422 HQ via `movieOutput.setOutputSettings([AVVideoCodecKey:
//     .proRes422HQ], for: connection)` after confirming
//     `availableVideoCodecTypes` contains it (matches M2-B / M4 exactly).
//   - MovieFile start anchor read via iOS 18.2+ delegate
//     `fileOutput(_:didStartRecordingTo:startPTS:from:)`. A missing or
//     non-finite startPTS still fails the smoke (M4 P1 gate, not regressed).
//   - Two-phase `resolvedError` logic: recording-fatal vs stream/anchor —
//     `AVErrorRecordingSuccessfullyFinishedKey == true` is non-fatal
//     (M4 P2 fix, not regressed).
//   - Raw `startGyroUpdates` + `startAccelerometerUpdates` only;
//     `startDeviceMotionUpdates` is NOT called (Gyroflow data must be raw).
//   - Anchor: `mach_timebase_info` + `mach_absolute_time()` +
//     `ProcessInfo.processInfo.systemUptime` snapshot taken immediately
//     after the synchronous `session.startRunning()` returns. Motion
//     updates start on the same line so the offset stays bounded.
//   - No audio, no SSD, no JS bridge / UI surface.

import Foundation

#if os(iOS)

import AVFoundation
import CoreMedia
import CoreMotion
import UIKit
import Darwin.Mach

final class FilmtoneGcsvSmoke: NSObject {
    static let schemaVersion = 1

    enum SmokeError: Error, LocalizedError {
        case permissionDenied
        case noWideCamera
        case formatSelectionFailed(reason: String)
        case appleLog2EnumUnavailable
        case cannotAddInput
        case cannotAddMovieOutput
        case cannotAddVideoDataOutput
        case proRes422HQNotAvailable(available: [String])
        case writerStartFailed(message: String)
        case noVideoSamples
        case noGyroSamples
        case noAccelSamples
        case gyroUnavailable
        case accelerometerUnavailable
        case recordingFinishFailed(message: String)
        case movieRecordingProducedNoFile
        case movieStartPTSMissing
        case packageDirCreationFailed(message: String)
        case gcsvWriteFailed(message: String)
        case gcsvAccelResamplingDropped(droppedRowCount: Int, inRangeGyroCount: Int)
        case gcsvBoundaryTrimTooLarge(trimDurationSeconds: Double, limitSeconds: Double)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Camera permission denied."
            case .noWideCamera:
                return "No rear builtInWideAngleCamera available."
            case .formatSelectionFailed(let reason):
                return "M2-B-validated format mismatch: \(reason)"
            case .appleLog2EnumUnavailable:
                return "AVCaptureColorSpace(rawValue: 4) returned nil on this OS."
            case .cannotAddInput:
                return "AVCaptureSession.canAddInput returned false."
            case .cannotAddMovieOutput:
                return "AVCaptureSession.canAddOutput(movieFileOutput) returned false."
            case .cannotAddVideoDataOutput:
                return "AVCaptureSession.canAddOutput(videoDataOutput) returned false."
            case .proRes422HQNotAvailable(let available):
                return "AVVideoCodecType.proRes422HQ not in availableVideoCodecTypes \(available)."
            case .writerStartFailed(let message):
                return "AVCaptureMovieFileOutput startRecording failed: \(message)"
            case .noVideoSamples:
                return "VDO produced zero samples during the run."
            case .noGyroSamples:
                return "Gyro stream produced zero samples after start."
            case .noAccelSamples:
                return "Accelerometer stream produced zero samples after start."
            case .gyroUnavailable:
                return "CMMotionManager.isGyroAvailable returned false."
            case .accelerometerUnavailable:
                return "CMMotionManager.isAccelerometerAvailable returned false."
            case .recordingFinishFailed(let message):
                return "AVCaptureMovieFileOutput finished with error: \(message)"
            case .movieRecordingProducedNoFile:
                return "AVCaptureMovieFileOutput finished without producing a .mov file."
            case .movieStartPTSMissing:
                return "MovieFile didStartRecordingTo:startPTS:from: delegate did not deliver a finite startPTS — M5 master timeline anchor unavailable."
            case .packageDirCreationFailed(let message):
                return "Failed to create m5 package staging directory: \(message)"
            case .gcsvWriteFailed(let message):
                return "Failed to write m5-motion.gcsv: \(message)"
            case .gcsvAccelResamplingDropped(let droppedRowCount, let inRangeGyroCount):
                return "Strategy C resampling dropped \(droppedRowCount) of \(inRangeGyroCount) in-range gyro rows — nearest accel sample exceeded the tolerance. Stop Condition: accelDroppedRowCount must be 0 (boundary out-of-range gyro rows are tracked separately)."
            case .gcsvBoundaryTrimTooLarge(let trimDurationSeconds, let limitSeconds):
                return String(format: "Strategy C boundary trim %.6fs exceeded limit %.6fs (max(1.5 × gyroMedianInterval, 20ms)). Stop Condition: gyro/accel start-or-stop race is significantly worse than a single sample interval.", trimDurationSeconds, limitSeconds)
            }
        }
    }

    struct SmokeResult {
        let packageDirURL: URL
        let movURL: URL
        let gcsvURL: URL
        let jsonURL: URL
        let debugLogURL: URL
    }

    // MARK: - Public entry

    /// Run the M5-A `.gcsv` proof smoke once. Camera permission is requested
    /// if not already granted. Returns through `completion` on the main thread.
    static func runSmoke(duration: TimeInterval = 30.0,
                         motionMargin: TimeInterval = 1.0,
                         completion: @escaping (Result<SmokeResult, Error>) -> Void) {
        let smoke = FilmtoneGcsvSmoke()
        smoke.start(duration: duration, motionMargin: motionMargin) { result in
            _ = smoke
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Locked configuration (M2-B-validated, do not search)

    private static let lockedFormatIndex: Int = 56
    private static let lockedWidth: Int32 = 3840
    private static let lockedHeight: Int32 = 2160
    private static let lockedFPS: Double = 30
    private static let lockedRotationAngle: CGFloat = 90  // portrait pin
    private static let motionRequestedHz: Double = 200
    private static let motionRequestedInterval: TimeInterval = 1.0 / motionRequestedHz

    // M4 baseline (NOT a seed — drift gate only).
    // Numbers from `apps/capacitor-film-lab-ios/diagnostics/m4-combined-timing-smoke.json`
    // (M4 PASS commit `f8e7db15`).
    private static let m4BaselineVdoToGyroOffsetSeconds: Double = -0.048054834012873471
    private static let m4BaselineVdoToAccelOffsetSeconds: Double = -0.058061834017280489
    private static let driftToleranceSeconds: Double = 0.200

    // MARK: - State

    private let sessionQueue = DispatchQueue(label: "filmtone.m5.session")
    private let vdoQueue = DispatchQueue(label: "filmtone.m5.vdo")
    private let workerQueue = DispatchQueue(label: "filmtone.m5.worker")

    private let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?

    private let motion = CMMotionManager()

    /// Single serial OperationQueue shared by both raw streams. Same shape
    /// as M3 / M4 — serial FIFO ordering means the snapshot operation runs
    /// strictly after any handler operations enqueued before it, without
    /// any explicit lock on the sample arrays.
    private let motionHandlerQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "filmtone.m5.motion-handler"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInitiated
        return q
    }()

    private struct VDOSample {
        let ptsSeconds: Double
    }

    private struct MotionSample {
        let t: TimeInterval
        let x: Double
        let y: Double
        let z: Double
    }

    // VDO state — mutated only on vdoQueue.
    private var vdoSamples: [VDOSample] = []
    private var vdoFirstSamplePixelFormat: String?
    private var vdoFirstSampleDimensions: CMVideoDimensions?

    // Motion state — mutated only on motionHandlerQueue.
    private var gyroSamples: [MotionSample] = []
    private var accelSamples: [MotionSample] = []

    // Movie output state.
    private var movieDidStart: Bool = false
    private var movieDidFinish: Bool = false
    private var movieFinishError: Error?
    private var movieFinishedURL: URL?
    private var movieStartPTSSeconds: Double?
    private var movieRecordedDurationSnapshotSeconds: Double = 0

    // Anchor — captured immediately after session.startRunning() returns.
    private var anchorMachTimebaseNumer: UInt32 = 0
    private var anchorMachTimebaseDenom: UInt32 = 0
    private var anchorStartMachAbsolute: UInt64 = 0
    private var anchorStartBootUptimeSeconds: TimeInterval = 0

    // Connection state captured at startSession time.
    private var requestedStabilizationRaw: Int = AVCaptureVideoStabilizationMode.off.rawValue
    private var appliedStabilizationMovieRaw: Int = -999
    private var appliedStabilizationVdoRaw: Int = -999
    private var appliedMovieRotation: CGFloat = 0
    private var appliedVdoRotation: CGFloat = 0
    private var movieRotationApplied: Bool = false
    private var vdoRotationApplied: Bool = false

    // Session-level diagnostics.
    private var hardwareCostAfterCommit: Float = -1
    private var synchronizationClockDescription: String = "(none)"
    private var availableMovieCodecTypes: [String] = []
    private var sessionPresetAfterCommit: String = ""

    // Package directory state. The smoke writes into `stagingDirURL` while
    // running, then renames it atomically to `finalPackageDirURL` once
    // all artifacts exist (Phase 2 Step 10 — Goal "no scattered files").
    private var packageUUID: String = ""
    private var stagingDirURL: URL?
    private var finalPackageDirURL: URL?
    private var packageRenamedToFinal: Bool = false

    private var movURL: URL?
    private var gcsvURL: URL?
    private var jsonURL: URL?
    private var debugLogURL: URL?

    private var configuredAtBootTime: TimeInterval = 0
    private var startedAtBootTime: TimeInterval = 0
    private var stoppedAtBootTime: TimeInterval = 0
    private var requestedDuration: TimeInterval = 0
    private var motionMargin: TimeInterval = 1.0

    // Filled during finalize; written into diagnostics.
    private var lastGcsvOutput: FilmtoneGcsvWriter.Output?

    private var completion: ((Result<SmokeResult, Error>) -> Void)?
    private var didFinish = false

    /// Append a line to the persistent debug log so we have a record even
    /// when configureSession() throws before jsonURL is set.
    private func dlog(_ message: String) {
        NSLog("[FilmtoneM5Smoke] %@", message)
        guard let url = debugLogURL else { return }
        let line = "[\(Date().timeIntervalSince1970)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    // MARK: - Permission + setup

    private func start(duration: TimeInterval,
                       motionMargin: TimeInterval,
                       completion: @escaping (Result<SmokeResult, Error>) -> Void) {
        self.completion = completion
        self.requestedDuration = duration
        self.motionMargin = motionMargin

        // Generate UUID up front so logs and the eventual rename can both
        // reference the same package identifier.
        let uuid = UUID().uuidString.lowercased()
        self.packageUUID = uuid

        do {
            let dirs = try Self.makePackageStagingDir(uuid: uuid)
            self.stagingDirURL = dirs.staging
            self.finalPackageDirURL = dirs.final
            let logURL = dirs.staging.appendingPathComponent("m5-debug.log", isDirectory: false)
            try "[\(Date().timeIntervalSince1970)] M5 gcsv smoke begin uuid=\(uuid)\n"
                .data(using: .utf8)?
                .write(to: logURL, options: .atomic)
            self.debugLogURL = logURL
        } catch {
            self.completion?(.failure(SmokeError.packageDirCreationFailed(message: error.localizedDescription)))
            return
        }
        dlog("start() requesting camera authorization (status=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue))")

        guard motion.isGyroAvailable else {
            fail(error: SmokeError.gyroUnavailable)
            return
        }
        guard motion.isAccelerometerAvailable else {
            fail(error: SmokeError.accelerometerUnavailable)
            return
        }
        dlog("isGyroAvailable=true isAccelerometerAvailable=true isDeviceMotionAvailable=\(motion.isDeviceMotionAvailable)")

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            self.dlog("requestAccess granted=\(granted)")
            guard granted else {
                self.fail(error: SmokeError.permissionDenied)
                return
            }
            self.sessionQueue.async {
                do {
                    try self.configureSession()
                    self.dlog("configureSession OK, starting session…")
                    self.startSessionAndMotion()
                } catch {
                    self.dlog("configureSession threw: \(error.localizedDescription)")
                    self.fail(error: error)
                }
            }
        }
    }

    private func configureSession() throws {
        configuredAtBootTime = ProcessInfo.processInfo.systemUptime
        dlog("configureSession() — locating wide rear camera…")

        guard let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw SmokeError.noWideCamera
        }
        dlog("wide=\(wide.localizedName) formats=\(wide.formats.count)")

        guard wide.formats.indices.contains(Self.lockedFormatIndex) else {
            throw SmokeError.formatSelectionFailed(reason:
                "device.formats has \(wide.formats.count) entries, need index \(Self.lockedFormatIndex).")
        }
        let lockedFormat = wide.formats[Self.lockedFormatIndex]
        let supportedRaw = lockedFormat.supportedColorSpaces.map { $0.rawValue }
        dlog("formats[\(Self.lockedFormatIndex)].supportedColorSpaces (raw)=\(supportedRaw.map { String($0) }.joined(separator: ","))")
        guard supportedRaw.contains(4) else {
            throw SmokeError.formatSelectionFailed(reason:
                "formats[\(Self.lockedFormatIndex)].supportedColorSpaces does not contain appleLog2 (raw=4); have \(supportedRaw).")
        }
        let dims = CMVideoFormatDescriptionGetDimensions(lockedFormat.formatDescription)
        guard dims.width == Self.lockedWidth, dims.height == Self.lockedHeight else {
            throw SmokeError.formatSelectionFailed(reason:
                "formats[\(Self.lockedFormatIndex)] dimensions are \(dims.width)x\(dims.height); need \(Self.lockedWidth)x\(Self.lockedHeight).")
        }
        let fpsOk = lockedFormat.videoSupportedFrameRateRanges.contains {
            $0.minFrameRate <= Self.lockedFPS && Self.lockedFPS <= $0.maxFrameRate
        }
        guard fpsOk else {
            throw SmokeError.formatSelectionFailed(reason:
                "formats[\(Self.lockedFormatIndex)] does not support \(Self.lockedFPS) fps.")
        }
        guard let appleLog2 = AVCaptureColorSpace(rawValue: 4) else {
            throw SmokeError.appleLog2EnumUnavailable
        }
        self.device = wide

        // ---- session-level configuration ----------------------------------
        session.beginConfiguration()
        session.sessionPreset = .inputPriority
        session.automaticallyConfiguresCaptureDeviceForWideColor = false
        dlog("session.sessionPreset=.inputPriority, autoWideColor=false")

        let input = try AVCaptureDeviceInput(device: wide)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw SmokeError.cannotAddInput
        }
        session.addInput(input)
        self.input = input
        dlog("session.addInput(wide) OK")

        try wide.lockForConfiguration()
        wide.activeFormat = lockedFormat
        wide.activeColorSpace = appleLog2
        let frameDuration = CMTime(value: 1, timescale: 30)
        wide.activeVideoMinFrameDuration = frameDuration
        wide.activeVideoMaxFrameDuration = frameDuration
        wide.unlockForConfiguration()
        dlog("activeFormat=formats[\(Self.lockedFormatIndex)], activeColorSpace=appleLog2, fps=30 applied")

        // ---- AVCaptureMovieFileOutput as ProRes Apple Log 2 master --------
        let movieOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(movieOutput) else {
            session.commitConfiguration()
            throw SmokeError.cannotAddMovieOutput
        }
        session.addOutput(movieOutput)
        self.movieOutput = movieOutput
        dlog("session.addOutput(movieFileOutput) OK")

        let movieConnection = movieOutput.connection(with: .video)
        let availableCodecs = movieOutput.availableVideoCodecTypes.map { $0.rawValue }
        availableMovieCodecTypes = availableCodecs
        dlog("movieOutput.availableVideoCodecTypes=\(availableCodecs.joined(separator: ","))")
        guard availableCodecs.contains(AVVideoCodecType.proRes422HQ.rawValue) else {
            session.commitConfiguration()
            throw SmokeError.proRes422HQNotAvailable(available: availableCodecs)
        }
        if let movieConnection {
            movieOutput.setOutputSettings(
                [AVVideoCodecKey: AVVideoCodecType.proRes422HQ],
                for: movieConnection
            )
            dlog("movieOutput.setOutputSettings(proRes422HQ) OK")
        }

        // ---- AVCaptureVideoDataOutput as timing side-band -----------------
        let vdo = AVCaptureVideoDataOutput()
        vdo.alwaysDiscardsLateVideoFrames = false
        vdo.setSampleBufferDelegate(self, queue: vdoQueue)
        guard session.canAddOutput(vdo) else {
            session.commitConfiguration()
            throw SmokeError.cannotAddVideoDataOutput
        }
        session.addOutput(vdo)
        self.videoDataOutput = vdo
        dlog("session.addOutput(videoDataOutput) OK")

        if let movieConnection {
            if movieConnection.isVideoRotationAngleSupported(Self.lockedRotationAngle) {
                movieConnection.videoRotationAngle = Self.lockedRotationAngle
                movieRotationApplied = true
            }
            if movieConnection.isVideoStabilizationSupported {
                movieConnection.preferredVideoStabilizationMode = .off
            }
        }
        if let vdoConnection = vdo.connection(with: .video) {
            if vdoConnection.isVideoRotationAngleSupported(Self.lockedRotationAngle) {
                vdoConnection.videoRotationAngle = Self.lockedRotationAngle
                vdoRotationApplied = true
            }
            if vdoConnection.isVideoStabilizationSupported {
                vdoConnection.preferredVideoStabilizationMode = .off
            }
        }

        session.commitConfiguration()
        sessionPresetAfterCommit = session.sessionPreset.rawValue
        hardwareCostAfterCommit = session.hardwareCost
        dlog("commitConfiguration done. preset=\(sessionPresetAfterCommit) hardwareCost=\(hardwareCostAfterCommit)")

        if let syncClock = session.synchronizationClock {
            synchronizationClockDescription = String(describing: syncClock)
        } else {
            synchronizationClockDescription = "(synchronizationClock=nil)"
        }
        dlog("session.synchronizationClock=\(synchronizationClockDescription)")

        // ---- prepare master file path inside the staging package dir ------
        guard let stagingDirURL else {
            throw SmokeError.packageDirCreationFailed(message: "staging dir URL nil at output-path stage")
        }
        let movURL = stagingDirURL.appendingPathComponent("m5-master.mov", isDirectory: false)
        let gcsvURL = stagingDirURL.appendingPathComponent("m5-motion.gcsv", isDirectory: false)
        let jsonURL = stagingDirURL.appendingPathComponent("m5-combined-timing.json", isDirectory: false)
        try? FileManager.default.removeItem(at: movURL)
        try? FileManager.default.removeItem(at: gcsvURL)
        try? FileManager.default.removeItem(at: jsonURL)
        self.movURL = movURL
        self.gcsvURL = gcsvURL
        self.jsonURL = jsonURL
    }

    private func startSessionAndMotion() {
        motion.gyroUpdateInterval = Self.motionRequestedInterval
        motion.accelerometerUpdateInterval = Self.motionRequestedInterval

        dlog("session.startRunning() …")
        session.startRunning()
        dlog("session.isRunning=\(session.isRunning)")

        // ----- Anchor capture --------------------------------------------
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        anchorMachTimebaseNumer = tb.numer
        anchorMachTimebaseDenom = tb.denom

        anchorStartMachAbsolute = mach_absolute_time()
        anchorStartBootUptimeSeconds = ProcessInfo.processInfo.systemUptime
        startedAtBootTime = anchorStartBootUptimeSeconds

        motion.startGyroUpdates(to: motionHandlerQueue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.gyroSamples.append(MotionSample(
                t: data.timestamp,
                x: data.rotationRate.x,
                y: data.rotationRate.y,
                z: data.rotationRate.z
            ))
        }
        motion.startAccelerometerUpdates(to: motionHandlerQueue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.accelSamples.append(MotionSample(
                t: data.timestamp,
                x: data.acceleration.x,
                y: data.acceleration.y,
                z: data.acceleration.z
            ))
        }
        dlog("anchor: machAbsolute=\(anchorStartMachAbsolute) bootUptime=\(anchorStartBootUptimeSeconds) tb=\(anchorMachTimebaseNumer)/\(anchorMachTimebaseDenom); motion updates issued")

        if let movieConn = movieOutput?.connection(with: .video) {
            appliedStabilizationMovieRaw = movieConn.activeVideoStabilizationMode.rawValue
            appliedMovieRotation = movieConn.videoRotationAngle
        }
        if let vdoConn = videoDataOutput?.connection(with: .video) {
            appliedStabilizationVdoRaw = vdoConn.activeVideoStabilizationMode.rawValue
            appliedVdoRotation = vdoConn.videoRotationAngle
        }

        guard let movieOutput, let movURL else {
            fail(error: SmokeError.cannotAddMovieOutput)
            return
        }
        movieOutput.startRecording(to: movURL, recordingDelegate: self)
        dlog("movieOutput.startRecording(to: \(movURL.lastPathComponent)) requested")

        sessionQueue.asyncAfter(deadline: .now() + requestedDuration) { [weak self] in
            self?.requestStop()
        }
    }

    private func requestStop() {
        guard !didFinish else { return }
        guard let movieOutput else { return }
        movieRecordedDurationSnapshotSeconds = CMTimeGetSeconds(movieOutput.recordedDuration)
        dlog("requestStop: recordedDuration snapshot=\(movieRecordedDurationSnapshotSeconds)s")
        movieOutput.stopRecording()
        // didFinishRecordingTo delegate fires and triggers finalizeAndComplete().
    }

    private func finalizeAndComplete() {  // not `finalize` — collides with NSObject.finalize
        guard !didFinish else { return }
        didFinish = true
        dlog("finalizeAndComplete() begin")

        workerQueue.asyncAfter(deadline: .now() + motionMargin) { [weak self] in
            self?.stopMotionAndAssemble()
        }
    }

    private func stopMotionAndAssemble() {
        var gyroSnapshot: [MotionSample] = []
        var accelSnapshot: [MotionSample] = []
        var snapshotStopBootTime: TimeInterval = 0

        let snapshotOp = BlockOperation { [weak self] in
            guard let self else { return }
            self.motion.stopGyroUpdates()
            self.motion.stopAccelerometerUpdates()
            snapshotStopBootTime = ProcessInfo.processInfo.systemUptime
            gyroSnapshot = self.gyroSamples
            accelSnapshot = self.accelSamples
        }
        motionHandlerQueue.addOperation(snapshotOp)
        snapshotOp.waitUntilFinished()

        stoppedAtBootTime = snapshotStopBootTime
        dlog("motion snapshot finished. gyroCount=\(gyroSnapshot.count) accelCount=\(accelSnapshot.count) stopBootTime=\(stoppedAtBootTime)")

        session.stopRunning()
        let vdoSnapshot: [VDOSample] = vdoQueue.sync { vdoSamples }
        let vdoFirstPixelFormat = vdoQueue.sync { vdoFirstSamplePixelFormat }
        let vdoFirstDims = vdoQueue.sync { vdoFirstSampleDimensions }
        dlog("session.stopRunning() done. vdoCount=\(vdoSnapshot.count)")

        // M5 master timeline anchor = video.movieFile.startPTSSeconds.
        // Without a finite startPTS the .mov has no usable PTS↔motion
        // mapping anchor (M4 P1 gate, not regressed).
        let movieStartPTSValid: Bool
        if let s = movieStartPTSSeconds, s.isFinite {
            movieStartPTSValid = true
        } else {
            movieStartPTSValid = false
        }

        // Two-phase resolvedError (M4 P2 fix preserved): recording-fatal vs
        // stream/anchor checks are independent. AVCaptureMovieFileOutput
        // delivers a non-nil `error` even on graceful stops with
        // `AVErrorRecordingSuccessfullyFinishedKey == true`; that case is
        // non-fatal and must not short-circuit the stream / anchor checks.
        let recordingFatalError: SmokeError?
        if let movieFinishError {
            let nsError = movieFinishError as NSError
            let succeededFlag = nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool
            if succeededFlag == true {
                recordingFatalError = nil
            } else {
                recordingFatalError = .recordingFinishFailed(message: nsError.localizedDescription)
            }
        } else {
            recordingFatalError = nil
        }

        var resolvedError: SmokeError?
        if let recordingFatalError {
            resolvedError = recordingFatalError
        } else if vdoSnapshot.isEmpty {
            resolvedError = .noVideoSamples
        } else if gyroSnapshot.isEmpty {
            resolvedError = .noGyroSamples
        } else if accelSnapshot.isEmpty {
            resolvedError = .noAccelSamples
        } else if !movieStartPTSValid {
            resolvedError = .movieStartPTSMissing
        } else {
            resolvedError = nil
        }

        // ---- Build gcsv (Strategy C: combined on gyro timeline) ----------
        let gyroForWriter = gyroSnapshot.map {
            FilmtoneGcsvWriter.GyroSample(timestampSeconds: $0.t, x: $0.x, y: $0.y, z: $0.z)
        }
        let accelForWriter = accelSnapshot.map {
            FilmtoneGcsvWriter.AccelSample(timestampSeconds: $0.t, x: $0.x, y: $0.y, z: $0.z)
        }
        let gcsvOutput = FilmtoneGcsvWriter.make(
            gyro: gyroForWriter,
            accel: accelForWriter,
            videofilename: "m5-master.mov"
        )
        self.lastGcsvOutput = gcsvOutput

        var gcsvWritten = false
        if let gcsvURL {
            do {
                try gcsvOutput.bytes.write(to: gcsvURL, options: .atomic)
                gcsvWritten = true
                dlog("gcsv written: \(gcsvURL.lastPathComponent) rowCount=\(gcsvOutput.rowCount) headerBytes=\(gcsvOutput.headerBytes) drop=\(gcsvOutput.metrics.droppedRowCount)")
            } catch {
                dlog("gcsv write failed: \(error.localizedDescription)")
                if resolvedError == nil {
                    resolvedError = .gcsvWriteFailed(message: error.localizedDescription)
                }
            }
        }

        // Strategy C Stop Conditions: any in-range drop fails the smoke,
        // and the boundary trim must stay within max(1.5 × gyroMedian,
        // 20ms). Only apply these gates when we actually had non-empty
        // streams to begin with — an empty gyro / accel stream is
        // already the dominant failure.
        let metrics = gcsvOutput.metrics
        let inRangeCount = gyroSnapshot.count - metrics.outOfRangeTotalCount
        if resolvedError == nil
            && !gyroSnapshot.isEmpty
            && !accelSnapshot.isEmpty
            && metrics.droppedRowCount > 0 {
            resolvedError = .gcsvAccelResamplingDropped(
                droppedRowCount: metrics.droppedRowCount,
                inRangeGyroCount: inRangeCount
            )
        }
        if resolvedError == nil
            && !gyroSnapshot.isEmpty
            && !accelSnapshot.isEmpty
            && !metrics.trimDurationWithinLimit {
            resolvedError = .gcsvBoundaryTrimTooLarge(
                trimDurationSeconds: metrics.trimDurationTotalSeconds,
                limitSeconds: metrics.trimDurationLimitSeconds
            )
        }

        let movieURLOnDisk = movieFinishedURL ?? movURL
        let movieExists: Bool
        let movieSize: Int64
        if let movieURLOnDisk,
           let attrs = try? FileManager.default.attributesOfItem(atPath: movieURLOnDisk.path) {
            movieExists = true
            movieSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        } else {
            movieExists = false
            movieSize = 0
        }
        let startPTSDescription: String
        if let s = movieStartPTSSeconds {
            startPTSDescription = "\(s)"
        } else {
            startPTSDescription = "nil"
        }
        dlog("master mov exists=\(movieExists) size=\(movieSize) startPTSSeconds=\(startPTSDescription)")

        let gcsvSize: Int64
        if let gcsvURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: gcsvURL.path) {
            gcsvSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        } else {
            gcsvSize = 0
        }

        writeDiagnostics(
            vdoSnapshot: vdoSnapshot,
            vdoFirstPixelFormat: vdoFirstPixelFormat,
            vdoFirstDimensions: vdoFirstDims,
            gyro: gyroSnapshot,
            accel: accelSnapshot,
            movieExists: movieExists,
            movieSize: movieSize,
            gcsvWritten: gcsvWritten,
            gcsvSize: gcsvSize,
            gcsvOutput: gcsvOutput,
            resolvedError: resolvedError
        )

        // Atomic rename staging → final once all artifacts exist (or were
        // attempted). Even on failure we rename so devicectl pull has a
        // single, well-named directory; the smokeError field communicates
        // failure separately. If the rename itself fails (cross-volume,
        // permissions, etc.) the staging dir is left in place and
        // `packageRenamedToFinal` stays false.
        finalizePackageRename()

        let resolvedDirURL = packageRenamedToFinal
            ? (finalPackageDirURL ?? stagingDirURL)
            : stagingDirURL

        if let resolvedError {
            completion?(.failure(resolvedError))
            return
        }
        guard movieExists,
              let resolvedDirURL,
              let movieFinalURL = movieURLOnDisk.map({ resolvedURL(after: $0, dir: resolvedDirURL) }),
              let gcsvFinalURL = gcsvURL.map({ resolvedURL(after: $0, dir: resolvedDirURL) }),
              let jsonFinalURL = jsonURL.map({ resolvedURL(after: $0, dir: resolvedDirURL) }),
              let logFinalURL = debugLogURL.map({ resolvedURL(after: $0, dir: resolvedDirURL) }) else {
            completion?(.failure(SmokeError.movieRecordingProducedNoFile))
            return
        }
        completion?(.success(SmokeResult(
            packageDirURL: resolvedDirURL,
            movURL: movieFinalURL,
            gcsvURL: gcsvFinalURL,
            jsonURL: jsonFinalURL,
            debugLogURL: logFinalURL
        )))
    }

    /// After the staging→final rename, the URLs captured during the run
    /// still point at the staging path. Translate them into the final
    /// directory so `SmokeResult` describes the files at their post-rename
    /// locations.
    private func resolvedURL(after preRenameURL: URL, dir resolvedDirURL: URL) -> URL {
        return resolvedDirURL.appendingPathComponent(preRenameURL.lastPathComponent, isDirectory: false)
    }

    /// Move the staging directory to the final `m5-package-<UUID>/` path.
    /// On success, sets `packageRenamedToFinal = true`. On failure, logs
    /// and leaves staging in place — the smoke still returns SmokeResult
    /// pointing at staging.
    private func finalizePackageRename() {
        guard let stagingDirURL, let finalPackageDirURL else {
            dlog("finalizePackageRename: missing staging or final dir URL")
            return
        }
        // Drop a marker doing handle-flush before the rename so the debug
        // log content survives the move.
        do {
            try FileManager.default.moveItem(at: stagingDirURL, to: finalPackageDirURL)
            packageRenamedToFinal = true
            dlog("package directory renamed: \(finalPackageDirURL.path)")
        } catch {
            dlog("package directory rename failed: \(error.localizedDescription)")
        }
    }

    private func fail(error: Error) {
        // Even on early failure, write whatever diagnostics we can and
        // still attempt the staging→final rename so the package surface
        // is consistent for devicectl pull.
        let emptyMetrics = FilmtoneGcsvWriter.ResamplingMetrics(
            exactRowCount: 0,
            interpolatedRowCount: 0,
            droppedRowCount: 0,
            outOfRangeStartCount: 0,
            outOfRangeEndCount: 0,
            outOfRangeTotalCount: 0,
            trimDurationStartSeconds: 0,
            trimDurationEndSeconds: 0,
            trimDurationTotalSeconds: 0,
            gyroMedianIntervalSeconds: 0,
            trimDurationLimitSeconds: 0.020,
            trimDurationWithinLimit: true,
            maxDeltaSeconds: 0,
            medianDeltaSeconds: 0,
            toleranceSeconds: FilmtoneGcsvWriter.defaultAccelResamplingToleranceSeconds
        )
        let emptyOutput = FilmtoneGcsvWriter.Output(
            bytes: Data(),
            rowCount: 0,
            headerBytes: 0,
            metrics: emptyMetrics
        )
        writeDiagnostics(
            vdoSnapshot: [],
            vdoFirstPixelFormat: nil,
            vdoFirstDimensions: nil,
            gyro: [],
            accel: [],
            movieExists: false,
            movieSize: 0,
            gcsvWritten: false,
            gcsvSize: 0,
            gcsvOutput: emptyOutput,
            resolvedError: error
        )
        finalizePackageRename()
        completion?(.failure(error))
    }

    // MARK: - Filesystem

    private struct PackageDirURLs {
        let staging: URL
        let final: URL
    }

    private static func makePackageStagingDir(uuid: String) throws -> PackageDirURLs {
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let captures = caches.appendingPathComponent("Filmtone/captures", isDirectory: true)
        try FileManager.default.createDirectory(at: captures, withIntermediateDirectories: true)
        let staging = captures.appendingPathComponent("m5-staging-\(uuid)", isDirectory: true)
        let final = captures.appendingPathComponent("m5-package-\(uuid)", isDirectory: true)
        try? FileManager.default.removeItem(at: staging)
        try? FileManager.default.removeItem(at: final)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        return PackageDirURLs(staging: staging, final: final)
    }

    private func writeDiagnostics(vdoSnapshot: [VDOSample],
                                  vdoFirstPixelFormat: String?,
                                  vdoFirstDimensions: CMVideoDimensions?,
                                  gyro: [MotionSample],
                                  accel: [MotionSample],
                                  movieExists: Bool,
                                  movieSize: Int64,
                                  gcsvWritten: Bool,
                                  gcsvSize: Int64,
                                  gcsvOutput: FilmtoneGcsvWriter.Output,
                                  resolvedError: Error?) {
        guard let jsonURL else { return }
        let payload = makeDiagnosticsPayload(
            vdoSnapshot: vdoSnapshot,
            vdoFirstPixelFormat: vdoFirstPixelFormat,
            vdoFirstDimensions: vdoFirstDimensions,
            gyro: gyro,
            accel: accel,
            movieExists: movieExists,
            movieSize: movieSize,
            gcsvWritten: gcsvWritten,
            gcsvSize: gcsvSize,
            gcsvOutput: gcsvOutput,
            resolvedError: resolvedError
        )
        do {
            let data = try JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: jsonURL, options: .atomic)
        } catch {
            dlog("failed to write diagnostics JSON: \(error.localizedDescription)")
        }
    }

    private func makeDiagnosticsPayload(vdoSnapshot: [VDOSample],
                                        vdoFirstPixelFormat: String?,
                                        vdoFirstDimensions: CMVideoDimensions?,
                                        gyro: [MotionSample],
                                        accel: [MotionSample],
                                        movieExists: Bool,
                                        movieSize: Int64,
                                        gcsvWritten: Bool,
                                        gcsvSize: Int64,
                                        gcsvOutput: FilmtoneGcsvWriter.Output,
                                        resolvedError: Error?) -> [String: Any] {
        let durationDict: [String: Any] = [
            "requestedSeconds": requestedDuration,
            "motionMarginSeconds": motionMargin,
            "elapsedSeconds": stoppedAtBootTime > startedAtBootTime
                ? stoppedAtBootTime - startedAtBootTime
                : 0,
        ]
        let uiDevice = UIDevice.current
        let deviceDict: [String: Any] = [
            "model": uiDevice.model,
            "name": uiDevice.name,
            "systemName": uiDevice.systemName,
            "systemVersion": uiDevice.systemVersion,
            "machine": Self.utsnameMachine(),
        ]
        let anchorDict: [String: Any] = [
            "machTimebaseNumer": anchorMachTimebaseNumer,
            "machTimebaseDenom": anchorMachTimebaseDenom,
            "startMachAbsolute": anchorStartMachAbsolute,
            "startBootUptimeSeconds": anchorStartBootUptimeSeconds,
        ]
        let formatDict: [String: Any] = [
            "formatIndex": Self.lockedFormatIndex,
            "pixelFormat": vdoFirstPixelFormat ?? "x422",
            "colorSpace": "AppleLog2",
            "colorSpaceRawValue": 4,
            "dimensions": [Self.lockedWidth, Self.lockedHeight],
            "fps": Self.lockedFPS,
        ]
        let firstSampleDimsAny: Any = vdoFirstDimensions.map {
            ["width": Int($0.width), "height": Int($0.height)] as [String: Any]
        } ?? NSNull()
        let writerDict: [String: Any] = [
            "codec": AVVideoCodecType.proRes422HQ.rawValue,
            "availableVideoCodecTypes": availableMovieCodecTypes,
            "movFileSizeBytes": movieSize,
            "movFileExists": movieExists,
            "vdoFirstSampleDimensions": firstSampleDimsAny,
        ]
        let movieFileDict: [String: Any] = [
            "outputPath": movURL?.path ?? "",
            "outputURL": movieFinishedURL?.path ?? movURL?.path ?? "",
            "didStart": movieDidStart,
            "didFinish": movieDidFinish,
            "finishError": movieFinishError?.localizedDescription ?? NSNull(),
            "startPTSSeconds": movieStartPTSSeconds ?? NSNull(),
            "recordedDurationSeconds": movieRecordedDurationSnapshotSeconds,
            "movFileSizeBytes": movieSize,
        ]
        let vdoStats = Self.computeVDOStats(samples: vdoSnapshot)
        let vdoDict: [String: Any] = vdoStats.merging([
            "rotation": [
                "appliedAngle": appliedVdoRotation,
                "applied": vdoRotationApplied,
            ],
            "stabilization": [
                "applied": Self.stabilizationName(appliedStabilizationVdoRaw),
                "appliedRaw": appliedStabilizationVdoRaw,
            ],
        ]) { _, new in new }
        let videoDict: [String: Any] = [
            "format": formatDict,
            "writer": writerDict,
            "movieFile": movieFileDict,
            "vdo": vdoDict,
            "movieRotation": [
                "appliedAngle": appliedMovieRotation,
                "applied": movieRotationApplied,
            ],
            "movieStabilization": [
                "applied": Self.stabilizationName(appliedStabilizationMovieRaw),
                "appliedRaw": appliedStabilizationMovieRaw,
            ],
        ]
        let coreMotionDict: [String: Any] = [
            "isGyroAvailable": motion.isGyroAvailable,
            "isAccelerometerAvailable": motion.isAccelerometerAvailable,
            "isDeviceMotionAvailable": motion.isDeviceMotionAvailable,
            "requestedGyroIntervalSeconds": Self.motionRequestedInterval,
            "requestedAccelIntervalSeconds": Self.motionRequestedInterval,
            "requestedHz": Self.motionRequestedHz,
            "fusedDeviceMotionStarted": false,
        ]
        let motionDict: [String: Any] = [
            "coreMotion": coreMotionDict,
            "gyro": Self.computeMotionStreamStats(samples: gyro),
            "accel": Self.computeMotionStreamStats(samples: accel),
        ]
        let mappingDict = Self.computeMappingDict(
            vdo: vdoSnapshot,
            gyro: gyro,
            accel: accel
        )
        let sessionDict: [String: Any] = [
            "presetAfterCommit": sessionPresetAfterCommit,
            "hardwareCostAfterCommit": hardwareCostAfterCommit,
            "synchronizationClock": synchronizationClockDescription,
            "automaticallyConfiguresCaptureDeviceForWideColor": false,
        ]
        let timestampsDict: [String: Any] = [
            "configuredAtBootTime": configuredAtBootTime,
            "startedAtBootTime": startedAtBootTime,
            "stoppedAtBootTime": stoppedAtBootTime,
        ]

        let runLocalDict = Self.computeRunLocalSyncOffsets(
            movieStartPTSSeconds: movieStartPTSSeconds,
            firstVdoPTS: vdoSnapshot.first?.ptsSeconds,
            firstGyroTS: gyro.first?.t,
            firstAccelTS: accel.first?.t
        )
        let baselineDict: [String: Any] = [
            "source": "M4 PASS commit f8e7db15",
            "purpose": "drift gate only — NOT the M5-B sync seed",
            "vdoPTSMinusGyroTSSeconds_M4": Self.m4BaselineVdoToGyroOffsetSeconds,
            "vdoPTSMinusAccelTSSeconds_M4": Self.m4BaselineVdoToAccelOffsetSeconds,
            "driftToleranceSeconds": Self.driftToleranceSeconds,
            "vdoFirstPtsToGyroOffsetWithinM4DriftTolerance": Self.driftWithinTolerance(
                runLocal: runLocalDict["runLocalVdoFirstPtsToGyroOffsetSeconds"],
                baseline: Self.m4BaselineVdoToGyroOffsetSeconds,
                tolerance: Self.driftToleranceSeconds
            ),
            "vdoFirstPtsToAccelOffsetWithinM4DriftTolerance": Self.driftWithinTolerance(
                runLocal: runLocalDict["runLocalVdoFirstPtsToAccelOffsetSeconds"],
                baseline: Self.m4BaselineVdoToAccelOffsetSeconds,
                tolerance: Self.driftToleranceSeconds
            ),
        ]
        let metrics = gcsvOutput.metrics
        let gcsvDict: [String: Any] = [
            "path": gcsvURL?.path ?? "",
            "lastPathComponent": gcsvURL?.lastPathComponent ?? "",
            "fileSizeBytes": gcsvSize,
            "written": gcsvWritten,
            "rowCount": gcsvOutput.rowCount,
            "headerBytes": gcsvOutput.headerBytes,
            "rowConstructionStrategy": "C",
            "rowConstructionStrategyName": "combined-on-gyro-timeline",
            "axisConvention": [
                "mode": "sensor-native",
                "orientation": FilmtoneGcsvWriter.defaultOrientation,
                "remapApplied": false,
                "rawSensorFrameNote": "Core Motion raw rotationRate (rad/s) and acceleration (g) emitted unchanged. M5-B verifies against rotated .mov; orientation may be overridden if desktop evidence requires image-frame remap.",
            ],
            "timestampBasis": "motion-relative",
            "gyroUnit": "rad/s",
            "accelUnit": "g",
            "tscale": FilmtoneGcsvWriter.defaultTscale,
            "gscale": FilmtoneGcsvWriter.defaultGscale,
            "ascale": FilmtoneGcsvWriter.defaultAscale,
            "imuRequestedHz": Self.motionRequestedHz,
            "imuEffectiveHz": Self.computeEffectiveHz(samples: gyro),
            "accelToGyroMaxDeltaSeconds": metrics.maxDeltaSeconds,
            "accelToGyroMedianDeltaSeconds": metrics.medianDeltaSeconds,
            "accelDroppedRowCount": metrics.droppedRowCount,
            "accelInterpolatedRowCount": metrics.interpolatedRowCount,
            "accelExactRowCount": metrics.exactRowCount,
            "accelOutOfRangeStartCount": metrics.outOfRangeStartCount,
            "accelOutOfRangeEndCount": metrics.outOfRangeEndCount,
            "accelOutOfRangeTotalCount": metrics.outOfRangeTotalCount,
            "gyroAccelTrimDurationStartSeconds": metrics.trimDurationStartSeconds,
            "gyroAccelTrimDurationEndSeconds": metrics.trimDurationEndSeconds,
            "gyroAccelTrimDurationTotalSeconds": metrics.trimDurationTotalSeconds,
            "gyroAccelTrimDurationLimitSeconds": metrics.trimDurationLimitSeconds,
            "gyroAccelTrimDurationWithinLimit": metrics.trimDurationWithinLimit,
            "gyroMedianIntervalSeconds": metrics.gyroMedianIntervalSeconds,
            "accelResamplingToleranceSeconds": metrics.toleranceSeconds,
        ]
        let packageDict: [String: Any] = [
            "uuid": packageUUID,
            "stagingDirectoryPath": stagingDirURL?.path ?? "",
            "finalDirectoryPath": finalPackageDirURL?.path ?? "",
            "renamedToFinal": packageRenamedToFinal,
            "movFileSizeBytes": movieSize,
            "gcsvFileSizeBytes": gcsvSize,
        ]

        var payload: [String: Any] = [
            "schemaVersion": Self.schemaVersion,
            "lane": "v2-capture-gyroflow",
            "milestone": "M5-A",
            "smokeLaneEnvVar": "m5",
            "duration": durationDict,
            "device": deviceDict,
            "anchor": anchorDict,
            "video": videoDict,
            "motion": motionDict,
            "mapping": mappingDict,
            "session": sessionDict,
            "timestamps": timestampsDict,
            "gcsv": gcsvDict,
            "package": packageDict,
            "runLocalSyncOffsets": runLocalDict,
            "baselineExpectedRange": baselineDict,
            "smokeError": resolvedError?.localizedDescription ?? NSNull(),
        ]
        if let device {
            payload["captureDevice"] = [
                "uniqueID": device.uniqueID,
                "deviceType": device.deviceType.rawValue,
                "localizedName": device.localizedName,
            ]
        }
        return payload
    }

    // MARK: - Run-local sync offsets

    /// Compute the four run-local offsets from THIS run's first samples.
    /// These are the seeds M5-B feeds into Gyroflow's sync slider. M4
    /// numbers serve only as the drift gate (see `baselineExpectedRange`).
    private static func computeRunLocalSyncOffsets(movieStartPTSSeconds: Double?,
                                                   firstVdoPTS: Double?,
                                                   firstGyroTS: TimeInterval?,
                                                   firstAccelTS: TimeInterval?) -> [String: Any] {
        let mvStartGyro: Any
        let mvStartAccel: Any
        let vdoGyro: Any
        let vdoAccel: Any
        if let s = movieStartPTSSeconds, let g = firstGyroTS {
            mvStartGyro = s - g
        } else { mvStartGyro = NSNull() }
        if let s = movieStartPTSSeconds, let a = firstAccelTS {
            mvStartAccel = s - a
        } else { mvStartAccel = NSNull() }
        if let v = firstVdoPTS, let g = firstGyroTS {
            vdoGyro = v - g
        } else { vdoGyro = NSNull() }
        if let v = firstVdoPTS, let a = firstAccelTS {
            vdoAccel = v - a
        } else { vdoAccel = NSNull() }
        return [
            "runLocalMovieStartToGyroOffsetSeconds": mvStartGyro,
            "runLocalMovieStartToAccelOffsetSeconds": mvStartAccel,
            "runLocalVdoFirstPtsToGyroOffsetSeconds": vdoGyro,
            "runLocalVdoFirstPtsToAccelOffsetSeconds": vdoAccel,
            "movieStartPTSSeconds": movieStartPTSSeconds ?? NSNull(),
            "firstVdoPTSSeconds": firstVdoPTS ?? NSNull(),
            "firstGyroCmLogTimestampSeconds": firstGyroTS ?? NSNull(),
            "firstAccelCmLogTimestampSeconds": firstAccelTS ?? NSNull(),
            "primarySeedKey": "runLocalMovieStartToGyroOffsetSeconds",
        ]
    }

    private static func driftWithinTolerance(runLocal: Any?,
                                             baseline: Double,
                                             tolerance: Double) -> Any {
        guard let value = runLocal as? Double else { return NSNull() }
        return abs(value - baseline) <= tolerance
    }

    private static func computeEffectiveHz(samples: [MotionSample]) -> Double {
        guard samples.count >= 2 else { return 0 }
        let intervals = (1..<samples.count).map { samples[$0].t - samples[$0 - 1].t }
        let sorted = intervals.sorted()
        let median = sorted[sorted.count / 2]
        return median > 0 ? 1.0 / median : 0
    }

    // MARK: - VDO / motion stats (shared form with M4)

    private static func computeVDOStats(samples: [VDOSample]) -> [String: Any] {
        guard !samples.isEmpty else {
            return [
                "sampleCount": 0,
                "firstPTSSeconds": NSNull(),
                "lastPTSSeconds": NSNull(),
                "coverageSeconds": 0,
                "effectiveFps": 0,
                "intervals": NSNull(),
            ]
        }
        let first = samples.first!.ptsSeconds
        let last = samples.last!.ptsSeconds
        let coverage = max(0, last - first)
        let count = samples.count
        var intervals: [Double] = []
        if count >= 2 {
            intervals.reserveCapacity(count - 1)
            for i in 1..<count {
                intervals.append(samples[i].ptsSeconds - samples[i - 1].ptsSeconds)
            }
        }
        let stats = Self.intervalStats(intervals)
        let effectiveFps = stats.median > 0 ? 1.0 / stats.median : 0
        return [
            "sampleCount": count,
            "firstPTSSeconds": first,
            "lastPTSSeconds": last,
            "coverageSeconds": coverage,
            "effectiveFps": effectiveFps,
            "intervals": stats.dict,
        ]
    }

    private static func computeMotionStreamStats(samples: [MotionSample]) -> [String: Any] {
        guard !samples.isEmpty else {
            return [
                "sampleCount": 0,
                "firstTS": NSNull(),
                "lastTS": NSNull(),
                "coverageSeconds": 0,
                "effectiveHz": 0,
                "intervals": NSNull(),
            ]
        }
        let first = samples.first!.t
        let last = samples.last!.t
        let coverage = max(0, last - first)
        let count = samples.count
        var intervals: [Double] = []
        if count >= 2 {
            intervals.reserveCapacity(count - 1)
            for i in 1..<count {
                intervals.append(samples[i].t - samples[i - 1].t)
            }
        }
        let stats = Self.intervalStats(intervals)
        let effectiveHz = stats.median > 0 ? 1.0 / stats.median : 0
        return [
            "sampleCount": count,
            "firstTS": first,
            "lastTS": last,
            "coverageSeconds": coverage,
            "effectiveHz": effectiveHz,
            "intervals": stats.dict,
        ]
    }

    private struct IntervalStats {
        let median: Double
        let dict: [String: Any]
    }

    private static func intervalStats(_ raw: [Double]) -> IntervalStats {
        let sorted = raw.sorted()
        let median: Double
        let maxGap: Double
        let p99: Double
        let gapOver50: Int
        let gapOver100: Int
        let gapOver200: Int
        if sorted.isEmpty {
            median = 0; maxGap = 0; p99 = 0
            gapOver50 = 0; gapOver100 = 0; gapOver200 = 0
        } else {
            median = sorted[sorted.count / 2]
            maxGap = sorted.last ?? 0
            let p99Index = max(0, Int((Double(sorted.count) * 0.99).rounded(.down)) - 1)
            p99 = sorted[min(p99Index, sorted.count - 1)]
            gapOver50 = sorted.filter { $0 > 0.050 }.count
            gapOver100 = sorted.filter { $0 > 0.100 }.count
            gapOver200 = sorted.filter { $0 > 0.200 }.count
        }
        let dict: [String: Any] = [
            "medianSeconds": median,
            "maxGapSeconds": maxGap,
            "p99Seconds": p99,
            "gapCountOver50ms": gapOver50,
            "gapCountOver100ms": gapOver100,
            "gapCountOver200ms": gapOver200,
        ]
        return IntervalStats(median: median, dict: dict)
    }

    private static func computeMappingDict(vdo: [VDOSample],
                                           gyro: [MotionSample],
                                           accel: [MotionSample]) -> [String: Any] {
        let firstVdo: Any = vdo.first.map { $0.ptsSeconds } ?? NSNull()
        let firstGyro: Any = gyro.first.map { $0.t } ?? NSNull()
        let firstAccel: Any = accel.first.map { $0.t } ?? NSNull()
        let vdoMinusGyro: Any
        let vdoMinusAccel: Any
        if let v = vdo.first?.ptsSeconds, let g = gyro.first?.t {
            vdoMinusGyro = v - g
        } else {
            vdoMinusGyro = NSNull()
        }
        if let v = vdo.first?.ptsSeconds, let a = accel.first?.t {
            vdoMinusAccel = v - a
        } else {
            vdoMinusAccel = NSNull()
        }
        return [
            "firstVdoPTSSeconds": firstVdo,
            "firstGyroTSSeconds": firstGyro,
            "firstAccelTSSeconds": firstAccel,
            "vdoPTSMinusGyroTSSeconds": vdoMinusGyro,
            "vdoPTSMinusAccelTSSeconds": vdoMinusAccel,
        ]
    }

    private static func stabilizationName(_ raw: Int) -> String {
        switch raw {
        case -1: return "auto"
        case 0: return "off"
        case 1: return "standard"
        case 2: return "cinematic"
        case 3: return "cinematicExtended"
        case 4: return "previewOptimized"
        case 5: return "cinematicExtendedEnhanced"
        case -999: return "unmeasured"
        default: return "unknown(\(raw))"
        }
    }

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

    private static func utsnameMachine() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        var bytes: [UInt8] = []
        for child in mirror.children {
            if let v = child.value as? Int8, v != 0 {
                bytes.append(UInt8(bitPattern: v))
            }
        }
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}

// MARK: - VDO sample buffer delegate (timing side-band)

extension FilmtoneGcsvSmoke: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let ptsSec = CMTimeGetSeconds(pts)
        if vdoSamples.isEmpty {
            if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
                let pf = CMFormatDescriptionGetMediaSubType(formatDescription)
                vdoFirstSamplePixelFormat = Self.fourCC(pf)
                vdoFirstSampleDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            }
        }
        vdoSamples.append(VDOSample(ptsSeconds: ptsSec))
    }
}

// MARK: - MovieFileOutput recording delegate

extension FilmtoneGcsvSmoke: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        movieDidStart = true
        dlog("movieFileOutput didStartRecordingTo \(fileURL.lastPathComponent)")
    }

    @available(iOS 18.2, *)
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    startPTS: CMTime,
                    from connections: [AVCaptureConnection]) {
        movieDidStart = true
        movieStartPTSSeconds = CMTimeGetSeconds(startPTS)
        dlog("movieFileOutput didStartRecordingTo (startPTS) \(fileURL.lastPathComponent) startPTSSeconds=\(movieStartPTSSeconds ?? -1)")
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        movieDidFinish = true
        movieFinishError = error
        movieFinishedURL = outputFileURL
        if let error {
            dlog("movieFileOutput didFinishRecordingTo \(outputFileURL.lastPathComponent) error=\(error.localizedDescription)")
        } else {
            dlog("movieFileOutput didFinishRecordingTo \(outputFileURL.lastPathComponent) OK")
        }
        sessionQueue.async { [weak self] in
            self?.finalizeAndComplete()
        }
    }
}

#endif
