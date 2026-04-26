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
struct SidecarLutRef: Encodable {
    let size: Int
    let intensity: Double
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
            inputLut: request.inputLut.map { SidecarLutRef(size: $0.size, intensity: $0.intensity) },
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
            realtimeRatio: inputs.realtimeRatio
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
            mezzanine: mezzanine
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
            return SidecarLutRef(size: creative.size, intensity: creative.intensity)
        }
        if let legacy = request.lut {
            return SidecarLutRef(size: legacy.size, intensity: legacy.intensity)
        }
        return nil
    }
}
