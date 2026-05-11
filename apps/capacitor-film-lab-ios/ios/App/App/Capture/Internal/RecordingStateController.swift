// Phase 4A: CaptureSession split — recording state machine + timers + storage.
//
// Owns the recording state enum, elapsed timer, auto-stop task, storage
// policy / pressure monitor, requested stabilization storage, and the
// per-run scratch state (capture id, package URLs, started timestamp,
// recorded duration snapshot, pending failure, recording capture
// rotation).  The AVCaptureSession, movieOutput, and AV delegate
// lifecycle remain on the facade so this controller does not own any
// AVFoundation thread context.

import Foundation

#if os(iOS)

import AVFoundation
import Combine
import CoreMedia
import UIKit

@MainActor
final class RecordingStateController: ObservableObject {

    enum SessionState: Equatable {
        case idle
        case configuring
        case ready
        case recording(startedAt: Date)
        case stopping
        case completed(FilmtoneCapturePackage)
        case failed(FilmtoneCaptureFailure)
    }

    // MARK: - Constants

    /// Internal-mode product cap.  Explicit, not a hidden fallback.
    static let internalDurationCapSeconds: Double = 10.0

    /// External-mode soft ceiling.  S4 (2026-05-09) raised this from
    /// 60 s to 300 s so the V2 capture surface supports a real 5 min
    /// take on a connected SSD.
    static let externalDurationCapSeconds: Double = 300.0

    private static let fallbackProResBytesPerSecond: Double = 82.0 * 1024.0 * 1024.0
    private static let storageCriticalHeadroomBytes: Int64 = 1 * 1024 * 1024 * 1024
    private static let storageWarningHeadroomBytes: Int64 = 3 * 1024 * 1024 * 1024
    private static let storageFinalizeHeadroomBytes: Int64 = 2 * 1024 * 1024 * 1024
    private static let storageUnreadableGraceSamples = 3

    // MARK: - @Published state

    @Published private(set) var state: SessionState = .idle
    @Published private(set) var elapsedSeconds: Double = 0
    @Published private(set) var storagePolicy: FilmtoneCaptureStoragePolicy = .internalDocumentsCapped
    @Published private(set) var storagePressure: FilmtoneCaptureStoragePressure?

    /// S1 (2026-05-09): owner-requested stabilization for the next run.
    /// Default `.on` preserves the M10 / M5-A handheld baseline
    /// (`cinematicExtendedEnhanced`).  The facade owns the live
    /// AVCaptureConnection mutation; this controller only holds the
    /// requested value and gates state on the right phase for changes.
    @Published private(set) var requestedStabilization: FilmtoneRequestedStabilization = .on

    // MARK: - Per-run scratch state

    private(set) var captureId: String = UUID().uuidString.lowercased()
    private(set) var packageDirURL: URL?
    private(set) var masterURL: URL?
    private(set) var proxyURL: URL?
    private(set) var startedAtBootTime: TimeInterval = 0
    private(set) var recordedDurationSnapshot: Double = 0
    private(set) var pendingFailure: FilmtoneCaptureFailure?
    private(set) var recordingCaptureRotation: FilmtoneCaptureVideoRotation?

    // MARK: - Tasks / timers

    private var elapsedTimer: Timer?
    private var autoStopTask: Task<Void, Never>?
    private var storagePressureTask: Task<Void, Never>?
    private var storagePressureUnreadableSamples: Int = 0

    // MARK: - State / mode setters

    func setState(_ newState: SessionState) {
        state = newState
    }

    func useExternalFolder(_ folderURL: URL?) {
        if let folderURL {
            storagePolicy = .externalSecurityScopedFolder(folderURL)
        } else {
            storagePolicy = .internalDocumentsCapped
        }
        storagePressure = nil
    }

    /// Raw setter for the requested stabilization mode.  The facade
    /// owns the `state == .ready` gate, format support check, and live
    /// AVCaptureConnection reconfigure — this controller only persists
    /// the value into the @Published storage that the view reads.
    func setRequestedStabilization(_ mode: FilmtoneRequestedStabilization) {
        requestedStabilization = mode
    }

    func setRecordingCaptureRotation(_ rotation: FilmtoneCaptureVideoRotation?) {
        recordingCaptureRotation = rotation
    }

    func setPendingFailure(_ failure: FilmtoneCaptureFailure?) {
        pendingFailure = failure
    }

    /// Duration cap derived from the resolved storage policy.  10 s for
    /// internal, 300 s for external SSD.
    func currentDurationLimit() -> Double {
        switch storagePolicy {
        case .internalDocumentsCapped:
            return Self.internalDurationCapSeconds
        case .externalSecurityScopedFolder:
            return Self.externalDurationCapSeconds
        }
    }

    // MARK: - Recording lifecycle

    /// Allocate a new capture identity + on-disk package paths.  The
    /// path-making closure is supplied by the facade so the V2 caches /
    /// external-folder layout policy stays adjacent to its
    /// `FilmtoneProductCapture` neighbour.  Throws when the closure
    /// throws — the facade wraps as
    /// `FilmtoneCaptureFailure.packageDirCreationFailed`.
    func prepareForStart(
        makePaths: (_ captureId: String, _ policy: FilmtoneCaptureStoragePolicy) throws
            -> (packageDir: URL, master: URL, proxy: URL)
    ) throws -> (master: URL, proxy: URL, packageDir: URL, captureId: String, durationLimit: Double) {
        let newId = UUID().uuidString.lowercased()
        let (dir, master, proxy) = try makePaths(newId, storagePolicy)
        captureId = newId
        packageDirURL = dir
        masterURL = master
        proxyURL = proxy
        startedAtBootTime = ProcessInfo.processInfo.systemUptime
        recordedDurationSnapshot = 0
        pendingFailure = nil
        elapsedSeconds = 0
        return (master, proxy, dir, newId, currentDurationLimit())
    }

    /// Flip state to `.recording` and start the elapsed timer.  Caller
    /// has already called `prepareForStart` and wired the AV delegate.
    func beginRecording(at startedAt: Date) {
        state = .recording(startedAt: startedAt)
        startElapsedTimer()
    }

    /// Flip state to `.stopping`, cancel the auto-stop, and stop the
    /// elapsed timer.  Caller passes the recorded duration sampled
    /// from `AVCaptureMovieFileOutput.recordedDuration`.
    func markStopping(recordedDuration: Double) {
        state = .stopping
        cancelAutoStop()
        stopElapsedTimer()
        cancelStoragePressureMonitor(clear: true)
        recordedDurationSnapshot = recordedDuration
    }

    /// Reset per-run scratch state and return to `.ready` for the next
    /// take.  S3 (2026-05-09) keeps the AV session graph hot; only the
    /// scratch state here is cleared.  No-op outside `.completed`.
    func resetForRearm() {
        guard case .completed = state else { return }
        masterURL = nil
        proxyURL = nil
        packageDirURL = nil
        recordedDurationSnapshot = 0
        pendingFailure = nil
        elapsedSeconds = 0
        storagePressure = nil
        recordingCaptureRotation = nil
        state = .ready
    }

    /// Tear-down reset.  Caller invokes when the AV session itself is
    /// being stopped.  Clears timers + scratch and drops state back to
    /// `.idle` only from `.ready` — other states (e.g. `.failed`) keep
    /// their value so the next visible UI still sees them.
    func resetForTeardown() {
        cancelAutoStop()
        stopElapsedTimer()
        cancelStoragePressureMonitor(clear: true)
        if case .ready = state {
            state = .idle
        }
    }

    /// Snapshot of per-run state needed by the package assembler at
    /// movie-finished time.  Pulled into a struct so the facade does
    /// not poke at controller internals directly.
    struct RecordingSnapshot {
        let captureId: String
        let packageDirURL: URL
        let masterURL: URL
        let proxyURL: URL
        let recordedDuration: Double
        let durationLimit: Double
        let storagePolicy: FilmtoneCaptureStoragePolicy
        let requestedStabilization: FilmtoneRequestedStabilization
        let recordingCaptureRotation: FilmtoneCaptureVideoRotation?
    }

    /// Build a snapshot for the package assembler.  Returns nil when
    /// the per-run paths are missing (movie finished before
    /// `prepareForStart` succeeded) so the caller can surface a loud
    /// failure rather than build a half-empty package.
    func makeRecordingSnapshot() -> RecordingSnapshot? {
        guard let packageDirURL, let masterURL, let proxyURL else {
            return nil
        }
        return RecordingSnapshot(
            captureId: captureId,
            packageDirURL: packageDirURL,
            masterURL: masterURL,
            proxyURL: proxyURL,
            recordedDuration: recordedDurationSnapshot,
            durationLimit: currentDurationLimit(),
            storagePolicy: storagePolicy,
            requestedStabilization: requestedStabilization,
            recordingCaptureRotation: recordingCaptureRotation
        )
    }

    // MARK: - Elapsed timer

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

    // MARK: - Auto-stop

    /// Schedule an auto-stop after `seconds`.  Invokes `onAutoStop`
    /// only when the current state is still `.recording` — guard is
    /// inside the task so a user stop between schedule and fire does
    /// not race the AV delegate.
    func startAutoStop(after seconds: Double, onAutoStop: @escaping @MainActor () -> Void) {
        autoStopTask?.cancel()
        autoStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await MainActor.run {
                guard let self else { return }
                if case .recording = self.state {
                    onAutoStop()
                }
            }
        }
    }

    func cancelAutoStop() {
        autoStopTask?.cancel()
        autoStopTask = nil
    }

    // MARK: - Storage pressure monitor

    /// Begin polling free space on the master volume against the
    /// projected write budget for the remaining duration of the run.
    /// Reports `.warning` / `.critical` / `.unreadable` through
    /// `storagePressure`.
    func startStoragePressureMonitor(
        volumeURL: URL,
        masterURL: URL,
        durationLimit: Double
    ) {
        cancelStoragePressureMonitor(clear: true)
        updateStoragePressure(
            volumeURL: volumeURL,
            masterURL: masterURL,
            durationLimit: durationLimit
        )
        storagePressureTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard case .recording = self.state else {
                        self.cancelStoragePressureMonitor(clear: true)
                        return
                    }
                    self.updateStoragePressure(
                        volumeURL: volumeURL,
                        masterURL: masterURL,
                        durationLimit: durationLimit
                    )
                }
            }
        }
    }

    func cancelStoragePressureMonitor(clear: Bool) {
        storagePressureTask?.cancel()
        storagePressureTask = nil
        storagePressureUnreadableSamples = 0
        if clear {
            storagePressure = nil
        }
    }

    private func updateStoragePressure(
        volumeURL: URL,
        masterURL: URL,
        durationLimit: Double
    ) {
        guard case .recording(let startedAt) = state else {
            storagePressure = nil
            return
        }
        let elapsed = max(0, Date().timeIntervalSince(startedAt))
        let secondsRemaining = max(0, durationLimit - elapsed)
        guard secondsRemaining > 0 else {
            storagePressure = nil
            return
        }

        let snapshot = FilmtoneCapturePreflight.capacitySnapshot(folderURL: volumeURL)
        guard let availableBytes = snapshot.availableBytes else {
            storagePressureUnreadableSamples += 1
            if storagePressureUnreadableSamples >= Self.storageUnreadableGraceSamples {
                storagePressure = FilmtoneCaptureStoragePressure(
                    level: .unreadable,
                    availableBytes: nil,
                    projectedNeedBytes: nil,
                    secondsRemaining: secondsRemaining,
                    measuredRate: false
                )
            }
            return
        }
        storagePressureUnreadableSamples = 0

        let rate = estimatedMasterWriteRate(masterURL: masterURL, elapsed: elapsed)
        let projectedMasterBytes = Int64((rate.bytesPerSecond * secondsRemaining).rounded(.up))
        let projectedNeedBytes = projectedMasterBytes + Self.storageFinalizeHeadroomBytes
        let criticalThreshold = projectedNeedBytes + Self.storageCriticalHeadroomBytes
        let warningThreshold = projectedNeedBytes + Self.storageWarningHeadroomBytes

        if availableBytes <= criticalThreshold {
            storagePressure = FilmtoneCaptureStoragePressure(
                level: .critical,
                availableBytes: availableBytes,
                projectedNeedBytes: projectedNeedBytes,
                secondsRemaining: secondsRemaining,
                measuredRate: rate.measured
            )
        } else if availableBytes <= warningThreshold {
            storagePressure = FilmtoneCaptureStoragePressure(
                level: .warning,
                availableBytes: availableBytes,
                projectedNeedBytes: projectedNeedBytes,
                secondsRemaining: secondsRemaining,
                measuredRate: rate.measured
            )
        } else {
            storagePressure = nil
        }
    }

    private func estimatedMasterWriteRate(
        masterURL: URL,
        elapsed: Double
    ) -> (bytesPerSecond: Double, measured: Bool) {
        guard elapsed >= 3,
              let fileSize = Self.fileSize(at: masterURL),
              fileSize >= 64 * 1024 * 1024 else {
            return (Self.fallbackProResBytesPerSecond, false)
        }
        let measuredRate = Double(fileSize) / max(elapsed, 1)
        return (max(measuredRate, Self.fallbackProResBytesPerSecond), true)
    }

    private static func fileSize(at url: URL) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let value = attrs[.size] as? NSNumber else {
            return nil
        }
        let bytes = value.int64Value
        return bytes > 0 ? bytes : nil
    }
}

#endif
