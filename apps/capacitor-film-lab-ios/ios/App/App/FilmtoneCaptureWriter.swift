// Filmtone V2 capture / Gyroflow lane — M2-A Video-Only Writer Smoke.
//
// Wires AVCaptureSession + AVCaptureDeviceInput (rear wide) +
// AVCaptureVideoDataOutput + AVAssetWriter using the M1-locked candidate:
//
//   - device       : AVCaptureDeviceTypeBuiltInWideAngleCamera (rear)
//   - format       : device.formats[56]   (10-bit 4:2:2, x422)
//   - colorSpace   : .appleLog2 (raw 4)
//   - dimensions   : 3840 x 2160 @ 30 fps
//   - writer codec : AVVideoCodecType.proRes422HQ
//
// Records ~5-7 seconds of silent video to the internal sandbox
// (Library/Caches/Filmtone/captures/m2a-smoke.mov), and writes a minimal
// diagnostics JSON next to it covering all M2 Done Conditions:
// writer status / first-last PTS / frame count / dropped count / selected
// format / colorSpace / fps / dimensions / orientation / requested-applied
// stabilization.
//
// Hard invariants (M2-A boundary):
//   - DEBUG-only entry. AppDelegate runs runSmoke() under #if DEBUG only.
//   - No silent fallback. activeFormat / activeColorSpace selection failures
//     abort the smoke loudly with a logged reason.
//   - No audio track (strategy.md: M1-M4 produce silent video).
//   - No JS bridge / UI surface in M2-A.
//   - Internal sandbox output only.

import AVFoundation
import CoreMedia
import Foundation

#if os(iOS)

final class FilmtoneCaptureWriter: NSObject {
    static let schemaVersion = 1

    enum SmokeError: Error, LocalizedError {
        case permissionDenied
        case noWideCamera
        case formatIndexOutOfRange(have: Int, want: Int)
        case appleLog2NotSupported(supportedRaw: [Int])
        case appleLog2EnumUnavailable
        case pixelFormatNotAvailable(want: String, available: [String])
        case cannotAddInput
        case cannotAddOutput
        case writerSetupFailed(String)
        case writerFinishedWithFailure(status: Int, message: String)
        case noSamplesCaptured

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
            case .pixelFormatNotAvailable(let want, let available):
                return "Wanted pixel format \(want) not in available \(available)."
            case .cannotAddInput:
                return "AVCaptureSession.canAddInput returned false."
            case .cannotAddOutput:
                return "AVCaptureSession.canAddOutput returned false."
            case .writerSetupFailed(let msg):
                return "AVAssetWriter setup failed: \(msg)"
            case .writerFinishedWithFailure(let status, let message):
                return "AVAssetWriter finished status=\(status) error=\(message)"
            case .noSamplesCaptured:
                return "No video samples were captured during the smoke window."
            }
        }
    }

    struct SmokeResult {
        let movURL: URL
        let jsonURL: URL
    }

    // MARK: - Public entry

    /// Run the M2-A smoke once. Camera permission is requested if not
    /// already granted. Returns through `completion` on the main thread.
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
    private static let lockedPixelFormat: OSType = kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange  // 'x422'
    private static let lockedRotationAngle: CGFloat = 90  // portrait pin

    // MARK: - State

    private let sessionQueue = DispatchQueue(label: "filmtone.m2a.session")
    private let writerQueue = DispatchQueue(label: "filmtone.m2a.writer")

    private let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?

    private var movURL: URL?
    private var jsonURL: URL?

    private var firstPTS: CMTime?
    private var lastPTS: CMTime?
    private var frameCount: Int = 0
    private var droppedFrameCount: Int = 0
    private var appendErrorCount: Int = 0
    private var notReadyCount: Int = 0

    private var requestedStabilizationRaw: Int = AVCaptureVideoStabilizationMode.off.rawValue
    private var appliedStabilizationRaw: Int = -999
    private var requestedRotation: CGFloat = 0
    private var appliedRotation: CGFloat = 0
    private var rotationApplied: Bool = false

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
        NSLog("[FilmtoneM2Smoke] %@", message)
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

        // Open the persistent debug log immediately so any later failure has
        // a paper trail. We create captures/ here too, so makeCaptureDir() in
        // configureSession() is idempotent.
        if let dir = try? Self.makeCaptureDir() {
            let logURL = dir.appendingPathComponent("m2a-debug.log", isDirectory: false)
            try? "[\(Date().timeIntervalSince1970)] M2-A smoke begin\n".data(using: .utf8)?
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
        dlog("formats[56].supportedColorSpaces (raw)=\(rawJoined)")
        guard supportedRaw.contains(4) else {
            throw SmokeError.appleLog2NotSupported(supportedRaw: supportedRaw)
        }
        guard let appleLog2 = AVCaptureColorSpace(rawValue: 4) else {
            throw SmokeError.appleLog2EnumUnavailable
        }

        try wide.lockForConfiguration()
        wide.activeFormat = lockedFormat
        wide.activeColorSpace = appleLog2
        dlog("activeFormat + activeColorSpace=appleLog2 applied")
        let frameDuration = CMTime(value: 1, timescale: 30)
        if lockedFormat.videoSupportedFrameRateRanges.contains(where: {
            $0.minFrameRate <= Self.lockedFPS && Self.lockedFPS <= $0.maxFrameRate
        }) {
            wide.activeVideoMinFrameDuration = frameDuration
            wide.activeVideoMaxFrameDuration = frameDuration
        }
        wide.unlockForConfiguration()
        self.device = wide

        session.beginConfiguration()
        session.automaticallyConfiguresCaptureDeviceForWideColor = false

        let input = try AVCaptureDeviceInput(device: wide)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw SmokeError.cannotAddInput
        }
        session.addInput(input)
        self.input = input

        let videoOutput = AVCaptureVideoDataOutput()
        let availableTypes = videoOutput.availableVideoPixelFormatTypes
        let availableHex = availableTypes
            .map { String(format: "%@(0x%08x)", Self.fourCC($0), $0) }
            .joined(separator: ",")
        dlog("availableVideoPixelFormatTypes=\(availableHex)")
        guard availableTypes.contains(Self.lockedPixelFormat) else {
            session.commitConfiguration()
            throw SmokeError.pixelFormatNotAvailable(
                want: Self.fourCC(Self.lockedPixelFormat),
                available: availableTypes.map { Self.fourCC($0) }
            )
        }
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: Self.lockedPixelFormat),
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = false
        videoOutput.setSampleBufferDelegate(self, queue: writerQueue)
        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            throw SmokeError.cannotAddOutput
        }
        session.addOutput(videoOutput)
        self.videoOutput = videoOutput

        if let connection = videoOutput.connection(with: .video) {
            requestedRotation = Self.lockedRotationAngle
            if connection.isVideoRotationAngleSupported(Self.lockedRotationAngle) {
                connection.videoRotationAngle = Self.lockedRotationAngle
                rotationApplied = true
            }
            requestedStabilizationRaw = AVCaptureVideoStabilizationMode.off.rawValue
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .off
            }
        }

        session.commitConfiguration()

        // Writer
        let captureDir = try Self.makeCaptureDir()
        let movURL = captureDir.appendingPathComponent("m2a-smoke.mov", isDirectory: false)
        let jsonURL = captureDir.appendingPathComponent("m2a-writer-smoke.json", isDirectory: false)
        try? FileManager.default.removeItem(at: movURL)
        try? FileManager.default.removeItem(at: jsonURL)
        self.movURL = movURL
        self.jsonURL = jsonURL

        do {
            let writer = try AVAssetWriter(outputURL: movURL, fileType: .mov)
            let outputSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.proRes422HQ,
                AVVideoWidthKey: Int(Self.lockedWidth),
                AVVideoHeightKey: Int(Self.lockedHeight),
            ]
            let writerInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: outputSettings,
                sourceFormatHint: lockedFormat.formatDescription
            )
            writerInput.expectsMediaDataInRealTime = true
            guard writer.canAdd(writerInput) else {
                throw SmokeError.writerSetupFailed("writer.canAdd(input) returned false.")
            }
            writer.add(writerInput)
            self.assetWriter = writer
            self.assetWriterInput = writerInput
        } catch let error as SmokeError {
            throw error
        } catch {
            throw SmokeError.writerSetupFailed(error.localizedDescription)
        }
    }

    private func startSession() {
        startedAtBootTime = ProcessInfo.processInfo.systemUptime
        dlog("session.startRunning() …")
        session.startRunning()
        dlog("session.isRunning=\(session.isRunning)")

        if let connection = videoOutput?.connection(with: .video) {
            appliedStabilizationRaw = connection.activeVideoStabilizationMode.rawValue
            appliedRotation = connection.videoRotationAngle
        }

        sessionQueue.asyncAfter(deadline: .now() + requestedDuration) { [weak self] in
            self?.stop()
        }
    }

    private func stop() {
        guard !didFinish else { return }
        didFinish = true
        stoppedAtBootTime = ProcessInfo.processInfo.systemUptime
        session.stopRunning()
        writerQueue.async { [weak self] in
            self?.finishWriting()
        }
    }

    private func finishWriting() {
        guard let writer = assetWriter, let writerInput = assetWriterInput else {
            fail(error: SmokeError.noSamplesCaptured)
            return
        }
        guard frameCount > 0 else {
            writer.cancelWriting()
            fail(error: SmokeError.noSamplesCaptured)
            return
        }
        writerInput.markAsFinished()
        writer.finishWriting { [weak self] in
            guard let self else { return }
            let status = writer.status
            let writerError = writer.error
            self.writeDiagnostics(status: status, error: writerError)
            switch status {
            case .completed:
                if let movURL = self.movURL, let jsonURL = self.jsonURL {
                    self.completion?(.success(SmokeResult(movURL: movURL, jsonURL: jsonURL)))
                } else {
                    self.completion?(.failure(SmokeError.writerFinishedWithFailure(
                        status: status.rawValue,
                        message: "missing output URL"
                    )))
                }
            default:
                self.completion?(.failure(SmokeError.writerFinishedWithFailure(
                    status: status.rawValue,
                    message: writerError?.localizedDescription ?? "unknown writer error"
                )))
            }
        }
    }

    private func fail(error: Error) {
        // Best-effort diagnostics on early failures.
        writeDiagnostics(status: .failed, error: error)
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

    private func writeDiagnostics(status: AVAssetWriter.Status, error: Error?) {
        guard let jsonURL else { return }
        let payload = makeDiagnosticsPayload(status: status, error: error)
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

    private func makeDiagnosticsPayload(status: AVAssetWriter.Status, error: Error?) -> [String: Any] {
        var payload: [String: Any] = [
            "schemaVersion": Self.schemaVersion,
            "lane": "v2-capture-gyroflow",
            "milestone": "M2-A",
            "outputPath": movURL?.path ?? "",
            "writerStatus": Self.writerStatusName(status),
            "writerError": error?.localizedDescription ?? NSNull(),
            "frameCount": frameCount,
            "droppedFrameCount": droppedFrameCount,
            "appendErrorCount": appendErrorCount,
            "notReadyCount": notReadyCount,
            "fps": Self.lockedFPS,
            "dimensions": [
                "width": Self.lockedWidth,
                "height": Self.lockedHeight,
            ],
            "selectedFormat": [
                "formatIndex": Self.lockedFormatIndex,
                "fourCC": Self.fourCC(Self.lockedPixelFormat),
                "dimensions": [
                    "width": Self.lockedWidth,
                    "height": Self.lockedHeight,
                ],
                "fps": Self.lockedFPS,
            ],
            "colorSpace": "appleLog2",
            "colorSpaceRawValue": 4,
            "orientation": [
                "requestedRotationAngle": requestedRotation,
                "appliedRotationAngle": appliedRotation,
                "rotationApplied": rotationApplied,
            ],
            "stabilization": [
                "requested": Self.stabilizationName(requestedStabilizationRaw),
                "requestedRaw": requestedStabilizationRaw,
                "applied": Self.stabilizationName(appliedStabilizationRaw),
                "appliedRaw": appliedStabilizationRaw,
            ],
            "duration": [
                "requestedSeconds": requestedDuration,
                "elapsedSeconds": stoppedAtBootTime > startedAtBootTime
                    ? stoppedAtBootTime - startedAtBootTime
                    : 0,
            ],
            "timestamps": [
                "configuredAtBootTime": configuredAtBootTime,
                "startedAtBootTime": startedAtBootTime,
                "stoppedAtBootTime": stoppedAtBootTime,
            ],
            "firstSamplePTS": firstPTS.map(Self.ptsToDict) ?? NSNull(),
            "lastSamplePTS": lastPTS.map(Self.ptsToDict) ?? NSNull(),
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

    private static func writerStatusName(_ status: AVAssetWriter.Status) -> String {
        switch status {
        case .unknown: return "unknown"
        case .writing: return "writing"
        case .completed: return "completed"
        case .failed: return "failed"
        case .cancelled: return "cancelled"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }

    private static func stabilizationName(_ raw: Int) -> String {
        // Cover the full known iOS 26 range. Any unknown value falls through.
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

// MARK: - Sample buffer delegate

extension FilmtoneCaptureWriter: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let writer = assetWriter, let writerInput = assetWriterInput else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if writer.status == .unknown {
            if !writer.startWriting() {
                dlog("startWriting failed: \(writer.error?.localizedDescription ?? "nil")")
                return
            }
            writer.startSession(atSourceTime: pts)
            firstPTS = pts
        }
        guard writer.status == .writing else { return }
        if writerInput.isReadyForMoreMediaData {
            if writerInput.append(sampleBuffer) {
                frameCount += 1
                lastPTS = pts
            } else {
                appendErrorCount += 1
            }
        } else {
            notReadyCount += 1
            droppedFrameCount += 1
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        droppedFrameCount += 1
    }
}

#endif
