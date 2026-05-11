// Phase 4A: CaptureSession split — package assembly + persistence.
//
// Owns the post-record invariant gates (Apple Log 2 color space,
// `cinematicExtendedEnhanced` stabilization, capture rotation, ProRes
// 422 HQ codec FourCC), the `FilmtoneCapturePackage` construction body,
// the security-scoped bookmark sampling for external masters, and the
// `capture-package.json` persistence write.  Proxy export is kicked
// off as `Task.detached`; on completion the assembler flips the
// `RecordingStateController.state` to `.completed` / `.failed` and
// fires a cleanup callback so the facade can drop the AV delegate and
// stop the storage-pressure task.

import Foundation

#if os(iOS)

import AVFoundation
import CoreMedia

@MainActor
final class CapturePackageAssembler {

    /// Snapshot of the device-side exposure/focus/metering controls at
    /// record-stop time.  Provided by the facade after reading
    /// `CaptureDeviceManager` state.
    struct ExposureSnapshot {
        let mode: CaptureDeviceManager.ExposureMode
        let biasEV: Float
        let focusPoint: CGPoint?
        let meteringPoint: CGPoint?
        let manualISO: Float
        let manualShutterSeconds: Double
        let manualInheritedFromAuto: Bool
    }

    /// Snapshot of the WB lock state at record-stop time.
    struct WhiteBalanceSnapshot {
        let mode: CaptureDeviceManager.WhiteBalanceMode
        let lockedGains: AVCaptureDevice.WhiteBalanceGains?
    }

    private weak var stateController: RecordingStateController?

    init(stateController: RecordingStateController) {
        self.stateController = stateController
    }

    // MARK: - Package paths

    /// Build the per-run package directory + master + proxy URLs.
    /// Internal-mode masters live inside the package directory under
    /// Caches; external-mode masters live next to the caller-supplied
    /// security-scoped folder with a captureId-stamped filename so
    /// concurrent takes to the same folder do not collide.
    static func makePackagePaths(
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

    // MARK: - Stabilization mapping

    /// S1 (2026-05-09): map the structured request onto the AVFoundation
    /// enum.  No fallback case — the enum is exhaustive over what S1
    /// ships.
    static func avMode(
        for request: FilmtoneRequestedStabilization
    ) -> AVCaptureVideoStabilizationMode {
        switch request {
        case .on: return .cinematicExtendedEnhanced
        case .off: return .off
        }
    }

    /// Compact label for AVCaptureVideoStabilizationMode.  Used by the
    /// `.stabilizationDowngraded(requested:active:)` failure surface so
    /// the owner sees a concrete name (cinematic / standard / off /
    /// auto) instead of "<some integer>".
    nonisolated static func stabilizationDescription(_ mode: AVCaptureVideoStabilizationMode) -> String {
        switch mode {
        case .off: return "off"
        case .standard: return "standard"
        case .cinematic: return "cinematic"
        case .cinematicExtended: return "cinematicExtended"
        case .cinematicExtendedEnhanced: return "cinematicExtendedEnhanced"
        case .previewOptimized: return "previewOptimized"
        case .lowLatency: return "lowLatency"
        case .auto: return "auto"
        @unknown default: return "unknown(\(mode.rawValue))"
        }
    }

    /// Reads the first video track's CMFormatDescription mediaSubType
    /// (FourCC) from a finalized .mov.  Returns `0` if the asset has no
    /// readable video track / format description; the caller treats `0`
    /// as a downgrade since `apch` is the only acceptable subtype.
    static func readVideoMediaSubtype(from url: URL) -> CMVideoCodecType {
        let asset = AVURLAsset(url: url)
        let tracks = asset.tracks(withMediaType: .video)
        guard let track = tracks.first else { return 0 }
        let descriptions = track.formatDescriptions
        guard let cm = descriptions.first else { return 0 }
        // formatDescriptions on AVAssetTrack is `[Any]` of
        // CMFormatDescription bridged from Obj-C; cast to the typed
        // CMVideoFormatDescription.
        let fd = cm as! CMFormatDescription
        return CMFormatDescriptionGetMediaSubType(fd)
    }

    /// Pretty-print a FourCC for the failure banner (e.g., 0x68766331
    /// → "hvc1").  Returns nil on the sentinel `0`.
    nonisolated static func fourccString(_ code: CMVideoCodecType) -> String? {
        if code == 0 { return nil }
        let chars: [Character] = (0..<4).map { i in
            let byte = UInt8(truncatingIfNeeded: (UInt32(code) >> ((3 - i) * 8)) & 0xFF)
            return Character(UnicodeScalar(byte))
        }
        return String(chars)
    }

    // MARK: - Movie-finished handler

    /// Drive the post-record flow: validate invariants, kick off proxy
    /// export, build + persist `FilmtoneCapturePackage`, flip the
    /// controller's state to `.completed` / `.failed`.  Caller has
    /// already cancelled the storage-pressure task and dropped the AV
    /// delegate via `onCleanup`.
    func handleMovieFinished(
        failure: FilmtoneCaptureFailure?,
        device: AVCaptureDevice?,
        movieOutputConnection: AVCaptureConnection?,
        appleLog2ColorSpaceRaw: Int,
        lensRecord: FilmtoneCaptureLensRecord?,
        selectedLook: FilmtoneSelectedLookRecord?,
        customLut: FilmtoneCaptureCustomLutRecord?,
        exposure: ExposureSnapshot,
        whiteBalance: WhiteBalanceSnapshot,
        onCleanup: () -> Void
    ) {
        onCleanup()
        guard let stateController else { return }

        if let failure {
            stateController.setState(.failed(failure))
            return
        }

        guard let snapshot = stateController.makeRecordingSnapshot() else {
            stateController.setState(.failed(.unexpected(reason: "missing URLs after movie finish")))
            return
        }

        // Verify master existence before kicking off proxy.
        guard FileManager.default.fileExists(atPath: snapshot.masterURL.path) else {
            stateController.setState(.failed(.masterFileMissing))
            return
        }

        // Verify post-recording invariants (Apple Log 2 + ProRes 422 HQ
        // + cinematicExtendedEnhanced).  Strict equality — any downgrade
        // surfaces as an explicit failure rather than silently producing
        // a master that violates the M5-A / M7 quality baseline.
        if let device {
            let observedRaw = device.activeColorSpace.rawValue
            if observedRaw != appleLog2ColorSpaceRaw {
                stateController.setState(.failed(.colorSpaceDowngraded(
                    expectedRaw: appleLog2ColorSpaceRaw,
                    observedRaw: observedRaw
                )))
                return
            }
        }
        // S1 (2026-05-09): exact-mode gate against the run's requested
        // stabilization.  No fallback / silent degrade.
        guard let connection = movieOutputConnection else {
            stateController.setState(.failed(.stabilizationDowngraded(
                requested: snapshot.requestedStabilization.canonicalModeName,
                active: "connection-unavailable"
            )))
            return
        }
        let activeMode = connection.activeVideoStabilizationMode
        let expectedMode = Self.avMode(for: snapshot.requestedStabilization)
        let observedStabilizationName = Self.stabilizationDescription(activeMode)
        if activeMode != expectedMode {
            stateController.setState(.failed(.stabilizationDowngraded(
                requested: snapshot.requestedStabilization.canonicalModeName,
                active: observedStabilizationName
            )))
            return
        }
        let observedCaptureRotation = FilmtoneCaptureVideoRotation(
            degrees: connection.videoRotationAngle
        )
        if let requested = snapshot.recordingCaptureRotation,
           observedCaptureRotation != requested {
            stateController.setState(.failed(.captureRotationRejected(
                requested: requested.degrees,
                active: observedCaptureRotation.degrees
            )))
            return
        }

        // Verify the actual encoded master FourCC.  The connection-level
        // codec request can be silently honored by the encoder yet the
        // resulting file rewritten with a different subtype on certain
        // OS / thermal states.  ProRes 422 HQ FourCC = 'apch'.
        let observedSubtype = Self.readVideoMediaSubtype(from: snapshot.masterURL)
        if observedSubtype != kCMVideoCodecType_AppleProRes422HQ {
            stateController.setState(.failed(.codecDowngraded(
                observed: Self.fourccString(observedSubtype)
            )))
            return
        }
        let masterAudioTrackCount: Int
        switch CaptureMasterAudioValidator.validateMasterAudioTrackCount(at: snapshot.masterURL) {
        case .success(let count):
            masterAudioTrackCount = count
        case .failure(let failure):
            stateController.setState(.failed(failure))
            return
        }

        // S1 (2026-05-09): parameters reflect the owner's requested
        // stabilization for the run that just finished.
        let parameters: FilmtoneCaptureParameters = .baseline(
            requestedStabilization: snapshot.requestedStabilization
        )

        // M12 / S12-C+E: exposure snapshot at record-stop.  Auto-mode
        // runs persist nil for the manual-only fields; manual-mode runs
        // persist the held ISO / shutter / inheritance flag.  We always
        // emit the record (even at the all-default state) so the
        // package distinguishes "M12 capture, owner did not touch the
        // controls" from "pre-M12 capture decoded from disk".
        let isManual = exposure.mode == .manual
        let exposureControl = FilmtoneCaptureExposureControlRecord(
            mode: exposure.mode.rawValue,
            biasEV: Double(exposure.biasEV),
            focusPointX: exposure.focusPoint.map { Double($0.x) },
            focusPointY: exposure.focusPoint.map { Double($0.y) },
            meteringPointX: exposure.meteringPoint.map { Double($0.x) },
            meteringPointY: exposure.meteringPoint.map { Double($0.y) },
            manualISO: isManual ? Double(exposure.manualISO) : nil,
            manualShutterDurationSeconds: isManual ? exposure.manualShutterSeconds : nil,
            inheritedFromAuto: isManual ? exposure.manualInheritedFromAuto : nil
        )
        // M12 / S12-D: WB lock state at record-stop.
        let whiteBalanceRecord: FilmtoneCaptureWhiteBalanceRecord
        switch whiteBalance.mode {
        case .auto:
            whiteBalanceRecord = FilmtoneCaptureWhiteBalanceRecord(
                mode: "auto",
                redGain: nil,
                greenGain: nil,
                blueGain: nil
            )
        case .locked:
            whiteBalanceRecord = FilmtoneCaptureWhiteBalanceRecord(
                mode: "locked",
                redGain: whiteBalance.lockedGains.map { Double($0.redGain) },
                greenGain: whiteBalance.lockedGains.map { Double($0.greenGain) },
                blueGain: whiteBalance.lockedGains.map { Double($0.blueGain) }
            )
        }

        let masterURL = snapshot.masterURL
        let proxyURL = snapshot.proxyURL
        let packageDirURL = snapshot.packageDirURL
        let storagePolicy = snapshot.storagePolicy
        let captureId = snapshot.captureId
        let recordedDuration = snapshot.recordedDuration
        let durationLimit = snapshot.durationLimit

        // Kick off proxy generation off-main; flip state when complete.
        Task.detached(priority: .userInitiated) { [weak stateController] in
            let proxyResult = await FilmtoneProxyGenerator.export(
                masterURL: masterURL,
                proxyURL: proxyURL
            )
            await MainActor.run {
                guard let stateController else { return }
                switch proxyResult {
                case .success:
                    // M14-B: snapshot a security-scoped bookmark for
                    // the master file URL when the storage policy is
                    // external.  The capture surface still holds folder
                    // scope at this moment (releaseExternalFolderScope
                    // runs from the view's dismiss / .completed branch,
                    // which is downstream of this MainActor.run).
                    // Internal masters do not need a bookmark — the
                    // path lives in app Documents and remains reachable
                    // without scope.
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
                        customLut: customLut,
                        exposureControl: exposureControl,
                        whiteBalance: whiteBalanceRecord,
                        masterBookmark: masterBookmark,
                        observedStabilization: observedStabilizationName,
                        requestedCaptureRotationDegrees: snapshot.recordingCaptureRotation?.degrees,
                        observedCaptureRotationDegrees: observedCaptureRotation.degrees,
                        masterAudioTrackCount: masterAudioTrackCount
                    )
                    // Master/proxy linkage is the M10 deliverable; if
                    // we can't write `capture-package.json` next to
                    // the proxy, the relaunch reconnect path is
                    // silently broken.  Surface as a loud failure
                    // rather than letting the editor receive a
                    // .completed state with no on-disk linkage to
                    // back it.
                    guard let writtenJSONURL = FilmtoneCapturePackagePersistence
                        .write(package: pkg),
                          FileManager.default.fileExists(atPath: writtenJSONURL.path) else {
                        stateController.setState(.failed(
                            .packagePersistenceFailed(
                                reason: "capture-package.json write failed at \(packageDirURL.path)"
                            )
                        ))
                        return
                    }
                    stateController.setState(.completed(pkg))
                case .failure(let reason):
                    stateController.setState(.failed(.proxyExportFailed(reason: reason)))
                }
            }
        }
    }

}

#endif
