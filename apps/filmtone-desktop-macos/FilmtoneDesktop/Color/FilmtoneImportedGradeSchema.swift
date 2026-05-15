import Foundation

enum FilmtoneImportedGradeConstants {
    static let schemaId = "filmtone-imported-grade-v1"
    static let schemaVersion = 1
}

struct FilmtoneImportedGradeControl: Codable, Equatable, Sendable {
    enum Slot: String, Codable, Sendable {
        case preLut
        case postLut
    }

    let id: String
    let slot: Slot
    let operation: String
    let paramKey: String?
    let label: String
    let defaultValue: Double
    let min: Double
    let max: Double

    func clamped(_ value: Double?) -> Double {
        let candidate = value ?? defaultValue
        if !candidate.isFinite { return defaultValue }
        return Swift.max(min, Swift.min(max, candidate))
    }
}

struct FilmtoneImportedGradeLook: Codable, Equatable, Sendable {
    enum Source: Codable, Equatable, Sendable {
        case davinciPowerGradePackage(packagePath: String?)
        case davinciDrx(drxPath: String?)
        case cubeOnly(packagePath: String?)

        private enum CodingKeys: String, CodingKey {
            case kind, packagePath, drxPath
        }

        private enum Kind: String, Codable {
            case davinciPowerGradePackage = "davinci-powergrade-package"
            case davinciDrx = "davinci-drx"
            case cubeOnly = "cube-only"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            switch try c.decode(Kind.self, forKey: .kind) {
            case .davinciPowerGradePackage:
                self = .davinciPowerGradePackage(packagePath: try c.decodeIfPresent(String.self, forKey: .packagePath))
            case .davinciDrx:
                self = .davinciDrx(drxPath: try c.decodeIfPresent(String.self, forKey: .drxPath))
            case .cubeOnly:
                self = .cubeOnly(packagePath: try c.decodeIfPresent(String.self, forKey: .packagePath))
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .davinciPowerGradePackage(let packagePath):
                try c.encode(Kind.davinciPowerGradePackage, forKey: .kind)
                try c.encodeIfPresent(packagePath, forKey: .packagePath)
            case .davinciDrx(let drxPath):
                try c.encode(Kind.davinciDrx, forKey: .kind)
                try c.encodeIfPresent(drxPath, forKey: .drxPath)
            case .cubeOnly(let packagePath):
                try c.encode(Kind.cubeOnly, forKey: .kind)
                try c.encodeIfPresent(packagePath, forKey: .packagePath)
            }
        }

        var sourceKindLabel: String {
            switch self {
            case .davinciPowerGradePackage: return "davinci-powergrade-package"
            case .davinciDrx: return "davinci-drx"
            case .cubeOnly: return "cube-only"
            }
        }
    }

    enum BaseLook: Codable, Equatable, Sendable {
        case none
        case cube(path: String, size: Int, intensity: Double, sourceHash: String?)

        private enum CodingKeys: String, CodingKey {
            case kind, path, size, intensity, sourceHash
        }

        private enum Kind: String, Codable {
            case none
            case cube
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            switch try c.decode(Kind.self, forKey: .kind) {
            case .none:
                self = .none
            case .cube:
                self = .cube(
                    path: try c.decode(String.self, forKey: .path),
                    size: try c.decode(Int.self, forKey: .size),
                    intensity: try c.decodeIfPresent(Double.self, forKey: .intensity) ?? 1.0,
                    sourceHash: try c.decodeIfPresent(String.self, forKey: .sourceHash)
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .none:
                try c.encode(Kind.none, forKey: .kind)
            case .cube(let path, let size, let intensity, let sourceHash):
                try c.encode(Kind.cube, forKey: .kind)
                try c.encode(path, forKey: .path)
                try c.encode(size, forKey: .size)
                try c.encode(intensity, forKey: .intensity)
                try c.encodeIfPresent(sourceHash, forKey: .sourceHash)
            }
        }
    }

    let schemaId: String
    let schemaVersion: Int
    let id: UUID
    let title: String
    let source: Source
    let baseLook: BaseLook
    let preLutControls: [FilmtoneImportedGradeControl]
    let postLutControls: [FilmtoneImportedGradeControl]
    let sourceGraph: FilmtoneImportedGradeSourceGraph?
    let unsupportedMetadata: [String]

    init(
        schemaId: String = FilmtoneImportedGradeConstants.schemaId,
        schemaVersion: Int = FilmtoneImportedGradeConstants.schemaVersion,
        id: UUID,
        title: String,
        source: Source,
        baseLook: BaseLook,
        preLutControls: [FilmtoneImportedGradeControl] = [],
        postLutControls: [FilmtoneImportedGradeControl] = [],
        sourceGraph: FilmtoneImportedGradeSourceGraph? = nil,
        unsupportedMetadata: [String] = []
    ) {
        self.schemaId = schemaId
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.source = source
        self.baseLook = baseLook
        self.preLutControls = preLutControls
        self.postLutControls = postLutControls
        self.sourceGraph = sourceGraph
        self.unsupportedMetadata = unsupportedMetadata
    }

    func validate() throws {
        guard schemaId == FilmtoneImportedGradeConstants.schemaId else {
            throw ValidationError.schemaId(schemaId)
        }
        guard schemaVersion == FilmtoneImportedGradeConstants.schemaVersion else {
            throw ValidationError.schemaVersion(schemaVersion)
        }
        var seen = Set<String>()
        for control in preLutControls {
            try validate(control: control, expectedSlot: .preLut, seen: &seen)
        }
        for control in postLutControls {
            try validate(control: control, expectedSlot: .postLut, seen: &seen)
        }
        try sourceGraph?.validate()
    }

    private func validate(
        control: FilmtoneImportedGradeControl,
        expectedSlot: FilmtoneImportedGradeControl.Slot,
        seen: inout Set<String>
    ) throws {
        guard control.slot == expectedSlot else {
            throw ValidationError.controlSlot(control.id)
        }
        guard !seen.contains(control.id) else {
            throw ValidationError.duplicateControl(control.id)
        }
        seen.insert(control.id)
        guard control.min <= control.max,
              control.defaultValue >= control.min,
              control.defaultValue <= control.max else {
            throw ValidationError.controlRange(control.id)
        }
    }

    enum ValidationError: LocalizedError, Equatable {
        case schemaId(String)
        case schemaVersion(Int)
        case duplicateControl(String)
        case controlSlot(String)
        case controlRange(String)

        var errorDescription: String? {
            switch self {
            case .schemaId(let value): return "Unsupported Imported Grade schema id: \(value)."
            case .schemaVersion(let value): return "Unsupported Imported Grade schema version: \(value)."
            case .duplicateControl(let id): return "Duplicate Imported Grade control id: \(id)."
            case .controlSlot(let id): return "Imported Grade control is in the wrong slot: \(id)."
            case .controlRange(let id): return "Imported Grade control range is invalid: \(id)."
            }
        }
    }
}

struct FilmtoneImportedGradeSourceGraph: Codable, Equatable, Sendable {
    struct Triplet: Codable, Equatable, Sendable {
        let parameterId: Int
        let values: [Double]
    }

    struct WheelBlock: Codable, Equatable, Sendable {
        let path: [Int]
        let floatValues: [Double]
    }

    struct Node: Codable, Equatable, Sendable {
        let index: Int
        let protobufPath: [Int]
        let recognizedOps: [String]
        let unsupportedPayloadBase64: String?
        let approximateInnerFieldCount: Int
    }

    let format: String
    let decoded: Bool
    let bodyVersionFlag: Int?
    let rawTriplets: [Triplet]
    let wheelAdjustmentBlocks: [WheelBlock]
    let nodes: [Node]
    let approximateNodeCount: Int
    let unsupportedNotes: [String]

    init(
        format: String = "davinci-drx",
        decoded: Bool,
        bodyVersionFlag: Int?,
        rawTriplets: [Triplet] = [],
        wheelAdjustmentBlocks: [WheelBlock] = [],
        nodes: [Node] = [],
        approximateNodeCount: Int,
        unsupportedNotes: [String] = []
    ) {
        self.format = format
        self.decoded = decoded
        self.bodyVersionFlag = bodyVersionFlag
        self.rawTriplets = rawTriplets
        self.wheelAdjustmentBlocks = wheelAdjustmentBlocks
        self.nodes = nodes
        self.approximateNodeCount = approximateNodeCount
        self.unsupportedNotes = unsupportedNotes
    }

    func validate() throws {
        guard format == "davinci-drx" else { throw ValidationError.format(format) }
        if let bodyVersionFlag, bodyVersionFlag < 0 { throw ValidationError.negative("bodyVersionFlag") }
        for triplet in rawTriplets where triplet.parameterId < 0 {
            throw ValidationError.negative("rawTriplets.parameterId")
        }
        for block in wheelAdjustmentBlocks where block.path.contains(where: { $0 < 0 }) {
            throw ValidationError.negative("wheelAdjustmentBlocks.path")
        }
        for node in nodes {
            if node.index < 0 { throw ValidationError.negative("nodes.index") }
            if node.protobufPath.contains(where: { $0 < 0 }) {
                throw ValidationError.negative("nodes.protobufPath")
            }
            if node.approximateInnerFieldCount < 0 {
                throw ValidationError.negative("nodes.approximateInnerFieldCount")
            }
        }
        if approximateNodeCount < 0 { throw ValidationError.negative("approximateNodeCount") }
    }

    enum ValidationError: LocalizedError, Equatable {
        case format(String)
        case negative(String)

        var errorDescription: String? {
            switch self {
            case .format(let value): return "Unsupported source graph format: \(value)."
            case .negative(let field): return "Imported Grade source graph contains a negative \(field)."
            }
        }
    }
}
