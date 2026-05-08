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
            captureDevice.unlockForConfiguration()

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
                        lens: lensRecord
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
