// Filmtone V2 native camera capture — external folder preflight (M10).
//
// Trimmed port of DualLogCamera's `ExternalStorageAccessController`.
// Verifies a user-picked folder is on a different volume than the app
// sandbox, runs a tiny write probe (necessary because iOS userfsd /
// FileProvider mounts return 0 from the volume capacity APIs even when
// writes succeed), and reports a low-bar capacity gate.
//
// Filmtone holds the security-scoped URL only for the run window
// (capture view acquires on present and releases on dismiss /
// completion / failure).  Cross-launch persistence of the picked
// folder is owned by `FilmtoneExternalFolderBookmark`, which stores
// a minimal bookmark in UserDefaults and re-runs this preflight on
// the resolved URL before committing the auto-restore.

import Foundation

#if os(iOS)

enum FilmtoneCapturePreflight {

    struct Result {
        let passed: Bool
        let notes: [String]
        let warnings: [String]
        let verdict: Verdict
    }

    enum Verdict: String {
        case external
        case notExternal
    }

    /// Free-capacity gate.  M5-A measured ProRes 422 HQ at 3840×2160
    /// 30 fps Apple Log 2 at ≈ 2.5–2.7 GB / 30 s; the V2 capture
    /// surface ships at 24 fps, so per-second master rate scales by
    /// 24/30 ≈ 0.8 — i.e. roughly 4.0–4.3 GB / 60 s.  S4 (2026-05-09)
    /// raised the external recording ceiling from 60 s to 300 s, so a
    /// single 5 min ProRes 422 HQ Apple Log 2 master measures at
    /// ≈ 20–22 GB.  Add ≈ 1 GB proxy export staging and a few GB of
    /// finalize / mov-atom write headroom.  30 GB keeps the gate
    /// honest at the new ceiling and preserves the ≈ 1.5× safety
    /// margin the prior 10 GB / 60 s gate held against the same
    /// "passed → ENOSPC mid-recording" failure mode flagged in the
    /// M10 review.
    static let minimumFreeBytes: Int64 = 30 * 1024 * 1024 * 1024

    /// Tolerance for `volumeTotalCapacity` match against Documents.  iOS
    /// Files-picker URLs that resolve to the iPhone's NAND (e.g.
    /// On My iPhone, iCloud Drive shadow paths) report the same total
    /// capacity as the app sandbox even when the volume URL / UUID are
    /// not exposed.  A capacity that matches Documents within these
    /// thresholds is treated as proof that the picked folder is still
    /// the internal volume — rejected as `.notExternal` rather than
    /// silently pretending it is an external SSD.
    private static let totalCapacityMatchAbsoluteToleranceBytes: Int64 = 100_000_000
    private static let totalCapacityMatchRelativeTolerance: Double = 0.05

    static func preflight(folderURL: URL) -> Result {
        let verdict = classify(folderURL: folderURL)
        if verdict.classification != .external {
            return Result(
                passed: false,
                notes: ["selected URL is not classified as external: \(verdict.reason)"],
                warnings: [],
                verdict: .notExternal
            )
        }

        let probe = writeProbe(folderURL: folderURL)
        if !probe.succeeded {
            return Result(
                passed: false,
                notes: ["write probe failed: \(probe.error ?? "unknown")"],
                warnings: [],
                verdict: .external
            )
        }

        let capacity = readCapacity(folderURL: folderURL)
        let availableBytes = capacity.availableForImportantUsage
            ?? capacity.freeCapacity
            ?? statfsFree(folderURL: folderURL)

        var warnings: [String] = []
        if let free = availableBytes {
            if free < minimumFreeBytes {
                let freeGB = Double(free) / 1_073_741_824.0
                let gateGB = Double(minimumFreeBytes) / 1_073_741_824.0
                return Result(
                    passed: false,
                    notes: [String(
                        format: "free %.2f GB < required %.2f GB",
                        freeGB, gateGB
                    )],
                    warnings: [],
                    verdict: .external
                )
            }
        } else {
            // Free capacity unreadable.  Accept iff total capacity meets
            // the gate (write probe already passed).  Surface as warning.
            if let total = capacity.totalCapacity, total >= minimumFreeBytes {
                let totalGB = Double(total) / 1_073_741_824.0
                warnings.append(String(
                    format: "free capacity unreadable on selected volume (total %.2f GB ≥ gate); proceeding because write probe succeeded",
                    totalGB
                ))
            } else {
                return Result(
                    passed: false,
                    notes: ["free capacity unreadable and totalCapacity below gate"],
                    warnings: [],
                    verdict: .external
                )
            }
        }

        return Result(
            passed: true,
            notes: [],
            warnings: warnings,
            verdict: .external
        )
    }

    // MARK: - Classification

    struct Classification {
        let classification: ClassificationVerdict
        let reason: String
    }

    enum ClassificationVerdict {
        case external
        case notExternal
    }

    static func classify(folderURL: URL) -> Classification {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let selectedPath = folderURL.path
        let docsPath = docs.path

        let isInsideAppSandbox = selectedPath.hasPrefix(docsPath)
            || selectedPath.contains("/Containers/Data/Application/")
        if isInsideAppSandbox {
            return Classification(
                classification: .notExternal,
                reason: "selected path is inside the app sandbox: \(selectedPath)"
            )
        }
        let isInsideICloudDrive = selectedPath.contains("com~apple~CloudDocs")
            || selectedPath.contains("Mobile Documents/com~apple~CloudDocs")
        if isInsideICloudDrive {
            return Classification(
                classification: .notExternal,
                reason: "selected path is inside iCloud Drive"
            )
        }

        let keys: Set<URLResourceKey> = [
            .volumeURLKey, .volumeUUIDStringKey, .volumeNameKey,
            .volumeIsLocalKey, .volumeIsRemovableKey, .volumeIsInternalKey,
            .volumeTotalCapacityKey,
        ]
        let selectedVals = try? folderURL.resourceValues(forKeys: keys)
        let docsVals = try? docs.resourceValues(forKeys: keys)
        let selectedURL = selectedVals?.volume?.absoluteString
        let docsVolumeURL = docsVals?.volume?.absoluteString
        let selectedUUID = selectedVals?.volumeUUIDString
        let docsUUID = docsVals?.volumeUUIDString

        let urlMatch = selectedURL != nil && selectedURL == docsVolumeURL
        let uuidMatch = selectedUUID != nil && selectedUUID == docsUUID
        if urlMatch || uuidMatch {
            return Classification(
                classification: .notExternal,
                reason: "selected volume metadata matches Documents (urlMatch=\(urlMatch) uuidMatch=\(uuidMatch))"
            )
        }

        // Capacity-match hard reject.  iOS Files-picker URLs that resolve
        // to the iPhone's NAND (On My iPhone subfolders, iCloud Drive
        // shadow paths) typically expose `nil` for volume URL/UUID even
        // though the underlying volume is the same as Documents.  The
        // discriminator that survives this is `volumeTotalCapacity`: an
        // external SSD reports a different total capacity than the
        // device's NAND.  If the selected folder's total capacity matches
        // Documents within tolerance, refuse as `.notExternal`.  This
        // prevents M10's "SSDなしで巨大 master を local に持ち込まない"
        // contract from being violated by an On-My-iPhone misclick.
        if let s = selectedVals?.volumeTotalCapacity.map(Int64.init),
           let d = docsVals?.volumeTotalCapacity.map(Int64.init),
           d > 0 {
            let diff = abs(s - d)
            let pct = Double(diff) / Double(max(d, 1))
            if diff <= Self.totalCapacityMatchAbsoluteToleranceBytes
                || pct <= Self.totalCapacityMatchRelativeTolerance {
                return Classification(
                    classification: .notExternal,
                    reason: String(
                        format: "volumeTotalCapacity matches Documents within tolerance (selected=%lld vs Documents=%lld, Δ=%lld bytes, %.1f%%); treating selection as same internal volume",
                        s, d, diff, pct * 100.0
                    )
                )
            }
        }

        var reasons: [String] = []
        if selectedURL == nil && selectedUUID == nil {
            reasons.append("iOS did not expose volume URL/UUID for the selected URL (typical for Files picker)")
        } else {
            reasons.append("selected volume metadata distinct from Documents")
        }
        if let s = selectedVals?.volumeTotalCapacity.map(Int64.init),
           let d = docsVals?.volumeTotalCapacity.map(Int64.init), d > 0 {
            let diff = abs(s - d)
            let pct = Double(diff) / Double(max(d, 1))
            reasons.append(String(
                format: "volumeTotalCapacity differs (selected=%lld vs Documents=%lld, Δ=%lld bytes, %.1f%%)",
                s, d, diff, pct * 100.0
            ))
        }
        if let removable = selectedVals?.volumeIsRemovable, removable {
            reasons.append("isRemovable=true")
        }
        if let isInternal = selectedVals?.volumeIsInternal {
            reasons.append("isInternal=\(isInternal)")
        }
        if let name = selectedVals?.volumeName, !name.isEmpty {
            reasons.append("volumeName=\(name)")
        }

        return Classification(
            classification: .external,
            reason: reasons.joined(separator: "; ")
        )
    }

    // MARK: - Capacity

    struct CapacitySnapshot: Equatable {
        let availableBytes: Int64?
        let totalBytes: Int64?
    }

    static func capacitySnapshot(folderURL: URL) -> CapacitySnapshot {
        let capacity = readCapacity(folderURL: folderURL)
        return CapacitySnapshot(
            availableBytes: capacity.availableForImportantUsage
                ?? capacity.freeCapacity
                ?? statfsFree(folderURL: folderURL),
            totalBytes: capacity.totalCapacity
        )
    }

    private struct Capacity {
        let availableForImportantUsage: Int64?
        let totalCapacity: Int64?
        let freeCapacity: Int64?
    }

    private static func readCapacity(folderURL: URL) -> Capacity {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeTotalCapacityKey,
        ]
        var importantUsage: Int64? = nil
        var totalCapacity: Int64? = nil
        var freeCapacity: Int64? = nil
        if let vals = try? folderURL.resourceValues(forKeys: keys) {
            // iOS userfsd / FileProvider mounts return 0 (not nil) for
            // available-capacity APIs even when the volume has free
            // space.  Treat 0 as unreadable so the statfs(3) fallback
            // can fire.
            if let v = vals.volumeAvailableCapacityForImportantUsage, v > 0 {
                importantUsage = Int64(v)
            }
            if let v = vals.volumeAvailableCapacity, v > 0 {
                freeCapacity = Int64(v)
            }
            if let v = vals.volumeTotalCapacity, v > 0 {
                totalCapacity = Int64(v)
            }
        }
        if freeCapacity == nil || totalCapacity == nil {
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: folderURL.path) {
                if freeCapacity == nil,
                   let v = (attrs[.systemFreeSize] as? NSNumber)?.int64Value, v > 0 {
                    freeCapacity = v
                }
                if totalCapacity == nil,
                   let v = (attrs[.systemSize] as? NSNumber)?.int64Value, v > 0 {
                    totalCapacity = v
                }
            }
        }
        return Capacity(
            availableForImportantUsage: importantUsage,
            totalCapacity: totalCapacity,
            freeCapacity: freeCapacity
        )
    }

    private static func statfsFree(folderURL: URL) -> Int64? {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: folderURL.path),
           let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value,
           free > 0 {
            return free
        }
        return nil
    }

    // MARK: - Write probe

    private struct WriteProbe {
        let succeeded: Bool
        let error: String?
    }

    private static func writeProbe(folderURL: URL) -> WriteProbe {
        let probeURL = folderURL.appendingPathComponent(
            ".filmtone-capture-probe-\(UUID().uuidString.prefix(8)).txt"
        )
        do {
            let data = "filmtone preflight write probe".data(using: .utf8) ?? Data()
            try data.write(to: probeURL, options: .atomic)
            try? FileManager.default.removeItem(at: probeURL)
            return WriteProbe(succeeded: true, error: nil)
        } catch {
            return WriteProbe(succeeded: false, error: error.localizedDescription)
        }
    }
}

extension FilmtoneCapturePreflight.Classification {
    var asResultVerdict: FilmtoneCapturePreflight.Verdict {
        switch classification {
        case .external: return .external
        case .notExternal: return .notExternal
        }
    }
}

#endif
