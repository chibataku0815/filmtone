import Foundation

struct ContractCheckError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw ContractCheckError(message: message)
    }
}

@main
struct VerifyPhase0Contract {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        try expect(
            args.count == 2 || args.count == 3,
            "usage: verify-phase0-contract <canonical-export-request> <legacy-project-state> [<hlg-export-request>]"
        )

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let canonicalURL = URL(fileURLWithPath: args[0])
        let legacyURL = URL(fileURLWithPath: args[1])

        let canonical = try decoder.decode(
            Phase0ExportRequestDTO.self,
            from: Data(contentsOf: canonicalURL)
        )
        try expect(
            canonical.grade.presetVersion == FilmtonePhase0Math.presetVersion,
            "canonical presetVersion drift"
        )
        try expect(
            canonical.output == FilmtonePhase0Math.outputProfile,
            "canonical output profile drift"
        )
        try expect(
            canonical.sourceUri == "file:///tmp/phase0-source.mov",
            "canonical sourceUri drift"
        )
        try expect(
            canonical.sourceProbe?.cameraOptics?.source == "assumed",
            "canonical cameraOptics drift"
        )
        try expect(canonical.inputLut != nil, "canonical request is missing inputLut")
        try expect(canonical.creativeLut != nil, "canonical request is missing creativeLut")
        try expect(
            abs(canonical.grade.params.exposure - 0.12) < 0.0001,
            "canonical exposure drift"
        )
        try expect(
            abs(canonical.grade.params.grainIntensity - 0.1) < 0.0001,
            "canonical grainIntensity drift"
        )

        let legacy = try decoder.decode(
            FilmtoneProjectState.self,
            from: Data(contentsOf: legacyURL)
        )
        try expect(legacy.inputLut == nil, "legacy fixture should not populate inputLut")
        try expect(legacy.creativeLut != nil, "legacy fixture should populate creativeLut")
        try expect(
            abs((legacy.creativeLut?.intensity ?? 0) - 0.8) < 0.0001,
            "legacy creativeLut intensity drift"
        )
        try expect(legacy.presetName == "cinematic", "legacy presetName drift")
        try expect(
            legacy.output == FilmtonePhase0Math.outputProfile,
            "legacy output profile drift"
        )

        let reencoded = try encoder.encode(legacy)
        let reencodedString = String(decoding: reencoded, as: UTF8.self)
        try expect(
            reencodedString.contains("\"creativeLut\""),
            "re-encoded legacy state is missing creativeLut"
        )
        try expect(
            !reencodedString.contains("\"lut\""),
            "re-encoded legacy state still contains lut"
        )

        // --- Hidden defaults SSOT (CONTRACT_DEFAULTS 19 keys) ---
        // Confirms that the generated Swift block matches the TS source of
        // truth. Three drift sensors: two hot keys (ray-angle, used by T3)
        // plus a distant field (crossFilterEdgeLengthGain) to catch a
        // half-emitted block.
        try expect(
            abs(FilmtonePhase0Generated.hiddenDefaults.depthRayAngleGamma - 1.4) < 1e-6,
            "hidden defaults: depthRayAngleGamma drift"
        )
        try expect(
            abs(FilmtonePhase0Generated.hiddenDefaults.depthRayAngleInnerThreshold - 0.1) < 1e-6,
            "hidden defaults: depthRayAngleInnerThreshold drift"
        )
        try expect(
            abs(FilmtonePhase0Generated.hiddenDefaults.crossFilterEdgeLengthGain - 0.45) < 1e-6,
            "hidden defaults: crossFilterEdgeLengthGain drift (distant key sanity check)"
        )

        // --- Preset count sanity ---
        try expect(
            FilmtonePhase0Generated.paramsByName.count == 10,
            "preset count should be 10 (got \(FilmtonePhase0Generated.paramsByName.count))"
        )

        // --- Optional HLG fixture decode (Stream 1 produced fixture) ---
        if args.count == 3 {
            let hlgURL = URL(fileURLWithPath: args[2])
            if FileManager.default.fileExists(atPath: hlgURL.path) {
                let hlg = try decoder.decode(
                    Phase0ExportRequestDTO.self,
                    from: Data(contentsOf: hlgURL)
                )
                try expect(
                    hlg.sourceProbe?.sourceVideoMetadata?.colorClass == .hdrHlg,
                    "HLG fixture colorClass should be .hdrHlg"
                )
                try expect(
                    hlg.sourceProbe?.sourceVideoMetadata?.hdrPreparationPolicy?.strategy == .coreImageToneMapSdr,
                    "HLG fixture hdrPreparationPolicy.strategy should be .coreImageToneMapSdr"
                )
            }
        }

        print("Phase0 contract fixtures verified")
    }
}
