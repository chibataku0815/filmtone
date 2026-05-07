// Filmtone V2 capture / Gyroflow lane — M2-B Path C Dual-Output Coexistence Smoke.
//
// Records a ProRes 422 HQ Apple Log 2 master via AVCaptureMovieFileOutput
// while running AVCaptureVideoDataOutput as a timing / diagnostics side-band.
// Both outputs coexist on one AVCaptureSession (.inputPriority preset).
//
// Locked configuration (from M1):
//   - device       : AVCaptureDeviceTypeBuiltInWideAngleCamera (rear)
//   - format       : device.formats[56]
//   - colorSpace   : .appleLog2 (raw 4)
//   - dimensions   : 3840 x 2160 @ 30 fps
//   - master codec : AVVideoCodecType.proRes422HQ via AVCaptureMovieFileOutput
//
// VDO is timing-only. It does NOT write a file. Per-sample PTS is captured
// for M3/M4 timing-mapping work, and availableVideoPixelFormatTypes is
// recorded AFTER addOutput so the M2-A "connected to" ordering bug is
// resolved (TN3121).
//
// Path B (VDO + AVAssetWriter as the sole product master writer) is
// rejected — see archive/2026-05-07-m2-writer-path-decision.md.
//
// Hard invariants (M2-B boundary):
//   - DEBUG-only entry. AppDelegate runs runSmoke() under #if DEBUG only.
//   - No silent fallback. Permission, format, colorSpace, codec, and
//     output-attach failures abort the smoke loudly with a logged reason.
//   - No audio track (strategy.md: M1-M4 produce silent video).
//   - No JS bridge / UI surface in M2-B.
//   - Internal sandbox output only.

import AVFoundation
import CoreMedia
import Foundation

#if os(iOS)

final class FilmtoneCaptureWriter: NSObject {
    static let schemaVersion = 2

    enum SmokeError: Error, LocalizedError {
        case permissionDenied
        case noWideCamera
        case formatIndexOutOfRange(have: Int, want: Int)
        case appleLog2NotSupported(supportedRaw: [Int])
        case appleLog2EnumUnavailable
        case cannotAddInput
        case cannotAddMovieOutput
        case cannotAddVideoDataOutput
        case proRes422HQNotAvailable(available: [String])
        case movieRecordingFinishedWithFailure(message: String)
        case movieRecordingProducedNoFile

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Camera permission denied."
            case .noWideCamera:
                return "No rear builtInWideAngleCamera available."
            case .formatIndexOutOfRange(let have, let want):
                return "Format index \(want) out of range (have \(have))."
            case .appleLog2NotSupported(let raw):
                return "appleLog2 (raw=4) not in supportedColorSpaces \(raw)."
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
            case .movieRecordingFinishedWithFailure(let message):
                return "AVCaptureMovieFileOutput finished with error: \(message)"
            case .movieRecordingProducedNoFile:
                return "AVCaptureMovieFileOutput finished without producing a .mov file."
            }
        }
    }

    struct SmokeResult {
        let movURL: URL
        let jsonURL: URL
    }

    // MARK: - Public entry

    /// Run the M2-B Path C coexistence smoke once. Camera permission is
    /// requested if not already granted. Returns through `completion` on
    /// the main thread.
    static func runSmoke(duration: TimeInterval = 6.0,
                         completion: @escaping (Result<SmokeResult, Error>) -> Void) {
        let writer = FilmtoneCaptureWriter()
        writer.start(duration: duration) { result in
            // Hold a strong reference to `writer` until completion.
            _ = writer
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Locked configuration (from M1)

    private static let lockedFormatIndex: Int = 56
    private static let lockedWidth: Int32 = 3840
    private static let lockedHeight: Int32 = 2160
    private static let lockedFPS: Double = 30
    private static let lockedRotationAngle: CGFloat = 90  // portrait pin

    // MARK: - State

    private let sessionQueue = DispatchQueue(label: "filmtone.m2b.session")
    private let vdoQueue = DispatchQueue(label: "filmtone.m2b.vdo")

    private let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?

    private var movURL: URL?
    private var jsonURL: URL?

    // VDO side-band timing
    private var vdoFirstPTS: CMTime?
    private var vdoLastPTS: CMTime?
    private var vdoFrameCount: Int = 0
    private var vdoDroppedFrameCount: Int = 0
    private var vdoFirstSamplePixelFormat: String?
    private var vdoFirstSampleDimensions: CMVideoDimensions?

    // Movie output state
    private var movieDidStart: Bool = false
    private var movieDidFinish: Bool = false
    private var movieFinishError: Error?
    private var movieFinishedURL: URL?
    private var movieRecordingStartedAt: TimeInterval = 0
    private var movieRecordingStoppedAt: TimeInterval = 0
    private var movieDidStartSyncClockTime: CMTime?
    private var movieStopRequestedSyncClockTime: CMTime?

    // Connection state captured at startSession time
    private var requestedStabilizationRaw: Int = AVCaptureVideoStabilizationMode.off.rawValue
    private var appliedStabilizationMovieRaw: Int = -999
    private var appliedStabilizationVdoRaw: Int = -999
    private var requestedRotation: CGFloat = 0
    private var appliedMovieRotation: CGFloat = 0
    private var appliedVdoRotation: CGFloat = 0
    private var movieRotationApplied: Bool = false
    private var vdoRotationApplied: Bool = false

    // Session-level diagnostics
    private var hardwareCostAfterCommit: Float = -1
    private var synchronizationClockDescription: String = "(none)"
    private var availableMovieCodecTypes: [String] = []
    private var availableVideoPixelFormatTypesAfterAdd: [String] = []
    private var sessionPresetAfterCommit: String = ""

    private var configuredAtBootTime: TimeInterval = 0
    private var startedAtBootTime: TimeInterval = 0
    private var stoppedAtBootTime: TimeInterval = 0
    private var requestedDuration: TimeInterval = 0

    private var completion: ((Result<SmokeResult, Error>) -> Void)?
    private var didFinish = false
    private var debugLogURL: URL?

    /// Append a line to the persistent debug log so we have a record even
    /// when configureSession() throws before jsonURL is set. Best-effort —
    /// failures here are silently ignored.
    private func dlog(_ message: String) {
        NSLog("[FilmtoneM2BSmoke] %@", message)
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
                       completion: @escaping (Result<SmokeResult, Error>) -> Void) {
        self.completion = completion
        self.requestedDuration = duration

        if let dir = try? Self.makeCaptureDir() {
            let logURL = dir.appendingPathComponent("m2b-debug.log", isDirectory: false)
            try? "[\(Date().timeIntervalSince1970)] M2-B Path C smoke begin\n"
                .data(using: .utf8)?
                .write(to: logURL, options: .atomic)
            self.debugLogURL = logURL
        }
        dlog("start() requesting camera authorization (status=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue))")
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
                    self.startSession()
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
            throw SmokeError.formatIndexOutOfRange(have: wide.formats.count, want: Self.lockedFormatIndex)
        }
        let lockedFormat = wide.formats[Self.lockedFormatIndex]
        let supportedRaw = lockedFormat.supportedColorSpaces.map { $0.rawValue }
        let rawJoined = supportedRaw.map { String($0) }.joined(separator: ",")
        dlog("formats[\(Self.lockedFormatIndex)].supportedColorSpaces (raw)=\(rawJoined)")
        guard supportedRaw.contains(4) else {
            throw SmokeError.appleLog2NotSupported(supportedRaw: supportedRaw)
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

        // Step: add input BEFORE setting activeFormat / activeColorSpace.
        // Apple TN3121: availableVideoPixelFormatTypes is "dynamic, and
        // depends on the activeFormat of the capture device that the
        // AVCaptureVideoDataOutput is connected to". The "connected to"
        // chain only exists once the device's input is on the session.
        let input = try AVCaptureDeviceInput(device: wide)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw SmokeError.cannotAddInput
        }
        session.addInput(input)
        self.input = input
        dlog("session.addInput(wide) OK")

        // ---- device-level configuration -----------------------------------
        // Apple `.inputPriority` doc: "When you change the device's format,
        // the session preset automatically changes to this value." We set
        // .inputPriority explicitly above too, so the eventual preset is
        // unambiguous.
        try wide.lockForConfiguration()
        wide.activeFormat = lockedFormat
        wide.activeColorSpace = appleLog2
        dlog("activeFormat=formats[\(Self.lockedFormatIndex)], activeColorSpace=appleLog2 applied")
        let frameDuration = CMTime(value: 1, timescale: 30)
        if lockedFormat.videoSupportedFrameRateRanges.contains(where: {
            $0.minFrameRate <= Self.lockedFPS && Self.lockedFPS <= $0.maxFrameRate
        }) {
            wide.activeVideoMinFrameDuration = frameDuration
            wide.activeVideoMaxFrameDuration = frameDuration
            dlog("activeVideoMin/MaxFrameDuration=1/30 applied")
        }
        wide.unlockForConfiguration()

        // ---- AVCaptureMovieFileOutput as ProRes Apple Log 2 master --------
        let movieOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(movieOutput) else {
            session.commitConfiguration()
            throw SmokeError.cannotAddMovieOutput
        }
        session.addOutput(movieOutput)
        self.movieOutput = movieOutput
        dlog("session.addOutput(movieFileOutput) OK")

        // Movie codec: ProRes 422 HQ. availableVideoCodecTypes is dynamic
        // and only valid AFTER addOutput when the connection exists.
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

        // ---- AVCaptureVideoDataOutput as timing / diagnostics side-band --
        let vdo = AVCaptureVideoDataOutput()
        // Leave videoSettings = nil so VDO uses the device's native delivery
        // (no transcode). We're not writing through VDO; we only need PTS
        // and a record of what the device actually delivers under
        // .appleLog2 + format[\(Self.lockedFormatIndex)] post-addOutput.
        vdo.alwaysDiscardsLateVideoFrames = false
        vdo.setSampleBufferDelegate(self, queue: vdoQueue)
        guard session.canAddOutput(vdo) else {
            session.commitConfiguration()
            throw SmokeError.cannotAddVideoDataOutput
        }
        session.addOutput(vdo)
        self.videoDataOutput = vdo
        dlog("session.addOutput(videoDataOutput) OK")

        // Step: query availableVideoPixelFormatTypes ONLY AFTER addOutput.
        // M2-A queried before addOutput, so it saw a stale (pre-connection)
        // list. Per TN3121 this is the correct ordering. We log the result
        // as observation; this smoke does not fail on it because VDO is
        // timing-only.
        let availableTypes = vdo.availableVideoPixelFormatTypes
        availableVideoPixelFormatTypesAfterAdd = availableTypes.map { Self.fourCC($0) }
        let availableHex = availableTypes
            .map { String(format: "%@(0x%08x)", Self.fourCC($0), $0) }
            .joined(separator: ",")
        dlog("[post-addOutput] vdo.availableVideoPixelFormatTypes=\(availableHex)")

        // ---- per-connection rotation + stabilization ----------------------
        // Both outputs share the same physical pipeline, but each has its
        // own AVCaptureConnection. Configure them symmetrically.
        requestedRotation = Self.lockedRotationAngle
        requestedStabilizationRaw = AVCaptureVideoStabilizationMode.off.rawValue

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
        let movURL = captureDir.appendingPathComponent("m2b-master.mov", isDirectory: false)
        let jsonURL = captureDir.appendingPathComponent("m2b-coexistence-smoke.json", isDirectory: false)
        try? FileManager.default.removeItem(at: movURL)
        try? FileManager.default.removeItem(at: jsonURL)
        self.movURL = movURL
        self.jsonURL = jsonURL
    }

    private func startSession() {
        startedAtBootTime = ProcessInfo.processInfo.systemUptime
        dlog("session.startRunning() …")
        session.startRunning()
        dlog("session.isRunning=\(session.isRunning)")

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
        movieRecordingStartedAt = ProcessInfo.processInfo.systemUptime
        movieOutput.startRecording(to: movURL, recordingDelegate: self)
        dlog("movieOutput.startRecording(to: \(movURL.lastPathComponent)) requested")

        sessionQueue.asyncAfter(deadline: .now() + requestedDuration) { [weak self] in
            self?.requestStop()
        }
    }

    private func requestStop() {
        guard !didFinish else { return }
        movieRecordingStoppedAt = ProcessInfo.processInfo.systemUptime
        if let syncClock = session.synchronizationClock {
            movieStopRequestedSyncClockTime = CMClockGetTime(syncClock)
        }
        dlog("movieOutput.stopRecording() requested at sysUptime=\(movieRecordingStoppedAt)")
        movieOutput?.stopRecording()
        // didFinishRecordingTo delegate will fire and triggers finalizeAndComplete().
    }

    private func finalizeAndComplete() {  // not `finalize` — collides with NSObject.finalize
        guard !didFinish else { return }
        didFinish = true
        stoppedAtBootTime = ProcessInfo.processInfo.systemUptime
        session.stopRunning()
        // Flush in-flight VDO sample callbacks before reading their state.
        // session.stopRunning() prevents new buffers from being delivered;
        // vdoQueue.sync { } drains any callback already enqueued. Without
        // this, vdoFirstPTS / vdoLastPTS / vdoFrameCount /
        // vdoFirstSampleDimensions are read on sessionQueue while still
        // being mutated on vdoQueue (CMVideoDimensions is a 2-word struct,
        // so torn reads are possible).
        vdoQueue.sync { }
        dlog("session.stopRunning() + vdoQueue drain done. finalize.")

        let resolvedError: SmokeError?
        if let movieFinishError {
            // AVCaptureFileOutputRecordingDelegate reports an error even on
            // graceful stopRecording when the file is fully usable, with
            // userInfo[AVErrorRecordingSuccessfullyFinishedKey] = true. We
            // only treat hard failures as fatal here.
            let nsError = movieFinishError as NSError
            let userInfo = nsError.userInfo
            let succeededFlag = userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool
            if succeededFlag == true {
                resolvedError = nil
            } else {
                resolvedError = .movieRecordingFinishedWithFailure(message: nsError.localizedDescription)
            }
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
        dlog("master mov exists=\(movieExists) size=\(movieSize)")

        writeDiagnostics(movieExists: movieExists, movieSize: movieSize, resolvedError: resolvedError)

        if let resolvedError {
            completion?(.failure(resolvedError))
            return
        }
        guard movieExists, let jsonURL, let movieURLOnDisk else {
            completion?(.failure(SmokeError.movieRecordingProducedNoFile))
            return
        }
        completion?(.success(SmokeResult(movURL: movieURLOnDisk, jsonURL: jsonURL)))
    }

    private func fail(error: Error) {
        // Best-effort diagnostics on early failures.
        writeDiagnostics(movieExists: false, movieSize: 0, resolvedError: error)
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

    private func writeDiagnostics(movieExists: Bool, movieSize: Int64, resolvedError: Error?) {
        guard let jsonURL else { return }
        let payload = makeDiagnosticsPayload(movieExists: movieExists, movieSize: movieSize, resolvedError: resolvedError)
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

    private func makeDiagnosticsPayload(movieExists: Bool, movieSize: Int64, resolvedError: Error?) -> [String: Any] {
        // Built incrementally to keep the Swift type checker fast — one big
        // nested dict literal trips "compiler is unable to type-check this
        // expression in reasonable time".
        let sessionDict: [String: Any] = [
            "presetAfterCommit": sessionPresetAfterCommit,
            "hardwareCostAfterCommit": hardwareCostAfterCommit,
            "synchronizationClock": synchronizationClockDescription,
            "automaticallyConfiguresCaptureDeviceForWideColor": false,
        ]
        let selectedFormatDict: [String: Any] = [
            "formatIndex": Self.lockedFormatIndex,
            "dimensions": [
                "width": Self.lockedWidth,
                "height": Self.lockedHeight,
            ],
            "fps": Self.lockedFPS,
            "colorSpace": "appleLog2",
            "colorSpaceRawValue": 4,
        ]
        let movieRotation: [String: Any] = [
            "requestedAngle": requestedRotation,
            "appliedAngle": appliedMovieRotation,
            "applied": movieRotationApplied,
        ]
        let movieStabilization: [String: Any] = [
            "requested": Self.stabilizationName(requestedStabilizationRaw),
            "requestedRaw": requestedStabilizationRaw,
            "applied": Self.stabilizationName(appliedStabilizationMovieRaw),
            "appliedRaw": appliedStabilizationMovieRaw,
        ]
        let movieDict: [String: Any] = [
            "outputPath": movURL?.path ?? "",
            "outputURL": movieFinishedURL?.path ?? movURL?.path ?? "",
            "fileExists": movieExists,
            "fileSizeBytes": movieSize,
            "didStart": movieDidStart,
            "didFinish": movieDidFinish,
            "finishError": movieFinishError?.localizedDescription ?? NSNull(),
            "availableVideoCodecTypes": availableMovieCodecTypes,
            "selectedCodec": AVVideoCodecType.proRes422HQ.rawValue,
            "didStartSyncClockTime": movieDidStartSyncClockTime.map(Self.ptsToDict) ?? NSNull(),
            "stopRequestedSyncClockTime": movieStopRequestedSyncClockTime.map(Self.ptsToDict) ?? NSNull(),
            "recordingStartedAtBootTime": movieRecordingStartedAt,
            "recordingStoppedAtBootTime": movieRecordingStoppedAt,
            "rotation": movieRotation,
            "stabilization": movieStabilization,
        ]
        let vdoRotation: [String: Any] = [
            "requestedAngle": requestedRotation,
            "appliedAngle": appliedVdoRotation,
            "applied": vdoRotationApplied,
        ]
        let vdoStabilization: [String: Any] = [
            "requested": Self.stabilizationName(requestedStabilizationRaw),
            "requestedRaw": requestedStabilizationRaw,
            "applied": Self.stabilizationName(appliedStabilizationVdoRaw),
            "appliedRaw": appliedStabilizationVdoRaw,
        ]
        let firstSampleDimsAny: Any = vdoFirstSampleDimensions.map {
            ["width": Int($0.width), "height": Int($0.height)] as [String: Any]
        } ?? NSNull()
        let vdoDict: [String: Any] = [
            "frameCount": vdoFrameCount,
            "droppedFrameCount": vdoDroppedFrameCount,
            "firstSamplePTS": vdoFirstPTS.map(Self.ptsToDict) ?? NSNull(),
            "lastSamplePTS": vdoLastPTS.map(Self.ptsToDict) ?? NSNull(),
            "firstSamplePixelFormat": vdoFirstSamplePixelFormat ?? NSNull(),
            "firstSampleDimensions": firstSampleDimsAny,
            "availableVideoPixelFormatTypesAfterAdd": availableVideoPixelFormatTypesAfterAdd,
            "rotation": vdoRotation,
            "stabilization": vdoStabilization,
        ]
        let durationDict: [String: Any] = [
            "requestedSeconds": requestedDuration,
            "elapsedSeconds": stoppedAtBootTime > startedAtBootTime
                ? stoppedAtBootTime - startedAtBootTime
                : 0,
        ]
        let timestampsDict: [String: Any] = [
            "configuredAtBootTime": configuredAtBootTime,
            "startedAtBootTime": startedAtBootTime,
            "stoppedAtBootTime": stoppedAtBootTime,
        ]
        var payload: [String: Any] = [
            "schemaVersion": Self.schemaVersion,
            "lane": "v2-capture-gyroflow",
            "milestone": "M2-B",
            "writerPath": "Path C — AVCaptureMovieFileOutput master + AVCaptureVideoDataOutput timing side-band",
            "session": sessionDict,
            "selectedFormat": selectedFormatDict,
            "movieFileOutput": movieDict,
            "videoDataOutputSideBand": vdoDict,
            "duration": durationDict,
            "timestamps": timestampsDict,
            "smokeError": resolvedError?.localizedDescription ?? NSNull(),
        ]
        if let device {
            payload["device"] = [
                "uniqueID": device.uniqueID,
                "deviceType": device.deviceType.rawValue,
                "localizedName": device.localizedName,
            ]
        }
        return payload
    }

    private static func ptsToDict(_ pts: CMTime) -> [String: Any] {
        return [
            "value": pts.value,
            "timescale": pts.timescale,
            "seconds": CMTimeGetSeconds(pts),
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
}

// MARK: - VDO sample buffer delegate (timing side-band)

extension FilmtoneCaptureWriter: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if vdoFirstPTS == nil {
            vdoFirstPTS = pts
            if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
                let pf = CMFormatDescriptionGetMediaSubType(formatDescription)
                vdoFirstSamplePixelFormat = Self.fourCC(pf)
                vdoFirstSampleDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            }
            dlog("vdo first sample pts=\(CMTimeGetSeconds(pts)) pixelFormat=\(vdoFirstSamplePixelFormat ?? "?")")
        }
        vdoLastPTS = pts
        vdoFrameCount += 1
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        vdoDroppedFrameCount += 1
    }
}

// MARK: - MovieFileOutput recording delegate

extension FilmtoneCaptureWriter: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        movieDidStart = true
        if let syncClock = session.synchronizationClock {
            movieDidStartSyncClockTime = CMClockGetTime(syncClock)
        }
        dlog("movieFileOutput didStartRecordingTo \(fileURL.lastPathComponent)")
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
