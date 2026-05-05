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
        resolvedSourceProfile: CameraProfileCatalogEntry? = nil
    ) throws -> URL {
        let sidecarURL = sidecarURL(for: request.outputURL)
        let payload = sidecarPayload(
            for: request,
            sourceInterpretation: sourceInterpretation,
            resolvedSourceProfile: resolvedSourceProfile
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
        resolvedSourceProfile: CameraProfileCatalogEntry? = nil
    ) -> [String: Any] {
        let strength = FilmtonePresetCatalog.clampStrength(request.presetStrength)
        let liveQuickState = request.quickState.clamped()
        let params = FilmtonePresetCatalog.resolved(
            presetName: request.presetName,
            strength: strength,
            lookSlug: request.lookSlug,
            quickState: liveQuickState,
            paramOverrides: request.paramOverrides
        )
        let lookVersion = FilmtonePresetCatalog.presetVersion

        // M5-A.2: when a Look is active, switch lookId to the
        // `filmtone:builtin:<slug>:<v>` namespace and overwrite
        // baseLookName with the slug so a sidecar consumer can route by
        // identity. baseLookName intentionally hides the underlying preset
        // ("reset") because the Look's overrides + cube are the SSOT.
        let lookId: String
        let baseLookName: String
        if let lookSlug = request.lookSlug {
            lookId = FilmtonePresetCatalog.lookId(forSlug: lookSlug)
            baseLookName = lookSlug
        } else {
            lookId = FilmtonePresetCatalog.lookId(for: request.presetName)
            baseLookName = request.presetName
        }

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
            "batchLookChoice": [
                "lookId": lookId,
                "lookVersion": lookVersion,
                "baseLookName": baseLookName,
                "strength": strength,
            ],
            "lookId": lookId,
            "lookVersion": lookVersion,
            "quickState": [
                "filmCharacter": liveQuickState.filmCharacter,
                "era": liveQuickState.era,
                "dynamics": liveQuickState.dynamics,
            ],
        ]
        if let sourceInterpretation {
            payload["sourceInterpretation"] = sourceInterpretation
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
        // M5-A.2 additive: emit `creativeLut` provenance when a Look is
        // active and its cube resolves. SHA mismatch / missing resource
        // path returns nil from the loader → block is omitted (OQ-3:
        // attempted-and-failed signal not surfaced in the sidecar).
        if let lookSlug = request.lookSlug,
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
        return payload
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
            "fade": p.fade,
            "shadowTone": p.shadowTone,
            "highlightTone": p.highlightTone,
            "shadowHue": p.shadowHue,
            "highlightHue": p.highlightHue,
            "vignette": p.vignette,
            "grainIntensity": p.grainIntensity,
        ]
    }
}
