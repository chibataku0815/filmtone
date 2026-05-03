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
        sourceInterpretation: String? = nil
    ) throws -> URL {
        let sidecarURL = sidecarURL(for: request.outputURL)
        let payload = sidecarPayload(for: request, sourceInterpretation: sourceInterpretation)
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
        sourceInterpretation: String? = nil
    ) -> [String: Any] {
        let params = FilmtonePresetCatalog.params(for: request.presetName)
        let lookId = FilmtonePresetCatalog.lookId(for: request.presetName)
        let lookVersion = FilmtonePresetCatalog.presetVersion

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
                "baseLookName": request.presetName,
                "strength": 1.0,
            ],
            "lookId": lookId,
            "lookVersion": lookVersion,
            "quickState": [
                "filmCharacter": 0.0,
                "era": 0.0,
                "dynamics": 0.0,
            ],
        ]
        if let sourceInterpretation {
            payload["sourceInterpretation"] = sourceInterpretation
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
