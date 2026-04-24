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
            args.count == 2,
            "usage: verify-phase0-contract <canonical-export-request> <legacy-project-state>"
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

        print("Phase0 contract fixtures verified")
    }
}
