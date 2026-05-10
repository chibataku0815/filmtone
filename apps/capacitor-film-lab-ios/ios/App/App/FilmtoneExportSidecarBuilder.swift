import Foundation
import CoreGraphics
import FilmLabSwiftCore

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
    /// Mezzanine variant actually consumed during export, nil if mezzanine not used.
    let mezzanineUsedVariant: String?
    /// `MezzanineService.Profile.version` of the consumed mezzanine; nil when no mezzanine used.
    let mezzanineProfileVersion: Int?
    /// v1.4 additive truth fields. Stored as `var` with `nil` default so
    /// the synthesized memberwise init exposes them with defaults; existing
    /// test fixtures (`scripts/swift/test-sidecar-builder.swift`) keep their
    /// memberwise-init shape, and the production call site populates them
    /// from the FilmtoneExportSession route-time snapshot. See
    /// `SidecarMezzanine` doc-comment for semantics.
    var mezzanineUrlLastPathComponent: String? = nil
    var mezzanineFileSizeBytes: Int64? = nil
    var mezzanineDurationSec: Double? = nil
    var mezzanineWidth: Int? = nil
    var mezzanineHeight: Int? = nil
    var mezzanineCodec: String? = nil
    var mezzaninePrewarmHit: Bool? = nil
    var mezzanineGeneratedDuringExport: Bool? = nil
    var mezzanineValidationStatus: String? = nil
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
    /// v1.3 Item 2 Phase E: provenance for the Saved Look that was applied to
    /// the export at run time. nil when the user exported without applying a
    /// Saved Look (or after dirtying the project state since apply). Built-in
    /// catalog entries surface `bundled: true` + `bundledSlug` for downstream
    /// importers (Filmtone Connect for DaVinci); user-saved entries omit both.
    /// `FilmtoneExportSession.writeExportSidecar` converts a `SavedLookEntry`
    /// into this builder-local struct so the sidecar contract test stays free
    /// of `FilmtoneLibrarySchema` dependencies.
    let appliedSavedLook: SidecarSavedLookRef?
    /// v1.3 Camera Profiles Phase G: source-profile provenance. Identifies
    /// which Camera Profile drove the input normalization, plus the
    /// auto-resolution probe class when applicable. nil for legacy callers
    /// (preserves byte-identical sidecar output for paths that haven't
    /// adopted Phase G yet).
    let cameraProfile: SidecarCameraProfile?
    /// v1.5 additive export bottleneck telemetry. nil preserves the previous
    /// sidecar shape for legacy/unit-test call sites.
    var performance: SidecarPerformance? = nil
    /// Source-relative highlight markers shared by iOS, Desktop, and DaVinci.
    /// nil preserves the previous sidecar shape; an empty marker list should
    /// be omitted by callers.
    var highlightMarkers: FilmtoneHighlightMarkers? = nil
    /// M14-C (2026-05-09): capture-package master/proxy provenance.
    /// `var ... = nil` so the synthesized memberwise init exposes the
    /// field with a default — legacy fixtures and tests stay
    /// compilable. Production call site
    /// `FilmtoneExportSession.writeExportSidecar` populates from the
    /// session's `captureProvenance` property when present.
    var captureProvenance: SidecarCaptureProvenance? = nil
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
    /// v1.3 Item 2 Phase E: which Saved Look (built-in or user-created) was
    /// applied to this export at run time. nil when no Saved Look was active.
    /// Additive optional field — V1 readers ignore unknown keys (CLAUDE.md §5).
    let savedLook: SidecarSavedLookRef?
    /// v1.3 Camera Profiles Phase G: which Camera Profile drove the input
    /// normalization for this export. Additive optional V1 field; nil
    /// preserves the v1.2-shaped sidecar.
    let cameraProfile: SidecarCameraProfile?
    /// v1.4 Backlight Veil identity selected for this render request. The
    /// visible spatial values are resolved at render time; this additive field
    /// keeps downstream tools from losing the user's Look + Veil combination.
    let opticalFilterProfileId: String?
    /// v1.5 additive wall-clock stage totals used to identify export bottlenecks.
    let performance: SidecarPerformance?
    /// Source-relative marker intent for DaVinci / Desktop round-trip. Additive
    /// optional V1 field; absence means no marker intent.
    let highlightMarkers: FilmtoneHighlightMarkers?
    /// M14-C (2026-05-09): which capture-package file the export read
    /// from — master or proxy fallback. Additive optional V1 field;
    /// nil omits the block (Photos / Files non-capture edits).
    let captureProvenance: SidecarCaptureProvenance?
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
    /// v1.4 Creative LUT Pack 01 provenance — emitted only when the LUT
    /// originated from a `CreativeLutBinding.bundled` catalog entry. nil
    /// for user-imported LUTs and library-resolved LUTs. Encoded with
    /// `encodeIfPresent` so pre-v1.4 sidecar consumers that ignore unknown
    /// keys remain compatible (V1 schema additive).
    let bundledSlug: String?
    let bundledPackId: String?

    init(
        size: Int,
        intensity: Double,
        sourceHash: String?,
        bundledSlug: String? = nil,
        bundledPackId: String? = nil
    ) {
        self.size = size
        self.intensity = intensity
        self.sourceHash = sourceHash
        self.bundledSlug = bundledSlug
        self.bundledPackId = bundledPackId
    }

    private enum CodingKeys: String, CodingKey {
        case size, intensity, sourceHash, bundledSlug, bundledPackId
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(size, forKey: .size)
        try c.encode(intensity, forKey: .intensity)
        try c.encodeIfPresent(sourceHash, forKey: .sourceHash)
        try c.encodeIfPresent(bundledSlug, forKey: .bundledSlug)
        try c.encodeIfPresent(bundledPackId, forKey: .bundledPackId)
    }
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

/// v1.5 export bottleneck telemetry. This is intentionally wall-clock based
/// rather than Instruments-only so a normal real-device export leaves a usable
/// profile in the sidecar JSON.
struct SidecarPerformance: Encodable {
    let exportElapsedMs: Int
    let mediaPipelineMs: Double?
    let decodeMs: Double
    let decodeSamples: Int
    let waitEncoderMs: Double
    let buildGraphMs: Double
    let renderMs: Double
    let appendMs: Double
    let writerFinishMs: Double
    let mediaPipelineResidualMs: Double?
    let renderedFrames: Int
    let avgRenderMsPerFrame: Double?
    let renderShareOfExport: Double?
    let renderShareOfMediaPipeline: Double?
    let thermalStateAtStart: String?
    let thermalStateAtEnd: String?
    let lowPowerModeEnabledAtStart: Bool?
    let lowPowerModeEnabledAtEnd: Bool?
    let processorCount: Int?
    let activeProcessorCountAtStart: Int?
    let activeProcessorCountAtEnd: Int?
    let physicalMemoryBytes: UInt64?
    let disabledRenderStages: [String]?
    let acceleratedRenderStages: [String]?
    let renderStageProfile: SidecarRenderStageProfile?
}

/// Temporary v1.5 profiler payload. Each stage is measured by forcing Core
/// Image evaluation into a scratch pixel buffer after that stage boundary.
/// Stage values are cumulative from the original input through that boundary;
/// incremental values are derived by subtracting the previous boundary.
struct SidecarRenderStageProfile: Encodable {
    let mode: String
    let source: String
    let frameStride: Int
    let sampledFrames: Int
    let totalFrames: Int
    let forcedRenderMs: Double
    let stages: [SidecarRenderStageMetric]
}

struct SidecarRenderStageMetric: Encodable {
    let stage: String
    let samples: Int
    let failures: Int
    let cumulativeMs: Double
    let cumulativeAvgMsPerSample: Double?
    let estimatedCumulativeMs: Double?
    let incrementalMsFromPreviousStage: Double?
    let incrementalAvgMsPerSample: Double?
    let estimatedIncrementalMs: Double?
}

/// v1.3 Camera Profiles Phase G: provenance for the Camera Profile that
/// drove input normalization for this export. Builder-local struct (the
/// standalone sidecar contract test can't compile FilmtoneSourceProfileSchema
/// without dragging in the wider media types graph) — `FilmtoneExportSession`
/// flattens `CameraProfileSelection` + the resolved catalog entry into
/// these stringly-typed fields.
///
/// Field semantics:
///
/// - `selectionKind`: which `CameraProfileSelection` case applied
///   (`"auto" | "built-in" | "user-import"`).
/// - `catalogId`: the namespaced catalog id, only set when `selectionKind`
///   is `"built-in"` or when `.auto` resolved through the catalog at
///   export time.
/// - `curve`: the `SourceProfileCurve` raw value (`"apple-log"` /
///   `"apple-log-2"` / `"dji-dlog"` / `"dji-dlog-m"` / `"canon-clog"` /
///   `"canon-log3-cinema-gamut"` / `"panasonic-vlog"` / `"sony-slog3"`),
///   nil for `nilProfile` / `userImport`.
/// - `impl`: the `SourceProfileImpl` discriminator (`"native-policy"` /
///   `"synthesized"` / `"nil-profile"` / `"bundled-cube"`), nil only when
///   the export ran without a recognized profile (auto with no probe).
/// - `resolvedFromAutoVia`: when `selectionKind == "auto"`, records which
///   probe `colorClass` selected the catalog entry (e.g. `"apple-log"`).
///   nil when the user explicitly picked the profile.
struct SidecarCameraProfile: Encodable {
    let selectionKind: String
    let catalogId: String?
    let curve: String?
    let impl: String?
    let resolvedFromAutoVia: String?
}

/// v1.3 Item 2 Phase E: provenance entry for a Saved Look applied to the
/// export. Mirrors the durable `SavedLookEntry` schema (in
/// `FilmtoneLibrarySchema.swift`) but stays builder-local so the sidecar
/// contract test compiles without pulling the entire library schema graph.
///
/// `bundled` and `bundledSlug` are `Optional` so user-saved looks omit them
/// from the JSON via `encodeIfPresent`. Built-in catalog entries set
/// `bundled = true` plus the catalog `bundledSlug` (e.g.
/// `"filmtone-signature"`) so Filmtone Connect for DaVinci and other
/// downstream readers can recognize built-ins across renames or app updates.
struct SidecarSavedLookRef: Encodable {
    let id: String
    let name: String
    let updatedAtIso: String
    let bundled: Bool?
    let bundledSlug: String?
}

/// Records whether (and which variant of) a mezzanine asset was consumed for this export.
/// `used == false` is a meaningful signal: the export ran via the source-direct path on
/// purpose (policy declined, or the requested mezzanine is still missing). `variant` is one
/// of the ProfileVariant raw values when used; nil when not. `profileVersion` mirrors
/// `MezzanineService.Profile.version` so importers can detect schema drift.
///
/// v1.4 (additive — V1 schema reader still ignores unknown keys, so no schemaVersion
/// bump): when `used == true`, also record the routed file's identity, metrics, and
/// validation outcome so the four observable surfaces (sidecar / output mp4 / on-device
/// cache file / device file listing) can be cross-checked from the sidecar alone. This
/// closes the prior class of bugs where the sidecar said "qualityHDR used" while the
/// device-side cache was actually a 5.88 s truncated stub. Every v1.4 field is optional
/// so V1 readers stay byte-compatible.
struct SidecarMezzanine: Encodable {
    let used: Bool
    let variant: String?
    let profileVersion: Int?
    /// Last path component of the cached mezzanine file actually consumed
    /// (the SHA-256-named mp4 inside Library/Caches/FilmtonePhase0/mezzanine).
    let urlLastPathComponent: String?
    let fileSizeBytes: Int64?
    let durationSec: Double?
    let width: Int?
    let height: Int?
    /// FourCC media-subtype string from the cache file's first video track
    /// (e.g. "hvc1", "avc1"). Lower-cased.
    let codec: String?
    /// True when this export found the cache already populated (a prewarm
    /// from import time hit). False when this export had to call
    /// `ensureMezzanineBlocking` synchronously and wait for generation.
    /// nil when no quality variant was even requested for this export.
    let prewarmHit: Bool?
    /// Convenience inverse of `prewarmHit` for diagnostic clarity. When
    /// `prewarmHit == false`, generatedDuringExport is true. nil otherwise.
    let generatedDuringExport: Bool?
    /// One of: "valid" (passed the route-time race guard), "invalidated-before-open"
    /// (an evicted/raced cache file was caught by the race guard and the export
    /// fell back to source-direct), "disabled-on-ios" (route policy returned nil
    /// for this source class — used in conjunction with `used: false`).
    let validationStatus: String?
}

/// M14-C (2026-05-09): records whether the export pipeline read from
/// the capture-package master or the proxy fallback, and why.
///
/// Emitted only when a capture-package was the source of this export
/// (the editor adopted via `FilmtoneEditorStore.adoptCaptureResult`).
/// Photos / Files non-capture edits omit the field entirely.
///
/// Field semantics:
///   - `mode` — `"master"` when the export read the master file;
///     `"proxy"` when the master was unreachable + the export fell
///     back to the proxy.
///   - `reason` — present only on `mode == "proxy"`. Values are
///     `"masterFileMissing"` (the file did not exist at the
///     package's `masterURL.path`) or
///     `"masterProbeFailed:<NSError-localized>"` (the file existed
///     but the probe could not read it, typically a security-scoped
///     access denial).
///   - `masterUriUsed` — file URI of the master that was either
///     successfully read OR was *intended* and fell back. Present
///     for both master + proxy modes so DaVinci importers can see
///     the originally-targeted master regardless of the outcome.
///   - `proxyUriUsed` — file URI of the proxy file. Present only
///     on `mode == "proxy"` so importers can distinguish the
///     fallback artifact from the intended master.
///
/// All fields except `mode` are `Optional` and emit via
/// `encodeIfPresent` — sidecar JSON omits nil fields so the master
/// path produces `{ "mode": "master", "masterUriUsed": "..." }`
/// without superfluous nulls.
struct SidecarCaptureProvenance: Encodable {
    let mode: String
    let reason: String?
    let masterUriUsed: String?
    let proxyUriUsed: String?
    /// S1 (2026-05-09): owner-requested stabilization for the source
    /// run.  `"on"` -> cinematicExtendedEnhanced was preferred, `"off"`
    /// -> stabilization was deliberately disabled (gimbal capture).
    /// Optional / additive — pre-S1 sidecars omit the field and
    /// pre-S1 readers ignore it.
    let requestedStabilization: String?
    /// S1: AVFoundation mode name observed on the movie connection at
    /// record-finish time.  Equals the canonical name of the requested
    /// mode on a clean run; the post-record gate would have failed the
    /// run if they diverged.  Optional / additive.
    let observedStabilization: String?
    /// S7: custom capture LUT provenance. These fields are nil when the
    /// capture used a built-in Look or Filmtone default.
    let customLutTitle: String?
    let customLutLibraryId: String?
    let customLutSourceHash: String?
    let customLutSize: Int?
    let customLutIntensity: Double?
    let customLutConversionPolicy: String?
    let customLutTransformWarningAccepted: Bool?
    let customLutTransformWarningReason: String?
    let customLutTransformWarningKind: String?
    let customLutTransformWarningSignal: String?

    init(
        mode: String,
        reason: String?,
        masterUriUsed: String?,
        proxyUriUsed: String?,
        requestedStabilization: String? = nil,
        observedStabilization: String? = nil,
        customLutTitle: String? = nil,
        customLutLibraryId: String? = nil,
        customLutSourceHash: String? = nil,
        customLutSize: Int? = nil,
        customLutIntensity: Double? = nil,
        customLutConversionPolicy: String? = nil,
        customLutTransformWarningAccepted: Bool? = nil,
        customLutTransformWarningReason: String? = nil,
        customLutTransformWarningKind: String? = nil,
        customLutTransformWarningSignal: String? = nil
    ) {
        self.mode = mode
        self.reason = reason
        self.masterUriUsed = masterUriUsed
        self.proxyUriUsed = proxyUriUsed
        self.requestedStabilization = requestedStabilization
        self.observedStabilization = observedStabilization
        self.customLutTitle = customLutTitle
        self.customLutLibraryId = customLutLibraryId
        self.customLutSourceHash = customLutSourceHash
        self.customLutSize = customLutSize
        self.customLutIntensity = customLutIntensity
        self.customLutConversionPolicy = customLutConversionPolicy
        self.customLutTransformWarningAccepted = customLutTransformWarningAccepted
        self.customLutTransformWarningReason = customLutTransformWarningReason
        self.customLutTransformWarningKind = customLutTransformWarningKind
        self.customLutTransformWarningSignal = customLutTransformWarningSignal
    }

    private enum CodingKeys: String, CodingKey {
        case mode, reason, masterUriUsed, proxyUriUsed
        case requestedStabilization, observedStabilization
        case customLutTitle, customLutLibraryId, customLutSourceHash
        case customLutSize, customLutIntensity, customLutConversionPolicy
        case customLutTransformWarningAccepted, customLutTransformWarningReason
        case customLutTransformWarningKind, customLutTransformWarningSignal
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(reason, forKey: .reason)
        try container.encodeIfPresent(masterUriUsed, forKey: .masterUriUsed)
        try container.encodeIfPresent(proxyUriUsed, forKey: .proxyUriUsed)
        try container.encodeIfPresent(
            requestedStabilization, forKey: .requestedStabilization
        )
        try container.encodeIfPresent(
            observedStabilization, forKey: .observedStabilization
        )
        try container.encodeIfPresent(customLutTitle, forKey: .customLutTitle)
        try container.encodeIfPresent(customLutLibraryId, forKey: .customLutLibraryId)
        try container.encodeIfPresent(customLutSourceHash, forKey: .customLutSourceHash)
        try container.encodeIfPresent(customLutSize, forKey: .customLutSize)
        try container.encodeIfPresent(customLutIntensity, forKey: .customLutIntensity)
        try container.encodeIfPresent(
            customLutConversionPolicy, forKey: .customLutConversionPolicy
        )
        try container.encodeIfPresent(
            customLutTransformWarningAccepted,
            forKey: .customLutTransformWarningAccepted
        )
        try container.encodeIfPresent(
            customLutTransformWarningReason,
            forKey: .customLutTransformWarningReason
        )
        try container.encodeIfPresent(
            customLutTransformWarningKind,
            forKey: .customLutTransformWarningKind
        )
        try container.encodeIfPresent(
            customLutTransformWarningSignal,
            forKey: .customLutTransformWarningSignal
        )
    }
}

struct SidecarPackageLuts: Encodable {
    let combinedColor: String
    let preOpticalColor: String?
    let postOpticalColor: String?
}

struct SidecarPackageEffects: Encodable {
    let dctl: String?
}

struct SidecarPackage: Encodable {
    static let layoutID = "filmtone-connect-package-v2"

    let layout: String
    /// Deprecated v1 compatibility alias. In v2 this intentionally points to
    /// the original source media so older importers do not double-process the
    /// baked iOS render.
    let mediaFilename: String
    let sourceMediaFilename: String
    let renderedMediaFilename: String
    let referenceAfterFilename: String
    let referenceAfterTimeSec: Double
    let luts: SidecarPackageLuts
    let effects: SidecarPackageEffects?

    init(
        sourceMediaFilename: String,
        renderedMediaFilename: String,
        referenceAfterFilename: String,
        referenceAfterTimeSec: Double,
        combinedColorFilename: String,
        preOpticalColorFilename: String? = nil,
        postOpticalColorFilename: String? = nil,
        effectsDctlFilename: String? = nil,
        layout: String = layoutID
    ) {
        self.layout = layout
        self.mediaFilename = sourceMediaFilename
        self.sourceMediaFilename = sourceMediaFilename
        self.renderedMediaFilename = renderedMediaFilename
        self.referenceAfterFilename = referenceAfterFilename
        self.referenceAfterTimeSec = referenceAfterTimeSec
        self.luts = SidecarPackageLuts(
            combinedColor: combinedColorFilename,
            preOpticalColor: preOpticalColorFilename,
            postOpticalColor: postOpticalColorFilename
        )
        self.effects = effectsDctlFilename.map { SidecarPackageEffects(dctl: $0) }
    }
}

enum FilmtoneConnectPackageFiles {
    static func orderedPackageFileUris(
        renderedUri: String,
        sidecarUri: String,
        sourceMediaUri: String,
        preOpticalCubeUri: String? = nil,
        postOpticalCubeUri: String? = nil,
        cubeUri: String,
        dctlUri: String,
        referenceAfterUri: String
    ) -> [String] {
        var uris = [
            renderedUri,
            sidecarUri,
            sourceMediaUri,
        ]
        if let preOpticalCubeUri {
            uris.append(preOpticalCubeUri)
        }
        if let postOpticalCubeUri {
            uris.append(postOpticalCubeUri)
        }
        uris.append(cubeUri)
        uris.append(dctlUri)
        uris.append(referenceAfterUri)
        return uris
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
        // v1.4 additive truth fields populated when used=true OR when the caller surfaced
        // a route-level validationStatus (e.g. "disabled-on-ios" with used=false).
        let mezzanine = SidecarMezzanine(
            used: inputs.mezzanineUsedVariant != nil,
            variant: inputs.mezzanineUsedVariant,
            profileVersion: inputs.mezzanineProfileVersion,
            urlLastPathComponent: inputs.mezzanineUrlLastPathComponent,
            fileSizeBytes: inputs.mezzanineFileSizeBytes,
            durationSec: inputs.mezzanineDurationSec,
            width: inputs.mezzanineWidth,
            height: inputs.mezzanineHeight,
            codec: inputs.mezzanineCodec,
            prewarmHit: inputs.mezzaninePrewarmHit,
            generatedDuringExport: inputs.mezzanineGeneratedDuringExport,
            validationStatus: inputs.mezzanineValidationStatus
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
            depth: depth,
            savedLook: inputs.appliedSavedLook,
            cameraProfile: inputs.cameraProfile,
            opticalFilterProfileId: request.opticalFilterProfileId,
            performance: inputs.performance,
            highlightMarkers: inputs.highlightMarkers,
            captureProvenance: inputs.captureProvenance
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
                ),
                bundledSlug: creative.bundledSlug,
                bundledPackId: creative.bundledPackId
            )
        }
        if let legacy = request.lut {
            return SidecarLutRef(
                size: legacy.size,
                intensity: legacy.intensity,
                sourceHash: try? FilmtoneLutBlobCodec.sourceHash(
                    data: legacy.data,
                    size: legacy.size
                ),
                bundledSlug: legacy.bundledSlug,
                bundledPackId: legacy.bundledPackId
            )
        }
        return nil
    }
}

enum FilmtoneConnectCubeWriter {
    static let defaultCubeSize = 33
    static let defaultTitle = "Filmtone Combined Color"
    private enum ColorBridgeSection {
        case combined
        case preOptical
        case postOptical
    }

    static func writeCombinedColorCube(
        for request: Phase0ExportRequestDTO,
        to url: URL,
        size: Int = defaultCubeSize
    ) throws {
        let text = makeCombinedColorCubeText(for: request, size: size)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func writePreOpticalColorCube(
        for request: Phase0ExportRequestDTO,
        to url: URL,
        size: Int = defaultCubeSize
    ) throws {
        let text = makePreOpticalColorCubeText(for: request, size: size)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func writePostOpticalColorCube(
        for request: Phase0ExportRequestDTO,
        to url: URL,
        size: Int = defaultCubeSize
    ) throws {
        let text = makePostOpticalColorCubeText(for: request, size: size)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func makeCombinedColorCubeText(
        for request: Phase0ExportRequestDTO,
        size: Int = defaultCubeSize
    ) -> String {
        makeColorCubeText(
            for: request,
            size: size,
            title: defaultTitle,
            comment: "# Full scalar compatibility bridge. Split color LUTs are preferred by package v2 DCTL.",
            section: .combined
        )
    }

    static func makePreOpticalColorCubeText(
        for request: Phase0ExportRequestDTO,
        size: Int = defaultCubeSize
    ) -> String {
        makeColorCubeText(
            for: request,
            size: size,
            title: "Filmtone Pre Optical Color",
            comment: "# Input/base/compression color before the Resolve texture bridge.",
            section: .preOptical
        )
    }

    static func makePostOpticalColorCubeText(
        for request: Phase0ExportRequestDTO,
        size: Int = defaultCubeSize
    ) -> String {
        makeColorCubeText(
            for: request,
            size: size,
            title: "Filmtone Post Optical Color",
            comment: "# Creative/print color after the Resolve texture bridge.",
            section: .postOptical
        )
    }

    private static func makeColorCubeText(
        for request: Phase0ExportRequestDTO,
        size: Int,
        title: String,
        comment: String,
        section: ColorBridgeSection
    ) -> String {
        let resolvedSize = max(2, size)
        var lines: [String] = [
            "TITLE \"\(title)\"",
            "# Generated by Filmtone Connect for DaVinci.",
            comment,
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
                        request: request,
                        section: section
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
        request: Phase0ExportRequestDTO,
        section: ColorBridgeSection
    ) -> RGB {
        let params = request.grade.params
        var current = RGB(red, green, blue)

        if section == .combined || section == .preOptical {
            current = applyPreOpticalColorBridge(current, request: request, params: params)
        }

        if section == .combined || section == .postOptical {
            current = applyPostOpticalColorBridge(current, request: request, params: params)
        }
        return current.clamped()
    }

    private static func applyPreOpticalColorBridge(
        _ rgb: RGB,
        request: Phase0ExportRequestDTO,
        params: Phase0ParamsDTO
    ) -> RGB {
        var current = rgb
        if let inputLut = request.inputLut {
            current = applyLut(inputLut, to: current)
        } else if let policy = request.sourceProbe?.inputTransformPolicy {
            current = applyAutomaticInputTransform(policy, to: current)
        }

        current = applyBaseGrade(current, params: params)
        current = applyFilmCompression(current, params: params)
        return current
    }

    private static func applyPostOpticalColorBridge(
        _ rgb: RGB,
        request: Phase0ExportRequestDTO,
        params: Phase0ParamsDTO
    ) -> RGB {
        var current = rgb
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
        return current
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

enum FilmtoneConnectDctlWriter {
    static let defaultTitle = "Filmtone Connect Bridge"
    private static let dctlRgbShiftThreshold = 0.0001
    private static let dctlRgbShiftReferenceMax = 0.005
    private static let dctlRgbShiftProbeMixAtMax = 0.72
    private static let dctlRgbShiftPixelOffset = 2
    private static let dctlEdgeSoftnessThreshold = 0.0001
    private static let dctlAberrationEdgeSoftenScale = 32.0
    private static let dctlAberrationEdgeSoftenMax = 0.52
    private static let dctlAberrationEdgeSoftenCurve = 1.55
    private static let dctlAberrationBlurRadiusMin = 1.6
    private static let dctlAberrationBlurRadiusMax = 6.2
    private static let dctlAberrationBlurRadiusCap = 7.8
    private static let dctlLensSoftnessBlurBoost = 1.85
    private static let dctlDiffusionThreshold = 0.0001
    private static let dctlDiffusionAmountScale = 0.67688378
    private static let dctlDiffusionCompositeBase = 0.87
    private static let dctlDiffusionMipTapRadii = [3, 7, 15, 31]
    private static let dctlDiffusionMipGroupWeights = [0.22, 0.26, 0.25, 0.15]
    private static let dctlDiffusionCenterWeight = 0.12
    private static let dctlDiffusionCenterMaskStart = 0.25
    private static let dctlDiffusionCenterMaskEnd = 0.80

    private struct DctlEdgeSoftnessParams {
        let aberrationSoften: Double
        let lensDrive: Double
        let tapRadius: Int
    }

    private struct DctlDiffusionParams {
        let amount: Double
        let tapRadii: [Int]
        let groupWeights: [Double]
        let centerWeight: Double
        let maskStart: Double
        let maskEnd: Double
    }

    private struct DctlColorCalibration {
        let redGain: Double
        let greenGain: Double
        let blueGain: Double
        let redOffset: Double
        let greenOffset: Double
        let blueOffset: Double
    }

    static func writeBridgeDctl(
        for request: Phase0ExportRequestDTO,
        cubeFilename: String,
        preOpticalColorFilename: String? = nil,
        postOpticalColorFilename: String? = nil,
        outputFps: Int,
        sourceSeed: Double,
        to url: URL
    ) throws {
        let text = makeBridgeDctlText(
            for: request,
            cubeFilename: cubeFilename,
            preOpticalColorFilename: preOpticalColorFilename,
            postOpticalColorFilename: postOpticalColorFilename,
            outputFps: outputFps,
            sourceSeed: sourceSeed
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func makeBridgeDctlText(
        for request: Phase0ExportRequestDTO,
        cubeFilename: String,
        preOpticalColorFilename: String? = nil,
        postOpticalColorFilename: String? = nil,
        outputFps: Int,
        sourceSeed: Double
    ) -> String {
        guard let preOpticalColorFilename, let postOpticalColorFilename else {
            return makeLegacyColorOnlyBridgeDctlText(cubeFilename: cubeFilename)
        }

        let calibration = dctlResolveTextureCalibration(for: request)
        let textureOpticsBlock = makeDctlTextureOpticsBlock(for: request)

        return """
// \(defaultTitle)
// Generated by Filmtone iOS. Apply through Filmtone Connect package v2.
// Split bridge order: pre-optical color LUT, Resolve-verified RGB shift, edge-masked softness, and multi-radius mip-like diffusion,
// post-optical creative/print LUT, then Resolve texture color compensation.
// Bloom, halation, exact diffusion parity, vignette, grain, and time effects remain explicit visual equivalence blockers until ported and verified in Resolve.
DEFINE_LUT(FilmtonePreOpticalColor, \(preOpticalColorFilename))
DEFINE_LUT(FilmtonePostOpticalColor, \(postOpticalColorFilename))

__DEVICE__ float filmtone_clamp(float v, float lo, float hi)
{
    return _fminf(_fmaxf(v, lo), hi);
}
\(textureOpticsBlock.helpers)

__DEVICE__ float3 transform(int p_Width, int p_Height, int p_X, int p_Y, __TEXTURE__ p_TexR, __TEXTURE__ p_TexG, __TEXTURE__ p_TexB)
{
\(textureOpticsBlock.transform)
    return make_float3(
        filmtone_clamp(rgb.x * \(dctlFloat(calibration.redGain)) + \(dctlFloat(calibration.redOffset)), 0.0f, 1.0f),
        filmtone_clamp(rgb.y * \(dctlFloat(calibration.greenGain)) + \(dctlFloat(calibration.greenOffset)), 0.0f, 1.0f),
        filmtone_clamp(rgb.z * \(dctlFloat(calibration.blueGain)) + \(dctlFloat(calibration.blueOffset)), 0.0f, 1.0f)
    );
}
"""
    }

    private static func makeDctlTextureOpticsBlock(
        for request: Phase0ExportRequestDTO
    ) -> (helpers: String, transform: String) {
        let rgbShiftMix = dctlRgbShiftMix(for: request)
        let edgeSoftness = dctlEdgeSoftnessParams(for: request)
        let diffusion = dctlDiffusionParams(for: request)

        guard rgbShiftMix > 0 || edgeSoftness != nil || diffusion != nil else {
            return (
                helpers: "",
                transform: """
                    float3 rgb = make_float3(_tex2D(p_TexR, p_X, p_Y), _tex2D(p_TexG, p_X, p_Y), _tex2D(p_TexB, p_X, p_Y));
                    rgb = APPLY_LUT(rgb.x, rgb.y, rgb.z, FilmtonePreOpticalColor);
                    rgb = APPLY_LUT(rgb.x, rgb.y, rgb.z, FilmtonePostOpticalColor);
                """
            )
        }

        let helpers = makeDctlTextureOpticsHelpers(
            includeSmoothstep: edgeSoftness != nil || diffusion != nil,
            includeGlow: diffusion != nil
        )
        guard edgeSoftness != nil || diffusion != nil else {
            let centerSample = makeDctlPreOpticalRgbShiftSample(
                xExpr: "p_X",
                yExpr: "p_Y",
                rgbShiftMix: rgbShiftMix,
                sxVar: "sx",
                syVar: "sy",
                rxVar: "rx",
                ryVar: "ry",
                bxVar: "bx",
                byVar: "by",
                centerVar: "center",
                redVar: "redSample",
                blueVar: "blueSample",
                outRVar: "r",
                outGVar: "g",
                outBVar: "b"
            )
            return (
                helpers: helpers,
                transform: """
                    int cx = p_Width / 2;
                    int cy = p_Height / 2;
                """ + "\n" + centerSample + "\n" + """
                    float3 rgb = APPLY_LUT(r, g, b, FilmtonePostOpticalColor);
                """
            )
        }

        guard let edgeSoftness else {
            let centerSample = makeDctlPreOpticalRgbShiftSample(
                xExpr: "p_X",
                yExpr: "p_Y",
                rgbShiftMix: rgbShiftMix,
                sxVar: "sx",
                syVar: "sy",
                rxVar: "rx",
                ryVar: "ry",
                bxVar: "bx",
                byVar: "by",
                centerVar: "center",
                redVar: "redSample",
                blueVar: "blueSample",
                outRVar: "outR",
                outGVar: "outG",
                outBVar: "outB"
            )
            let diffusionBlock = diffusion.map(makeDctlDiffusionBlock) ?? ""
            return (
                helpers: helpers,
                transform: """
                    int cx = p_Width / 2;
                    int cy = p_Height / 2;
                """ + "\n" + centerSample + "\n" + makeDctlEdgeRadiusBlock() + "\n" + diffusionBlock + "\n" + """
                    float3 rgb = APPLY_LUT(outR, outG, outB, FilmtonePostOpticalColor);
                """
            )
        }

        let radius = edgeSoftness.tapRadius
        let centerSample = makeDctlPreOpticalRgbShiftSample(
            xExpr: "p_X",
            yExpr: "p_Y",
            rgbShiftMix: rgbShiftMix,
            sxVar: "sx",
            syVar: "sy",
            rxVar: "rx",
            ryVar: "ry",
            bxVar: "bx",
            byVar: "by",
            centerVar: "center",
            redVar: "redSample",
            blueVar: "blueSample",
            outRVar: "r",
            outGVar: "g",
            outBVar: "b"
        )
        let leftSample = makeDctlPreOpticalRgbShiftSample(
            xExpr: "lx",
            yExpr: "p_Y",
            rgbShiftMix: rgbShiftMix,
            sxVar: "lSx",
            syVar: "lSy",
            rxVar: "lRx",
            ryVar: "lRy",
            bxVar: "lBx",
            byVar: "lBy",
            centerVar: "lCenter",
            redVar: "lRedSample",
            blueVar: "lBlueSample",
            outRVar: "lR",
            outGVar: "lG",
            outBVar: "lB"
        )
        let rightSample = makeDctlPreOpticalRgbShiftSample(
            xExpr: "rxTap",
            yExpr: "p_Y",
            rgbShiftMix: rgbShiftMix,
            sxVar: "rSx",
            syVar: "rSy",
            rxVar: "rRx",
            ryVar: "rRy",
            bxVar: "rBx",
            byVar: "rBy",
            centerVar: "rCenter",
            redVar: "rRedSample",
            blueVar: "rBlueSample",
            outRVar: "rR",
            outGVar: "rG",
            outBVar: "rB"
        )
        let upSample = makeDctlPreOpticalRgbShiftSample(
            xExpr: "p_X",
            yExpr: "uy",
            rgbShiftMix: rgbShiftMix,
            sxVar: "uSx",
            syVar: "uSy",
            rxVar: "uRx",
            ryVar: "uRy",
            bxVar: "uBx",
            byVar: "uBy",
            centerVar: "uCenter",
            redVar: "uRedSample",
            blueVar: "uBlueSample",
            outRVar: "uR",
            outGVar: "uG",
            outBVar: "uB"
        )
        let downSample = makeDctlPreOpticalRgbShiftSample(
            xExpr: "p_X",
            yExpr: "dy",
            rgbShiftMix: rgbShiftMix,
            sxVar: "dSx",
            syVar: "dSy",
            rxVar: "dRx",
            ryVar: "dRy",
            bxVar: "dBx",
            byVar: "dBy",
            centerVar: "dCenter",
            redVar: "dRedSample",
            blueVar: "dBlueSample",
            outRVar: "dR",
            outGVar: "dG",
            outBVar: "dB"
        )
        let transform = """
            int cx = p_Width / 2;
            int cy = p_Height / 2;
            int softenRadius = \(radius);
            int lx = filmtone_clamp_int(p_X - softenRadius, 0, p_Width - 1);
            int rxTap = filmtone_clamp_int(p_X + softenRadius, 0, p_Width - 1);
            int uy = filmtone_clamp_int(p_Y - softenRadius, 0, p_Height - 1);
            int dy = filmtone_clamp_int(p_Y + softenRadius, 0, p_Height - 1);
        """ + "\n" + centerSample + "\n" + leftSample + "\n" + rightSample + "\n" + upSample + "\n" + downSample + "\n" + makeDctlEdgeRadiusBlock() + "\n" + """
            float edgeMask = filmtone_smoothstep(0.25f, 1.0f, edgeR);
            float lensW = _powf(edgeR, 1.52f);
            float lensWeight = filmtone_clamp(\(dctlFloat(edgeSoftness.lensDrive)) * lensW, 0.0f, 1.0f);
            float lensMix = lensWeight * 0.720000000f;
            float softenAmt = filmtone_clamp((\(dctlFloat(edgeSoftness.aberrationSoften)) * edgeMask) + (lensMix * edgeMask), 0.0f, 1.0f);
            float blurR = r * 0.400000000f + lR * 0.150000000f + rR * 0.150000000f + uR * 0.150000000f + dR * 0.150000000f;
            float blurG = g * 0.400000000f + lG * 0.150000000f + rG * 0.150000000f + uG * 0.150000000f + dG * 0.150000000f;
            float blurB = b * 0.400000000f + lB * 0.150000000f + rB * 0.150000000f + uB * 0.150000000f + dB * 0.150000000f;
            float outR = r * (1.0f - softenAmt) + blurR * softenAmt;
            float outG = g * (1.0f - softenAmt) + blurG * softenAmt;
            float outB = b * (1.0f - softenAmt) + blurB * softenAmt;
        """ + "\n" + (diffusion.map(makeDctlDiffusionBlock) ?? "") + "\n" + """
            float3 rgb = APPLY_LUT(outR, outG, outB, FilmtonePostOpticalColor);
        """
        return (helpers: helpers, transform: transform)
    }

    private static func makeDctlTextureOpticsHelpers(includeSmoothstep: Bool, includeGlow: Bool) -> String {
        var helpers = """

__DEVICE__ int filmtone_clamp_int(int v, int lo, int hi)
{
    if (v < lo) {
        return lo;
    }
    if (v > hi) {
        return hi;
    }
    return v;
}
"""
        if includeSmoothstep {
            helpers += """

__DEVICE__ float filmtone_smoothstep(float edge0, float edge1, float x)
{
    float t = filmtone_clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
    return t * t * (3.0f - 2.0f * t);
}
"""
        }
        if includeGlow {
            helpers += """

__DEVICE__ float filmtone_luma(float r, float g, float b)
{
    return r * 0.2126f + g * 0.7152f + b * 0.0722f;
}

__DEVICE__ float filmtone_glow_shoulder(float energy)
{
    return 1.0f - _expf(-_fmaxf(energy, 0.0f));
}

__DEVICE__ float filmtone_glow_headroom(float r, float g, float b, float floorValue)
{
    float luma = filmtone_luma(r, g, b);
    float root = _sqrtf(filmtone_clamp(1.0f - luma, 0.0f, 1.0f));
    return floorValue * (1.0f - root) + root;
}
"""
        }
        return helpers
    }

    private static func makeDctlEdgeRadiusBlock() -> String {
        """
            float edgeX = ((float)p_X + 0.5f) - ((float)p_Width * 0.5f);
            float edgeY = ((float)p_Y + 0.5f) - ((float)p_Height * 0.5f);
            float halfWidth = (float)p_Width * 0.5f;
            float halfHeight = (float)p_Height * 0.5f;
            float halfDiag = _fmaxf(_sqrtf((halfWidth * halfWidth) + (halfHeight * halfHeight)), 1.0f);
            float edgeR = filmtone_clamp(_sqrtf((edgeX * edgeX) + (edgeY * edgeY)) / halfDiag, 0.0f, 1.0f);
        """
    }

    private static func makeDctlDiffusionBlock(_ diffusion: DctlDiffusionParams) -> String {
        var lines: [String] = []
        var redTerms = ["(outR * \(dctlFloat(diffusion.centerWeight)))"]
        var greenTerms = ["(outG * \(dctlFloat(diffusion.centerWeight)))"]
        var blueTerms = ["(outB * \(dctlFloat(diffusion.centerWeight)))"]

        for (index, tapRadius) in diffusion.tapRadii.enumerated() {
            let groupWeight = diffusion.groupWeights[index]
            let axisWeight = groupWeight * 0.55 / 4
            let diagonalWeight = groupWeight * 0.45 / 4
            let prefix = "md\(index)"
            lines.append("""
            int \(prefix)Radius = \(tapRadius);
            int \(prefix)Lx = filmtone_clamp_int(p_X - \(prefix)Radius, 0, p_Width - 1);
            int \(prefix)Rx = filmtone_clamp_int(p_X + \(prefix)Radius, 0, p_Width - 1);
            int \(prefix)Uy = filmtone_clamp_int(p_Y - \(prefix)Radius, 0, p_Height - 1);
            int \(prefix)Dy = filmtone_clamp_int(p_Y + \(prefix)Radius, 0, p_Height - 1);
            float3 \(prefix)L = make_float3(_tex2D(p_TexR, \(prefix)Lx, p_Y), _tex2D(p_TexG, \(prefix)Lx, p_Y), _tex2D(p_TexB, \(prefix)Lx, p_Y));
            float3 \(prefix)R = make_float3(_tex2D(p_TexR, \(prefix)Rx, p_Y), _tex2D(p_TexG, \(prefix)Rx, p_Y), _tex2D(p_TexB, \(prefix)Rx, p_Y));
            float3 \(prefix)U = make_float3(_tex2D(p_TexR, p_X, \(prefix)Uy), _tex2D(p_TexG, p_X, \(prefix)Uy), _tex2D(p_TexB, p_X, \(prefix)Uy));
            float3 \(prefix)D = make_float3(_tex2D(p_TexR, p_X, \(prefix)Dy), _tex2D(p_TexG, p_X, \(prefix)Dy), _tex2D(p_TexB, p_X, \(prefix)Dy));
            float3 \(prefix)LU = make_float3(_tex2D(p_TexR, \(prefix)Lx, \(prefix)Uy), _tex2D(p_TexG, \(prefix)Lx, \(prefix)Uy), _tex2D(p_TexB, \(prefix)Lx, \(prefix)Uy));
            float3 \(prefix)RU = make_float3(_tex2D(p_TexR, \(prefix)Rx, \(prefix)Uy), _tex2D(p_TexG, \(prefix)Rx, \(prefix)Uy), _tex2D(p_TexB, \(prefix)Rx, \(prefix)Uy));
            float3 \(prefix)LD = make_float3(_tex2D(p_TexR, \(prefix)Lx, \(prefix)Dy), _tex2D(p_TexG, \(prefix)Lx, \(prefix)Dy), _tex2D(p_TexB, \(prefix)Lx, \(prefix)Dy));
            float3 \(prefix)RD = make_float3(_tex2D(p_TexR, \(prefix)Rx, \(prefix)Dy), _tex2D(p_TexG, \(prefix)Rx, \(prefix)Dy), _tex2D(p_TexB, \(prefix)Rx, \(prefix)Dy));
            \(prefix)L = APPLY_LUT(\(prefix)L.x, \(prefix)L.y, \(prefix)L.z, FilmtonePreOpticalColor);
            \(prefix)R = APPLY_LUT(\(prefix)R.x, \(prefix)R.y, \(prefix)R.z, FilmtonePreOpticalColor);
            \(prefix)U = APPLY_LUT(\(prefix)U.x, \(prefix)U.y, \(prefix)U.z, FilmtonePreOpticalColor);
            \(prefix)D = APPLY_LUT(\(prefix)D.x, \(prefix)D.y, \(prefix)D.z, FilmtonePreOpticalColor);
            \(prefix)LU = APPLY_LUT(\(prefix)LU.x, \(prefix)LU.y, \(prefix)LU.z, FilmtonePreOpticalColor);
            \(prefix)RU = APPLY_LUT(\(prefix)RU.x, \(prefix)RU.y, \(prefix)RU.z, FilmtonePreOpticalColor);
            \(prefix)LD = APPLY_LUT(\(prefix)LD.x, \(prefix)LD.y, \(prefix)LD.z, FilmtonePreOpticalColor);
            \(prefix)RD = APPLY_LUT(\(prefix)RD.x, \(prefix)RD.y, \(prefix)RD.z, FilmtonePreOpticalColor);
            """)
            redTerms.append(diffusionTerm(prefix: prefix, axisWeight: axisWeight, diagonalWeight: diagonalWeight, channel: "x"))
            greenTerms.append(diffusionTerm(prefix: prefix, axisWeight: axisWeight, diagonalWeight: diagonalWeight, channel: "y"))
            blueTerms.append(diffusionTerm(prefix: prefix, axisWeight: axisWeight, diagonalWeight: diagonalWeight, channel: "z"))
        }

        lines.append("""
            float diffR = \(redTerms.joined(separator: " + "));
            float diffG = \(greenTerms.joined(separator: " + "));
            float diffB = \(blueTerms.joined(separator: " + "));
            float diffSpatial = 1.0f - filmtone_smoothstep(\(dctlFloat(diffusion.maskStart)), \(dctlFloat(diffusion.maskEnd)), edgeR);
            float diffHeadroom = filmtone_glow_headroom(outR, outG, outB, 0.880000000f);
            float diffGlowR = filmtone_glow_shoulder(diffR * \(dctlFloat(diffusion.amount)) * diffSpatial) * diffHeadroom;
            float diffGlowG = filmtone_glow_shoulder(diffG * \(dctlFloat(diffusion.amount)) * diffSpatial) * diffHeadroom;
            float diffGlowB = filmtone_glow_shoulder(diffB * \(dctlFloat(diffusion.amount)) * diffSpatial) * diffHeadroom;
            outR = outR + _fminf(diffGlowR, _fmaxf(0.0f, 1.0f - outR));
            outG = outG + _fminf(diffGlowG, _fmaxf(0.0f, 1.0f - outG));
            outB = outB + _fminf(diffGlowB, _fmaxf(0.0f, 1.0f - outB));
        """)
        return lines.joined(separator: "\n")
    }

    private static func diffusionTerm(
        prefix: String,
        axisWeight: Double,
        diagonalWeight: Double,
        channel: String
    ) -> String {
        "(\(prefix)L.\(channel) * \(dctlFloat(axisWeight))) + (\(prefix)R.\(channel) * \(dctlFloat(axisWeight))) + (\(prefix)U.\(channel) * \(dctlFloat(axisWeight))) + (\(prefix)D.\(channel) * \(dctlFloat(axisWeight))) + (\(prefix)LU.\(channel) * \(dctlFloat(diagonalWeight))) + (\(prefix)RU.\(channel) * \(dctlFloat(diagonalWeight))) + (\(prefix)LD.\(channel) * \(dctlFloat(diagonalWeight))) + (\(prefix)RD.\(channel) * \(dctlFloat(diagonalWeight)))"
    }

    private static func makeDctlPreOpticalRgbShiftSample(
        xExpr: String,
        yExpr: String,
        rgbShiftMix: Double,
        sxVar: String,
        syVar: String,
        rxVar: String,
        ryVar: String,
        bxVar: String,
        byVar: String,
        centerVar: String,
        redVar: String,
        blueVar: String,
        outRVar: String,
        outGVar: String,
        outBVar: String
    ) -> String {
        let offset = dctlRgbShiftPixelOffset
        let shiftedMix = dctlFloat(rgbShiftMix)
        let centerMix = dctlFloat(1 - rgbShiftMix)
        return """
            int \(sxVar) = 0;
            int \(syVar) = 0;
            if (\(xExpr) > cx) { \(sxVar) = 1; }
            if (\(xExpr) < cx) { \(sxVar) = -1; }
            if (\(yExpr) > cy) { \(syVar) = 1; }
            if (\(yExpr) < cy) { \(syVar) = -1; }
            int \(rxVar) = filmtone_clamp_int(\(xExpr) + \(sxVar) * \(offset), 0, p_Width - 1);
            int \(ryVar) = filmtone_clamp_int(\(yExpr) + \(syVar) * \(offset), 0, p_Height - 1);
            int \(bxVar) = filmtone_clamp_int(\(xExpr) - \(sxVar) * \(offset), 0, p_Width - 1);
            int \(byVar) = filmtone_clamp_int(\(yExpr) - \(syVar) * \(offset), 0, p_Height - 1);
            float3 \(centerVar) = make_float3(_tex2D(p_TexR, \(xExpr), \(yExpr)), _tex2D(p_TexG, \(xExpr), \(yExpr)), _tex2D(p_TexB, \(xExpr), \(yExpr)));
            float3 \(redVar) = make_float3(_tex2D(p_TexR, \(rxVar), \(ryVar)), _tex2D(p_TexG, \(rxVar), \(ryVar)), _tex2D(p_TexB, \(rxVar), \(ryVar)));
            float3 \(blueVar) = make_float3(_tex2D(p_TexR, \(bxVar), \(byVar)), _tex2D(p_TexG, \(bxVar), \(byVar)), _tex2D(p_TexB, \(bxVar), \(byVar)));
            \(centerVar) = APPLY_LUT(\(centerVar).x, \(centerVar).y, \(centerVar).z, FilmtonePreOpticalColor);
            \(redVar) = APPLY_LUT(\(redVar).x, \(redVar).y, \(redVar).z, FilmtonePreOpticalColor);
            \(blueVar) = APPLY_LUT(\(blueVar).x, \(blueVar).y, \(blueVar).z, FilmtonePreOpticalColor);
            float \(outRVar) = \(centerVar).x * \(centerMix) + \(redVar).x * \(shiftedMix);
            float \(outGVar) = \(centerVar).y;
            float \(outBVar) = \(centerVar).z * \(centerMix) + \(blueVar).z * \(shiftedMix);
        """
    }

    private static func makeLegacyColorOnlyBridgeDctlText(cubeFilename: String) -> String {
        """
// \(defaultTitle)
// Generated by Filmtone iOS. Apply through Filmtone Connect package v2.
// This DCTL applies the package combined-color cube inside Resolve's documented
// LUT graph path. Non-cube optical/time effects remain explicit equivalence
// blockers until they are ported byte-for-byte from the iOS render pipeline.
DEFINE_LUT(FilmtoneCombinedColor, \(cubeFilename))

__DEVICE__ float filmtone_clamp(float v, float lo, float hi)
{
    return _fminf(_fmaxf(v, lo), hi);
}

__DEVICE__ float3 transform(int p_Width, int p_Height, int p_X, int p_Y, float p_R, float p_G, float p_B)
{
    float3 rgb = make_float3(p_R, p_G, p_B);
    rgb = APPLY_LUT(rgb.x, rgb.y, rgb.z, FilmtoneCombinedColor);
    return make_float3(
        filmtone_clamp(rgb.x, 0.0f, 1.0f),
        filmtone_clamp(rgb.y, 0.0f, 1.0f),
        filmtone_clamp(rgb.z, 0.0f, 1.0f)
    );
}
"""
    }

    private static func dctlFloat(_ value: Double) -> String {
        let finite = value.isFinite ? value : 0
        return String(
            format: "%.9ff",
            locale: Locale(identifier: "en_US_POSIX"),
            finite
        )
    }

    private static func dctlRgbShiftMix(for request: Phase0ExportRequestDTO) -> Double {
        let normalized = clamp(
            request.grade.params.rgbShift / dctlRgbShiftReferenceMax,
            min: 0,
            max: 1
        )
        let mix = normalized * dctlRgbShiftProbeMixAtMax
        return mix > dctlRgbShiftThreshold ? mix : 0
    }

    private static func dctlEdgeSoftnessParams(
        for request: Phase0ExportRequestDTO
    ) -> DctlEdgeSoftnessParams? {
        let params = request.grade.params
        let normalizedRgbShift = clamp(
            params.rgbShift / dctlRgbShiftReferenceMax,
            min: 0,
            max: 1
        )
        let aberrationSoften = dctlAberrationEdgeSoften(for: normalizedRgbShift)
        let lensSoftness = clamp(params.lensSoftness)
        guard aberrationSoften > dctlEdgeSoftnessThreshold || lensSoftness > dctlEdgeSoftnessThreshold else {
            return nil
        }

        let lensDrive = pow(lensSoftness, 0.78)
        let aberrationDrive = pow(
            clamp(aberrationSoften / dctlAberrationEdgeSoftenMax),
            0.82
        )
        let blurRadius = min(
            lerp(
                dctlAberrationBlurRadiusMin,
                dctlAberrationBlurRadiusMax,
                aberrationDrive
            ) + (lensDrive * dctlLensSoftnessBlurBoost),
            dctlAberrationBlurRadiusCap
        )
        let tapRadius = max(1, min(7, Int(blurRadius.rounded())))
        return DctlEdgeSoftnessParams(
            aberrationSoften: aberrationSoften,
            lensDrive: lensDrive,
            tapRadius: tapRadius
        )
    }

    private static func dctlAberrationEdgeSoften(for normalizedRgbShift: Double) -> Double {
        let normalized = clamp(normalizedRgbShift)
        guard normalized > dctlEdgeSoftnessThreshold else {
            return 0
        }

        let linear = normalized * (dctlAberrationEdgeSoftenScale * dctlRgbShiftReferenceMax)
        let boosted = pow(normalized, dctlAberrationEdgeSoftenCurve) * dctlAberrationEdgeSoftenMax
        return min(dctlAberrationEdgeSoftenMax, max(linear, boosted))
    }

    private static func dctlDiffusionParams(
        for request: Phase0ExportRequestDTO
    ) -> DctlDiffusionParams? {
        let diffusion = clamp(request.grade.params.diffusion)
        guard diffusion > dctlDiffusionThreshold else {
            return nil
        }

        return DctlDiffusionParams(
            amount: diffusion * dctlDiffusionAmountScale * dctlDiffusionCompositeBase,
            tapRadii: dctlDiffusionMipTapRadii,
            groupWeights: dctlDiffusionMipGroupWeights,
            centerWeight: dctlDiffusionCenterWeight,
            maskStart: dctlDiffusionCenterMaskStart,
            maskEnd: dctlDiffusionCenterMaskEnd
        )
    }

    private static func dctlResolveTextureCalibration(
        for request: Phase0ExportRequestDTO
    ) -> DctlColorCalibration {
        if request.sourceProbe?.sourceVideoMetadata?.colorClass == .hdrHlg {
            // Resolve's HLG texture decode lands warmer/brighter than the
            // Core Image tone-map path. These channel gains are verified
            // against the C0061 HLG package probe and are scoped to HLG only.
            return DctlColorCalibration(
                redGain: 0.92000000,
                greenGain: 0.88300000,
                blueGain: 0.92400000,
                redOffset: 0,
                greenOffset: 0,
                blueOffset: 0
            )
        }

        switch request.sourceProbe?.inputTransformPolicy?.strategy {
        case .appleLogToRec709, .appleLog2ToRec709:
            // Resolve's DCTL texture path does not exactly match the Core Image
            // sample path used by the iOS export for Apple Log sources. The
            // affine calibration is intentionally scoped to the Apple Log bridge
            // and is measured against the real C052 package reference frame.
            return DctlColorCalibration(
                redGain: 0.49998965,
                greenGain: 0.52846118,
                blueGain: 0.51499777,
                redOffset: 0.46939863,
                greenOffset: 0.38849754,
                blueOffset: 0.36848030
            )
        default:
            return DctlColorCalibration(
                redGain: 1,
                greenGain: 1,
                blueGain: 1,
                redOffset: 0,
                greenOffset: 0,
                blueOffset: 0
            )
        }
    }

    private static func clamp(_ value: Double, min minValue: Double = 0, max maxValue: Double = 1) -> Double {
        min(max(value, minValue), maxValue)
    }

    private static func lerp(_ start: Double, _ end: Double, _ amount: Double) -> Double {
        start + ((end - start) * amount)
    }
}
