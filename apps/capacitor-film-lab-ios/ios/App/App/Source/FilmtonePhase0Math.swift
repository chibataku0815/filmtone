import Foundation
import FilmLabSwiftCore

// FilmtoneQuickState / FilmtonePhase0Params / FilmtonePhase0ParamsPatch /
// FilmtonePhase0HiddenDefaults はすべて FilmLabSwiftCore (M4-B Phase 2/3) に
// 集約済み。iOS-only な normalizer / DTO bridge / optics-glow ヘルパーだけ
// extension としてここに残す。

extension FilmtonePhase0Params {
    func asDTO() -> Phase0ParamsDTO {
        .init(
            exposure: exposure,
            contrast: contrast,
            saturation: saturation,
            temperature: temperature,
            tint: tint,
            rgbShift: rgbShift,
            lensSoftness: lensSoftness,
            detailSoftness: detailSoftness,
            grainRadialMix: grainRadialMix,
            grainSize: grainSize,
            bloomThreshold: bloomThreshold,
            bloomStrength: bloomStrength,
            bloomRadius: bloomRadius,
            diffusion: diffusion,
            halationIntensity: halationIntensity,
            halationSpread: halationSpread,
            halationHue: halationHue,
            halationThreshold: halationThreshold,
            halationRadius: halationRadius,
            bloomSoftKnee: bloomSoftKnee,
            halationSoftKnee: halationSoftKnee,
            compressionAmount: compressionAmount,
            compressionRange: compressionRange,
            printContrast: printContrast,
            cyan: cyan,
            magenta: magenta,
            yellow: yellow,
            shutterAngle: shutterAngle,
            trailIntensity: trailIntensity,
            fade: fade,
            shadowTone: shadowTone,
            shadowLatitude: shadowLatitude,
            highlightTone: highlightTone,
            shadowHue: shadowHue,
            highlightHue: highlightHue,
            vignette: vignette,
            grainIntensity: grainIntensity
        )
    }
}

extension FilmtonePhase0ParamsPatch {
    func normalized(over base: FilmtonePhase0Params) -> FilmtonePhase0ParamsPatch {
        var normalized: [String: Double] = [:]

        for key in FilmtonePhase0Generated.paramKeys {
            guard let value = values[key] else {
                continue
            }

            let clampedValue = FilmtonePhase0Math.clampParam(key, value)
            if abs(clampedValue - base.value(for: key)) >= FilmtonePhase0Math.paramEqualityTolerance {
                normalized[key] = clampedValue
            }
        }

        return .init(values: normalized)
    }

    func settingValue(
        _ value: Double,
        for key: String,
        over base: FilmtonePhase0Params
    ) -> FilmtonePhase0ParamsPatch {
        var next = values
        let clampedValue = FilmtonePhase0Math.clampParam(key, value)

        if abs(clampedValue - base.value(for: key)) < FilmtonePhase0Math.paramEqualityTolerance {
            next.removeValue(forKey: key)
        } else {
            next[key] = clampedValue
        }

        return .init(values: next)
    }

    /// Like `normalized(over:)` but preserves optics + glow keys verbatim
    /// even when their value matches the baseline. Used at Look apply time
    /// so a Look's optical signature stays explicit in `paramOverrides`,
    /// surfacing it through Adjust-sheet UI signals (`hasAdvancedAdjustments`,
    /// disclosure auto-expand, per-group "Custom" status).
    func normalizedPreservingOpticsGlow(over base: FilmtonePhase0Params) -> FilmtonePhase0ParamsPatch {
        let opticsGlow = Set(Self.opticsGlowKeys)
        var next: [String: Double] = [:]
        for key in FilmtonePhase0Generated.paramKeys {
            guard let value = values[key] else { continue }
            let clampedValue = FilmtonePhase0Math.clampParam(key, value)
            let differsFromBase = abs(clampedValue - base.value(for: key)) >= FilmtonePhase0Math.paramEqualityTolerance
            if opticsGlow.contains(key) || differsFromBase {
                next[key] = clampedValue
            }
        }
        return .init(values: next)
    }
}

struct FilmtoneProjectState: Codable {
    var schemaVersion: Int
    var projectId: String
    var createdAt: String
    var updatedAt: String
    var presetName: String
    /// v1.4 Look V2 — kernel preset version that the export pipeline must use
    /// for THIS project (NOT the global `FilmtonePhase0Math.presetVersion`).
    /// Apply path: a v1 saved Look stamps "v1" here so it keeps rendering
    /// through the v1 kernel even after the iOS preset bumps to v2 globally.
    /// Fresh projects default to the current `FilmtonePhase0Math.presetVersion`.
    var presetVersion: String
    var strength: Double
    var quickState: FilmtoneQuickState
    var paramOverrides: FilmtonePhase0ParamsPatch
    var params: FilmtonePhase0Params
    var inputLut: ParsedCubeLutDTO?
    var creativeLut: ParsedCubeLutDTO?
    var output: Phase0OutputProfileDTO
    /// v1.3 Camera Profiles Phase A — selected source profile. Defaults to
    /// `.auto` for v1.2 saves (decoded via `decodeIfPresent ?? .auto`) and
    /// for fresh projects so existing behavior is byte-identical until the
    /// user picks a Camera Profile from the new picker (Phase F).
    var cameraProfile: CameraProfileSelection
    /// v1.4 Backlight Veil — active optical filter profile id, or nil = OFF.
    /// Stored in the project so Look + Veil survives preview/export request
    /// rebuilds instead of relying on process-global render state.
    var opticalFilterProfileId: String?

    init(
        schemaVersion: Int = FilmtonePhase0Math.projectSchemaVersion,
        projectId: String,
        createdAt: String,
        updatedAt: String,
        presetName: String,
        presetVersion: String = FilmtonePhase0Math.presetVersion,
        strength: Double,
        quickState: FilmtoneQuickState,
        paramOverrides: FilmtonePhase0ParamsPatch = .empty,
        params: FilmtonePhase0Params,
        inputLut: ParsedCubeLutDTO?,
        creativeLut: ParsedCubeLutDTO?,
        output: Phase0OutputProfileDTO,
        cameraProfile: CameraProfileSelection = .auto,
        opticalFilterProfileId: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.projectId = projectId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.presetName = presetName
        self.presetVersion = presetVersion
        self.strength = strength
        self.quickState = quickState
        self.paramOverrides = paramOverrides
        self.params = params
        self.inputLut = inputLut
        self.creativeLut = creativeLut
        self.output = output
        self.cameraProfile = cameraProfile
        self.opticalFilterProfileId = opticalFilterProfileId
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case projectId
        case createdAt
        case updatedAt
        case presetName
        case presetVersion
        case strength
        case quickState
        case params
        case lut
        case inputLut
        case creativeLut
        case output
        case cameraProfile
        case opticalFilterProfileId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? FilmtonePhase0Math.projectSchemaVersion
        projectId = try container.decode(String.self, forKey: .projectId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)

        let decodedPresetName = try container.decode(String.self, forKey: .presetName)
        presetName = FilmtonePhase0Math.safePresetName(decodedPresetName)
        // v1.4 — v1.3 saves (without `presetVersion`) decode as the current
        // global IOS_PRESET_VERSION ("v2"). v1.x saved Looks that round-trip
        // through `applySavedLook` will overwrite this from the SavedLookEntry.
        presetVersion = try container.decodeIfPresent(String.self, forKey: .presetVersion)
            ?? FilmtonePhase0Math.presetVersion
        strength = try container.decodeIfPresent(Double.self, forKey: .strength) ?? FilmtonePhase0Math.presetStrengthDefault
        quickState = (try container.decodeIfPresent(FilmtoneQuickState.self, forKey: .quickState) ?? .zero).clamped()

        let derivedParams = FilmtonePhase0Math.deriveParams(
            presetName: presetName,
            strength: strength,
            quickState: quickState
        )
        let decodedPatch = try container.decodeIfPresent(FilmtonePhase0ParamsPatch.self, forKey: .params) ?? .empty
        paramOverrides = decodedPatch.normalized(over: derivedParams)
        params = derivedParams.applyingPatch(paramOverrides)

        inputLut = try container.decodeIfPresent(ParsedCubeLutDTO.self, forKey: .inputLut)
        let legacyLut = try container.decodeIfPresent(ParsedCubeLutDTO.self, forKey: .lut)
        creativeLut = try container.decodeIfPresent(ParsedCubeLutDTO.self, forKey: .creativeLut) ?? legacyLut
        output = try container.decodeIfPresent(Phase0OutputProfileDTO.self, forKey: .output) ?? FilmtonePhase0Math.outputProfile
        // v1.3 Camera Profiles Phase A — additive optional. v1.2 saves
        // (without this key) decode as `.auto`, preserving prior behavior.
        cameraProfile = try container.decodeIfPresent(CameraProfileSelection.self, forKey: .cameraProfile) ?? .auto
        // v1.4 Backlight Veil — additive optional. Older saves decode as OFF.
        opticalFilterProfileId = try container.decodeIfPresent(String.self, forKey: .opticalFilterProfileId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(presetName, forKey: .presetName)
        try container.encode(presetVersion, forKey: .presetVersion)
        try container.encode(strength, forKey: .strength)
        try container.encode(quickState, forKey: .quickState)
        try container.encode(paramOverrides, forKey: .params)
        try container.encodeIfPresent(inputLut, forKey: .inputLut)
        try container.encodeIfPresent(creativeLut, forKey: .creativeLut)
        try container.encode(output, forKey: .output)
        try container.encode(cameraProfile, forKey: .cameraProfile)
        try container.encodeIfPresent(opticalFilterProfileId, forKey: .opticalFilterProfileId)
    }
}

enum FilmtoneRequestBuildError: LocalizedError {
    case missingSource
    case sourceCaps([String])

    var errorDescription: String? {
        switch self {
        case .missingSource:
            return "A source must be selected before building an export request."
        case .sourceCaps(let violations):
            return violations.joined(separator: "\n")
        }
    }
}

enum FilmtonePhase0Math {
    static let rgbShiftMax = FilmtonePhase0Generated.rgbShiftMax
    static let projectSchemaVersion = FilmtonePhase0Generated.schemaVersion
    static let presetVersion = FilmtonePhase0Generated.presetVersion
    static let presetStrengthDefault = FilmtonePhase0Generated.presetStrengthDefault
    static let sourceDurationCapSec = FilmtonePhase0Generated.sourceDurationCapSec
    static let sourceLongEdgeCap = FilmtonePhase0Generated.sourceLongEdgeCap
    static let sourceFileSizeCapBytes = FilmtonePhase0Generated.sourceFileSizeCapBytes
    static let previewRenderDebounceNanoseconds: UInt64 = 120_000_000
    static let paramEqualityTolerance = 0.0001

    static let outputProfile = FilmtonePhase0Generated.outputProfile

    static func safePresetName(_ presetName: String) -> String {
        if FilmtonePhase0Generated.paramsByName[presetName] != nil {
            return presetName
        }

        switch presetName {
        case "pro400h", "superia400":
            return "softBlue"
        case "gold200", "cinestill800t", "velvia50":
            return "amberGlow"
        case "portra", "ektar100", "cinematic":
            return "iphone"
        case "bw":
            return FilmtonePhase0Generated.presetDefault
        default:
            return FilmtonePhase0Generated.presetDefault
        }
    }

    static func createProjectState(presetName: String = FilmtonePhase0Generated.presetDefault) -> FilmtoneProjectState {
        let now = isoTimestamp()
        let safePresetName = safePresetName(presetName)
        return FilmtoneProjectState(
            projectId: UUID().uuidString.lowercased(),
            createdAt: now,
            updatedAt: now,
            presetName: safePresetName,
            strength: presetStrengthDefault,
            quickState: .zero,
            paramOverrides: .empty,
            params: deriveParams(
                presetName: safePresetName,
                strength: presetStrengthDefault,
                quickState: .zero
            ),
            inputLut: nil,
            creativeLut: nil,
            output: outputProfile
        )
    }

    static func clampStrength(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    static func clampLutIntensity(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    static func deriveParams(
        presetName: String,
        strength: Double,
        quickState: FilmtoneQuickState
    ) -> FilmtonePhase0Params {
        let base = interpolatePresetParams(presetName: presetName, strength: strength)
        return applyQuickState(to: base, quickState: quickState)
    }

    static func resolveParams(
        presetName: String,
        strength: Double,
        quickState: FilmtoneQuickState,
        paramOverrides: FilmtonePhase0ParamsPatch
    ) -> (base: FilmtonePhase0Params, overrides: FilmtonePhase0ParamsPatch, effective: FilmtonePhase0Params) {
        let base = deriveParams(
            presetName: presetName,
            strength: strength,
            quickState: quickState
        )
        let normalizedOverrides = paramOverrides.normalized(over: base)
        return (
            base,
            normalizedOverrides,
            base.applyingPatch(normalizedOverrides)
        )
    }

    static func interpolatePresetParams(
        presetName: String,
        strength: Double
    ) -> FilmtonePhase0Params {
        let target = FilmtonePhase0Generated.paramsByName[safePresetName(presetName)] ?? .reset
        let reset = FilmtonePhase0Params.reset
        let clampedStrength = clampStrength(strength)
        var next = reset

        for key in FilmtonePhase0Generated.paramKeys {
            let interpolated = reset.value(for: key) + (target.value(for: key) - reset.value(for: key)) * clampedStrength
            next.setValue(interpolated, for: key)
        }

        return next
    }

    static func applyQuickState(
        to base: FilmtonePhase0Params,
        quickState: FilmtoneQuickState
    ) -> FilmtonePhase0Params {
        let quick = quickState.clamped()
        var next = base

        for axis in FilmtonePhase0Generated.quickAxisIds {
            let axisValue = quick.value(forAxis: axis)
            guard let weights = FilmtonePhase0Generated.quickWeights[axis] else {
                continue
            }

            for (key, weight) in weights {
                let nextValue = clampParam(key, next.value(for: key) + axisValue * weight)
                next.setValue(nextValue, for: key)
            }
        }

        return next
    }

    static func sourceCapViolations(for probe: SourceProbeDTO?) -> [String] {
        guard let probe else {
            return []
        }

        var violations: [String] = []
        if let compatibilityViolation = sourceCompatibilityViolation(for: probe) {
            violations.append(compatibilityViolation)
        }

        if let durationSec = probe.durationSec, durationSec > sourceDurationCapSec {
            violations.append(
                "Source duration \(String(format: "%.1f", durationSec))s exceeds \(Int(sourceDurationCapSec))s"
            )
        }

        if let width = probe.width, let height = probe.height, max(width, height) > sourceLongEdgeCap {
            violations.append(
                "Source long edge \(max(width, height))px exceeds \(sourceLongEdgeCap)px"
            )
        }

        return violations
    }

    private static func sourceCompatibilityViolation(for probe: SourceProbeDTO) -> String? {
        guard probe.kind == .video else {
            return nil
        }

        if probe.codecFamily == .proresRaw ||
            probe.inputTransformPolicy?.strategy == .unsupported ||
            probe.sourceVideoMetadata?.inputTransformPolicy?.strategy == .unsupported
        {
            return "ProRes RAW is not supported in this version. Use standard ProRes 422, H.264, or HEVC."
        }

        switch normalizedSourceCodec(probe.codec) {
        case "aprn", "aprh":
            return "ProRes RAW is not supported in this version. Use standard ProRes 422, H.264, or HEVC."
        case "avdh":
            return "Avid DNxHR / DNxHD video can't be previewed or exported on iPhone. Convert this file to H.264, HEVC, or ProRes first."
        default:
            return nil
        }
    }

    private static func normalizedSourceCodec(_ codec: String?) -> String {
        codec?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    static func buildExportRequest(
        source: SourceInfoDTO?,
        probe: SourceProbeDTO?,
        project: FilmtoneProjectState,
        videoTimingMode: FilmtoneVideoTimingMode = .normal
    ) throws -> Phase0ExportRequestDTO {
        guard let source else {
            throw FilmtoneRequestBuildError.missingSource
        }

        let violations = sourceCapViolations(for: probe)
        if !violations.isEmpty {
            throw FilmtoneRequestBuildError.sourceCaps(violations)
        }

        return Phase0ExportRequestDTO(
            sourceUri: source.uri,
            sourceKind: source.kind,
            sourceProbe: probe,
            output: project.output,
            grade: Phase0GradeDTO(
                presetName: project.presetName,
                presetVersion: project.presetVersion,
                quickState: .init(
                    filmCharacter: project.quickState.filmCharacter,
                    era: project.quickState.era,
                    dynamics: project.quickState.dynamics
                ),
                params: project.params.asDTO()
            ),
            lut: nil,
            inputLut: transportLut(project.inputLut),
            creativeLut: transportLut(project.creativeLut),
            renderMode: nil,
            // v1.3 (D3.1): depth opt-in defaults to nil here; the WebView feature
            // flag (Stream 4, deferred) is the only path that surfaces depthEnabled
            // = true. Native callers that pre-date Stream 4 stay on the v1.2-
            // identical depth-off path.
            depthEnabled: nil,
            depthRenderer: nil,
            opticalFilterProfileId: project.opticalFilterProfileId,
            videoTimingMode: videoTimingMode
            // v1.3 Camera Profiles Phase E: cameraProfile travels OUTSIDE
            // the wire DTO (separate parameter on facade.runExport(...))
            // because it's iOS-internal state — not a value the JS bridge
            // needs to round-trip. Keeping it off the Codable DTO sidesteps
            // a Swift Codable synthesis edge case across the standalone
            // contract-test stub graph.
        )
    }

    static func isoTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func transportLut(_ lut: ParsedCubeLutDTO?) -> SerializableLutDTO? {
        guard let lut else {
            return nil
        }
        return .init(
            size: lut.size,
            data: lut.data,
            intensity: lut.intensity,
            bundledSlug: lut.bundledSlug,
            bundledPackId: lut.bundledPackId
        )
    }

    static func clampParam(_ key: String, _ value: Double) -> Double {
        switch key {
        case "exposure":
            return max(-2, min(2, value))
        case "contrast", "saturation":
            return max(0, min(2, value))
        case "temperature", "tint":
            return max(-1, min(1, value))
        case "cyan", "magenta", "yellow":
            return max(-1, min(1, value))
        case "halationSpread":
            return max(0, min(40, value))
        case "halationHue":
            return max(0, min(100, value))
        case "shutterAngle":
            let clamped = max(0, min(720, value))
            return clamped < 90 ? 0 : max(180, clamped)
        case "trailIntensity":
            return max(0, min(0.95, value))
        case "rgbShift":
            return max(0, min(rgbShiftMax, value))
        case "grainIntensity":
            return max(0, min(FilmtonePhase0Generated.grainIntensityMax, value))
        case "lensSoftness",
             "detailSoftness",
             "shadowLatitude",
             "grainRadialMix",
             "grainSize",
             "bloomThreshold",
             "bloomStrength",
             "bloomRadius",
             "diffusion",
             "halationIntensity",
             "halationThreshold",
             "halationRadius",
             "bloomSoftKnee",
             "halationSoftKnee",
             "compressionAmount",
             "compressionRange",
             "printContrast",
             "fade",
             "vignette":
            return max(0, min(1, value))
        default:
            return value
        }
    }
}
