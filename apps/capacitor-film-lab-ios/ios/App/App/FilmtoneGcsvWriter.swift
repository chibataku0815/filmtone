// Filmtone V2 capture / Gyroflow lane — M5-A `.gcsv` writer.
//
// Pure-Foundation function. No AVFoundation / CoreMotion / UIKit imports so
// the writer is testable from a standalone Swift host (scripts/swift/) and
// the host driver can stay decoupled from the Swift module that owns the
// capture session.
//
// Format pinned by Phase 0 (active.md):
//   - Header line 1:  `GYROFLOW IMU LOG`
//   - Header rows:    `version,1.3` / `id,filmtone_ios_m5` / `vendor,filmtone`
//                     / `videofilename,<basename>` / `tscale,0.000001`
//                     / `gscale,1.0` / `ascale,1.0` / `orientation,<3 chars>`
//   - Data header:    `t,gx,gy,gz,ax,ay,az`
//   - Data rows:      integer microseconds (`tscale * t = seconds`),
//                     gyro = raw `CMGyroData.rotationRate` rad/s
//                     (`gscale = 1.0`), accel = raw `CMAccelerometerData.acceleration`
//                     g (`ascale = 1.0`).
//
// Row construction (Strategy C — combined on gyro timeline):
//   - The output is trimmed to the **common IMU coverage window**:
//     gyro samples whose timestamps fall outside `[accel.first.t,
//     accel.last.t]` are excluded (boundary effect — gyro and accel are
//     two independent CoreMotion streams that do not start or stop at
//     exactly the same nanosecond). These boundary trims are reported
//     separately as `outOfRangeStartCount` / `outOfRangeEndCount` and
//     are NOT counted as `droppedRowCount`.
//   - Inside the common window, one row is emitted per gyro sample.
//     Accel is interpolated onto the gyro timeline so each row carries
//     a co-timed accel triple. Linear interpolation between the two
//     accel samples that bracket each gyro timestamp. A gyro row inside
//     the window whose nearest accel sample is more than
//     `toleranceSeconds` away is counted as a drop
//     (`droppedRowCount`) — Stop Condition: `droppedRowCount == 0`.
//   - The boundary trim is itself bounded by an additional gate:
//     `trimDurationTotalSeconds <= max(1.5 * gyroMedianIntervalSeconds,
//     0.020)`. Larger trims indicate a stream-start or stream-stop
//     race significantly worse than a single sample interval, which
//     the caller surfaces as a separate Stop Condition.
//   - Reconciliation (under PASS, `droppedRowCount == 0`):
//     `rowCount == gyro.count - outOfRangeTotalCount`.
//     General form: `rowCount == gyro.count - outOfRangeTotalCount -
//     droppedRowCount`.
//
// Axis convention: the writer ships sensor-native (raw) gyro/accel from
// Core Motion. The orientation string in the header tells Gyroflow how to
// interpret these axes against the image. M5-A defaults to `"XYZ"`
// (no remap); M5-B verifies and may override via `orientation:` if
// desktop evidence proves a different mapping is needed.

import Foundation

enum FilmtoneGcsvWriter {

    // MARK: - Public types

    struct GyroSample {
        /// Raw `CMLogItem.timestamp` in seconds (boot-relative; the writer
        /// only uses these as relative values).
        let timestampSeconds: TimeInterval
        /// `CMGyroData.rotationRate.x` (rad/s).
        let x: Double
        /// `CMGyroData.rotationRate.y` (rad/s).
        let y: Double
        /// `CMGyroData.rotationRate.z` (rad/s).
        let z: Double
    }

    struct AccelSample {
        /// Raw `CMLogItem.timestamp` in seconds.
        let timestampSeconds: TimeInterval
        /// `CMAccelerometerData.acceleration.x` (g).
        let x: Double
        /// `CMAccelerometerData.acceleration.y` (g).
        let y: Double
        /// `CMAccelerometerData.acceleration.z` (g).
        let z: Double
    }

    struct ResamplingMetrics {
        /// Gyro rows inside the common IMU window where the nearest
        /// accel sample landed at zero distance (alpha == 0 or
        /// alpha == 1). Rare in practice.
        let exactRowCount: Int
        /// Gyro rows inside the common IMU window where accel was
        /// linearly interpolated within the tolerance.
        let interpolatedRowCount: Int
        /// Gyro rows **inside** the common IMU window that had no
        /// accel sample within the tolerance. Stop Condition: must be 0.
        /// Boundary out-of-range gyro samples are NOT counted here —
        /// see `outOfRange*Count`.
        let droppedRowCount: Int
        /// Gyro samples whose timestamp fell **before** the first
        /// accel sample. Boundary trim, not a drop.
        let outOfRangeStartCount: Int
        /// Gyro samples whose timestamp fell **after** the last
        /// accel sample. Boundary trim, not a drop.
        let outOfRangeEndCount: Int
        /// `outOfRangeStartCount + outOfRangeEndCount`.
        let outOfRangeTotalCount: Int
        /// Trim duration at the start: `max(0, accel.first.t -
        /// gyro.first.t)`.
        let trimDurationStartSeconds: Double
        /// Trim duration at the end: `max(0, gyro.last.t - accel.last.t)`.
        let trimDurationEndSeconds: Double
        /// `trimDurationStartSeconds + trimDurationEndSeconds`.
        let trimDurationTotalSeconds: Double
        /// Median gyro inter-sample interval (seconds) — used as the
        /// basis for `trimDurationLimitSeconds`.
        let gyroMedianIntervalSeconds: Double
        /// `max(1.5 * gyroMedianIntervalSeconds, 0.020)`. Trim
        /// duration must stay within this for Stop Condition.
        let trimDurationLimitSeconds: Double
        /// `trimDurationTotalSeconds <= trimDurationLimitSeconds`.
        let trimDurationWithinLimit: Bool
        /// Maximum nearest-accel distance (seconds) across rows that
        /// resolved (excludes drops). Zero when no rows resolved.
        let maxDeltaSeconds: Double
        /// Median nearest-accel distance (seconds) across rows that
        /// resolved (excludes drops). Zero when no rows resolved.
        let medianDeltaSeconds: Double
        /// Tolerance applied (seconds).
        let toleranceSeconds: Double
    }

    struct Output {
        /// UTF-8 encoded `.gcsv` file contents.
        let bytes: Data
        /// Number of *data* rows written (excludes the header block).
        let rowCount: Int
        /// Byte length of the header block — from the `GYROFLOW IMU LOG`
        /// magic line through and including the `t,gx,gy,gz,ax,ay,az`
        /// data-header line plus its trailing newline.
        let headerBytes: Int
        /// Resampling metrics computed during row construction.
        let metrics: ResamplingMetrics
    }

    // MARK: - Phase 0 locked defaults

    static let formatVersion = "1.3"
    static let defaultIdentifier = "filmtone_ios_m5"
    static let defaultVendor = "filmtone"
    /// Microseconds — `t * tscale = seconds`. Phase 0 lock.
    static let defaultTscale = 0.000001
    /// Raw rad/s. Phase 0 lock.
    static let defaultGscale = 1.0
    /// Raw g. Phase 0 lock.
    static let defaultAscale = 1.0
    /// Sensor-native baseline. M5-B may override with image-frame remap
    /// codes (e.g., `"yXZ"`) if desktop validation demonstrates the
    /// raw orientation is wrong against the rotated `.mov`.
    static let defaultOrientation = "XYZ"
    /// One nominal accel sample at 100 Hz.
    static let defaultAccelResamplingToleranceSeconds = 0.010

    // MARK: - Public entry

    /// Build a `.gcsv` byte payload from a Strategy C gyro+accel pair.
    ///
    /// Assumes `gyro` and `accel` are sorted by `timestampSeconds`
    /// ascending, which `CMMotionManager` raw handlers guarantee in
    /// FIFO order on a serial OperationQueue (the M4 motion handler
    /// pattern). The function does not re-sort.
    static func make(
        gyro: [GyroSample],
        accel: [AccelSample],
        videofilename: String,
        identifier: String = defaultIdentifier,
        vendor: String = defaultVendor,
        orientation: String = defaultOrientation,
        tscale: Double = defaultTscale,
        gscale: Double = defaultGscale,
        ascale: Double = defaultAscale,
        toleranceSeconds: Double = defaultAccelResamplingToleranceSeconds
    ) -> Output {
        let header = makeHeader(
            videofilename: videofilename,
            identifier: identifier,
            vendor: vendor,
            orientation: orientation,
            tscale: tscale,
            gscale: gscale,
            ascale: ascale
        )
        var bytes = Data()
        bytes.append(header.data)
        let headerBytes = bytes.count

        // Build rows. Skip rows that fail the resampling tolerance.
        let resampling = resampleAccelOntoGyro(
            gyro: gyro,
            accel: accel,
            toleranceSeconds: toleranceSeconds
        )

        // First gyro timestamp anchors the gcsv internal time axis.
        // Phase 0 locked timestamp basis = motion-relative; row 0 always
        // has `t = 0`. `gscale = 1.0` and `ascale = 1.0` so values are
        // emitted directly without scaling.
        let firstGyroTS = gyro.first?.timestampSeconds ?? 0
        for row in resampling.rows {
            let relativeSeconds = row.gyro.timestampSeconds - firstGyroTS
            let microseconds = Int64((relativeSeconds * 1_000_000.0).rounded())
            let line = String(
                format: "%lld,%@,%@,%@,%@,%@,%@\n",
                microseconds,
                Self.formatFloat(row.gyro.x),
                Self.formatFloat(row.gyro.y),
                Self.formatFloat(row.gyro.z),
                Self.formatFloat(row.accel.x),
                Self.formatFloat(row.accel.y),
                Self.formatFloat(row.accel.z)
            )
            if let data = line.data(using: .utf8) {
                bytes.append(data)
            }
        }

        return Output(
            bytes: bytes,
            rowCount: resampling.rows.count,
            headerBytes: headerBytes,
            metrics: resampling.metrics
        )
    }

    // MARK: - Header builder

    private struct HeaderBlock {
        let data: Data
    }

    private static func makeHeader(
        videofilename: String,
        identifier: String,
        vendor: String,
        orientation: String,
        tscale: Double,
        gscale: Double,
        ascale: Double
    ) -> HeaderBlock {
        // tscale uses fixed-decimal so it is unambiguous; gscale/ascale
        // are written with a single decimal place for the same reason.
        let lines: [String] = [
            "GYROFLOW IMU LOG",
            "version,\(Self.formatVersion)",
            "id,\(identifier)",
            "vendor,\(vendor)",
            "videofilename,\(videofilename)",
            "tscale,\(Self.formatScale(tscale))",
            "gscale,\(Self.formatScale(gscale))",
            "ascale,\(Self.formatScale(ascale))",
            "orientation,\(orientation)",
            "t,gx,gy,gz,ax,ay,az",
        ]
        let joined = lines.joined(separator: "\n") + "\n"
        return HeaderBlock(data: joined.data(using: .utf8) ?? Data())
    }

    // MARK: - Resampling (Strategy C — linear interpolation)

    private struct ResolvedRow {
        let gyro: GyroSample
        let accel: AccelSample
    }

    private struct ResamplingResult {
        let rows: [ResolvedRow]
        let metrics: ResamplingMetrics
    }

    private static func resampleAccelOntoGyro(
        gyro: [GyroSample],
        accel: [AccelSample],
        toleranceSeconds: Double
    ) -> ResamplingResult {
        let gyroMedianInterval = computeMedianIntervalSeconds(gyroSamples: gyro)
        let trimLimit = max(1.5 * gyroMedianInterval, 0.020)

        // Edge cases: empty accel → no common window. Every gyro row is
        // out-of-range; nothing is dropped (drops are an in-range concept).
        guard !accel.isEmpty else {
            let metrics = ResamplingMetrics(
                exactRowCount: 0,
                interpolatedRowCount: 0,
                droppedRowCount: 0,
                outOfRangeStartCount: gyro.count,
                outOfRangeEndCount: 0,
                outOfRangeTotalCount: gyro.count,
                trimDurationStartSeconds: 0,
                trimDurationEndSeconds: 0,
                trimDurationTotalSeconds: 0,
                gyroMedianIntervalSeconds: gyroMedianInterval,
                trimDurationLimitSeconds: trimLimit,
                trimDurationWithinLimit: false,
                maxDeltaSeconds: 0,
                medianDeltaSeconds: 0,
                toleranceSeconds: toleranceSeconds
            )
            return ResamplingResult(rows: [], metrics: metrics)
        }

        var rows: [ResolvedRow] = []
        rows.reserveCapacity(gyro.count)

        var resolvedDeltas: [Double] = []
        resolvedDeltas.reserveCapacity(gyro.count)

        var exactCount = 0
        var interpCount = 0
        var droppedCount = 0
        var outOfRangeStart = 0
        var outOfRangeEnd = 0

        // Two-pointer walk. `leftIndex` is the largest accel index whose
        // timestamp is <= the current gyro timestamp.
        var leftIndex = 0

        for g in gyro {
            // Out-of-range left: gyro before first accel — boundary trim,
            // not a drop.
            if g.timestampSeconds < accel[0].timestampSeconds {
                outOfRangeStart += 1
                continue
            }
            // Out-of-range right: gyro after last accel — boundary trim,
            // not a drop.
            if g.timestampSeconds > accel[accel.count - 1].timestampSeconds {
                outOfRangeEnd += 1
                continue
            }
            // Advance leftIndex so accel[leftIndex].t <= g.t < accel[leftIndex+1].t,
            // or g.t == accel.last.t.
            while leftIndex + 1 < accel.count
                && accel[leftIndex + 1].timestampSeconds <= g.timestampSeconds {
                leftIndex += 1
            }
            // After advance, two valid configurations:
            //   (a) leftIndex < accel.count - 1 and accel[leftIndex].t <= g.t
            //       <= accel[leftIndex+1].t  (interior bracket).
            //   (b) leftIndex == accel.count - 1 and g.t == accel[leftIndex].t
            //       (right edge, exact match).
            let left = accel[leftIndex]
            let leftDelta = g.timestampSeconds - left.timestampSeconds
            let resolved: ResolvedRow
            let nearestDelta: Double

            if leftIndex + 1 < accel.count {
                let right = accel[leftIndex + 1]
                let span = right.timestampSeconds - left.timestampSeconds
                let rightDelta = right.timestampSeconds - g.timestampSeconds
                nearestDelta = min(leftDelta, rightDelta)
                if nearestDelta > toleranceSeconds {
                    droppedCount += 1
                    continue
                }
                if span > 0 {
                    let alpha = leftDelta / span
                    let ax = left.x + alpha * (right.x - left.x)
                    let ay = left.y + alpha * (right.y - left.y)
                    let az = left.z + alpha * (right.z - left.z)
                    let interpolatedAccel = AccelSample(
                        timestampSeconds: g.timestampSeconds,
                        x: ax, y: ay, z: az
                    )
                    resolved = ResolvedRow(gyro: g, accel: interpolatedAccel)
                    if nearestDelta == 0 {
                        exactCount += 1
                    } else {
                        interpCount += 1
                    }
                } else {
                    // Degenerate: two accel samples with identical timestamps.
                    // Treat as exact match against `left`.
                    resolved = ResolvedRow(gyro: g, accel: AccelSample(
                        timestampSeconds: g.timestampSeconds,
                        x: left.x, y: left.y, z: left.z
                    ))
                    exactCount += 1
                }
            } else {
                // Right-edge exact match (g.t == accel.last.t).
                nearestDelta = leftDelta  // == 0 in this branch
                if nearestDelta > toleranceSeconds {
                    droppedCount += 1
                    continue
                }
                resolved = ResolvedRow(gyro: g, accel: AccelSample(
                    timestampSeconds: g.timestampSeconds,
                    x: left.x, y: left.y, z: left.z
                ))
                exactCount += 1
            }

            rows.append(resolved)
            resolvedDeltas.append(nearestDelta)
        }

        let maxDelta = resolvedDeltas.max() ?? 0
        let medianDelta: Double
        if resolvedDeltas.isEmpty {
            medianDelta = 0
        } else {
            let sorted = resolvedDeltas.sorted()
            medianDelta = sorted[sorted.count / 2]
        }

        let trimStart = max(0.0, accel[0].timestampSeconds
            - (gyro.first?.timestampSeconds ?? accel[0].timestampSeconds))
        let trimEnd = max(0.0, (gyro.last?.timestampSeconds
            ?? accel[accel.count - 1].timestampSeconds)
            - accel[accel.count - 1].timestampSeconds)
        let trimTotal = trimStart + trimEnd
        let outOfRangeTotal = outOfRangeStart + outOfRangeEnd

        let metrics = ResamplingMetrics(
            exactRowCount: exactCount,
            interpolatedRowCount: interpCount,
            droppedRowCount: droppedCount,
            outOfRangeStartCount: outOfRangeStart,
            outOfRangeEndCount: outOfRangeEnd,
            outOfRangeTotalCount: outOfRangeTotal,
            trimDurationStartSeconds: trimStart,
            trimDurationEndSeconds: trimEnd,
            trimDurationTotalSeconds: trimTotal,
            gyroMedianIntervalSeconds: gyroMedianInterval,
            trimDurationLimitSeconds: trimLimit,
            trimDurationWithinLimit: trimTotal <= trimLimit,
            maxDeltaSeconds: maxDelta,
            medianDeltaSeconds: medianDelta,
            toleranceSeconds: toleranceSeconds
        )
        return ResamplingResult(rows: rows, metrics: metrics)
    }

    /// Median inter-sample interval (seconds) for a gyro sample
    /// sequence. Zero when fewer than 2 samples.
    private static func computeMedianIntervalSeconds(gyroSamples: [GyroSample]) -> Double {
        guard gyroSamples.count >= 2 else { return 0 }
        var intervals: [Double] = []
        intervals.reserveCapacity(gyroSamples.count - 1)
        for i in 1..<gyroSamples.count {
            intervals.append(gyroSamples[i].timestampSeconds - gyroSamples[i - 1].timestampSeconds)
        }
        let sorted = intervals.sorted()
        return sorted[sorted.count / 2]
    }

    // MARK: - Number formatting

    /// 9 fractional digits — well above what Core Motion samples carry,
    /// well within Rust f64 round-trip safety. Avoids exponent notation
    /// to keep the file readable in plain text editors.
    private static func formatFloat(_ value: Double) -> String {
        return String(format: "%.9f", value)
    }

    /// Compact non-exponent representation for header scalar values.
    /// `1.0` → `"1.0"`, `0.000001` → `"0.000001"`. Avoids `%g`'s exponent
    /// fallback on small numbers.
    private static func formatScale(_ value: Double) -> String {
        // Use `%.6f` and strip trailing zeros while preserving a trailing
        // decimal point with at least one zero (so `1.0` stays `1.0`).
        var s = String(format: "%.6f", value)
        while s.hasSuffix("0") {
            s.removeLast()
        }
        if s.hasSuffix(".") {
            s.append("0")
        }
        return s
    }
}
