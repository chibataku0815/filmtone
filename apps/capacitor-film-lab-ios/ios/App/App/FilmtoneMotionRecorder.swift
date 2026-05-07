// Filmtone V2 capture / Gyroflow lane — M3 Motion-Only Recorder Smoke.
//
// Proves Core Motion sample delivery on iPhone 17 Pro / iOS 26.4.2 is
// stable and dense enough on its own — without any AVCaptureSession
// running — that M4 can later combine it with the M2-B Path C ProRes
// Apple Log 2 video pipeline for Gyroflow timing mapping.
//
// Hard invariants (M3 boundary):
//   - DEBUG-only entry. AppDelegate runs runSmoke() under #if DEBUG only,
//     and only when FILMTONE_SMOKE_LANE=m3 (env-var dispatcher) so the
//     smoke is mutually exclusive with M1 / M2-B.
//   - Raw startGyroUpdates / startAccelerometerUpdates only.
//     startDeviceMotionUpdates is NOT called (fused device-motion samples
//     are not used for Gyroflow data per strategy.md M3 done condition).
//   - Append-only handlers on a single serial OperationQueue. No
//     filtering, no JSON serialisation, no defer in handlers.
//   - Finalize: enqueue a snapshot BlockOperation onto the same handler
//     queue, then waitUntilFinished from an outside thread (never from
//     the handler queue itself — would deadlock).
//   - Done conditions are evaluated against the snapshot, not against
//     "samples observed during stop". Per SDK header, stop may cancel
//     pending operations on the queue; that loss is bounded and acceptable.

import CoreMotion
import Foundation
import UIKit

#if os(iOS)

final class FilmtoneMotionRecorder: NSObject {
    static let schemaVersion = 1

    enum SmokeError: Error, LocalizedError {
        case coreMotionUnavailable
        case gyroUnavailable
        case accelerometerUnavailable
        case noGyroSamples
        case noAccelSamples

        var errorDescription: String? {
            switch self {
            case .coreMotionUnavailable:
                return "CMMotionManager could not be initialized."
            case .gyroUnavailable:
                return "CMMotionManager.isGyroAvailable returned false."
            case .accelerometerUnavailable:
                return "CMMotionManager.isAccelerometerAvailable returned false."
            case .noGyroSamples:
                return "Gyro stream produced zero samples after start."
            case .noAccelSamples:
                return "Accelerometer stream produced zero samples after start."
            }
        }
    }

    struct SmokeResult {
        let jsonURL: URL
        let debugLogURL: URL
    }

    // MARK: - Public entry

    /// Run the M3 motion-only smoke once. Returns through `completion` on
    /// the main thread.
    static func runSmoke(duration: TimeInterval = 10.0,
                         completion: @escaping (Result<SmokeResult, Error>) -> Void) {
        let recorder = FilmtoneMotionRecorder()
        recorder.start(duration: duration) { result in
            // Hold a strong reference to `recorder` until completion.
            _ = recorder
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Locked configuration

    private static let requestedHz: Double = 200
    private static let requestedInterval: TimeInterval = 1.0 / requestedHz

    // MARK: - State

    private let motion = CMMotionManager()

    /// Single serial OperationQueue shared by both raw streams. Both
    /// startGyroUpdates and startAccelerometerUpdates dispatch handler
    /// operations onto this queue, and the finalize snapshot is also an
    /// operation on this queue. Serial FIFO ordering means the snapshot
    /// runs strictly after any handler operations enqueued before it,
    /// without any explicit lock on the sample arrays.
    private let handlerQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "filmtone.m3.motion-handler"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInitiated
        return q
    }()

    /// Worker queue for the duration timer + finalize. NOT the handler
    /// queue — calling `waitUntilFinished` on a snapshot operation must
    /// happen from outside the handler queue or it deadlocks.
    private let workerQueue = DispatchQueue(label: "filmtone.m3.worker")

    private struct Sample {
        let t: TimeInterval
        let x: Double
        let y: Double
        let z: Double
    }

    // Mutated only on handlerQueue. Read after snapshot completes.
    private var gyroSamples: [Sample] = []
    private var accelSamples: [Sample] = []

    private var jsonURL: URL?
    private var debugLogURL: URL?

    private var requestedDuration: TimeInterval = 0
    private var configuredAtBootTime: TimeInterval = 0
    private var startedAtBootTime: TimeInterval = 0
    private var stoppedAtBootTime: TimeInterval = 0
    private var completion: ((Result<SmokeResult, Error>) -> Void)?
    private var didFinish = false

    /// Append a line to the persistent debug log. Best-effort — failures
    /// here are silently ignored.
    private func dlog(_ message: String) {
        NSLog("[FilmtoneM3Smoke] %@", message)
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

    // MARK: - Start

    private func start(duration: TimeInterval,
                       completion: @escaping (Result<SmokeResult, Error>) -> Void) {
        self.completion = completion
        self.requestedDuration = duration

        if let dir = try? Self.makeCaptureDir() {
            let logURL = dir.appendingPathComponent("m3-debug.log", isDirectory: false)
            try? "[\(Date().timeIntervalSince1970)] M3 motion-only smoke begin\n"
                .data(using: .utf8)?
                .write(to: logURL, options: .atomic)
            self.debugLogURL = logURL
            let resolvedJSONURL = dir.appendingPathComponent(
                "m3-motion-only-smoke.json", isDirectory: false
            )
            try? FileManager.default.removeItem(at: resolvedJSONURL)
            self.jsonURL = resolvedJSONURL
        }
        dlog("starting motion-only smoke duration=\(duration) requestedInterval=\(Self.requestedInterval)")

        configuredAtBootTime = ProcessInfo.processInfo.systemUptime

        guard motion.isGyroAvailable else {
            dlog("gyro unavailable; aborting")
            fail(error: SmokeError.gyroUnavailable)
            return
        }
        guard motion.isAccelerometerAvailable else {
            dlog("accelerometer unavailable; aborting")
            fail(error: SmokeError.accelerometerUnavailable)
            return
        }
        dlog("isGyroAvailable=true isAccelerometerAvailable=true isDeviceMotionAvailable=\(motion.isDeviceMotionAvailable)")

        motion.gyroUpdateInterval = Self.requestedInterval
        motion.accelerometerUpdateInterval = Self.requestedInterval

        startedAtBootTime = ProcessInfo.processInfo.systemUptime

        motion.startGyroUpdates(to: handlerQueue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.gyroSamples.append(Sample(
                t: data.timestamp,
                x: data.rotationRate.x,
                y: data.rotationRate.y,
                z: data.rotationRate.z
            ))
        }
        motion.startAccelerometerUpdates(to: handlerQueue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.accelSamples.append(Sample(
                t: data.timestamp,
                x: data.acceleration.x,
                y: data.acceleration.y,
                z: data.acceleration.z
            ))
        }
        dlog("startGyroUpdates + startAccelerometerUpdates issued at sysUptime=\(startedAtBootTime)")

        workerQueue.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.finalizeAndComplete()
        }
    }

    private func finalizeAndComplete() {  // not `finalize` — collides with NSObject.finalize
        guard !didFinish else { return }
        didFinish = true
        dlog("finalizeAndComplete() begin (workerQueue, requesting snapshot on handlerQueue)")

        var gyroSnapshot: [Sample] = []
        var accelSnapshot: [Sample] = []
        var snapshotStopBootTime: TimeInterval = 0

        // Enqueue stop+snapshot onto the handler queue. Serial FIFO
        // ordering guarantees any handler operations enqueued before this
        // one run first and their appends are observed when we read the
        // arrays here. After our stop calls return, CoreMotion stops
        // adding new handler operations; any pending operations added
        // between this enqueue and our run already executed in front of
        // us. Operations CoreMotion would have added after stop may be
        // cancelled per SDK header — that loss is bounded.
        let snapshotOp = BlockOperation { [weak self] in
            guard let self else { return }
            self.motion.stopGyroUpdates()
            self.motion.stopAccelerometerUpdates()
            snapshotStopBootTime = ProcessInfo.processInfo.systemUptime
            gyroSnapshot = self.gyroSamples
            accelSnapshot = self.accelSamples
        }
        handlerQueue.addOperation(snapshotOp)
        // Safe: we are on workerQueue, not handlerQueue.
        snapshotOp.waitUntilFinished()

        stoppedAtBootTime = snapshotStopBootTime
        dlog("snapshot finished. gyroCount=\(gyroSnapshot.count) accelCount=\(accelSnapshot.count) stopBootTime=\(stoppedAtBootTime)")

        var resolvedError: SmokeError?
        if gyroSnapshot.isEmpty {
            resolvedError = .noGyroSamples
        } else if accelSnapshot.isEmpty {
            resolvedError = .noAccelSamples
        }

        writeDiagnostics(
            gyro: gyroSnapshot,
            accel: accelSnapshot,
            resolvedError: resolvedError
        )

        if let resolvedError {
            completion?(.failure(resolvedError))
            return
        }
        guard let jsonURL, let debugLogURL else {
            completion?(.failure(SmokeError.coreMotionUnavailable))
            return
        }
        completion?(.success(SmokeResult(jsonURL: jsonURL, debugLogURL: debugLogURL)))
    }

    private func fail(error: Error) {
        writeDiagnostics(gyro: [], accel: [], resolvedError: error)
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

    private func writeDiagnostics(gyro: [Sample], accel: [Sample], resolvedError: Error?) {
        guard let jsonURL else { return }
        let payload = makeDiagnosticsPayload(
            gyro: gyro,
            accel: accel,
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

    private func makeDiagnosticsPayload(gyro: [Sample], accel: [Sample], resolvedError: Error?) -> [String: Any] {
        let durationDict: [String: Any] = [
            "requestedSeconds": requestedDuration,
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
        let coreMotionDict: [String: Any] = [
            "isGyroAvailable": motion.isGyroAvailable,
            "isAccelerometerAvailable": motion.isAccelerometerAvailable,
            "isDeviceMotionAvailable": motion.isDeviceMotionAvailable,
            "requestedGyroIntervalSeconds": Self.requestedInterval,
            "requestedAccelIntervalSeconds": Self.requestedInterval,
            "requestedHz": Self.requestedHz,
            "fusedDeviceMotionStarted": false,
        ]
        let timestampsDict: [String: Any] = [
            "configuredAtBootTime": configuredAtBootTime,
            "startedAtBootTime": startedAtBootTime,
            "stoppedAtBootTime": stoppedAtBootTime,
        ]

        let payload: [String: Any] = [
            "schemaVersion": Self.schemaVersion,
            "lane": "v2-capture-gyroflow",
            "milestone": "M3",
            "smokeLaneEnvVar": "m3",
            "duration": durationDict,
            "device": deviceDict,
            "coreMotion": coreMotionDict,
            "timestamps": timestampsDict,
            "gyro": Self.computeStreamStats(samples: gyro),
            "accel": Self.computeStreamStats(samples: accel),
            "smokeError": resolvedError?.localizedDescription ?? NSNull(),
        ]
        return payload
    }

    private static func computeStreamStats(samples: [Sample]) -> [String: Any] {
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
        let firstTS = samples.first!.t
        let lastTS = samples.last!.t
        let coverage = max(0, lastTS - firstTS)
        let count = samples.count

        var intervals: [Double] = []
        if count >= 2 {
            intervals.reserveCapacity(count - 1)
            for i in 1..<count {
                intervals.append(samples[i].t - samples[i - 1].t)
            }
        }
        let sorted = intervals.sorted()
        let median: Double
        let maxGap: Double
        let p99: Double
        let gapOver50: Int
        let gapOver100: Int
        let gapOver200: Int
        let effectiveHz: Double
        if sorted.isEmpty {
            median = 0; maxGap = 0; p99 = 0
            gapOver50 = 0; gapOver100 = 0; gapOver200 = 0
            effectiveHz = 0
        } else {
            median = sorted[sorted.count / 2]
            maxGap = sorted.last ?? 0
            let p99Index = max(0, Int((Double(sorted.count) * 0.99).rounded(.down)) - 1)
            p99 = sorted[min(p99Index, sorted.count - 1)]
            gapOver50 = sorted.filter { $0 > 0.050 }.count
            gapOver100 = sorted.filter { $0 > 0.100 }.count
            gapOver200 = sorted.filter { $0 > 0.200 }.count
            effectiveHz = median > 0 ? 1.0 / median : 0
        }

        let intervalsDict: [String: Any] = [
            "medianSeconds": median,
            "maxGapSeconds": maxGap,
            "p99Seconds": p99,
            "gapCountOver50ms": gapOver50,
            "gapCountOver100ms": gapOver100,
            "gapCountOver200ms": gapOver200,
        ]
        return [
            "sampleCount": count,
            "firstTS": firstTS,
            "lastTS": lastTS,
            "coverageSeconds": coverage,
            "effectiveHz": effectiveHz,
            "intervals": intervalsDict,
        ]
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

#endif
