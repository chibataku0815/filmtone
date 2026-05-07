import Foundation
import FilmLabSwiftCore

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
        try expect(
            abs(canonical.grade.params.shutterAngle) < 0.0001,
            "canonical shutterAngle drift"
        )
        try expect(
            abs(canonical.grade.params.trailIntensity) < 0.0001,
            "canonical trailIntensity drift"
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
        try expect(legacy.presetName == "iphone", "legacy presetName migration drift")
        try expect(
            legacy.output == FilmtonePhase0Math.outputProfile,
            "legacy output profile drift"
        )
        try expect(
            abs(legacy.params.shutterAngle) < 0.0001,
            "legacy shutterAngle should default to zero"
        )
        try expect(
            abs(legacy.params.trailIntensity) < 0.0001,
            "legacy trailIntensity should default to zero"
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
        try runLutClearRequestContracts(decoder: decoder, encoder: encoder)
        try runLutIntensityContracts()
        try runOpticalFilterRequestContract(decoder: decoder, encoder: encoder)

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
            FilmtonePhase0Generated.paramsByName.count == 4,
            "preset count should be 4 (got \(FilmtonePhase0Generated.paramsByName.count))"
        )
        // v1.4 Look V2 — re-derived from CD reference frames (warmglow /
        // guasha / mourning). handoff §3.6 reversal: Filmtone Signature
        // (iphone) is no longer the spatial-weakest; halation rises toward
        // portra reference (0.18). Soft Blue gets subtle warm window halo;
        // Amber Glow gets dramatic gold200-class warm halation.
        let expectedHalationByPreset = [
            "reset": 0.0,
            "iphone": 0.10,
            "softBlue": 0.06,
            "amberGlow": 0.16,
        ]
        for (presetName, expectedHalation) in expectedHalationByPreset {
            guard let params = FilmtonePhase0Generated.paramsByName[presetName] else {
                throw ContractCheckError(message: "missing iOS preset \(presetName)")
            }
            try expect(
                abs(params.halationIntensity - expectedHalation) < 1e-6,
                "iOS preset \(presetName) halation drift"
            )
        }

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

    static func runLutClearRequestContracts(
        decoder: JSONDecoder,
        encoder: JSONEncoder
    ) throws {
        let inputLut = makeLut(title: "Input LUT", intensity: 0.8)
        let creativeLut = makeLut(title: "Creative LUT", intensity: 0.6)

        var inputCleared = FilmtonePhase0Math.createProjectState()
        inputCleared.inputLut = inputLut
        inputCleared.creativeLut = creativeLut
        inputCleared.inputLut = nil

        let inputClearedRequest = try makeRequest(project: inputCleared)
        try expect(inputClearedRequest.lut == nil, "input clear request should not emit legacy lut")
        try expect(inputClearedRequest.inputLut == nil, "input clear request should clear inputLut")
        try expect(
            inputClearedRequest.creativeLut?.intensity == creativeLut.intensity,
            "input clear request should preserve creativeLut"
        )

        var creativeCleared = FilmtonePhase0Math.createProjectState()
        creativeCleared.inputLut = inputLut
        creativeCleared.creativeLut = creativeLut
        creativeCleared.creativeLut = nil

        let creativeClearedRequest = try makeRequest(project: creativeCleared)
        try expect(creativeClearedRequest.lut == nil, "creative clear request should not emit legacy lut")
        try expect(
            creativeClearedRequest.inputLut?.intensity == inputLut.intensity,
            "creative clear request should preserve inputLut"
        )
        try expect(creativeClearedRequest.creativeLut == nil, "creative clear request should clear creativeLut")

        let clearedData = try encoder.encode(FilmtonePhase0Math.createProjectState())
        let clearedString = String(decoding: clearedData, as: UTF8.self)
        try expect(!clearedString.contains("\"lut\""), "cleared project should not encode legacy lut")

        let decodedCleared = try decoder.decode(FilmtoneProjectState.self, from: clearedData)
        try expect(decodedCleared.inputLut == nil, "decoded cleared project should keep inputLut nil")
        try expect(decodedCleared.creativeLut == nil, "decoded cleared project should keep creativeLut nil")

        let decodedClearedRequest = try makeRequest(project: decodedCleared)
        try expect(decodedClearedRequest.lut == nil, "decoded cleared request should not emit legacy lut")
        try expect(decodedClearedRequest.inputLut == nil, "decoded cleared request should keep inputLut nil")
        try expect(decodedClearedRequest.creativeLut == nil, "decoded cleared request should keep creativeLut nil")
    }

    static func runLutIntensityContracts() throws {
        try expect(FilmtonePhase0Math.clampLutIntensity(-0.25) == 0, "LUT intensity should clamp below zero")
        try expect(FilmtonePhase0Math.clampLutIntensity(1.25) == 1, "LUT intensity should clamp above one")

        let originalInput = makeLut(title: "Input LUT", intensity: 0.8)
        let originalCreative = makeLut(title: "Creative LUT", intensity: 0.6)

        var inputChanged = FilmtonePhase0Math.createProjectState()
        inputChanged.inputLut = makeLut(title: originalInput.title, intensity: 0.37)
        inputChanged.creativeLut = originalCreative

        let inputChangedRequest = try makeRequest(project: inputChanged)
        try expect(inputChangedRequest.lut == nil, "input intensity request should not emit legacy lut")
        try expect(
            abs((inputChangedRequest.inputLut?.intensity ?? -1) - 0.37) < 0.0001,
            "input intensity should transport to request.inputLut"
        )
        try expect(
            abs((inputChangedRequest.creativeLut?.intensity ?? -1) - originalCreative.intensity) < 0.0001,
            "input intensity change should preserve creativeLut"
        )

        var creativeChanged = FilmtonePhase0Math.createProjectState()
        creativeChanged.inputLut = originalInput
        creativeChanged.creativeLut = makeLut(title: originalCreative.title, intensity: 0.42)

        let creativeChangedRequest = try makeRequest(project: creativeChanged)
        try expect(creativeChangedRequest.lut == nil, "creative intensity request should not emit legacy lut")
        try expect(
            abs((creativeChangedRequest.inputLut?.intensity ?? -1) - originalInput.intensity) < 0.0001,
            "creative intensity change should preserve inputLut"
        )
        try expect(
            abs((creativeChangedRequest.creativeLut?.intensity ?? -1) - 0.42) < 0.0001,
            "creative intensity should transport to request.creativeLut"
        )
    }

    static func runOpticalFilterRequestContract(
        decoder: JSONDecoder,
        encoder: JSONEncoder
    ) throws {
        var project = FilmtonePhase0Math.createProjectState()
        project.opticalFilterProfileId = "backlightVeil-1-4"

        let request = try makeRequest(project: project)
        try expect(
            request.opticalFilterProfileId == "backlightVeil-1-4",
            "Backlight Veil profile id should transport to export request"
        )

        let encoded = try encoder.encode(project)
        let decoded = try decoder.decode(FilmtoneProjectState.self, from: encoded)
        try expect(
            decoded.opticalFilterProfileId == "backlightVeil-1-4",
            "Backlight Veil profile id should persist in project state"
        )
    }

    static func makeRequest(project: FilmtoneProjectState) throws -> Phase0ExportRequestDTO {
        try FilmtonePhase0Math.buildExportRequest(
            source: SourceInfoDTO(
                uri: "file:///tmp/lut-clear-contract.mov",
                filename: "lut-clear-contract.mov",
                kind: .video,
                mimeType: "video/quicktime"
            ),
            probe: nil,
            project: project
        )
    }

    static func makeLut(title: String, intensity: Double) -> ParsedCubeLutDTO {
        ParsedCubeLutDTO(
            title: title,
            size: 2,
            data: [
                0, 0, 0,
                1, 0, 0,
                0, 1, 0,
                1, 1, 0,
                0, 0, 1,
                1, 0, 1,
                0, 1, 1,
                1, 1, 1,
            ],
            intensity: intensity
        )
    }
}
