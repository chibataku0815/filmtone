import Foundation

struct FilmtoneQuickState: Codable, Equatable {
    var filmCharacter: Double
    var era: Double
    var dynamics: Double

    static let zero = FilmtoneQuickState(filmCharacter: 0, era: 0, dynamics: 0)

    func clamped() -> FilmtoneQuickState {
        .init(
            filmCharacter: Self.clampAxis(filmCharacter),
            era: Self.clampAxis(era),
            dynamics: Self.clampAxis(dynamics)
        )
    }

    private static func clampAxis(_ value: Double) -> Double {
        max(-1, min(1, value))
    }
}

struct FilmtonePhase0Params: Codable, Equatable {
    var exposure: Double
    var contrast: Double
    var saturation: Double
    var temperature: Double
    var tint: Double
    var fade: Double
    var vignette: Double
    var grainIntensity: Double

    static let reset = FilmtonePhase0Params(
        exposure: 0,
        contrast: 1,
        saturation: 1,
        temperature: 0,
        tint: 0,
        fade: 0,
        vignette: 0,
        grainIntensity: 0
    )

    func asDTO() -> Phase0ParamsDTO {
        .init(
            exposure: exposure,
            contrast: contrast,
            saturation: saturation,
            temperature: temperature,
            tint: tint,
            fade: fade,
            vignette: vignette,
            grainIntensity: grainIntensity
        )
    }
}

struct FilmtoneProjectState: Codable {
    var schemaVersion: Int
    var projectId: String
    var createdAt: String
    var updatedAt: String
    var presetName: String
    var strength: Double
    var quickState: FilmtoneQuickState
    var params: FilmtonePhase0Params
    var inputLut: ParsedCubeLutDTO?
    var creativeLut: ParsedCubeLutDTO?
    var output: Phase0OutputProfileDTO

    init(
        schemaVersion: Int = FilmtonePhase0Math.projectSchemaVersion,
        projectId: String,
        createdAt: String,
        updatedAt: String,
        presetName: String,
        strength: Double,
        quickState: FilmtoneQuickState,
        params: FilmtonePhase0Params,
        inputLut: ParsedCubeLutDTO?,
        creativeLut: ParsedCubeLutDTO?,
        output: Phase0OutputProfileDTO
    ) {
        self.schemaVersion = schemaVersion
        self.projectId = projectId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.presetName = presetName
        self.strength = strength
        self.quickState = quickState
        self.params = params
        self.inputLut = inputLut
        self.creativeLut = creativeLut
        self.output = output
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case projectId
        case createdAt
        case updatedAt
        case presetName
        case strength
        case quickState
        case params
        case lut
        case inputLut
        case creativeLut
        case output
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? FilmtonePhase0Math.projectSchemaVersion
        projectId = try container.decode(String.self, forKey: .projectId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        presetName = try container.decode(String.self, forKey: .presetName)
        strength = try container.decodeIfPresent(Double.self, forKey: .strength) ?? FilmtonePhase0Math.presetStrengthDefault
        quickState = (try container.decodeIfPresent(FilmtoneQuickState.self, forKey: .quickState) ?? .zero).clamped()
        params = try container.decode(FilmtonePhase0Params.self, forKey: .params)
        inputLut = try container.decodeIfPresent(ParsedCubeLutDTO.self, forKey: .inputLut)
        let legacyLut = try container.decodeIfPresent(ParsedCubeLutDTO.self, forKey: .lut)
        creativeLut = try container.decodeIfPresent(ParsedCubeLutDTO.self, forKey: .creativeLut) ?? legacyLut
        output = try container.decodeIfPresent(Phase0OutputProfileDTO.self, forKey: .output) ?? FilmtonePhase0Math.outputProfile
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(presetName, forKey: .presetName)
        try container.encode(strength, forKey: .strength)
        try container.encode(quickState, forKey: .quickState)
        try container.encode(params, forKey: .params)
        try container.encodeIfPresent(inputLut, forKey: .inputLut)
        try container.encodeIfPresent(creativeLut, forKey: .creativeLut)
        try container.encode(output, forKey: .output)
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
    static let projectSchemaVersion = 1
    static let presetVersion = "v1"
    static let presetStrengthDefault = 1.0
    static let sourceDurationCapSec = 300.0
    static let sourceLongEdgeCap = 3840
    static let sourceFileSizeCapBytes = 2 * 1024 * 1024 * 1024
    static let previewRenderDebounceNanoseconds: UInt64 = 120_000_000

    static let outputProfile = Phase0OutputProfileDTO(
        longEdge: 1920,
        fps: 30,
        codec: "h264",
        container: "mp4",
        preserveAudio: true
    )

    static func createProjectState(presetName: String = "cinematic") -> FilmtoneProjectState {
        let now = isoTimestamp()
        let safePresetName = FilmtonePresetCatalog.paramsByName[presetName] == nil ? "cinematic" : presetName
        return FilmtoneProjectState(
            projectId: UUID().uuidString.lowercased(),
            createdAt: now,
            updatedAt: now,
            presetName: safePresetName,
            strength: presetStrengthDefault,
            quickState: .zero,
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

    static func deriveParams(
        presetName: String,
        strength: Double,
        quickState: FilmtoneQuickState
    ) -> FilmtonePhase0Params {
        let base = interpolatePresetParams(presetName: presetName, strength: strength)
        return applyQuickState(to: base, quickState: quickState)
    }

    static func interpolatePresetParams(
        presetName: String,
        strength: Double
    ) -> FilmtonePhase0Params {
        let target = FilmtonePresetCatalog.paramsByName[presetName] ?? .reset
        let reset = FilmtonePhase0Params.reset
        let clampedStrength = clampStrength(strength)
        return .init(
            exposure: reset.exposure + (target.exposure - reset.exposure) * clampedStrength,
            contrast: reset.contrast + (target.contrast - reset.contrast) * clampedStrength,
            saturation: reset.saturation + (target.saturation - reset.saturation) * clampedStrength,
            temperature: reset.temperature + (target.temperature - reset.temperature) * clampedStrength,
            tint: reset.tint + (target.tint - reset.tint) * clampedStrength,
            fade: reset.fade + (target.fade - reset.fade) * clampedStrength,
            vignette: reset.vignette + (target.vignette - reset.vignette) * clampedStrength,
            grainIntensity: reset.grainIntensity + (target.grainIntensity - reset.grainIntensity) * clampedStrength
        )
    }

    static func applyQuickState(
        to base: FilmtonePhase0Params,
        quickState: FilmtoneQuickState
    ) -> FilmtonePhase0Params {
        let quick = quickState.clamped()
        return .init(
            exposure: clampParam("exposure", base.exposure + quick.dynamics * 0.24),
            contrast: clampParam("contrast", base.contrast + quick.era * -0.06 + quick.dynamics * 0.18),
            saturation: clampParam("saturation", base.saturation + quick.filmCharacter * 0.24 + quick.era * -0.12),
            temperature: clampParam("temperature", base.temperature + quick.filmCharacter * 0.16),
            tint: clampParam("tint", base.tint + quick.filmCharacter * -0.06),
            fade: clampParam("fade", base.fade + quick.era * 0.18),
            vignette: clampParam("vignette", base.vignette + quick.filmCharacter * 0.12),
            grainIntensity: clampParam("grainIntensity", base.grainIntensity + quick.filmCharacter * 0.22)
        )
    }

    static func sourceCapViolations(for probe: SourceProbeDTO?) -> [String] {
        guard let probe else {
            return []
        }

        var violations: [String] = []
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

        if let fileSizeBytes = probe.fileSizeBytes, fileSizeBytes > sourceFileSizeCapBytes {
            violations.append(
                "Source size \(fileSizeBytes) bytes exceeds \(sourceFileSizeCapBytes) bytes"
            )
        }

        return violations
    }

    static func buildExportRequest(
        source: SourceInfoDTO?,
        probe: SourceProbeDTO?,
        project: FilmtoneProjectState
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
                presetVersion: presetVersion,
                quickState: .init(
                    filmCharacter: project.quickState.filmCharacter,
                    era: project.quickState.era,
                    dynamics: project.quickState.dynamics
                ),
                params: project.params.asDTO()
            ),
            lut: nil,
            inputLut: transportLut(project.inputLut),
            creativeLut: transportLut(project.creativeLut)
        )
    }

    static func isoTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func transportLut(_ lut: ParsedCubeLutDTO?) -> SerializableLutDTO? {
        guard let lut else {
            return nil
        }
        return .init(size: lut.size, data: lut.data, intensity: lut.intensity)
    }

    private static func clampParam(_ key: String, _ value: Double) -> Double {
        switch key {
        case "exposure":
            return max(-2, min(2, value))
        case "contrast", "saturation":
            return max(0, min(2, value))
        case "temperature", "tint":
            return max(-1, min(1, value))
        case "fade", "vignette", "grainIntensity":
            return max(0, min(1, value))
        default:
            return value
        }
    }
}
