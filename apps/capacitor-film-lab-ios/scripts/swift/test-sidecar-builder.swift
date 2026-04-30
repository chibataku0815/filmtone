import Foundation
import CoreGraphics

struct SidecarCheckError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw SidecarCheckError(message: message)
    }
}

@main
struct TestSidecarBuilder {
    static func main() throws {
        try runHlgFixtureBuild()
        try runSidecarURLDerivation()
        try runImageJobDerivation()
        try runSavedLookProvenance()
        print("Sidecar builder tests passed")
    }

    // MARK: - HLG fixture: build + schema asserts

    static func runHlgFixtureBuild() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        try expect(
            args.count >= 1,
            "usage: test-sidecar-builder <hlg-export-request>"
        )
        let fixtureURL = URL(fileURLWithPath: args[0])
        let decoder = JSONDecoder()
        let request = try decoder.decode(
            Phase0ExportRequestDTO.self,
            from: Data(contentsOf: fixtureURL)
        )

        let identity = SidecarDeviceIdentity(
            appVersion: "1.1.0",
            buildNumber: "42",
            deviceModel: "iPhone16,2",
            iosVersion: "17.5",
            exportedAtIso: "2026-04-24T12:00:00Z"
        )

        let inputs = SidecarBuildInputs(
            request: request,
            sourceProbe: request.sourceProbe,
            hdrPolicy: request.sourceProbe?.sourceVideoMetadata?.hdrPreparationPolicy,
            degradedDecodePath: false,
            outputURL: URL(fileURLWithPath: "/tmp/phase0-export.mp4"),
            outputSize: CGSize(width: 1920, height: 1080),
            fileSizeBytes: 12_345_678,
            elapsedMs: 4_200,
            realtimeRatio: 0.35,
            audioPreserved: true,
            identity: identity,
            renderMode: nil,
            mezzanineUsedVariant: nil,
            mezzanineProfileVersion: nil,
            colorPipeline: FilmtoneColorPipeline.defaultOutputContract(
                sourceMetadata: request.sourceProbe?.sourceVideoMetadata?.color,
                sourceColorClass: request.sourceProbe?.sourceVideoMetadata?.colorClass
            ),
            depth: nil,
            appliedSavedLook: nil
        )

        let data = try FilmtoneExportSidecarBuilder.build(inputs)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SidecarCheckError(message: "sidecar payload is not UTF-8")
        }

        // Byte budget — without the LUT data arrays the sidecar must stay small.
        try expect(
            data.count < 8_192,
            "sidecar payload too large: \(data.count) bytes"
        )

        // LUT `data` arrays must NOT leak into the sidecar. `"data":[` would
        // appear if the SerializableLutDTO was encoded verbatim rather than
        // through SidecarLutRef.
        try expect(
            !json.contains("\"data\":["),
            "sidecar JSON unexpectedly contains a LUT data array"
        )
        try expect(
            !json.contains("\"data\" :"),
            "sidecar JSON unexpectedly contains a LUT data key (pretty)"
        )

        // Decode back via the schema struct so required keys are exercised.
        let parsed = try decoder.decode(ParsedSidecar.self, from: data)

        try expect(parsed.kind == "filmtone-export-session", "kind mismatch")
        try expect(
            parsed.schema == "filmtone-ios-export-session-v1",
            "schema mismatch"
        )
        try expect(parsed.version == 1, "version mismatch")
        try expect(parsed.exportedAtIso == "2026-04-24T12:00:00Z", "exportedAtIso mismatch")
        try expect(parsed.appVersion == "1.1.0", "appVersion mismatch")
        try expect(parsed.buildNumber == "42", "buildNumber mismatch")
        try expect(parsed.job == "video", "job mismatch for HLG video fixture")
        try expect(parsed.device.model == "iPhone16,2", "device.model mismatch")
        try expect(parsed.device.iosVersion == "17.5", "device.iosVersion mismatch")

        try expect(
            parsed.input.kind == "video",
            "input.kind should be video"
        )
        try expect(
            parsed.input.sourceUri == request.sourceUri,
            "input.sourceUri mismatch"
        )

        try expect(parsed.hdrPolicy != nil, "hdrPolicy missing")
        try expect(
            parsed.hdrPolicy?.strategy == "core-image-tone-map-sdr",
            "hdrPolicy.strategy mismatch for HLG source"
        )
        try expect(
            parsed.hdrPolicy?.reason == "source-is-hdr-hlg",
            "hdrPolicy.reason mismatch for HLG source"
        )

        try expect(
            parsed.look.presetName == "cinematic",
            "look.presetName mismatch"
        )
        try expect(
            parsed.look.presetVersion == "v1",
            "look.presetVersion mismatch"
        )

        // LUT refs carry only summary info.
        try expect(parsed.lutRefs.inputLut?.size == 2, "inputLut.size should be 2")
        try expect(parsed.lutRefs.inputLut?.intensity == 1.0, "inputLut.intensity should be 1.0")
        try expect(parsed.lutRefs.creativeLut?.size == 2, "creativeLut.size should be 2")
        try expect(
            abs((parsed.lutRefs.creativeLut?.intensity ?? 0) - 0.72) < 1e-9,
            "creativeLut.intensity should be 0.72"
        )

        try expect(parsed.output.longEdge == 1920, "output.longEdge mismatch")
        try expect(parsed.output.fps == 24, "output.fps mismatch")
        try expect(parsed.output.codec == "h264", "output.codec mismatch")
        try expect(parsed.output.container == "mp4", "output.container mismatch")
        try expect(parsed.output.preserveAudio == true, "output.preserveAudio mismatch")
        try expect(
            parsed.output.outputUri.hasSuffix("/tmp/phase0-export.mp4"),
            "output.outputUri mismatch: \(parsed.output.outputUri)"
        )
        try expect(parsed.output.outputWidth == 1920, "output.outputWidth mismatch")
        try expect(parsed.output.outputHeight == 1080, "output.outputHeight mismatch")
        try expect(parsed.output.fileSizeBytes == 12_345_678, "output.fileSizeBytes mismatch")
        try expect(parsed.output.elapsedMs == 4_200, "output.elapsedMs mismatch")
        try expect(
            abs((parsed.output.realtimeRatio ?? 0) - 0.35) < 1e-9,
            "output.realtimeRatio mismatch"
        )
        try expect(
            parsed.output.outputColorProfile == "rec709-sdr-mp4",
            "output.outputColorProfile mismatch"
        )
        try expect(parsed.output.colorPrimaries == "bt709", "output.colorPrimaries mismatch")
        try expect(parsed.output.colorTransfer == "bt709", "output.colorTransfer mismatch")
        try expect(parsed.output.colorSpace == "bt709", "output.colorSpace mismatch")
    }

    // MARK: - Sidecar filename derivation

    static func runSidecarURLDerivation() throws {
        let out = URL(fileURLWithPath: "/tmp/phase0-export.mp4")
        let sidecar = FilmtoneExportSidecarBuilder.sidecarURL(for: out)
        try expect(
            sidecar.path == "/tmp/phase0-export.mp4.filmtone-ios-export-session-v1.json",
            "sidecar filename derivation broke: \(sidecar.path)"
        )
    }

    // MARK: - Job derivation for image sources

    static func runImageJobDerivation() throws {
        let request = Phase0ExportRequestDTO(
            sourceUri: "file:///tmp/phase0-source.jpg",
            sourceKind: .image,
            sourceProbe: nil,
            output: Phase0OutputProfileDTO(
                longEdge: 2048,
                fps: 0,
                codec: "jpeg",
                container: "jpg",
                preserveAudio: false
            ),
            grade: Phase0GradeDTO(
                presetName: "cinematic",
                presetVersion: "v1",
                quickState: Phase0QuickStateDTO(filmCharacter: 0, era: 0, dynamics: 0),
                params: zeroParams()
            ),
            lut: nil,
            inputLut: nil,
            creativeLut: nil,
            renderMode: nil,
            depthEnabled: nil,
            depthRenderer: nil
        )
        let identity = SidecarDeviceIdentity(
            appVersion: "1.1.0",
            buildNumber: "42",
            deviceModel: "iPhone16,2",
            iosVersion: "17.5",
            exportedAtIso: "2026-04-24T12:00:00Z"
        )
        let inputs = SidecarBuildInputs(
            request: request,
            sourceProbe: nil,
            hdrPolicy: nil,
            degradedDecodePath: false,
            outputURL: URL(fileURLWithPath: "/tmp/phase0-export.jpg"),
            outputSize: CGSize(width: 2048, height: 1365),
            fileSizeBytes: nil,
            elapsedMs: 150,
            realtimeRatio: nil,
            audioPreserved: nil,
            identity: identity,
            renderMode: nil,
            mezzanineUsedVariant: nil,
            mezzanineProfileVersion: nil,
            colorPipeline: FilmtoneColorPipeline.defaultOutputContract(
                sourceMetadata: nil,
                sourceColorClass: nil
            ),
            depth: nil,
            appliedSavedLook: nil
        )
        let data = try FilmtoneExportSidecarBuilder.build(inputs)
        let parsed = try JSONDecoder().decode(ParsedSidecar.self, from: data)
        try expect(parsed.job == "image", "job should be 'image' for image sourceKind")
        try expect(parsed.hdrPolicy == nil, "hdrPolicy should be nil for image inputs without metadata")
        try expect(parsed.input.kind == "image", "input.kind should be 'image'")
        try expect(parsed.lutRefs.inputLut == nil, "no inputLut expected")
        try expect(parsed.lutRefs.creativeLut == nil, "no creativeLut expected")
    }

    // MARK: - v1.3 Item 2 Phase E: Saved Look provenance

    /// Verifies that the sidecar's `savedLook` block round-trips correctly for
    /// both built-in catalog entries (bundled / bundledSlug populated) and
    /// user-saved entries (bundled / bundledSlug omitted). Also asserts that
    /// the absent-savedLook path leaves the field unset (so v1.2 readers
    /// continue to ignore an unknown key, per V1 contract).
    static func runSavedLookProvenance() throws {
        let identity = SidecarDeviceIdentity(
            appVersion: "1.3.0",
            buildNumber: "1",
            deviceModel: "iPhone16,2",
            iosVersion: "17.5",
            exportedAtIso: "2026-04-30T03:00:00Z"
        )
        let request = Phase0ExportRequestDTO(
            sourceUri: "file:///tmp/phase0-source.mp4",
            sourceKind: .video,
            sourceProbe: nil,
            output: Phase0OutputProfileDTO(
                longEdge: 1920,
                fps: 24,
                codec: "h264",
                container: "mp4",
                preserveAudio: true
            ),
            grade: Phase0GradeDTO(
                presetName: "iphone",
                presetVersion: "v1",
                quickState: Phase0QuickStateDTO(filmCharacter: 0, era: 0, dynamics: 0),
                params: zeroParams()
            ),
            lut: nil,
            inputLut: nil,
            creativeLut: nil,
            renderMode: nil,
            depthEnabled: nil,
            depthRenderer: nil
        )
        let colorPipeline = FilmtoneColorPipeline.defaultOutputContract(
            sourceMetadata: nil,
            sourceColorClass: nil
        )

        // Case 1: built-in catalog Look applied — bundled / bundledSlug
        // surface for downstream provenance (Filmtone Connect for DaVinci).
        let builtInRef = SidecarSavedLookRef(
            id: "FB1A0001-0000-4000-8000-000000000001",
            name: "Filmtone Signature",
            updatedAtIso: "2026-04-30T00:00:00Z",
            bundled: true,
            bundledSlug: "filmtone-signature"
        )
        let builtInInputs = SidecarBuildInputs(
            request: request,
            sourceProbe: nil,
            hdrPolicy: nil,
            degradedDecodePath: false,
            outputURL: URL(fileURLWithPath: "/tmp/phase0-export.mp4"),
            outputSize: CGSize(width: 1920, height: 1080),
            fileSizeBytes: nil,
            elapsedMs: 1000,
            realtimeRatio: nil,
            audioPreserved: true,
            identity: identity,
            renderMode: nil,
            mezzanineUsedVariant: nil,
            mezzanineProfileVersion: nil,
            colorPipeline: colorPipeline,
            depth: nil,
            appliedSavedLook: builtInRef
        )
        let builtInData = try FilmtoneExportSidecarBuilder.build(builtInInputs)
        guard let builtInJson = String(data: builtInData, encoding: .utf8) else {
            throw SidecarCheckError(message: "built-in sidecar payload is not UTF-8")
        }
        try expect(
            builtInData.count < 8_192,
            "built-in savedLook sidecar exceeds 8KB cap: \(builtInData.count) bytes"
        )
        try expect(
            !builtInJson.contains("\"data\":["),
            "built-in savedLook sidecar leaked a LUT data array"
        )
        let builtInParsed = try JSONDecoder().decode(SavedLookProbeSidecar.self, from: builtInData)
        try expect(builtInParsed.savedLook != nil, "built-in savedLook block missing")
        try expect(
            builtInParsed.savedLook?.id == "FB1A0001-0000-4000-8000-000000000001",
            "built-in savedLook.id mismatch"
        )
        try expect(
            builtInParsed.savedLook?.name == "Filmtone Signature",
            "built-in savedLook.name mismatch"
        )
        try expect(
            builtInParsed.savedLook?.bundled == true,
            "built-in savedLook.bundled should be true"
        )
        try expect(
            builtInParsed.savedLook?.bundledSlug == "filmtone-signature",
            "built-in savedLook.bundledSlug mismatch"
        )

        // Case 2: user-saved Look applied — bundled / bundledSlug omitted via
        // encodeIfPresent. The block itself is present (id + name +
        // updatedAtIso) so importers can still tie the export to a Look.
        let userRef = SidecarSavedLookRef(
            id: "12345678-1234-4123-8123-1234567890AB",
            name: "Sunset Roll",
            updatedAtIso: "2026-04-29T12:34:56Z",
            bundled: nil,
            bundledSlug: nil
        )
        let userInputs = SidecarBuildInputs(
            request: request,
            sourceProbe: nil,
            hdrPolicy: nil,
            degradedDecodePath: false,
            outputURL: URL(fileURLWithPath: "/tmp/phase0-export.mp4"),
            outputSize: CGSize(width: 1920, height: 1080),
            fileSizeBytes: nil,
            elapsedMs: 1000,
            realtimeRatio: nil,
            audioPreserved: true,
            identity: identity,
            renderMode: nil,
            mezzanineUsedVariant: nil,
            mezzanineProfileVersion: nil,
            colorPipeline: colorPipeline,
            depth: nil,
            appliedSavedLook: userRef
        )
        let userData = try FilmtoneExportSidecarBuilder.build(userInputs)
        guard let userJson = String(data: userData, encoding: .utf8) else {
            throw SidecarCheckError(message: "user sidecar payload is not UTF-8")
        }
        try expect(
            userData.count < 8_192,
            "user savedLook sidecar exceeds 8KB cap: \(userData.count) bytes"
        )
        try expect(
            !userJson.contains("\"bundled\""),
            "user-saved Look unexpectedly emitted bundled key"
        )
        try expect(
            !userJson.contains("\"bundledSlug\""),
            "user-saved Look unexpectedly emitted bundledSlug key"
        )
        let userParsed = try JSONDecoder().decode(SavedLookProbeSidecar.self, from: userData)
        try expect(userParsed.savedLook != nil, "user savedLook block missing")
        try expect(
            userParsed.savedLook?.id == "12345678-1234-4123-8123-1234567890AB",
            "user savedLook.id mismatch"
        )
        try expect(
            userParsed.savedLook?.name == "Sunset Roll",
            "user savedLook.name mismatch"
        )
        try expect(
            userParsed.savedLook?.bundled == nil,
            "user savedLook.bundled should be omitted (decoded to nil)"
        )

        // Case 3: no Saved Look applied — block is absent entirely so V1
        // readers ignore the key.
        let absentInputs = SidecarBuildInputs(
            request: request,
            sourceProbe: nil,
            hdrPolicy: nil,
            degradedDecodePath: false,
            outputURL: URL(fileURLWithPath: "/tmp/phase0-export.mp4"),
            outputSize: CGSize(width: 1920, height: 1080),
            fileSizeBytes: nil,
            elapsedMs: 1000,
            realtimeRatio: nil,
            audioPreserved: true,
            identity: identity,
            renderMode: nil,
            mezzanineUsedVariant: nil,
            mezzanineProfileVersion: nil,
            colorPipeline: colorPipeline,
            depth: nil,
            appliedSavedLook: nil
        )
        let absentData = try FilmtoneExportSidecarBuilder.build(absentInputs)
        guard let absentJson = String(data: absentData, encoding: .utf8) else {
            throw SidecarCheckError(message: "absent sidecar payload is not UTF-8")
        }
        try expect(
            !absentJson.contains("\"savedLook\""),
            "no-savedLook export unexpectedly emitted savedLook key"
        )
    }

    // MARK: - Helpers

    static func zeroParams() -> Phase0ParamsDTO {
        Phase0ParamsDTO(
            exposure: 0, contrast: 1, saturation: 1, temperature: 0, tint: 0,
            rgbShift: 0, lensSoftness: 0, grainRadialMix: 0, grainSize: 0,
            bloomThreshold: 0, bloomStrength: 0, bloomRadius: 0,
            diffusion: 0, halationIntensity: 0, halationSpread: 0,
            halationHue: 0, halationThreshold: 0, halationRadius: 0,
            bloomSoftKnee: 0, halationSoftKnee: 0, compressionAmount: 0,
            compressionRange: 0, printContrast: 0, cyan: 0, magenta: 0,
            yellow: 0, shutterAngle: 0, trailIntensity: 0,
            fade: 0, vignette: 0, grainIntensity: 0
        )
    }
}

// MARK: - Parsed-side mirror

private struct ParsedSidecar: Decodable {
    let kind: String
    let schema: String
    let version: Int
    let exportedAtIso: String
    let appVersion: String
    let buildNumber: String
    let job: String
    let device: ParsedDevice
    let input: ParsedInput
    let hdrPolicy: ParsedHdrPolicy?
    let look: ParsedLook
    let lutRefs: ParsedLutRefs
    let output: ParsedOutput
}

private struct ParsedDevice: Decodable {
    let model: String
    let iosVersion: String
}

private struct ParsedInput: Decodable {
    let sourceUri: String
    let kind: String
}

private struct ParsedHdrPolicy: Decodable {
    let strategy: String
    let reason: String
    let requiresFixtureValidation: Bool
}

private struct ParsedLook: Decodable {
    let presetName: String
    let presetVersion: String
}

private struct ParsedLutRef: Decodable {
    let size: Int
    let intensity: Double
}

private struct ParsedLutRefs: Decodable {
    let inputLut: ParsedLutRef?
    let creativeLut: ParsedLutRef?
}

private struct ParsedOutput: Decodable {
    let longEdge: Int
    let fps: Int
    let codec: String
    let container: String
    let preserveAudio: Bool
    let outputUri: String
    let outputWidth: Int
    let outputHeight: Int
    let fileSizeBytes: Int?
    let elapsedMs: Int
    let realtimeRatio: Double?
    let outputColorProfile: String
    let colorPrimaries: String
    let colorTransfer: String
    let colorSpace: String
}

// v1.3 Item 2 Phase E: minimal Decodable surface for the Saved Look provenance
// assertions. The probe omits every other field so the test stays focused on
// the new `savedLook` block alone — the canonical-payload assertions in
// `runHlgFixtureBuild` cover the remainder of the schema.
private struct SavedLookProbeSidecar: Decodable {
    let savedLook: ParsedSavedLookRef?
}

private struct ParsedSavedLookRef: Decodable {
    let id: String
    let name: String
    let updatedAtIso: String
    let bundled: Bool?
    let bundledSlug: String?
}
