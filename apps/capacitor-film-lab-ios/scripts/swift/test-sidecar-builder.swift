import Foundation
import CoreGraphics
import FilmLabSwiftCore

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
        let args = Array(CommandLine.arguments.dropFirst())
        if args.first == "--emit-highlight-marker-sidecar" {
            try expect(
                args.count == 3,
                "usage: test-sidecar-builder --emit-highlight-marker-sidecar <hlg-export-request> <output-sidecar-json>"
            )
            try emitHighlightMarkerSidecar(
                fixturePath: args[1],
                outputPath: args[2]
            )
            print("App-generated highlight marker sidecar written: \(args[2])")
            return
        }

        try runHlgFixtureBuild()
        try runSidecarURLDerivation()
        try runImageJobDerivation()
        try runSavedLookProvenance()
        try runCameraProfileProvenance()
        try runHighlightMarkersSidecarBlock()
        try runConnectPackageUriOrdering()
        try runConnectCubeWriter()
        try runConnectDctlWriter()
        print("Sidecar builder tests passed")
    }

    static func emitHighlightMarkerSidecar(
        fixturePath: String,
        outputPath: String
    ) throws {
        let fixtureURL = URL(fileURLWithPath: fixturePath)
        let outputURL = URL(fileURLWithPath: outputPath)
        let decoder = JSONDecoder()
        let request = try decoder.decode(
            Phase0ExportRequestDTO.self,
            from: Data(contentsOf: fixtureURL)
        )
        let markers = FilmtoneHighlightMarkers(
            sourceIdentity: FilmtoneMarkerSourceIdentity(
                filename: "C0061.mov",
                durationSec: 123.45,
                fps: 29.97,
                fileSizeBytes: 123_456_789,
                contentHash: "sha256:app-generated-smoke"
            ),
            markers: [
                FilmtoneHighlightMarker(
                    id: "filmtone-marker-001",
                    sourceTimeSec: 42.13,
                    sourceFps: 29.97,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-05-05T00:00:00.000Z"
                )
            ]
        )
        let inputs = SidecarBuildInputs(
            request: request,
            sourceProbe: request.sourceProbe,
            hdrPolicy: request.sourceProbe?.sourceVideoMetadata?.hdrPreparationPolicy,
            degradedDecodePath: false,
            outputURL: URL(fileURLWithPath: "/tmp/C0061-filmtone.mov"),
            outputSize: CGSize(width: 3840, height: 2160),
            fileSizeBytes: 12_345_678,
            elapsedMs: 4_200,
            realtimeRatio: 0.35,
            audioPreserved: true,
            identity: SidecarDeviceIdentity(
                appVersion: "1.4.0",
                buildNumber: "99",
                deviceModel: "iPhone17,1",
                iosVersion: "26.2",
                exportedAtIso: "2026-05-05T00:00:00.000Z"
            ),
            renderMode: "quality",
            mezzanineUsedVariant: nil,
            mezzanineProfileVersion: nil,
            colorPipeline: FilmtoneColorPipeline.defaultOutputContract(
                sourceMetadata: request.sourceProbe?.sourceVideoMetadata?.color,
                sourceColorClass: request.sourceProbe?.sourceVideoMetadata?.colorClass
            ),
            package: SidecarPackage(
                sourceMediaFilename: "C0061.mov",
                renderedMediaFilename: "C0061-filmtone.mov",
                referenceAfterFilename: "reference-after.jpg",
                referenceAfterTimeSec: 42.13,
                combinedColorFilename: "combined-color.cube",
                effectsDctlFilename: "filmtone-bridge.dctl"
            ),
            depth: nil,
            appliedSavedLook: nil,
            cameraProfile: nil,
            highlightMarkers: markers
        )
        let data = try FilmtoneExportSidecarBuilder.build(inputs)
        let parsed = try decoder.decode(ParsedSidecar.self, from: data)
        let markerParsed = try decoder.decode(HighlightMarkerProbeSidecar.self, from: data)
        try expect(parsed.package?.sourceMediaFilename == "C0061.mov", "emitted sidecar package source mismatch")
        try expect(parsed.package?.effects?.dctl == "filmtone-bridge.dctl", "emitted sidecar DCTL mismatch")
        try expect(markerParsed.highlightMarkers?.markers.first?.id == "filmtone-marker-001", "emitted sidecar marker id mismatch")
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL, options: [.atomic])
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
            package: SidecarPackage(
                sourceMediaFilename: "phase0-source.mov",
                renderedMediaFilename: "phase0-export.mp4",
                referenceAfterFilename: "reference-after.jpg",
                referenceAfterTimeSec: 1.05,
                combinedColorFilename: "combined-color.cube",
                preOpticalColorFilename: "pre-optical-color.cube",
                postOpticalColorFilename: "post-optical-color.cube",
                effectsDctlFilename: "filmtone-bridge.dctl"
            ),
            depth: nil,
            appliedSavedLook: nil,
            cameraProfile: nil
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
        try expect(parsed.package?.layout == "filmtone-connect-package-v2", "package.layout mismatch")
        try expect(parsed.package?.mediaFilename == "phase0-source.mov", "package.mediaFilename should alias source media")
        try expect(parsed.package?.sourceMediaFilename == "phase0-source.mov", "package.sourceMediaFilename mismatch")
        try expect(parsed.package?.renderedMediaFilename == "phase0-export.mp4", "package.renderedMediaFilename mismatch")
        try expect(parsed.package?.referenceAfterFilename == "reference-after.jpg", "package.referenceAfterFilename mismatch")
        try expect(
            abs((parsed.package?.referenceAfterTimeSec ?? 0) - 1.05) < 1e-9,
            "package.referenceAfterTimeSec mismatch"
        )
        try expect(parsed.package?.luts.combinedColor == "combined-color.cube", "package.luts.combinedColor mismatch")
        try expect(parsed.package?.luts.preOpticalColor == "pre-optical-color.cube", "package.luts.preOpticalColor mismatch")
        try expect(parsed.package?.luts.postOpticalColor == "post-optical-color.cube", "package.luts.postOpticalColor mismatch")
        try expect(parsed.package?.effects?.dctl == "filmtone-bridge.dctl", "package.effects.dctl mismatch")

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
            parsed.look.presetVersion == "v2",
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
            package: nil,
            depth: nil,
            appliedSavedLook: nil,
            cameraProfile: nil
        )
        let data = try FilmtoneExportSidecarBuilder.build(inputs)
        let parsed = try JSONDecoder().decode(ParsedSidecar.self, from: data)
        try expect(parsed.job == "image", "job should be 'image' for image sourceKind")
        try expect(parsed.hdrPolicy == nil, "hdrPolicy should be nil for image inputs without metadata")
        try expect(parsed.input.kind == "image", "input.kind should be 'image'")
        try expect(parsed.lutRefs.inputLut == nil, "no inputLut expected")
        try expect(parsed.lutRefs.creativeLut == nil, "no creativeLut expected")
        try expect(parsed.package == nil, "package should be nil when not supplied")
    }

    static func runConnectPackageUriOrdering() throws {
        let uris = FilmtoneConnectPackageFiles.orderedPackageFileUris(
            renderedUri: "file:///tmp/rendered.mp4",
            sidecarUri: "file:///tmp/rendered.mp4.filmtone-ios-export-session-v1.json",
            sourceMediaUri: "file:///tmp/source.mov",
            preOpticalCubeUri: "file:///tmp/pre-optical-color.cube",
            postOpticalCubeUri: "file:///tmp/post-optical-color.cube",
            cubeUri: "file:///tmp/combined-color.cube",
            dctlUri: "file:///tmp/filmtone-bridge.dctl",
            referenceAfterUri: "file:///tmp/reference-after.jpg"
        )
        try expect(
            uris == [
                "file:///tmp/rendered.mp4",
                "file:///tmp/rendered.mp4.filmtone-ios-export-session-v1.json",
                "file:///tmp/source.mov",
                "file:///tmp/pre-optical-color.cube",
                "file:///tmp/post-optical-color.cube",
                "file:///tmp/combined-color.cube",
                "file:///tmp/filmtone-bridge.dctl",
                "file:///tmp/reference-after.jpg",
            ],
            "connect package URI ordering changed"
        )
    }

    static func runHighlightMarkersSidecarBlock() throws {
        let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let decoder = JSONDecoder()
        let request = try decoder.decode(
            Phase0ExportRequestDTO.self,
            from: Data(contentsOf: fixtureURL)
        )
        let markers = FilmtoneHighlightMarkers(
            sourceIdentity: FilmtoneMarkerSourceIdentity(
                filename: request.sourceProbe?.filename,
                durationSec: request.sourceProbe?.durationSec,
                fps: request.sourceProbe?.frameRate,
                fileSizeBytes: request.sourceProbe?.fileSizeBytes.map { Int64($0) }
            ),
            markers: [
                FilmtoneHighlightMarker(
                    id: "filmtone-marker-test",
                    sourceTimeSec: 2.5,
                    sourceFps: request.sourceProbe?.frameRate,
                    createdOnPlatform: "ios",
                    createdAtIso: "2026-05-05T00:00:00.000Z"
                )
            ]
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
            identity: SidecarDeviceIdentity(
                appVersion: "1.4.0",
                buildNumber: "99",
                deviceModel: "iPhone17,1",
                iosVersion: "26.2",
                exportedAtIso: "2026-05-05T00:00:00.000Z"
            ),
            renderMode: "quality",
            mezzanineUsedVariant: nil,
            mezzanineProfileVersion: nil,
            colorPipeline: FilmtoneColorPipeline.defaultOutputContract(
                sourceMetadata: request.sourceProbe?.sourceVideoMetadata?.color,
                sourceColorClass: request.sourceProbe?.sourceVideoMetadata?.colorClass
            ),
            package: nil,
            depth: nil,
            appliedSavedLook: nil,
            cameraProfile: nil,
            highlightMarkers: markers
        )

        let data = try FilmtoneExportSidecarBuilder.build(inputs)
        let parsed = try decoder.decode(HighlightMarkerProbeSidecar.self, from: data)
        try expect(
            parsed.highlightMarkers?.schema == FilmtoneHighlightMarkers.schemaID,
            "highlightMarkers.schema mismatch"
        )
        try expect(
            parsed.highlightMarkers?.markers.first?.id == "filmtone-marker-test",
            "highlight marker id missing"
        )
        try expect(
            parsed.highlightMarkers?.markers.first?.createdOnPlatform == "ios",
            "highlight marker platform missing"
        )
        try expect(
            parsed.highlightMarkers?.markers.first?.sourceFrame != nil,
            "highlight marker should carry sourceFrame when fps is present"
        )
    }

    // MARK: - Connect cube writer

    static func runConnectCubeWriter() throws {
        let request = Phase0ExportRequestDTO(
            sourceUri: "file:///tmp/phase0-source.jpg",
            sourceKind: .image,
            sourceProbe: nil,
            output: Phase0OutputProfileDTO(
                longEdge: 2048,
                fps: 24,
                codec: "h264",
                container: "mp4",
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

        let text = FilmtoneConnectCubeWriter.makeCombinedColorCubeText(for: request, size: 2)
        try expect(text.contains("TITLE \"Filmtone Combined Color\""), "cube title missing")
        try expect(text.contains("LUT_3D_SIZE 2"), "cube size header missing")
        try expect(text.contains("DOMAIN_MIN 0.0 0.0 0.0"), "cube DOMAIN_MIN missing")
        try expect(text.contains("DOMAIN_MAX 1.0 1.0 1.0"), "cube DOMAIN_MAX missing")

        let dataLines = text
            .split(separator: "\n")
            .filter { line in
                line.first?.isNumber == true || line.first == "-"
            }
        try expect(dataLines.count == 8, "size 2 cube should emit 8 RGB rows, got \(dataLines.count)")
        try expect(
            dataLines.allSatisfy { $0.split(separator: " ").count == 3 },
            "cube rows should contain RGB triples only"
        )
        try expect(dataLines.first == "0.0000000 0.0000000 0.0000000", "identity cube first RGB row mismatch")
        try expect(dataLines.last == "1.0000000 1.0000000 1.0000000", "identity cube last RGB row mismatch")

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("filmtone-connect-test-\(UUID().uuidString).cube")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try FilmtoneConnectCubeWriter.writeCombinedColorCube(for: request, to: tempURL, size: 2)
        try expect(FileManager.default.fileExists(atPath: tempURL.path), "cube writer did not create a file")
    }

    static func runConnectDctlWriter() throws {
        let request = Phase0ExportRequestDTO(
            sourceUri: "file:///tmp/phase0-source.mov",
            sourceKind: .video,
            sourceProbe: nil,
            output: Phase0OutputProfileDTO(
                longEdge: 2048,
                fps: 24,
                codec: "h264",
                container: "mp4",
                preserveAudio: true
            ),
            grade: Phase0GradeDTO(
                presetName: "cinematic",
                presetVersion: "v1",
                quickState: Phase0QuickStateDTO(filmCharacter: 0, era: 0, dynamics: 0),
                params: Phase0ParamsDTO(
                    exposure: 0, contrast: 1, saturation: 1, temperature: 0, tint: 0,
                    rgbShift: 0.002, lensSoftness: 0, grainRadialMix: 0.4, grainSize: 0.3,
                    bloomThreshold: 0, bloomStrength: 0, bloomRadius: 0,
                    diffusion: 0.09, halationIntensity: 0, halationSpread: 0,
                    halationHue: 0, halationThreshold: 0, halationRadius: 0,
                    bloomSoftKnee: 0, halationSoftKnee: 0, compressionAmount: 0,
                    compressionRange: 0, printContrast: 0, cyan: 0, magenta: 0,
                    yellow: 0, shutterAngle: 0, trailIntensity: 0,
                    fade: 0,
                    shadowTone: 0, highlightTone: 0,
                    shadowHue: 225, highlightHue: 30,
                    vignette: 0.2, grainIntensity: 0.12
                )
            ),
            lut: nil,
            inputLut: nil,
            creativeLut: nil,
            renderMode: nil,
            depthEnabled: nil,
            depthRenderer: nil
        )

        let text = FilmtoneConnectDctlWriter.makeBridgeDctlText(
            for: request,
            cubeFilename: "combined-color.cube",
            preOpticalColorFilename: "pre-optical-color.cube",
            postOpticalColorFilename: "post-optical-color.cube",
            outputFps: 24,
            sourceSeed: 123.4
        )
        try expect(text.contains("DEFINE_LUT(FilmtonePreOpticalColor, pre-optical-color.cube)"), "DCTL should reference pre-optical cube")
        try expect(text.contains("DEFINE_LUT(FilmtonePostOpticalColor, post-optical-color.cube)"), "DCTL should reference post-optical cube")
        try expect(text.contains("APPLY_LUT"), "DCTL should apply the color bridge LUT")
        try expect(text.contains("__TEXTURE__ p_TexR"), "DCTL should use Resolve texture sampling")
        try expect(text.contains("explicit visual equivalence blockers"), "DCTL should declare unresolved effect coverage")
        try expect(text.contains("Resolve texture color"), "DCTL should document Resolve texture color compensation")
        let hlgFixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let hlgRequest = try JSONDecoder().decode(
            Phase0ExportRequestDTO.self,
            from: Data(contentsOf: hlgFixtureURL)
        )
        let hlgText = FilmtoneConnectDctlWriter.makeBridgeDctlText(
            for: hlgRequest,
            cubeFilename: "combined-color.cube",
            preOpticalColorFilename: "pre-optical-color.cube",
            postOpticalColorFilename: "post-optical-color.cube",
            outputFps: 24,
            sourceSeed: 123.4
        )
        try expect(
            hlgText.contains("rgb.x * 0.920000000f")
                && hlgText.contains("rgb.y * 0.883000000f")
                && hlgText.contains("rgb.z * 0.924000000f"),
            "HLG DCTL should carry Resolve texture compensation gains"
        )
        let appleLogRequest = Phase0ExportRequestDTO(
            sourceUri: "file:///tmp/apple-log-source.mov",
            sourceKind: .video,
            sourceProbe: SourceProbeDTO(
                uri: "file:///tmp/apple-log-source.mov",
                filename: "apple-log-source",
                kind: .video,
                mimeType: "video/quicktime",
                width: 2160,
                height: 3840,
                durationSec: 23.5,
                fileSizeBytes: 1_000_000,
                codec: "apcs",
                codecFamily: .prores422,
                frameRate: 24,
                logTransferFunction: .appleLog,
                inputTransformPolicy: SourceInputTransformPolicyDTO(
                    strategy: .appleLogToRec709,
                    reason: "source-is-apple-log",
                    requiresFixtureValidation: true,
                    warning: nil
                ),
                cameraOptics: nil,
                sourceVideoMetadata: SourceVideoMetadataDTO(
                    display: SourceDisplayGeometryDTO(
                        rawWidth: 3840,
                        rawHeight: 2160,
                        displayWidth: 2160,
                        displayHeight: 3840,
                        rotationDeg: 90,
                        source: "preferred-transform"
                    ),
                    color: SourceColorMetadataDTO(
                        colorRange: nil,
                        colorSpace: "bt2020nc",
                        colorTransfer: "apple-log",
                        colorPrimaries: "bt2020",
                        logTransferFunction: .appleLog,
                        hasMasteringDisplayMetadata: false,
                        hasContentLightMetadata: false
                    ),
                    colorClass: .appleLog,
                    hdrPreparationPolicy: nil,
                    timing: nil,
                    codecFamily: .prores422,
                    logTransferFunction: .appleLog,
                    inputTransformPolicy: SourceInputTransformPolicyDTO(
                        strategy: .appleLogToRec709,
                        reason: "source-is-apple-log",
                        requiresFixtureValidation: true,
                        warning: nil
                    )
                )
            ),
            output: Phase0OutputProfileDTO(
                longEdge: 2048,
                fps: 24,
                codec: "h264",
                container: "mp4",
                preserveAudio: true
            ),
            grade: Phase0GradeDTO(
                presetName: "reset",
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
        let appleLogText = FilmtoneConnectDctlWriter.makeBridgeDctlText(
            for: appleLogRequest,
            cubeFilename: "combined-color.cube",
            preOpticalColorFilename: "pre-optical-color.cube",
            postOpticalColorFilename: "post-optical-color.cube",
            outputFps: 24,
            sourceSeed: 123.4
        )
        try expect(
            appleLogText.contains("rgb.x * 0.499989650f + 0.469398630f")
                && appleLogText.contains("rgb.y * 0.528461180f + 0.388497540f")
                && appleLogText.contains("rgb.z * 0.514997770f + 0.368480300f"),
            "Apple Log DCTL should carry C052 affine Resolve texture calibration"
        )
        try expect(text.contains("filmtone_clamp_int"), "DCTL should include scalar-safe RGB shift sampling bounds")
        try expect(text.contains("filmtone_smoothstep"), "DCTL should include scalar-safe edge softness mask")
        try expect(text.contains("edge-masked softness"), "DCTL should document edge-masked softness coverage")
        try expect(text.contains("softenRadius"), "DCTL should sample edge softness taps")
        try expect(text.contains("float edgeMask = filmtone_smoothstep(0.25f, 1.0f, edgeR);"), "DCTL should use the iOS edge mask ramp")
        try expect(text.contains("float blurR = r * 0.400000000f"), "DCTL should blur with scalar channel taps")
        try expect(text.contains("float outR = r * (1.0f - softenAmt) + blurR * softenAmt;"), "DCTL should blend softness before the post LUT")
        try expect(text.contains("multi-radius mip-like diffusion"), "DCTL should document multi-radius diffusion coverage")
        try expect(text.contains("filmtone_glow_shoulder"), "DCTL should include scalar-safe diffusion shoulder")
        try expect(text.contains("int md0Radius = 3;"), "DCTL should sample near mip-like diffusion taps")
        try expect(text.contains("int md3Radius = 31;"), "DCTL should sample wide mip-like diffusion taps")
        try expect(text.contains("float diffR = (outR * 0.120000000f)"), "DCTL should build a scalar multi-radius diffusion plate")
        try expect(text.contains("float diffSpatial = 1.0f - filmtone_smoothstep(0.250000000f, 0.800000000f, edgeR);"), "DCTL should gate diffusion away from already-bright edges")
        try expect(text.contains("float diffGlowR = filmtone_glow_shoulder(diffR * 0.053000000f * diffSpatial) * diffHeadroom;"), "DCTL should scale diffusion from the request amount")
        try expect(text.contains("redSample = APPLY_LUT"), "DCTL should pre-LUT the red RGB shift sample")
        try expect(
            text.contains("float r = center.x * 0.712000000f + redSample.x * 0.288000000f;"),
            "DCTL should scale RGB shift mix from the request amount"
        )
        try expect(!text.contains("filmtone_apply_vignette"), "DCTL should not include unverified vignette approximation")
        try expect(!text.contains("filmtone_clamp3"), "DCTL should avoid custom float3 helpers that Resolve rejects")
        try expect(!text.contains("__DEVICE__ float3 filmtone"), "DCTL should avoid custom float3 helpers that Resolve rejects")
        try expect(!text.contains("filmtone_grain"), "DCTL should not include unverified grain approximation")

        let zeroOpticsRequest = Phase0ExportRequestDTO(
            sourceUri: "file:///tmp/phase0-source.mov",
            sourceKind: .video,
            sourceProbe: nil,
            output: Phase0OutputProfileDTO(
                longEdge: 2048,
                fps: 24,
                codec: "h264",
                container: "mp4",
                preserveAudio: true
            ),
            grade: Phase0GradeDTO(
                presetName: "reset",
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
        let zeroOpticsText = FilmtoneConnectDctlWriter.makeBridgeDctlText(
            for: zeroOpticsRequest,
            cubeFilename: "combined-color.cube",
            preOpticalColorFilename: "pre-optical-color.cube",
            postOpticalColorFilename: "post-optical-color.cube",
            outputFps: 24,
            sourceSeed: 123.4
        )
        try expect(zeroOpticsText.contains("rgb = APPLY_LUT(rgb.x, rgb.y, rgb.z, FilmtonePreOpticalColor);"), "zero-optics DCTL should keep the compact split color path")
        try expect(!zeroOpticsText.contains("filmtone_clamp_int"), "zero-optics DCTL should not include texture tap bounds")
        try expect(!zeroOpticsText.contains("filmtone_smoothstep"), "zero-optics DCTL should not include edge softness helpers")
        try expect(!zeroOpticsText.contains("filmtone_glow_shoulder"), "zero-optics DCTL should not include diffusion helpers")
        try expect(!zeroOpticsText.contains("softenRadius"), "zero-optics DCTL should not sample softness taps")
        try expect(!zeroOpticsText.contains("diffusionRadius"), "zero-optics DCTL should not sample diffusion taps")

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("filmtone-connect-test-\(UUID().uuidString).dctl")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try FilmtoneConnectDctlWriter.writeBridgeDctl(
            for: request,
            cubeFilename: "combined-color.cube",
            preOpticalColorFilename: "pre-optical-color.cube",
            postOpticalColorFilename: "post-optical-color.cube",
            outputFps: 24,
            sourceSeed: 123.4,
            to: tempURL
        )
        try expect(FileManager.default.fileExists(atPath: tempURL.path), "DCTL writer did not create a file")
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
            package: nil,
            depth: nil,
            appliedSavedLook: builtInRef,
            cameraProfile: nil
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
            package: nil,
            depth: nil,
            appliedSavedLook: userRef,
            cameraProfile: nil
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
            package: nil,
            depth: nil,
            appliedSavedLook: nil,
            cameraProfile: nil
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

    // MARK: - v1.3 Camera Profiles Phase G: cameraProfile provenance

    /// Verifies that the sidecar's `cameraProfile` block round-trips for
    /// each `selectionKind` (built-in, auto, user-import). Auto without a
    /// resolved catalog row still emits a block (selectionKind="auto",
    /// curve/impl/catalogId nil); the absent-block path is exercised by
    /// the existing HLG fixture test which leaves `cameraProfile: nil`.
    static func runCameraProfileProvenance() throws {
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

        // Case 1: V-Log selected — built-in synthesized path.
        let vlogProfile = SidecarCameraProfile(
            selectionKind: "built-in",
            catalogId: "built-in:source-profile.panasonic-vlog",
            curve: "panasonic-vlog",
            impl: "synthesized",
            resolvedFromAutoVia: nil
        )
        let vlogInputs = SidecarBuildInputs(
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
            package: nil,
            depth: nil,
            appliedSavedLook: nil,
            cameraProfile: vlogProfile
        )
        let vlogData = try FilmtoneExportSidecarBuilder.build(vlogInputs)
        try expect(
            vlogData.count < 8_192,
            "V-Log cameraProfile sidecar exceeds 8KB cap: \(vlogData.count) bytes"
        )
        let vlogParsed = try JSONDecoder().decode(CameraProfileProbeSidecar.self, from: vlogData)
        try expect(vlogParsed.cameraProfile != nil, "V-Log cameraProfile block missing")
        try expect(
            vlogParsed.cameraProfile?.selectionKind == "built-in",
            "V-Log selectionKind should be built-in"
        )
        try expect(
            vlogParsed.cameraProfile?.catalogId == "built-in:source-profile.panasonic-vlog",
            "V-Log catalogId mismatch"
        )
        try expect(
            vlogParsed.cameraProfile?.curve == "panasonic-vlog",
            "V-Log curve mismatch"
        )
        try expect(
            vlogParsed.cameraProfile?.impl == "synthesized",
            "V-Log impl mismatch"
        )

        // Case 2: Auto resolved through Apple Log probe.
        let autoProfile = SidecarCameraProfile(
            selectionKind: "auto",
            catalogId: "built-in:source-profile.apple-log",
            curve: "apple-log",
            impl: "native-policy",
            resolvedFromAutoVia: "apple-log"
        )
        let autoInputs = SidecarBuildInputs(
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
            package: nil,
            depth: nil,
            appliedSavedLook: nil,
            cameraProfile: autoProfile
        )
        let autoData = try FilmtoneExportSidecarBuilder.build(autoInputs)
        let autoParsed = try JSONDecoder().decode(CameraProfileProbeSidecar.self, from: autoData)
        try expect(
            autoParsed.cameraProfile?.selectionKind == "auto",
            "Auto selectionKind should be auto"
        )
        try expect(
            autoParsed.cameraProfile?.resolvedFromAutoVia == "apple-log",
            "Auto resolvedFromAutoVia mismatch"
        )

        // Case 3: nil cameraProfile (legacy path) — block omitted entirely.
        let nilInputs = SidecarBuildInputs(
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
            package: nil,
            depth: nil,
            appliedSavedLook: nil,
            cameraProfile: nil
        )
        let nilData = try FilmtoneExportSidecarBuilder.build(nilInputs)
        guard let nilJson = String(data: nilData, encoding: .utf8) else {
            throw SidecarCheckError(message: "nil cameraProfile sidecar payload is not UTF-8")
        }
        try expect(
            !nilJson.contains("\"cameraProfile\""),
            "nil-cameraProfile export unexpectedly emitted cameraProfile key"
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
            fade: 0,
            shadowTone: 0, highlightTone: 0,
            shadowHue: 225, highlightHue: 30,
            vignette: 0, grainIntensity: 0
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
    let package: ParsedPackage?
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

// v1.3 Camera Profiles Phase G: minimal Decodable surface for the
// cameraProfile assertions.
private struct CameraProfileProbeSidecar: Decodable {
    let cameraProfile: ParsedCameraProfile?
}

private struct HighlightMarkerProbeSidecar: Decodable {
    let highlightMarkers: FilmtoneHighlightMarkers?
}

private struct ParsedCameraProfile: Decodable {
    let selectionKind: String
    let catalogId: String?
    let curve: String?
    let impl: String?
    let resolvedFromAutoVia: String?
}

// v1.3 DaVinci spike: Decodable surface for the Filmtone Connect package
// assertions (URI ordering / cube writer / DCTL writer tests).
private struct ParsedPackage: Decodable {
    let layout: String
    let mediaFilename: String
    let sourceMediaFilename: String
    let renderedMediaFilename: String
    let referenceAfterFilename: String
    let referenceAfterTimeSec: Double
    let luts: ParsedPackageLuts
    let effects: ParsedPackageEffects?
}

private struct ParsedPackageLuts: Decodable {
    let combinedColor: String
    let preOpticalColor: String?
    let postOpticalColor: String?
}

private struct ParsedPackageEffects: Decodable {
    let dctl: String?
}
