import Foundation
import CoreGraphics

// MARK: - Builder inputs

/// Device / app identity fed to the sidecar builder via DI so the builder stays
/// free of `UIKit` / `Bundle.main` dependencies and can be unit-tested on host macOS.
struct SidecarDeviceIdentity {
    let appVersion: String
    let buildNumber: String
    let deviceModel: String
    let iosVersion: String
    let exportedAtIso: String
}

/// All inputs required to assemble a filmtone-ios-export-session-v1 sidecar JSON.
struct SidecarBuildInputs {
    let request: Phase0ExportRequestDTO
    let sourceProbe: SourceProbeDTO?
    let hdrPolicy: HdrPreparationPolicyDTO?
    let degradedDecodePath: Bool
    let outputURL: URL
    let outputSize: CGSize
    let fileSizeBytes: Int?
    let elapsedMs: Int
    let realtimeRatio: Double?
    let audioPreserved: Bool?
    let identity: SidecarDeviceIdentity
    /// Render mode selected for this export ("quality" | "speed"), nil if not surfaced by caller.
    let renderMode: String?
    /// Mezzanine variant actually consumed during export ("sdr" | "hdr"), nil if mezzanine not used.
    let mezzanineUsedVariant: String?
    /// `MezzanineService.Profile.version` of the consumed mezzanine; nil when no mezzanine used.
    let mezzanineProfileVersion: Int?
    /// Color-managed render contract used by both preview and export for this output.
    let colorPipeline: FilmtoneColorPipelineContract
    /// Filmtone Connect package manifest. nil keeps legacy sidecar-only exports
    /// byte-compatible except for other additive optional fields.
    let package: SidecarPackage?
    /// v1.3 (D3.5): depth × ray-angle prefilter block. Pass nil only on legacy
    /// call-sites that pre-date the v1.3 wave; v1.3+ call-sites should always
    /// supply a `SidecarDepthInfo` (with `used: false` when depth was not
    /// applied, mirroring the mezzanine block convention).
    let depth: SidecarDepthInfo?
}

// MARK: - Sidecar schema (filmtone-ios-export-session-v1)
//
// The Codable struct mirrors the JSON payload exactly. Keys are stable —
// they are part of the contract consumed by Desktop/importer round-trip.
// Sorted keys are emitted by the encoder so `.sortedKeys` produces a
// deterministic byte stream.

struct FilmtoneExportSidecarV1: Encodable {
    let kind: String
    let schema: String
    let version: Int
    let exportedAtIso: String
    let appVersion: String
    let buildNumber: String
    let job: String
    let device: SidecarDevice
    let input: SidecarInput
    let hdrPolicy: HdrPreparationPolicyDTO?
    let look: SidecarLook
    let lutRefs: SidecarLutRefs
    let output: SidecarOutput
    /// Render mode for this export ("quality" | "speed"). Optional for backwards compatibility
    /// with v1.1 sidecars; older importers ignore unknown keys (schemaVersion stays 1).
    let renderMode: String?
    /// Mezzanine usage block (always emitted in v1.2+, even when used=false, to signal an
    /// explicit "no-mezzanine" path rather than absence of the field).
    let mezzanine: SidecarMezzanine?
    /// Filmtone Connect for DaVinci package manifest. Additive v1 field.
    let package: SidecarPackage?
    /// v1.3 (D3.5): depth × ray-angle prefilter block. Always emitted in v1.3+ even when
    /// `used == false` so importers can distinguish "no-depth (explicit)" from
    /// "v1.2 sidecar (field absent)". schemaVersion stays 1 — additive optional fields
    /// remain backwards-compatible.
    let depth: SidecarDepthInfo?
}

struct SidecarDevice: Encodable {
    let model: String
    let iosVersion: String
}

struct SidecarInput: Encodable {
    let sourceUri: String
    let filename: String?
    let kind: String
    let sourceProbe: SourceProbeDTO?
    let sourceVideoMetadata: SourceVideoMetadataDTO?
    let cameraOptics: CameraOpticsDTO?
}

struct SidecarLook: Encodable {
    let presetName: String
    let presetVersion: String
    let quickState: Phase0QuickStateDTO
    let params: Phase0ParamsDTO
}

/// Intentionally omits the full `data` array — only the shape summary
/// (size + intensity) travels with the sidecar so the payload stays small
/// and the LUT itself remains the SSOT in the source project file.
///
/// `sourceHash` is the SHA-256 of the canonical Float32 byte stream used by
/// `FilmtoneLibraryStore`. It lets desktop importers correlate two exports
/// that used the same imported `.cube` even when the user renamed it
/// between sessions. v1.3 (Item 3): additive optional field — pre-v1.3
/// readers ignore unknown keys per the V1 contract (CLAUDE.md §5).
struct SidecarLutRef: Encodable {
    let size: Int
    let intensity: Double
    let sourceHash: String?
}

struct SidecarLutRefs: Encodable {
    let inputLut: SidecarLutRef?
    let creativeLut: SidecarLutRef?
}

struct SidecarOutput: Encodable {
    let longEdge: Int
    let fps: Int
    let codec: String
    let container: String
    let preserveAudio: Bool
    let degradedDecodePath: Bool
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

/// Records whether (and which variant of) a mezzanine asset was consumed for this export.
/// `used == false` is a meaningful signal: the export ran via the source-direct path on
/// purpose (renderMode=quality on SDR source, or mezzanine missing/corrupt). `variant` is
/// "sdr" | "hdr" when used; nil when not. `profileVersion` mirrors
/// `MezzanineService.Profile.version` (currently 3) so importers can detect schema drift.
struct SidecarMezzanine: Encodable {
    let used: Bool
    let variant: String?
    let profileVersion: Int?
}

struct SidecarPackageLuts: Encodable {
    let combinedColor: String
}

struct SidecarPackage: Encodable {
    static let layoutID = "filmtone-connect-package-v1"

    let layout: String
    let mediaFilename: String
    let referenceAfterFilename: String
    let luts: SidecarPackageLuts

    init(
        mediaFilename: String,
        referenceAfterFilename: String,
        combinedColorFilename: String,
        layout: String = layoutID
    ) {
        self.layout = layout
        self.mediaFilename = mediaFilename
        self.referenceAfterFilename = referenceAfterFilename
        self.luts = SidecarPackageLuts(combinedColor: combinedColorFilename)
    }
}

// MARK: - Builder

enum FilmtoneExportSidecarBuilder {
    static let schemaID = "filmtone-ios-export-session-v1"
    static let kind = "filmtone-export-session"
    static let schemaVersion = 1
    static let sidecarFilenameSuffix = ".filmtone-ios-export-session-v1.json"

    /// Build a JSON payload representing the filmtone-ios-export-session-v1 sidecar.
    static func build(_ inputs: SidecarBuildInputs) throws -> Data {
        let payload = makePayload(inputs)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(payload)
    }

    /// Compute the sidecar URL that sits next to the export output.
    ///
    /// We append the suffix to the raw path so the media extension is
    /// preserved (e.g. `/tmp/foo.mp4.filmtone-ios-export-session-v1.json`).
    /// This keeps media + sidecar sortable together in Files / Finder.
    static func sidecarURL(for outputURL: URL) -> URL {
        let base = outputURL.path
        return URL(fileURLWithPath: base + sidecarFilenameSuffix)
    }

    // MARK: - Private helpers

    private static func makePayload(_ inputs: SidecarBuildInputs) -> FilmtoneExportSidecarV1 {
        let request = inputs.request
        let job = jobString(for: request.sourceKind)
        let probe = inputs.sourceProbe ?? request.sourceProbe

        let sourceVideoMetadata = probe?.sourceVideoMetadata
        let cameraOptics = probe?.cameraOptics

        let input = SidecarInput(
            sourceUri: request.sourceUri,
            filename: probe?.filename,
            kind: jobString(for: request.sourceKind),
            sourceProbe: probe,
            sourceVideoMetadata: sourceVideoMetadata,
            cameraOptics: cameraOptics
        )

        let look = SidecarLook(
            presetName: request.grade.presetName,
            presetVersion: request.grade.presetVersion,
            quickState: request.grade.quickState,
            params: request.grade.params
        )

        let lutRefs = SidecarLutRefs(
            inputLut: request.inputLut.map { lut in
                SidecarLutRef(
                    size: lut.size,
                    intensity: lut.intensity,
                    sourceHash: try? FilmtoneLutBlobCodec.sourceHash(data: lut.data, size: lut.size)
                )
            },
            creativeLut: resolveCreativeLutRef(request)
        )

        let output = SidecarOutput(
            longEdge: request.output.longEdge,
            fps: request.output.fps,
            codec: request.output.codec,
            container: request.output.container,
            preserveAudio: request.output.preserveAudio,
            degradedDecodePath: inputs.degradedDecodePath,
            outputUri: inputs.outputURL.absoluteString,
            outputWidth: Int(inputs.outputSize.width.rounded()),
            outputHeight: Int(inputs.outputSize.height.rounded()),
            fileSizeBytes: inputs.fileSizeBytes,
            elapsedMs: inputs.elapsedMs,
            realtimeRatio: inputs.realtimeRatio,
            outputColorProfile: inputs.colorPipeline.outputProfileID,
            colorPrimaries: inputs.colorPipeline.outputColorPrimariesID,
            colorTransfer: inputs.colorPipeline.outputColorTransferID,
            colorSpace: inputs.colorPipeline.outputColorSpaceID
        )

        _ = inputs.audioPreserved // currently not surfaced in schema; runtime uses output.preserveAudio

        // Mezzanine block is always emitted in v1.2+: used=false carries explicit "no-mezzanine"
        // semantics (vs. absent field which would mean "v1.1 sidecar / unknown"). variant is nil
        // when not used; profileVersion follows the same nullity to keep the pair consistent.
        let mezzanine = SidecarMezzanine(
            used: inputs.mezzanineUsedVariant != nil,
            variant: inputs.mezzanineUsedVariant,
            profileVersion: inputs.mezzanineProfileVersion
        )

        // v1.3 (D3.5 Phase A + Stream D Phase B): always emit the depth block.
        // When the caller passed nil (legacy / pre-v1.3 site, or video-export
        // path with no depth track) we materialize a `used: false` placeholder so
        // importers see a stable shape — same convention as the mezzanine block.
        // Phase B's `framesWithDepth` / `videoDepthSource` default to nil here;
        // video-export call-sites construct a fully-populated SidecarDepthInfo
        // upstream and pass it via `inputs.depth`.
        let depth = inputs.depth ?? SidecarDepthInfo(used: false)

        return FilmtoneExportSidecarV1(
            kind: kind,
            schema: schemaID,
            version: schemaVersion,
            exportedAtIso: inputs.identity.exportedAtIso,
            appVersion: inputs.identity.appVersion,
            buildNumber: inputs.identity.buildNumber,
            job: job,
            device: SidecarDevice(
                model: inputs.identity.deviceModel,
                iosVersion: inputs.identity.iosVersion
            ),
            input: input,
            hdrPolicy: inputs.hdrPolicy,
            look: look,
            lutRefs: lutRefs,
            output: output,
            renderMode: inputs.renderMode,
            mezzanine: mezzanine,
            package: inputs.package,
            depth: depth
        )
    }

    private static func jobString(for kind: FilmtoneSourceKind) -> String {
        switch kind {
        case .video:
            return "video"
        case .image:
            return "image"
        }
    }

    /// Creative LUT can arrive either via `creativeLut` or the legacy `lut` field.
    /// `creativeLut` wins when both are present (mirrors `FilmtoneExportSession`).
    private static func resolveCreativeLutRef(_ request: Phase0ExportRequestDTO) -> SidecarLutRef? {
        if let creative = request.creativeLut {
            return SidecarLutRef(
                size: creative.size,
                intensity: creative.intensity,
                sourceHash: try? FilmtoneLutBlobCodec.sourceHash(
                    data: creative.data,
                    size: creative.size
                )
            )
        }
        if let legacy = request.lut {
            return SidecarLutRef(
                size: legacy.size,
                intensity: legacy.intensity,
                sourceHash: try? FilmtoneLutBlobCodec.sourceHash(
                    data: legacy.data,
                    size: legacy.size
                )
            )
        }
        return nil
    }
}

enum FilmtoneConnectCubeWriter {
    static let defaultCubeSize = 33
    static let defaultTitle = "Filmtone Combined Color"

    static func writeCombinedColorCube(
        for request: Phase0ExportRequestDTO,
        to url: URL,
        size: Int = defaultCubeSize
    ) throws {
        let text = makeCombinedColorCubeText(for: request, size: size)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func makeCombinedColorCubeText(
        for request: Phase0ExportRequestDTO,
        size: Int = defaultCubeSize
    ) -> String {
        let resolvedSize = max(2, size)
        var lines: [String] = [
            "TITLE \"\(defaultTitle)\"",
            "# Generated by Filmtone Connect for DaVinci.",
            "# Color transform bridge only; baked optics/grain/depth travel in media + reference still.",
            "LUT_3D_SIZE \(resolvedSize)",
            "DOMAIN_MIN 0.0 0.0 0.0",
            "DOMAIN_MAX 1.0 1.0 1.0",
        ]
        lines.reserveCapacity((resolvedSize * resolvedSize * resolvedSize) + lines.count)

        for blueIndex in 0..<resolvedSize {
            let blue = Double(blueIndex) / Double(resolvedSize - 1)
            for greenIndex in 0..<resolvedSize {
                let green = Double(greenIndex) / Double(resolvedSize - 1)
                for redIndex in 0..<resolvedSize {
                    let red = Double(redIndex) / Double(resolvedSize - 1)
                    let rgb = applyColorBridge(
                        red: red,
                        green: green,
                        blue: blue,
                        request: request
                    )
                    lines.append(formatRGBLine(rgb))
                }
            }
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func applyColorBridge(
        red: Double,
        green: Double,
        blue: Double,
        request: Phase0ExportRequestDTO
    ) -> RGB {
        let params = request.grade.params
        var current = RGB(red, green, blue)

        if let inputLut = request.inputLut {
            current = applyLut(inputLut, to: current)
        } else if let policy = request.sourceProbe?.inputTransformPolicy {
            current = applyAutomaticInputTransform(policy, to: current)
        }

        current = applyBaseGrade(current, params: params)
        current = applyFilmCompression(current, params: params)

        if let creativeLut = request.creativeLut {
            current = applyLut(creativeLut, to: current)
        } else if let legacyLut = request.lut {
            current = applyLut(
                SerializableLutDTO(
                    size: legacyLut.size,
                    data: legacyLut.data,
                    intensity: legacyLut.intensity
                ),
                to: current
            )
        }

        current = applyPrintStage(current, params: params)
        return current.clamped()
    }

    private static func applyBaseGrade(_ rgb: RGB, params: Phase0ParamsDTO) -> RGB {
        var out = rgb
        let exposureScale = pow(2.0, params.exposure)
        out.r *= exposureScale
        out.g *= exposureScale
        out.b *= exposureScale

        out.r = (out.r - 0.5) * params.contrast + 0.5
        out.g = (out.g - 0.5) * params.contrast + 0.5
        out.b = (out.b - 0.5) * params.contrast + 0.5

        let luma = out.luma
        out.r = mix(luma, out.r, params.saturation)
        out.g = mix(luma, out.g, params.saturation)
        out.b = mix(luma, out.b, params.saturation)

        out.r += params.temperature * 0.1
        out.b -= params.temperature * 0.1
        out.r += params.tint * 0.05
        out.g -= params.tint * 0.08
        out.b += params.tint * 0.05

        out.r = out.r + params.fade * (1.0 - out.r)
        out.g = out.g + params.fade * (1.0 - out.g)
        out.b = out.b + params.fade * (1.0 - out.b)
        return out
    }

    private static func applyFilmCompression(_ rgb: RGB, params: Phase0ParamsDTO) -> RGB {
        guard params.compressionAmount > 0.0001 else {
            return rgb
        }
        let range = clamp(params.compressionRange)
        let k = mix(5.15, 2.85, range)
        let rangeSoft = smoothstep(edge0: 0.82, edge1: 1.0, x: range)
        let amount = params.compressionAmount * (1.0 - 0.18 * rangeSoft)
        let luma = rgb.luma
        let x = clamp(k * (luma - 0.5), min: -5.5, max: 5.5)
        let s = 1.0 / (1.0 + exp(-x))
        let scale = luma > 0.001 ? mix(luma, s, amount) / luma : 1.0
        return RGB(
            clamp(rgb.r * scale),
            clamp(rgb.g * scale),
            clamp(rgb.b * scale)
        )
    }

    private static func applyPrintStage(_ rgb: RGB, params: Phase0ParamsDTO) -> RGB {
        var out = rgb
        let cmyScale = 0.15
        out.r -= params.cyan * cmyScale
        out.g -= params.magenta * cmyScale
        out.b -= params.yellow * cmyScale

        if params.printContrast >= 0.001 {
            let k = mix(1.0, 5.0, params.printContrast)
            let s = RGB(
                1.0 / (1.0 + exp(-k * (out.r - 0.5))),
                1.0 / (1.0 + exp(-k * (out.g - 0.5))),
                1.0 / (1.0 + exp(-k * (out.b - 0.5)))
            )
            out = RGB(
                mix(out.r, s.r, params.printContrast),
                mix(out.g, s.g, params.printContrast),
                mix(out.b, s.b, params.printContrast)
            )
        }

        return out.clamped()
    }

    private static func applyLut(_ lut: SerializableLutDTO, to rgb: RGB) -> RGB {
        guard lut.size > 1, !lut.data.isEmpty else {
            return rgb
        }
        let sampled = sampleLut(lut.data, size: lut.size, at: rgb.clamped())
        let intensity = clamp(lut.intensity)
        return RGB(
            mix(rgb.r, sampled.r, intensity),
            mix(rgb.g, sampled.g, intensity),
            mix(rgb.b, sampled.b, intensity)
        )
    }

    private static func applyAutomaticInputTransform(
        _ policy: SourceInputTransformPolicyDTO,
        to rgb: RGB
    ) -> RGB {
        switch policy.strategy {
        case .appleLogToRec709, .appleLog2ToRec709:
            let converted = appleLogPixelToRec709(
                red: rgb.r,
                green: rgb.g,
                blue: rgb.b,
                rec2020GamutMap: true
            )
            return RGB(converted.red, converted.green, converted.blue)
        default:
            return rgb
        }
    }

    private static func sampleLut(_ data: [Double], size: Int, at rgb: RGB) -> RGB {
        let red = interpolationBounds(for: rgb.r, size: size)
        let green = interpolationBounds(for: rgb.g, size: size)
        let blue = interpolationBounds(for: rgb.b, size: size)
        var result = RGB(0, 0, 0)

        for blueCorner in 0...1 {
            let blueIndex = blueCorner == 0 ? blue.lower : blue.upper
            let blueWeight = blueCorner == 0 ? 1 - blue.fraction : blue.fraction
            for greenCorner in 0...1 {
                let greenIndex = greenCorner == 0 ? green.lower : green.upper
                let greenWeight = greenCorner == 0 ? 1 - green.fraction : green.fraction
                for redCorner in 0...1 {
                    let redIndex = redCorner == 0 ? red.lower : red.upper
                    let redWeight = redCorner == 0 ? 1 - red.fraction : red.fraction
                    let weight = redWeight * greenWeight * blueWeight
                    let value = lutValue(
                        data,
                        size: size,
                        red: redIndex,
                        green: greenIndex,
                        blue: blueIndex
                    )
                    result.r += value.r * weight
                    result.g += value.g * weight
                    result.b += value.b * weight
                }
            }
        }

        return result
    }

    private static func interpolationBounds(
        for coordinate: Double,
        size: Int
    ) -> (lower: Int, upper: Int, fraction: Double) {
        let scaled = clamp(coordinate) * Double(size - 1)
        let lower = max(0, min(size - 1, Int(floor(scaled))))
        let upper = min(size - 1, lower + 1)
        return (lower, upper, scaled - Double(lower))
    }

    private static func lutValue(
        _ data: [Double],
        size: Int,
        red: Int,
        green: Int,
        blue: Int
    ) -> RGB {
        let rgbCount = size * size * size * 3
        let rgbaCount = size * size * size * 4
        let base: Int
        let stride: Int
        if data.count >= rgbaCount {
            stride = 4
            base = ((blue * size * size) + (green * size) + red) * stride
        } else {
            stride = 3
            base = ((blue * size * size) + (green * size) + red) * stride
        }
        guard base + 2 < data.count, data.count >= rgbCount else {
            return RGB(0, 0, 0)
        }
        return RGB(data[base], data[base + 1], data[base + 2])
    }

    private static func appleLogPixelToRec709(
        red: Double,
        green: Double,
        blue: Double,
        rec2020GamutMap: Bool
    ) -> (red: Double, green: Double, blue: Double) {
        let linearRed = appleLogDecode(red)
        let linearGreen = appleLogDecode(green)
        let linearBlue = appleLogDecode(blue)

        let mapped: (red: Double, green: Double, blue: Double)
        if rec2020GamutMap {
            mapped = rec2020ToRec709(red: linearRed, green: linearGreen, blue: linearBlue)
        } else {
            mapped = (linearRed, linearGreen, linearBlue)
        }

        return (
            rec709Encode(filmtoneSdrShoulder(mapped.red)),
            rec709Encode(filmtoneSdrShoulder(mapped.green)),
            rec709Encode(filmtoneSdrShoulder(mapped.blue))
        )
    }

    private static func appleLogDecode(_ encoded: Double) -> Double {
        let r0 = -0.05641088
        let rt = 0.01
        let sigma = 47.28711236
        let beta = 0.00964052
        let gamma = 0.08550479
        let delta = 0.69336945
        let pt = sigma * pow(rt - r0, 2)

        if encoded >= pt {
            return pow(2, (encoded - delta) / gamma) - beta
        }
        if encoded >= 0 {
            return sqrt(max(encoded / sigma, 0)) + r0
        }
        return r0
    }

    private static func rec2020ToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        (
            red: 1.6605 * red - 0.5876 * green - 0.0728 * blue,
            green: -0.1246 * red + 1.1329 * green - 0.0083 * blue,
            blue: -0.0182 * red - 0.1006 * green + 1.1187 * blue
        )
    }

    private static func filmtoneSdrShoulder(_ linear: Double) -> Double {
        let exposed = max(0, linear * 1.18)
        let shoulder = exposed / (1 + max(exposed - 0.18, 0) * 0.42)
        return clamp(shoulder)
    }

    private static func rec709Encode(_ linear: Double) -> Double {
        let value = clamp(linear)
        if value < 0.018 {
            return value * 4.5
        }
        return 1.099 * pow(value, 0.45) - 0.099
    }

    private static func smoothstep(edge0: Double, edge1: Double, x: Double) -> Double {
        let t = clamp((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    private static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a * (1 - t) + b * t
    }

    private static func clamp(_ value: Double, min minValue: Double = 0, max maxValue: Double = 1) -> Double {
        min(max(value, minValue), maxValue)
    }

    private static func formatRGBLine(_ rgb: RGB) -> String {
        String(
            format: "%.7f %.7f %.7f",
            locale: Locale(identifier: "en_US_POSIX"),
            arguments: [rgb.r, rgb.g, rgb.b]
        )
    }

    private struct RGB {
        var r: Double
        var g: Double
        var b: Double

        init(_ r: Double, _ g: Double, _ b: Double) {
            self.r = r
            self.g = g
            self.b = b
        }

        var luma: Double {
            (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
        }

        func clamped() -> RGB {
            RGB(
                FilmtoneConnectCubeWriter.clamp(r),
                FilmtoneConnectCubeWriter.clamp(g),
                FilmtoneConnectCubeWriter.clamp(b)
            )
        }
    }
}
