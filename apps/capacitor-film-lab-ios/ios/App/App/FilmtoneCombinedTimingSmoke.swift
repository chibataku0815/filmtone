// Filmtone V2 capture / Gyroflow lane — M4 Combined Timing Smoke.
//
// One AVCaptureSession with the M2-B Path C ProRes 422 HQ Apple Log 2 master
// (AVCaptureMovieFileOutput) and the timing side-band (AVCaptureVideoDataOutput)
// runs simultaneously with raw Core Motion gyro + accelerometer (M3 path)
// for 30 seconds. The point is to record, in one place, enough timestamp
// material that M5 can map video PTS to Core Motion CMLogItem.timestamp
// without guessing.
//
// Single coordinator on purpose: M2-B's runSmoke and M3's runSmoke create
// separate sessions and separate `mach_absolute_time` snapshots, so calling
// them side-by-side would lose the shared anchor. The minimum capture-side
// and motion-side logic is duplicated here intentionally — keeping M2-B /
// M3 archives reproducible matters more than DRY.
//
// Hard invariants (M4 boundary):
//   - DEBUG-only entry. AppDelegate runs runSmoke() under #if DEBUG only,
//     and only when FILMTONE_SMOKE_LANE=m4 (env-var dispatcher) so the
//     smoke is mutually exclusive with M1 / M2-B / M3.
//   - Format pinned to M2-B-validated `device.formats[56]` — no search,
//     no fallback. Mismatch = `formatSelectionFailed`.
//   - ProRes 422 HQ via `movieOutput.setOutputSettings([AVVideoCodecKey:
//     .proRes422HQ], for: connection)` after confirming the connection-less
//     property `movieOutput.availableVideoCodecTypes` contains it
//     (matches M2-B exactly).
//   - MovieFile start anchor read via iOS 18.2+ delegate
//     `fileOutput(_:didStartRecordingTo:startPTS:from:)`. `recordedFileStartTime`
//     does not exist on `AVCaptureFileOutput`.
//   - Raw `startGyroUpdates` + `startAccelerometerUpdates` only.
//     `startDeviceMotionUpdates` is NOT called (Gyroflow data must be raw).
//   - Anchor: `mach_timebase_info` + `mach_absolute_time()` +
//     `ProcessInfo.processInfo.systemUptime` snapshot taken immediately
//     after the synchronous `session.startRunning()` returns. Motion
//     updates start on the same line so the offset stays bounded.
//   - No audio, no SSD, no JS bridge / UI surface.
//   - M4 records anchors and raw streams; per-frame motion lookup is M5.

import Foundation

#if os(iOS)

import AVFoundation
import CoreMedia
import CoreMotion
import UIKit
import Darwin.Mach

final class FilmtoneCombinedTimingSmoke: NSObject {
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
            }
        }
    }

    struct SmokeResult {
        let movURL: URL
        let jsonURL: URL
        let debugLogURL: URL
    }

    // MARK: - Public entry

    /// Run the M4 combined timing smoke once. Camera permission is requested
    /// if not already granted. Returns through `completion` on the main thread.
    static func runSmoke(duration: TimeInterval = 30.0,
                         motionMargin: TimeInterval = 1.0,
                         completion: @escaping (Result<SmokeResult, Error>) -> Void) {
        let smoke = FilmtoneCombinedTimingSmoke()
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

    // MARK: - State

    private let sessionQueue = DispatchQueue(label: "filmtone.m4.session")
    private let vdoQueue = DispatchQueue(label: "filmtone.m4.vdo")
    private let workerQueue = DispatchQueue(label: "filmtone.m4.worker")

    private let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?

    private let motion = CMMotionManager()

    /// Single serial OperationQueue shared by both raw streams. Same shape
    /// as M3 — serial FIFO ordering means the snapshot operation runs
    /// strictly after any handler operations enqueued before it, without
    /// any explicit lock on the sample arrays.
    private let motionHandlerQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "filmtone.m4.motion-handler"
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

    private var movURL: URL?
    private var jsonURL: URL?
    private var debugLogURL: URL?

    private var configuredAtBootTime: TimeInterval = 0
    private var startedAtBootTime: TimeInterval = 0
    private var stoppedAtBootTime: TimeInterval = 0
    private var requestedDuration: TimeInterval = 0
    private var motionMargin: TimeInterval = 1.0

    private var completion: ((Result<SmokeResult, Error>) -> Void)?
    private var didFinish = false

    /// Append a line to the persistent debug log so we have a record even
    /// when configureSession() throws before jsonURL is set.
    private func dlog(_ message: String) {
        NSLog("[FilmtoneM4Smoke] %@", message)
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

        if let dir = try? Self.makeCaptureDir() {
            let logURL = dir.appendingPathComponent("m4-debug.log", isDirectory: false)
            try? "[\(Date().timeIntervalSince1970)] M4 combined timing smoke begin\n"
                .data(using: .utf8)?
                .write(to: logURL, options: .atomic)
            self.debugLogURL = logURL
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

        // Pin to M2-B-validated formats[56]. No fallback: any drift from
        // the M2-B configuration would make the M4 combined evidence
        // incomparable to the M2-B PASS run.
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

        // ---- device-level configuration (must precede output attach for
        // .inputPriority semantics; mirrors M2-B exactly).
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

        // Movie codec: ProRes 422 HQ. availableVideoCodecTypes is a
        // connection-less property on AVCaptureMovieFileOutput; setOutputSettings
        // takes the connection. Same shape as M2-B.
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

        // ---- per-connection rotation + stabilization ----------------------
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

        // ---- prepare master file path -------------------------------------
        let captureDir = try Self.makeCaptureDir()
        let movURL = captureDir.appendingPathComponent("m4-master.mov", isDirectory: false)
        let jsonURL = captureDir.appendingPathComponent("m4-combined-timing-smoke.json", isDirectory: false)
        try? FileManager.default.removeItem(at: movURL)
        try? FileManager.default.removeItem(at: jsonURL)
        self.movURL = movURL
        self.jsonURL = jsonURL
    }

    private func startSessionAndMotion() {
        // Configure motion intervals before startRunning so motion is ready
        // to start the moment we capture the anchor.
        motion.gyroUpdateInterval = Self.motionRequestedInterval
        motion.accelerometerUpdateInterval = Self.motionRequestedInterval

        dlog("session.startRunning() …")
        session.startRunning()
        dlog("session.isRunning=\(session.isRunning)")

        // ----- Anchor capture --------------------------------------------
        // mach_timebase_info is process-stable, but per-snapshot reads are
        // cheap and keep the JSON self-describing.
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        anchorMachTimebaseNumer = tb.numer
        anchorMachTimebaseDenom = tb.denom

        // Snapshot mach_absolute_time and systemUptime as close together as
        // possible. ProcessInfo.systemUptime is mach_absolute_time-derived
        // on iOS, so the difference between these two reads is on the order
        // of a few hundred ns — well under the precision M5 needs for
        // mapping CMLogItem.timestamp (Hz=200, period=5ms).
        anchorStartMachAbsolute = mach_absolute_time()
        anchorStartBootUptimeSeconds = ProcessInfo.processInfo.systemUptime
        startedAtBootTime = anchorStartBootUptimeSeconds

        // Start motion updates immediately so motion overlaps the video on
        // both ends. Append-only handlers, no filtering.
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

        // Capture connection state observed after startRunning.
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
        // Snapshot recordedDuration just before stopRecording so it
        // reflects what was actually written to disk.
        movieRecordedDurationSnapshotSeconds = CMTimeGetSeconds(movieOutput.recordedDuration)
        dlog("requestStop: recordedDuration snapshot=\(movieRecordedDurationSnapshotSeconds)s")
        movieOutput.stopRecording()
        // didFinishRecordingTo delegate fires and triggers finalizeAndComplete().
    }

    private func finalizeAndComplete() {  // not `finalize` — collides with NSObject.finalize
        guard !didFinish else { return }
        didFinish = true
        dlog("finalizeAndComplete() begin")

        // Schedule motion stop motionMargin seconds after stopRecording
        // finalizes so motion overlaps the video on the trailing end.
        // Run the snapshot on workerQueue (NOT motionHandlerQueue — that
        // would deadlock waitUntilFinished).
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
        // Drain in-flight VDO sample callbacks before reading their state.
        let vdoSnapshot: [VDOSample] = vdoQueue.sync { vdoSamples }
        let vdoFirstPixelFormat = vdoQueue.sync { vdoFirstSamplePixelFormat }
        let vdoFirstDims = vdoQueue.sync { vdoFirstSampleDimensions }
        dlog("session.stopRunning() done. vdoCount=\(vdoSnapshot.count)")

        // M5 master timeline anchor = video.movieFile.startPTSSeconds.
        // Without a finite startPTS the .mov has no usable PTS↔motion
        // mapping anchor, so a delegate miss must fail the smoke even
        // when every other stream produced samples.
        let movieStartPTSValid: Bool
        if let s = movieStartPTSSeconds, s.isFinite {
            movieStartPTSValid = true
        } else {
            movieStartPTSValid = false
        }

        // Resolve recording fatality and stream / anchor health
        // independently. AVCaptureMovieFileOutput delivers a non-nil
        // `error` even on graceful stops (with
        // `AVErrorRecordingSuccessfullyFinishedKey == true`); that
        // non-fatal case must NOT short-circuit the M4 stream / anchor
        // checks (Stop Conditions require zero VDO / zero gyro / zero
        // accel / missing startPTS to fail the smoke).
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

        let resolvedError: SmokeError?
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

        writeDiagnostics(
            vdoSnapshot: vdoSnapshot,
            vdoFirstPixelFormat: vdoFirstPixelFormat,
            vdoFirstDimensions: vdoFirstDims,
            gyro: gyroSnapshot,
            accel: accelSnapshot,
            movieExists: movieExists,
            movieSize: movieSize,
            resolvedError: resolvedError
        )

        if let resolvedError {
            completion?(.failure(resolvedError))
            return
        }
        guard movieExists, let jsonURL, let movieURLOnDisk, let debugLogURL else {
            completion?(.failure(SmokeError.movieRecordingProducedNoFile))
            return
        }
        completion?(.success(SmokeResult(
            movURL: movieURLOnDisk,
            jsonURL: jsonURL,
            debugLogURL: debugLogURL
        )))
    }

    private func fail(error: Error) {
        writeDiagnostics(
            vdoSnapshot: [],
            vdoFirstPixelFormat: nil,
            vdoFirstDimensions: nil,
            gyro: [],
            accel: [],
            movieExists: false,
            movieSize: 0,
            resolvedError: error
        )
        completion?(.failure(error))
    }

    // MARK: - Filesystem

    private static func makeCaptureDir() throws -> URL {
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = caches.appendingPathComponent("Filmtone/captures", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeDiagnostics(vdoSnapshot: [VDOSample],
                                  vdoFirstPixelFormat: String?,
                                  vdoFirstDimensions: CMVideoDimensions?,
                                  gyro: [MotionSample],
                                  accel: [MotionSample],
                                  movieExists: Bool,
                                  movieSize: Int64,
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
        let mappingDict: [String: Any] = Self.computeMappingDict(
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

        var payload: [String: Any] = [
            "schemaVersion": Self.schemaVersion,
            "lane": "v2-capture-gyroflow",
            "milestone": "M4",
            "smokeLaneEnvVar": "m4",
            "duration": durationDict,
            "device": deviceDict,
            "anchor": anchorDict,
            "video": videoDict,
            "motion": motionDict,
            "mapping": mappingDict,
            "session": sessionDict,
            "timestamps": timestampsDict,
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

extension FilmtoneCombinedTimingSmoke: AVCaptureVideoDataOutputSampleBufferDelegate {
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

extension FilmtoneCombinedTimingSmoke: AVCaptureFileOutputRecordingDelegate {
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
