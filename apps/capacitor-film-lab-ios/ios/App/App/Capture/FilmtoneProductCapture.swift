// Filmtone V2 product capture surface — M7 bootstrap.
//
// First non-DEBUG, non-Smoke capture surface. Records one fixed-duration
// ProRes 422 HQ Apple Log 2 clip via AVCaptureMovieFileOutput with
// AVFoundation cinematicExtendedEnhanced stabilization wired from the
// first commit. No VDO, no CMMotionManager, no .gcsv, no env-var probing.
//
// Design is locked by owner OK 2026-05-07 (active.md subtask 3):
//   - recordClip(durationSeconds:) — 1-shot fixed-duration per call.
//   - start/stop pair is M7+ (out of scope here).
//   - Native UI is zero; entry is Capacitor plugin only.
//   - All failure cases are loud-fail with distinct FILMTONE_PRODUCT_CAPTURE_*
//     codes. Silent fallback is a hard antipattern.
//   - durationSeconds outside [1.0, 60.0] is a loud reject — never clamped.
//
// Package layout: Caches/Filmtone/captures/product-capture-<UUID>/
//   - clip.mov        (ProRes 422 HQ Apple Log 2)
//   - diagnostics.json (fixed ~17-field dictionary, same copy as plugin response)

import Foundation

#if os(iOS)

import AVFoundation
import CoreMedia
import UIKit

final class FilmtoneProductCapture: NSObject {

    // MARK: - Schema

    static let schemaVersion: Int = 1

    // MARK: - Duration bounds (locked M7; owner can re-tune in follow-up)

    /// Minimum accepted duration (seconds). Floor for stabilization + recording infra settle.
    static let minDurationSeconds: Double = 1.0

    /// Maximum accepted duration (seconds). 60s ≈ 4K ProRes 422 HQ ≈ 3.5 GB cap.
    static let maxDurationSeconds: Double = 60.0

    // MARK: - Error enum

    enum RecordClipError: Error, LocalizedError {
        case permissionDenied
        case noWideCamera
        case formatSelectionFailed(reason: String)
        case appleLog2EnumUnavailable
        case cannotAddInput
        case cannotAddMovieOutput
        case proRes422HQNotAvailable(available: [String])
        case unsupportedStabilizationModeForFormat(supported: [String])
        case stabilizationActiveModeOff(active: String)
        case stabilizationColorSpaceDowngraded(expectedRaw: Int, observedRaw: Int)
        case proRes422HQCodecDowngraded(observed: String?)
        case actualCodecReadFailed(message: String)
        case durationOutOfBounds(requestedSeconds: Double)
        case recordingFinishFailed(message: String)
        case movieRecordingProducedNoFile
        case packageDirCreationFailed(message: String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Camera permission denied."
            case .noWideCamera:
                return "No rear builtInWideAngleCamera available."
            case .formatSelectionFailed(let reason):
                return "M5-A validated format mismatch: \(reason)"
            case .appleLog2EnumUnavailable:
                return "AVCaptureColorSpace(rawValue: 4) returned nil on this OS."
            case .cannotAddInput:
                return "AVCaptureSession.canAddInput returned false."
            case .cannotAddMovieOutput:
                return "AVCaptureSession.canAddOutput(movieFileOutput) returned false."
            case .proRes422HQNotAvailable(let available):
                return "AVVideoCodecType.proRes422HQ not in availableVideoCodecTypes: \(available)."
            case .unsupportedStabilizationModeForFormat(let supported):
                return "cinematicExtendedEnhanced not supported on M5-A locked format. Supported: \(supported.joined(separator: "|"))."
            case .stabilizationActiveModeOff(let active):
                return "Stop Condition: preferredVideoStabilizationMode=cinematicExtendedEnhanced but activeVideoStabilizationMode=\(active) after startRecording. AVFoundation silently rejected the mode — no auto-fallback."
            case .stabilizationColorSpaceDowngraded(let expectedRaw, let observedRaw):
                return "Stop Condition: device.activeColorSpace.rawValue=\(observedRaw) (expected \(expectedRaw) = AppleLog2). Stabilization engagement caused a silent color-space downgrade."
            case .proRes422HQCodecDowngraded(let observed):
                let observedStr = observed ?? "<unread>"
                return "Stop Condition: recorded .mov video track mediaSubType=\(observedStr) (expected apch = proRes422HQ). AVFoundation silently downgraded the writer codec."
            case .actualCodecReadFailed(let message):
                return "Failed to read actual mediaSubType from recorded .mov via AVURLAsset: \(message)."
            case .durationOutOfBounds(let requested):
                return "durationSeconds=\(requested) is outside accepted bounds [\(FilmtoneProductCapture.minDurationSeconds), \(FilmtoneProductCapture.maxDurationSeconds)]. Loud reject — not clamped."
            case .recordingFinishFailed(let message):
                return "AVCaptureMovieFileOutput finished with error: \(message)"
            case .movieRecordingProducedNoFile:
                return "AVCaptureMovieFileOutput finished without producing a .mov file."
            case .packageDirCreationFailed(let message):
                return "Failed to create product capture package directory: \(message)"
            }
        }
    }

    // MARK: - Result type

    struct RecordClipResult {
        let packageDirURL: URL
        let movURL: URL
        let diagnosticsURL: URL
        let diagnosticsDict: [String: Any]
    }

    // MARK: - Locked configuration (M5-A validated, verbatim from smoke)

    private static let lockedFormatIndex: Int = 56
    private static let lockedWidth: Int32 = 3840
    private static let lockedHeight: Int32 = 2160
    private static let lockedFPS: Double = 30
    private static let lockedRotationAngle: CGFloat = 90  // portrait pin
    private static let appleLog2ColorSpaceRaw: Int = 4

    // Candidate modes to probe for the supportedStabilizationModes diagnostic field.
    private static let candidateStabilizationModes: [AVCaptureVideoStabilizationMode] = [
        .off,
        .standard,
        .cinematic,
        .cinematicExtended,
        .cinematicExtendedEnhanced,
        .auto,
    ]

    // MARK: - State

    private let sessionQueue = DispatchQueue(label: "filmtone.product.session")
    private let workerQueue = DispatchQueue(label: "filmtone.product.worker")

    private let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var movieOutput: AVCaptureMovieFileOutput?

    // Movie output state.
    private var movieDidStart: Bool = false
    private var movieDidFinish: Bool = false
    private var movieFinishError: Error?
    private var movieFinishedURL: URL?
    private var movieRecordedDurationSnapshotSeconds: Double = 0

    // Active-mode + colorSpace snapshots captured in didStartRecordingTo delegate.
    private var appliedStabilizationMovieRaw: Int = -999
    private var colorSpaceRawAfterRecordStart: Int = -999
    private var activeFormatMatchesLockedAfterRecordStart: Bool = false

    // Supported stabilization modes probed during configureSession.
    private var supportedStabilizationModes: [AVCaptureVideoStabilizationMode] = []

    // AVURLAsset codec probe result.
    private var actualMovieMediaSubType: String?
    private var actualMovieMediaSubTypeReadError: String?

    // Session diagnostics.
    private var hardwareCostAfterCommit: Float = -1
    private var sessionPresetAfterCommit: String = ""
    private var availableMovieCodecTypes: [String] = []

    // Package paths.
    private var packageUUID: String = ""
    private var packageDirURL: URL?
    private var movURL: URL?
    private var diagnosticsURL: URL?

    // Timing.
    private var startedAtBootTime: TimeInterval = 0
    private var stoppedAtBootTime: TimeInterval = 0
    private var requestedDurationSeconds: Double = 0

    private var completion: ((Result<RecordClipResult, Error>) -> Void)?
    private var didFinish = false

    // MARK: - Public entry

    /// Record one fixed-duration clip. `durationSeconds` must be in [1.0, 60.0];
    /// out-of-bounds is a loud reject — never clamped. Calls `completion` once
    /// on an unspecified queue; plugin wraps on MainActor.
    func recordClip(durationSeconds: Double,
                    completion: @escaping (Result<RecordClipResult, Error>) -> Void) {
        self.completion = completion

        // Duration validation BEFORE any AVCaptureSession state.
        guard durationSeconds >= Self.minDurationSeconds && durationSeconds <= Self.maxDurationSeconds else {
            completion(.failure(RecordClipError.durationOutOfBounds(requestedSeconds: durationSeconds)))
            return
        }
        self.requestedDurationSeconds = durationSeconds

        // Create package directory directly in final path (no staging-then-rename).
        let uuid = UUID().uuidString.lowercased()
        self.packageUUID = uuid
        do {
            let dirs = try Self.makeProductPackageDir(uuid: uuid)
            self.packageDirURL = dirs.packageDir
            self.movURL = dirs.movURL
            self.diagnosticsURL = dirs.diagnosticsURL
        } catch {
            completion(.failure(RecordClipError.packageDirCreationFailed(message: error.localizedDescription)))
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.completion?(.failure(RecordClipError.permissionDenied))
                return
            }
            self.sessionQueue.async {
                do {
                    try self.configureSession()
                    self.startSessionAndRecord()
                } catch {
                    self.fail(error: error)
                }
            }
        }
    }

    // MARK: - Session configuration

    private func configureSession() throws {
        guard let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw RecordClipError.noWideCamera
        }

        guard wide.formats.indices.contains(Self.lockedFormatIndex) else {
            throw RecordClipError.formatSelectionFailed(reason:
                "device.formats has \(wide.formats.count) entries, need index \(Self.lockedFormatIndex).")
        }
        let lockedFormat = wide.formats[Self.lockedFormatIndex]

        let supportedColorSpaceRaw = lockedFormat.supportedColorSpaces.map { $0.rawValue }
        guard supportedColorSpaceRaw.contains(Self.appleLog2ColorSpaceRaw) else {
            throw RecordClipError.formatSelectionFailed(reason:
                "formats[\(Self.lockedFormatIndex)].supportedColorSpaces does not contain appleLog2 (raw=4); have \(supportedColorSpaceRaw).")
        }

        let dims = CMVideoFormatDescriptionGetDimensions(lockedFormat.formatDescription)
        guard dims.width == Self.lockedWidth, dims.height == Self.lockedHeight else {
            throw RecordClipError.formatSelectionFailed(reason:
                "formats[\(Self.lockedFormatIndex)] dimensions are \(dims.width)x\(dims.height); need \(Self.lockedWidth)x\(Self.lockedHeight).")
        }

        let fpsOk = lockedFormat.videoSupportedFrameRateRanges.contains {
            $0.minFrameRate <= Self.lockedFPS && Self.lockedFPS <= $0.maxFrameRate
        }
        guard fpsOk else {
            throw RecordClipError.formatSelectionFailed(reason:
                "formats[\(Self.lockedFormatIndex)] does not support \(Self.lockedFPS) fps.")
        }

        guard let appleLog2 = AVCaptureColorSpace(rawValue: Self.appleLog2ColorSpaceRaw) else {
            throw RecordClipError.appleLog2EnumUnavailable
        }
        self.device = wide

        // Session configuration.
        session.beginConfiguration()
        session.sessionPreset = .inputPriority
        session.automaticallyConfiguresCaptureDeviceForWideColor = false

        let input = try AVCaptureDeviceInput(device: wide)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw RecordClipError.cannotAddInput
        }
        session.addInput(input)

        try wide.lockForConfiguration()
        wide.activeFormat = lockedFormat
        wide.activeColorSpace = appleLog2
        let frameDuration = CMTime(value: 1, timescale: 30)
        wide.activeVideoMinFrameDuration = frameDuration
        wide.activeVideoMaxFrameDuration = frameDuration
        wide.unlockForConfiguration()

        // AVCaptureMovieFileOutput for ProRes 422 HQ.
        let movieOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(movieOutput) else {
            session.commitConfiguration()
            throw RecordClipError.cannotAddMovieOutput
        }
        session.addOutput(movieOutput)
        self.movieOutput = movieOutput

        let movieConnection = movieOutput.connection(with: .video)
        let availableCodecs = movieOutput.availableVideoCodecTypes.map { $0.rawValue }
        self.availableMovieCodecTypes = availableCodecs
        guard availableCodecs.contains(AVVideoCodecType.proRes422HQ.rawValue) else {
            session.commitConfiguration()
            throw RecordClipError.proRes422HQNotAvailable(available: availableCodecs)
        }

        if let movieConnection {
            movieOutput.setOutputSettings(
                [AVVideoCodecKey: AVVideoCodecType.proRes422HQ],
                for: movieConnection
            )
        }

        // Stabilization probe: record supported set, then apply locked mode.
        // Product locks .cinematicExtendedEnhanced only — no env-var, no multi-mode array.
        let supportedModes = Self.candidateStabilizationModes.filter {
            lockedFormat.isVideoStabilizationModeSupported($0)
        }
        self.supportedStabilizationModes = supportedModes
        let supportedNames = supportedModes.map { Self.stabilizationName($0.rawValue) }

        guard supportedModes.contains(.cinematicExtendedEnhanced) else {
            session.commitConfiguration()
            throw RecordClipError.unsupportedStabilizationModeForFormat(supported: supportedNames)
        }

        if let movieConnection {
            if movieConnection.isVideoRotationAngleSupported(Self.lockedRotationAngle) {
                movieConnection.videoRotationAngle = Self.lockedRotationAngle
            }
            if movieConnection.isVideoStabilizationSupported {
                movieConnection.preferredVideoStabilizationMode = .cinematicExtendedEnhanced
            }
        }

        session.commitConfiguration()
        self.sessionPresetAfterCommit = session.sessionPreset.rawValue
        self.hardwareCostAfterCommit = session.hardwareCost
    }

    // MARK: - Session start + duration timer

    private func startSessionAndRecord() {
        session.startRunning()
        startedAtBootTime = ProcessInfo.processInfo.systemUptime

        guard let movieOutput, let movURL else {
            fail(error: RecordClipError.cannotAddMovieOutput)
            return
        }

        movieOutput.startRecording(to: movURL, recordingDelegate: self)

        // Fixed-duration timer: fires on sessionQueue, stops recording.
        sessionQueue.asyncAfter(deadline: .now() + requestedDurationSeconds) { [weak self] in
            self?.requestStop()
        }
    }

    private func requestStop() {
        guard !didFinish else { return }
        guard let movieOutput else { return }
        movieRecordedDurationSnapshotSeconds = CMTimeGetSeconds(movieOutput.recordedDuration)
        movieOutput.stopRecording()
        // didFinishRecordingTo fires and triggers finalizeAndComplete().
    }

    // MARK: - Finalize

    private func finalizeAndComplete() {
        guard !didFinish else { return }
        didFinish = true

        workerQueue.async { [weak self] in
            self?.assemble()
        }
    }

    private func assemble() {
        stoppedAtBootTime = ProcessInfo.processInfo.systemUptime
        session.stopRunning()

        // Two-phase resolvedError (M4 P2 fix pattern): recording-fatal vs
        // downstream checks are independent. Non-nil error with
        // AVErrorRecordingSuccessfullyFinishedKey == true is non-fatal.
        let recordingFatalError: RecordClipError?
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

        var resolvedError: RecordClipError?

        if let recordingFatalError {
            resolvedError = recordingFatalError
        } else if appliedStabilizationMovieRaw == AVCaptureVideoStabilizationMode.off.rawValue {
            // Stop Condition (a): preferred was cinematicExtendedEnhanced but
            // AVFoundation resolved active to .off after startRecording.
            resolvedError = .stabilizationActiveModeOff(
                active: Self.stabilizationName(appliedStabilizationMovieRaw)
            )
        } else if colorSpaceRawAfterRecordStart != -999
                    && colorSpaceRawAfterRecordStart != Self.appleLog2ColorSpaceRaw {
            // Stop Condition (c): Apple Log 2 silently downgraded.
            resolvedError = .stabilizationColorSpaceDowngraded(
                expectedRaw: Self.appleLog2ColorSpaceRaw,
                observedRaw: colorSpaceRawAfterRecordStart
            )
        }

        // Stop Condition (d): AVURLAsset codec read after recording finishes.
        let movieURLOnDisk = movieFinishedURL ?? movURL
        let movieExists: Bool
        let movieSizeBytes: Int64
        if let movieURLOnDisk,
           let attrs = try? FileManager.default.attributesOfItem(atPath: movieURLOnDisk.path) {
            movieExists = true
            movieSizeBytes = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        } else {
            movieExists = false
            movieSizeBytes = 0
        }

        if movieExists, let movieURLOnDisk {
            let probe = Self.readActualMovieMediaSubType(url: movieURLOnDisk)
            self.actualMovieMediaSubType = probe.subType
            self.actualMovieMediaSubTypeReadError = probe.errorMessage
        }

        if resolvedError == nil {
            if let observed = actualMovieMediaSubType {
                if observed != AVVideoCodecType.proRes422HQ.rawValue {
                    resolvedError = .proRes422HQCodecDowngraded(observed: observed)
                }
            } else if movieExists {
                resolvedError = .actualCodecReadFailed(
                    message: actualMovieMediaSubTypeReadError ?? "unknown"
                )
            }
        }

        // Build diagnostics dictionary.
        let diagDict = makeDiagnosticsDict(movieSizeBytes: movieSizeBytes, resolvedError: resolvedError)

        // Write diagnostics.json next to the clip.
        if let diagnosticsURL {
            do {
                let data = try JSONSerialization.data(
                    withJSONObject: diagDict,
                    options: [.prettyPrinted, .sortedKeys]
                )
                try data.write(to: diagnosticsURL, options: .atomic)
            } catch {
                NSLog("[FilmtoneProductCapture] diagnostics write failed: %@", error.localizedDescription)
            }
        }

        if let resolvedError {
            completion?(.failure(resolvedError))
            return
        }

        guard movieExists,
              let packageDirURL,
              let finalMovURL = movieURLOnDisk,
              let finalDiagURL = diagnosticsURL else {
            completion?(.failure(RecordClipError.movieRecordingProducedNoFile))
            return
        }

        completion?(.success(RecordClipResult(
            packageDirURL: packageDirURL,
            movURL: finalMovURL,
            diagnosticsURL: finalDiagURL,
            diagnosticsDict: diagDict
        )))
    }

    private func fail(error: Error) {
        let resolvedClipError: RecordClipError
        if let e = error as? RecordClipError {
            resolvedClipError = e
        } else {
            resolvedClipError = .recordingFinishFailed(message: error.localizedDescription)
        }
        // Write partial diagnostics even on early failure for debug evidence.
        let diagDict = makeDiagnosticsDict(movieSizeBytes: 0, resolvedError: resolvedClipError)
        if let diagnosticsURL {
            if let data = try? JSONSerialization.data(withJSONObject: diagDict, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: diagnosticsURL, options: .atomic)
            }
        }
        completion?(.failure(resolvedClipError))
    }

    // MARK: - Diagnostics

    private func makeDiagnosticsDict(movieSizeBytes: Int64, resolvedError: RecordClipError?) -> [String: Any] {
        let uiDevice = UIDevice.current
        let supportedNames = supportedStabilizationModes.map { Self.stabilizationName($0.rawValue) }

        let diagDict: [String: Any] = [
            "schemaVersion": Self.schemaVersion,
            "deviceModel": Self.utsnameMachine(),
            "iosVersion": uiDevice.systemVersion,
            "lockedFormatIndex": Self.lockedFormatIndex,
            "lockedDimensions": "\(Self.lockedWidth)x\(Self.lockedHeight)",
            "lockedFPS": Int(Self.lockedFPS),
            "preferredStabilizationMode": "cinematicExtendedEnhanced",
            "preferredStabilizationModeRaw": AVCaptureVideoStabilizationMode.cinematicExtendedEnhanced.rawValue,
            "supportedStabilizationModes": supportedNames,
            "appliedStabilizationMode": Self.stabilizationName(appliedStabilizationMovieRaw),
            "appliedStabilizationModeRaw": appliedStabilizationMovieRaw,
            "activeColorSpaceRaw": colorSpaceRawAfterRecordStart,
            "activeFormatMatchesLockedAfterRecordStart": activeFormatMatchesLockedAfterRecordStart,
            "actualMediaSubType": actualMovieMediaSubType ?? NSNull(),
            "actualMediaSubTypeReadError": actualMovieMediaSubTypeReadError ?? NSNull(),
            "movPath": movURL?.path ?? "",
            "movSizeBytes": movieSizeBytes,
            "requestedDurationSeconds": requestedDurationSeconds,
            "recordedDurationSeconds": movieRecordedDurationSnapshotSeconds,
            "startedAtBootTime": startedAtBootTime,
            "stoppedAtBootTime": stoppedAtBootTime,
            "hardwareCost": hardwareCostAfterCommit,
            "sessionPreset": sessionPresetAfterCommit,
            "captureError": resolvedError?.localizedDescription ?? NSNull(),
        ]
        return diagDict
    }

    // MARK: - Filesystem helpers

    private struct ProductPackagePaths {
        let packageDir: URL
        let movURL: URL
        let diagnosticsURL: URL
    }

    private static func makeProductPackageDir(uuid: String) throws -> ProductPackagePaths {
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let captures = caches.appendingPathComponent("Filmtone/captures", isDirectory: true)
        try FileManager.default.createDirectory(at: captures, withIntermediateDirectories: true)
        let packageDir = captures.appendingPathComponent("product-capture-\(uuid)", isDirectory: true)
        try? FileManager.default.removeItem(at: packageDir)
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)
        let movURL = packageDir.appendingPathComponent("clip.mov", isDirectory: false)
        let diagnosticsURL = packageDir.appendingPathComponent("diagnostics.json", isDirectory: false)
        return ProductPackagePaths(packageDir: packageDir, movURL: movURL, diagnosticsURL: diagnosticsURL)
    }

    // MARK: - AVURLAsset codec probe (verbatim from smoke L1597-1641)

    private struct CodecProbeResult {
        let subType: String?
        let errorMessage: String?
    }

    private static func readActualMovieMediaSubType(url: URL) -> CodecProbeResult {
        let asset = AVURLAsset(url: url)
        let semaphore = DispatchSemaphore(value: 0)
        var subType: String?
        var errorMessage: String?
        Task {
            defer { semaphore.signal() }
            do {
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard let track = tracks.first else {
                    errorMessage = "AVURLAsset reports zero video tracks"
                    return
                }
                let descs = try await track.load(.formatDescriptions)
                guard let first = descs.first else {
                    errorMessage = "video track has zero formatDescriptions"
                    return
                }
                let mediaSubType = CMFormatDescriptionGetMediaSubType(first)
                subType = Self.fourCC(mediaSubType)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        let timeoutResult = semaphore.wait(timeout: .now() + 5.0)
        if timeoutResult == .timedOut && subType == nil && errorMessage == nil {
            errorMessage = "AVURLAsset codec read timed out after 5s"
        }
        return CodecProbeResult(subType: subType, errorMessage: errorMessage)
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

    // MARK: - Stabilization mode name helper

    private static func stabilizationName(_ rawValue: Int) -> String {
        switch rawValue {
        case AVCaptureVideoStabilizationMode.off.rawValue: return "off"
        case AVCaptureVideoStabilizationMode.standard.rawValue: return "standard"
        case AVCaptureVideoStabilizationMode.cinematic.rawValue: return "cinematic"
        case AVCaptureVideoStabilizationMode.cinematicExtended.rawValue: return "cinematicExtended"
        case AVCaptureVideoStabilizationMode.cinematicExtendedEnhanced.rawValue: return "cinematicExtendedEnhanced"
        case AVCaptureVideoStabilizationMode.auto.rawValue: return "auto"
        default: return "unknown(\(rawValue))"
        }
    }
}

// MARK: - MovieFileOutput recording delegate

extension FilmtoneProductCapture: AVCaptureFileOutputRecordingDelegate {

    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        movieDidStart = true
        captureActiveStabilizationStateAfterRecordStart()
    }

    @available(iOS 18.2, *)
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    startPTS: CMTime,
                    from connections: [AVCaptureConnection]) {
        movieDidStart = true
        captureActiveStabilizationStateAfterRecordStart()
    }

    /// Re-read post-startRecording stabilization, color-space, and active-format.
    /// AVFoundation resolves the active stabilization mode at recording time only.
    private func captureActiveStabilizationStateAfterRecordStart() {
        if let movieConn = movieOutput?.connection(with: .video) {
            appliedStabilizationMovieRaw = movieConn.activeVideoStabilizationMode.rawValue
        }
        if let device {
            colorSpaceRawAfterRecordStart = device.activeColorSpace.rawValue
            if device.formats.indices.contains(Self.lockedFormatIndex) {
                activeFormatMatchesLockedAfterRecordStart = (device.activeFormat === device.formats[Self.lockedFormatIndex])
            } else {
                activeFormatMatchesLockedAfterRecordStart = false
            }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        movieDidFinish = true
        movieFinishError = error
        movieFinishedURL = outputFileURL
        sessionQueue.async { [weak self] in
            self?.finalizeAndComplete()
        }
    }
}

#endif
