import FilmLabSwiftCore
import Foundation

// Sidecar Case B (Look canonical only) per master handoff §10. Look
// Unification (`feature/desktop-look-unification`) is not yet landed in
// main (Phase 1c chat 開始時 grep: `BASE_LOOKS` export 不在 / Look
// Unification chat B handoff §0.6 — branch landed but not main-merged).
// Until merge, this writer emits Look-only fields. Phase 1c continues the
// Phase 1b posture; if main merge is observed mid-chat, switch to dual emit.
//
// Phase 1c additive: `sourceKind` ("still" | "video"). Existing readers
// ignore unknown fields so this is backward-compatible.
//
// Phase 2 C1 additive: `sourceInterpretation` (e.g. "sdr-bt709" /
// "display-p3-sdr" / "hdr-pq" / "apple-log" / "unknown"). Mirrors the
// `FilmtoneColorPipelineContract.sourceInterpretationID` produced by the
// canonical factory. Round-trips Phase 2 acceptance gate "Source profile id
// round-trips through sidecar" (04-phase-plan.md §Phase 2). Optional —
// callers without a contract may pass nil and the field is omitted.

enum FilmtoneSidecarWriter {
    static let appVersion = "0.1.0-macos"
    static let appPlatform = "macos-native"
    static let schemaVersion = 1

    static func writeSidecar(
        for request: any FilmtoneSidecarRequest,
        sourceInterpretation: String? = nil,
        resolvedSourceProfile: CameraProfileCatalogEntry? = nil,
        videoTimingMetadata: FilmtoneVideoTimingMetadataDTO? = nil
    ) throws -> URL {
        let sidecarURL = sidecarURL(for: request.outputURL)
        let payload = sidecarPayload(
            for: request,
            sourceInterpretation: sourceInterpretation,
            resolvedSourceProfile: resolvedSourceProfile,
            videoTimingMetadata: videoTimingMetadata
        )
        let json = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        try json.write(to: sidecarURL)
        return sidecarURL
    }

    static func sidecarURL(for outputURL: URL) -> URL {
        outputURL
            .deletingPathExtension()
            .appendingPathExtension("filmtone.json")
    }

    static func sidecarPayload(
        for request: any FilmtoneSidecarRequest,
        sourceInterpretation: String? = nil,
        resolvedSourceProfile: CameraProfileCatalogEntry? = nil,
        videoTimingMetadata: FilmtoneVideoTimingMetadataDTO? = nil
    ) -> [String: Any] {
        let gradeRecipe = request.gradeRecipe
        let strength = gradeRecipe.presetStrength
        let liveQuickState = gradeRecipe.quickState
        let resolvedGrade = FilmtoneGradeResolution.resolve(recipe: gradeRecipe)
        let params = resolvedGrade.params
        let lookVersion = FilmtonePresetCatalog.presetVersion

        // M5-A.2: when a Look is active, switch lookId to the
        // `filmtone:builtin:<slug>:<v>` namespace and overwrite
        // baseLookName with the slug so a sidecar consumer can route by
        // identity. baseLookName intentionally hides the underlying preset
        // ("reset") because the Look's overrides + cube are the SSOT.
        let lookId: String = gradeRecipe.lookSlug.map(FilmtonePresetCatalog.lookId(forSlug:))
            ?? FilmtonePresetCatalog.lookId(for: gradeRecipe.presetName)
        let baseLookName: String = gradeRecipe.lookSlug ?? gradeRecipe.presetName

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let exportedAt = isoFormatter.string(from: Date())

        var payload: [String: Any] = [
            "schemaVersion": schemaVersion,
            "exportedAtIso": exportedAt,
            "appVersion": appVersion,
            "appPlatform": appPlatform,
            "sourceFile": request.sourceURL.path,
            "sourceKind": request.sourceKind.rawValue,
            "outputFile": request.outputURL.path,
            "gradeParams": gradeParamsDictionary(params),
            "quickState": [
                "filmCharacter": liveQuickState.filmCharacter,
                "era": liveQuickState.era,
                "dynamics": liveQuickState.dynamics,
            ],
        ]
        if let importedGradeLook = gradeRecipe.importedGradeLook {
            var imported: [String: Any] = [
                "id": importedGradeLook.id.uuidString,
                "title": importedGradeLook.title,
                "sourceKind": importedGradeLook.source.sourceKindLabel,
                "resolvedLutIntensity": resolvedGrade.lutIntensity,
                "unsupportedMetadata": resolvedGrade.unsupportedMetadata,
            ]
            if let sourceGraph = importedGradeLook.sourceGraph,
               let graph = try? jsonObject(sourceGraph) {
                imported["sourceGraph"] = graph
            }
            payload["imported_grade"] = imported
        } else {
            payload["batchLookChoice"] = [
                "lookId": lookId,
                "lookVersion": lookVersion,
                "baseLookName": baseLookName,
                "strength": strength,
            ]
            payload["lookId"] = lookId
            payload["lookVersion"] = lookVersion
        }
        if let sourceInterpretation {
            payload["sourceInterpretation"] = sourceInterpretation
        }
        if let videoTimingMetadata {
            var timing: [String: Any] = [
                "videoTimingMode": videoTimingMetadata.videoTimingMode,
                "targetFps": videoTimingMetadata.targetFps,
                "speedMultiplier": videoTimingMetadata.speedMultiplier,
                "audioPolicy": videoTimingMetadata.audioPolicy,
            ]
            if let sourceFps = videoTimingMetadata.sourceFps {
                timing["sourceFps"] = sourceFps
            }
            if let sourceDurationSec = videoTimingMetadata.sourceDurationSec {
                timing["sourceDurationSec"] = sourceDurationSec
            }
            if let outputDurationSec = videoTimingMetadata.outputDurationSec {
                timing["outputDurationSec"] = outputDurationSec
            }
            payload["videoTiming"] = timing
        }
        if let highlightMarkers = request.highlightMarkers,
           !highlightMarkers.isEmpty,
           let markerPayload = try? jsonObject(highlightMarkers) {
            payload["highlightMarkers"] = markerPayload
        }
        // M5-C.1 additive: emit the user's source profile selection plus
        // (when known) the catalog entry actually applied. `selection`
        // captures intent (Auto vs sticky pick); `resolvedId` captures what
        // the export actually applied — useful when Auto resolved to
        // something like `apple-log` after probe. Existing readers ignore
        // unknown fields → backward-compatible.
        var sourceProfilePayload: [String: Any] = [
            "selection": request.sourceProfileSelection.identifierString,
        ]
        if let resolvedSourceProfile {
            sourceProfilePayload["resolvedId"] = resolvedSourceProfile.id
            sourceProfilePayload["resolvedName"] = resolvedSourceProfile.englishName
            if let curve = resolvedSourceProfile.curve {
                sourceProfilePayload["resolvedCurve"] = curve.rawValue
            }
        }
        payload["sourceProfile"] = sourceProfilePayload
        // M5-L3 additive: preserve the named optical filter identity
        // separately from `gradeParams`, which already contains the
        // resolved visible Backlight Veil values.
        // M5-M (CC-B) additive: emit `opticalFilterIntensity` when it
        // differs from 1.0 so readers can reconstruct the user's cursor
        // position. Omit at 1.0 for backward-compat (old readers ignore
        // the extra key anyway; new readers default to 1.0 when absent).
        if var opticalFilterProfile = FilmtoneOpticalFilterCatalog.sidecarPayload(
            for: gradeRecipe.opticalFilterProfileId
        ) {
            let intensity = gradeRecipe.opticalFilterIntensity
            if abs(intensity - 1.0) > 1e-9 {
                opticalFilterProfile["opticalFilterIntensity"] = intensity
            }
            payload["opticalFilterProfile"] = opticalFilterProfile
        }
        // M5-A.2 additive: emit `creativeLut` provenance when a Look is
        // active and its cube resolves. SHA mismatch / missing resource
        // path returns nil from the loader → block is omitted (OQ-3:
        // attempted-and-failed signal not surfaced in the sidecar).
        if case .importedGrade = resolvedGrade.source, let creativeLut = resolvedGrade.creativeLut {
            payload["creativeLut"] = [
                "size": creativeLut.size,
                "intensity": resolvedGrade.lutIntensity,
                "sourceHash": creativeLut.sourceHash,
                "source": "imported-grade",
            ]
        } else if let packageCreativeLut = gradeRecipe.packageCreativeLut {
            payload["creativeLut"] = [
                "size": packageCreativeLut.size,
                "intensity": packageCreativeLut.intensity,
                "sourceHash": packageCreativeLut.sourceHash,
                "source": "capture-package",
            ]
        } else if let lookSlug = gradeRecipe.lookSlug,
           strength > 0,
           let look = FilmtoneCreativePackCatalog.find(slug: lookSlug),
           let prepared = FilmtoneCreativeLutLoader.load(look: look) {
            payload["creativeLut"] = [
                "size": prepared.size,
                "intensity": prepared.intensity,
                "sourceHash": prepared.sourceHash,
                "bundledSlug": look.slug,
                "bundledPackId": look.packId,
            ]
        }
        if let capturePackageProvenance = request.capturePackageProvenance {
            payload["captureProvenance"] = captureProvenanceDictionary(capturePackageProvenance)
        }
        return payload
    }

    private static func captureProvenanceDictionary(
        _ provenance: FilmtoneCapturePackageProvenance
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "captureId": provenance.captureId,
            "packageJSONPath": provenance.packageJSONPath,
            "sourceMode": provenance.sourceMode.rawValue,
            "masterURLPath": provenance.masterURLPath,
            "proxyURLPath": provenance.proxyURLPath,
        ]
        if let fallbackReason = provenance.fallbackReason {
            payload["fallbackReason"] = fallbackReason
        }
        if let selectedLookSlug = provenance.selectedLookSlug {
            payload["selectedLookSlug"] = selectedLookSlug
        }
        if let selectedLookEnglishName = provenance.selectedLookEnglishName {
            payload["selectedLookEnglishName"] = selectedLookEnglishName
        }
        if let customLutTitle = provenance.customLutTitle {
            payload["customLutTitle"] = customLutTitle
        }
        if let customLutLibraryId = provenance.customLutLibraryId {
            payload["customLutLibraryId"] = customLutLibraryId
        }
        if let customLutSourceHash = provenance.customLutSourceHash {
            payload["customLutSourceHash"] = customLutSourceHash
        }
        if let customLutSize = provenance.customLutSize {
            payload["customLutSize"] = customLutSize
        }
        if let customLutIntensity = provenance.customLutIntensity {
            payload["customLutIntensity"] = customLutIntensity
        }
        if let customLutConversionPolicy = provenance.customLutConversionPolicy {
            payload["customLutConversionPolicy"] = customLutConversionPolicy
        }
        if let customLutPayloadState = provenance.customLutPayloadState {
            payload["customLutPayloadState"] = customLutPayloadState
        }
        if let customLutDataRef = provenance.customLutDataRef {
            payload["customLutDataRef"] = customLutDataRef
        }
        if let customLutDataFormat = provenance.customLutDataFormat {
            payload["customLutDataFormat"] = customLutDataFormat
        }
        if let requestedStabilization = provenance.requestedStabilization {
            payload["requestedStabilization"] = requestedStabilization
        }
        if let observedStabilization = provenance.observedStabilization {
            payload["observedStabilization"] = observedStabilization
        }
        if let requestedCaptureRotationDegrees = provenance.requestedCaptureRotationDegrees {
            payload["requestedCaptureRotationDegrees"] = requestedCaptureRotationDegrees
        }
        if let observedCaptureRotationDegrees = provenance.observedCaptureRotationDegrees {
            payload["observedCaptureRotationDegrees"] = observedCaptureRotationDegrees
        }
        if let masterAudioTrackCount = provenance.masterAudioTrackCount {
            payload["masterAudioTrackCount"] = masterAudioTrackCount
        }
        return payload
    }

    static func readHighlightMarkers(matchingSourceURL sourceURL: URL) -> FilmtoneHighlightMarkers? {
        let directory = sourceURL.deletingLastPathComponent()
        guard
            let urls = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
        else {
            return nil
        }

        let sourceFilename = sourceURL.lastPathComponent
        for url in urls
            .filter({ $0.pathExtension.lowercased() == "json" && $0.lastPathComponent.lowercased().contains("filmtone") })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard
                let data = try? Data(contentsOf: url),
                let envelope = try? JSONDecoder().decode(HighlightMarkerEnvelope.self, from: data),
                let markers = envelope.highlightMarkers,
                !markers.isEmpty
            else {
                continue
            }
            if markers.sourceIdentity.filename == nil ||
                markers.sourceIdentity.filename == sourceFilename ||
                envelope.package?.sourceMediaFilename == sourceFilename {
                return markers
            }
        }
        return nil
    }

    private static func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }

    private struct HighlightMarkerEnvelope: Decodable {
        let package: HighlightMarkerPackage?
        let highlightMarkers: FilmtoneHighlightMarkers?
    }

    private struct HighlightMarkerPackage: Decodable {
        let sourceMediaFilename: String?
    }

    private static func gradeParamsDictionary(_ p: FilmtonePhase0Params) -> [String: Double] {
        [
            "exposure": p.exposure,
            "contrast": p.contrast,
            "saturation": p.saturation,
            "temperature": p.temperature,
            "tint": p.tint,
            "rgbShift": p.rgbShift,
            "lensSoftness": p.lensSoftness,
            "detailSoftness": p.detailSoftness,
            "grainRadialMix": p.grainRadialMix,
            "grainSize": p.grainSize,
            "bloomThreshold": p.bloomThreshold,
            "bloomStrength": p.bloomStrength,
            "bloomRadius": p.bloomRadius,
            "diffusion": p.diffusion,
            "halationIntensity": p.halationIntensity,
            "halationSpread": p.halationSpread,
            "halationHue": p.halationHue,
            "halationThreshold": p.halationThreshold,
            "halationRadius": p.halationRadius,
            "bloomSoftKnee": p.bloomSoftKnee,
            "halationSoftKnee": p.halationSoftKnee,
            "compressionAmount": p.compressionAmount,
            "compressionRange": p.compressionRange,
            "printContrast": p.printContrast,
            "cyan": p.cyan,
            "magenta": p.magenta,
            "yellow": p.yellow,
            "shutterAngle": p.shutterAngle,
            "trailIntensity": p.trailIntensity,
            "filmBreathAmount": p.filmBreathAmount,
            "fade": p.fade,
            "shadowTone": p.shadowTone,
            "shadowLatitude": p.shadowLatitude,
            "highlightTone": p.highlightTone,
            "shadowHue": p.shadowHue,
            "highlightHue": p.highlightHue,
            "vignette": p.vignette,
            "grainIntensity": p.grainIntensity,
        ]
    }
}
