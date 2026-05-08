// Filmtone V2 native camera capture — capture package persistence (M10).
//
// `FilmtoneCapturePackage` is in-memory after `adoptCaptureResult(_:)`.
// On its own that means the master/proxy linkage evaporates on the next
// app launch — the editor would still find the proxy via the persisted
// SourceInfoDTO, but the master URL (and therefore "export the master",
// "share to camera roll from master", "reconnect SSD" affordances) would
// be lost.
//
// To survive a relaunch we write `capture-package.json` next to the
// proxy under `Caches/Filmtone/captures/<id>/` and (best-effort) mirror
// it into the security-scoped external folder when one is in use, so
// that re-discovering the SSD later still finds the linkage. The editor
// stores the local JSON path as `currentCapturePackageRef` in the
// persisted snapshot and re-hydrates `lastCapturePackage` from it on
// boot.

import Foundation

#if os(iOS)

/// On-disk shape of a capture package.  Mirrors `FilmtoneCapturePackage`
/// 1:1 with the storage policy flattened to a tag string + folder URL
/// (security-scoped URLs round-trip across launches via path string —
/// the user re-acquires scope by re-picking the folder, which is the
/// product affordance we want for "reconnect SSD" anyway).
struct FilmtoneCapturePackageSnapshotV1: Codable {
    var schemaVersion: Int
    var captureId: String
    var storagePolicyTag: String
    var externalFolderPath: String?
    var masterURLPath: String
    var proxyURLPath: String
    var packageDirURLPath: String
    var durationLimitSeconds: Double
    var recordedDurationSeconds: Double
    var parametersWidthPx: Int
    var parametersHeightPx: Int
    var parametersFrameRate: Double
    var parametersCodec: String
    var parametersColorSpace: String
    var parametersStabilization: String
    /// ISO8601 wall-clock timestamp of the snapshot write.  Useful for
    /// diagnostic banners ("recorded at …") without changing the
    /// capture pipeline.
    var writtenAtISO8601: String
    /// S8-B: rear lens identity for the run.  Optional in the V1 schema
    /// so pre-S8-B `capture-package.json` snapshots continue to decode
    /// cleanly (older runs simply have nil lens).  All new runs set
    /// these three fields together.
    var lensIdentifier: String?
    var lensDisplayName: String?
    var lensDeviceType: String?
    /// M12 / S12-B: capture-time owner-visible label ("0.5×" / "1×" /
    /// "2×" / "5×") and the format index used for the run.  Optional
    /// so pre-M12 snapshots decode with `magnificationLabel = nil` /
    /// `formatIndex = nil` on the rebuilt record.  No schemaVersion
    /// bump — the M11 schema already permitted optional additions.
    var lensMagnificationLabel: String?
    var lensFormatIndex: Int?
    /// S11-D (schemaVersion 2): capture-time Look chip recorded with
    /// the run.  All four are tri-required (UUID + name + intensity);
    /// missing any of them means the snapshot was either pre-M11 or
    /// the Filmtone default chip was selected — both decode to
    /// `selectedLook = nil`.  `selectedLookSlug` is independently
    /// optional even when the others are present (future non-bundled
    /// Looks).
    var selectedLookCanonicalUUID: String?
    var selectedLookSlug: String?
    var selectedLookEnglishName: String?
    var selectedLookIntensity: Double?
    /// M12 / S12-C: exposure / focus / metering control state at
    /// record-stop time.  `exposureMode` ("auto" | reserved "manual")
    /// is the trigger field — when present, the snapshot rebuilds a
    /// `FilmtoneCaptureExposureControlRecord` using the EV bias plus
    /// the focus / metering points (which are independently optional
    /// inside the record because a run that never tapped leaves them
    /// nil).  Pre-M12 snapshots have `exposureMode = nil` and decode
    /// to `exposureControl = nil` on the package.  No `schemaVersion`
    /// bump — schemaVersion 2's contract is "additive optional fields
    /// allowed" and these are.
    var exposureMode: String?
    var exposureBiasEV: Double?
    var focusPointNormalizedX: Double?
    var focusPointNormalizedY: Double?
    var meteringPointNormalizedX: Double?
    var meteringPointNormalizedY: Double?
    /// M12 / S12-D: white balance lock state.  `whiteBalanceMode`
    /// ("auto" | "locked") is the trigger field; locked snapshots
    /// also carry the three gain channels.  Auto snapshots leave the
    /// gains nil — see the `FilmtoneCaptureWhiteBalanceRecord` doc
    /// for why auto-mode gains are not persisted.  Pre-M12 snapshots
    /// have `whiteBalanceMode = nil` and decode to
    /// `whiteBalance = nil` on the package.
    var whiteBalanceMode: String?
    var whiteBalanceRedGain: Double?
    var whiteBalanceGreenGain: Double?
    var whiteBalanceBlueGain: Double?
    /// M12 / S12-E: manual exposure fields (ISO + shutter duration)
    /// recorded only when `exposureMode == "manual"`.  Auto-mode and
    /// pre-S12-E snapshots leave all three nil.  The two reading
    /// fields and the inheritance flag travel together so a partial-
    /// write (e.g. ISO present, shutter missing) decodes as a manual
    /// run with whichever fields the snapshot carried — the truth-
    /// gate verifier in S12-F asserts the field set per mode.
    var manualISO: Double?
    var manualShutterDurationSeconds: Double?
    var manualInheritedFromAuto: Bool?

    /// Bumped to 2 in S11-D.  Schema-version 1 snapshots written by
    /// M10 / S8-B continue to decode because every S11-D field is
    /// optional (`Codable` populates them with `nil` on absence).
    static let currentSchemaVersion = 2
}

enum FilmtoneCapturePackagePersistence {

    static let snapshotFilename = "capture-package.json"

    /// Write `capture-package.json` to the local package directory and,
    /// best-effort, mirror it into the external security-scoped folder
    /// that holds the master.  The mirror is best-effort because the
    /// user can revoke scope between recording finalize and this write
    /// — failing the mirror does NOT fail the capture.
    @discardableResult
    static func write(package: FilmtoneCapturePackage) -> URL? {
        let snapshot = makeSnapshot(from: package)
        guard let data = encode(snapshot: snapshot) else { return nil }

        let localURL = package.packageDirURL.appendingPathComponent(
            snapshotFilename, isDirectory: false
        )
        do {
            try FileManager.default.createDirectory(
                at: package.packageDirURL,
                withIntermediateDirectories: true
            )
            try data.write(to: localURL, options: .atomic)
        } catch {
            return nil
        }

        if case .externalSecurityScopedFolder(let folderURL) = package.storagePolicy {
            let mirror = folderURL.appendingPathComponent(
                "filmtone-capture-package-\(package.captureId).json",
                isDirectory: false
            )
            try? data.write(to: mirror, options: .atomic)
        }
        return localURL
    }

    /// Try to read a previously-written `capture-package.json`.  Caller
    /// passes the local JSON path persisted in
    /// `FilmtoneEditorStore.currentCapturePackageRef`.  Returns nil if
    /// the file no longer exists or is unreadable.
    static func read(localPackageJSONPath: String) -> FilmtoneCapturePackage? {
        let url = URL(fileURLWithPath: localPackageJSONPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(
            FilmtoneCapturePackageSnapshotV1.self, from: data
        ) else { return nil }
        return makePackage(from: snapshot)
    }

    // MARK: - Codec

    private static func makeSnapshot(
        from package: FilmtoneCapturePackage
    ) -> FilmtoneCapturePackageSnapshotV1 {
        let policyTag: String
        let externalPath: String?
        switch package.storagePolicy {
        case .externalSecurityScopedFolder(let url):
            policyTag = "external"
            externalPath = url.path
        case .internalDocumentsCapped:
            policyTag = "internal"
            externalPath = nil
        }
        return FilmtoneCapturePackageSnapshotV1(
            schemaVersion: FilmtoneCapturePackageSnapshotV1.currentSchemaVersion,
            captureId: package.captureId,
            storagePolicyTag: policyTag,
            externalFolderPath: externalPath,
            masterURLPath: package.masterURL.path,
            proxyURLPath: package.proxyURL.path,
            packageDirURLPath: package.packageDirURL.path,
            durationLimitSeconds: package.durationLimitSeconds,
            recordedDurationSeconds: package.recordedDurationSeconds,
            parametersWidthPx: package.parameters.widthPx,
            parametersHeightPx: package.parameters.heightPx,
            parametersFrameRate: package.parameters.frameRate,
            parametersCodec: package.parameters.codec,
            parametersColorSpace: package.parameters.colorSpace,
            parametersStabilization: package.parameters.stabilization,
            writtenAtISO8601: ISO8601DateFormatter().string(from: Date()),
            lensIdentifier: package.lens?.identifier,
            lensDisplayName: package.lens?.displayName,
            lensDeviceType: package.lens?.deviceType,
            lensMagnificationLabel: package.lens?.magnificationLabel,
            lensFormatIndex: package.lens?.formatIndex,
            selectedLookCanonicalUUID: package.selectedLook?.canonicalUUID.uuidString,
            selectedLookSlug: package.selectedLook?.slug,
            selectedLookEnglishName: package.selectedLook?.englishName,
            selectedLookIntensity: package.selectedLook?.intensity,
            exposureMode: package.exposureControl?.mode,
            exposureBiasEV: package.exposureControl?.biasEV,
            focusPointNormalizedX: package.exposureControl?.focusPointX,
            focusPointNormalizedY: package.exposureControl?.focusPointY,
            meteringPointNormalizedX: package.exposureControl?.meteringPointX,
            meteringPointNormalizedY: package.exposureControl?.meteringPointY,
            whiteBalanceMode: package.whiteBalance?.mode,
            whiteBalanceRedGain: package.whiteBalance?.redGain,
            whiteBalanceGreenGain: package.whiteBalance?.greenGain,
            whiteBalanceBlueGain: package.whiteBalance?.blueGain,
            manualISO: package.exposureControl?.manualISO,
            manualShutterDurationSeconds: package.exposureControl?.manualShutterDurationSeconds,
            manualInheritedFromAuto: package.exposureControl?.inheritedFromAuto
        )
    }

    private static func makePackage(
        from snapshot: FilmtoneCapturePackageSnapshotV1
    ) -> FilmtoneCapturePackage {
        let storagePolicy: FilmtoneCaptureStoragePolicy
        switch snapshot.storagePolicyTag {
        case "external":
            if let path = snapshot.externalFolderPath, !path.isEmpty {
                storagePolicy = .externalSecurityScopedFolder(URL(fileURLWithPath: path))
            } else {
                storagePolicy = .internalDocumentsCapped
            }
        default:
            storagePolicy = .internalDocumentsCapped
        }
        let parameters = FilmtoneCaptureParameters(
            widthPx: snapshot.parametersWidthPx,
            heightPx: snapshot.parametersHeightPx,
            frameRate: snapshot.parametersFrameRate,
            codec: snapshot.parametersCodec,
            colorSpace: snapshot.parametersColorSpace,
            stabilization: snapshot.parametersStabilization
        )
        // Lens fields are tri-required: rebuild the record only when all
        // three are present.  Any missing field means the snapshot was
        // either pre-S8-B or partially-written; treat it as "lens
        // unknown" and let downstream code deal with nil rather than
        // fabricating an identity.
        let lens: FilmtoneCaptureLensRecord?
        if let identifier = snapshot.lensIdentifier,
           let displayName = snapshot.lensDisplayName,
           let deviceType = snapshot.lensDeviceType {
            lens = FilmtoneCaptureLensRecord(
                identifier: identifier,
                displayName: displayName,
                deviceType: deviceType,
                magnificationLabel: snapshot.lensMagnificationLabel,
                formatIndex: snapshot.lensFormatIndex
            )
        } else {
            lens = nil
        }
        // S11-D: rebuild the selected-Look record only when the three
        // required identity fields (UUID + name + intensity) round-trip
        // cleanly.  Filmtone-default and pre-M11 snapshots have all of
        // them nil and decode to `selectedLook = nil`.  A partially-
        // written record (e.g. UUID present but name missing) is
        // treated as "look unknown" rather than fabricated, mirroring
        // the lens-record policy above.
        let selectedLook: FilmtoneSelectedLookRecord?
        if let uuidString = snapshot.selectedLookCanonicalUUID,
           let uuid = UUID(uuidString: uuidString),
           let englishName = snapshot.selectedLookEnglishName,
           let intensity = snapshot.selectedLookIntensity {
            selectedLook = FilmtoneSelectedLookRecord(
                canonicalUUID: uuid,
                slug: snapshot.selectedLookSlug,
                englishName: englishName,
                intensity: intensity
            )
        } else {
            selectedLook = nil
        }
        // S12-C / S12-E: rebuild the exposure-control record only
        // when `exposureMode` is present — that is the M12 sentinel
        // field that pre-M12 snapshots lack.  When the trigger is set,
        // we default `biasEV` to 0.0 if absent (treating "explicit
        // zero" as the floor), and the focus / metering points stay
        // independently optional because a run that never tapped
        // leaves them nil.  Manual-only fields (`manualISO` /
        // `manualShutterDurationSeconds` / `manualInheritedFromAuto`)
        // pass through verbatim — auto-mode runs leave them nil and
        // we do not synthesize values for them on a manual snapshot
        // that is missing one (S12-F's truth-gate verifier catches
        // partial-write states; decode stays permissive so a flaky
        // write does not corrupt the package linkage).
        let exposureControl: FilmtoneCaptureExposureControlRecord?
        if let mode = snapshot.exposureMode {
            exposureControl = FilmtoneCaptureExposureControlRecord(
                mode: mode,
                biasEV: snapshot.exposureBiasEV ?? 0.0,
                focusPointX: snapshot.focusPointNormalizedX,
                focusPointY: snapshot.focusPointNormalizedY,
                meteringPointX: snapshot.meteringPointNormalizedX,
                meteringPointY: snapshot.meteringPointNormalizedY,
                manualISO: snapshot.manualISO,
                manualShutterDurationSeconds: snapshot.manualShutterDurationSeconds,
                inheritedFromAuto: snapshot.manualInheritedFromAuto
            )
        } else {
            exposureControl = nil
        }
        // S12-D: rebuild the white-balance record only when
        // `whiteBalanceMode` is present (the M12 sentinel field).
        // Auto-mode snapshots are stored with the gains nil — that is
        // intentional, see `FilmtoneCaptureWhiteBalanceRecord` doc —
        // so we do NOT require the gains to be present to rebuild.
        // Locked-mode snapshots that are missing one or more gains
        // are still rebuilt here (the truth-gate verifier in S12-F
        // catches partial-write states).  Pre-M12 snapshots leave
        // `whiteBalance = nil` on the package.
        let whiteBalance: FilmtoneCaptureWhiteBalanceRecord?
        if let mode = snapshot.whiteBalanceMode {
            whiteBalance = FilmtoneCaptureWhiteBalanceRecord(
                mode: mode,
                redGain: snapshot.whiteBalanceRedGain,
                greenGain: snapshot.whiteBalanceGreenGain,
                blueGain: snapshot.whiteBalanceBlueGain
            )
        } else {
            whiteBalance = nil
        }
        return FilmtoneCapturePackage(
            captureId: snapshot.captureId,
            storagePolicy: storagePolicy,
            masterURL: URL(fileURLWithPath: snapshot.masterURLPath),
            proxyURL: URL(fileURLWithPath: snapshot.proxyURLPath),
            packageDirURL: URL(fileURLWithPath: snapshot.packageDirURLPath),
            durationLimitSeconds: snapshot.durationLimitSeconds,
            recordedDurationSeconds: snapshot.recordedDurationSeconds,
            parameters: parameters,
            lens: lens,
            selectedLook: selectedLook,
            exposureControl: exposureControl,
            whiteBalance: whiteBalance
        )
    }

    private static func encode(
        snapshot: FilmtoneCapturePackageSnapshotV1
    ) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(snapshot)
    }
}

#endif
