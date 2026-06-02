//
//  EditorAdvancedAdjustCatalog.swift
//  FilmLabSwiftCore
//
//  Shared Advanced Adjust group / control / recipe specification.
//

import Foundation

public enum FilmtoneAdvancedAdjustGroupID: String, CaseIterable, Hashable, Identifiable, Sendable {
    case basic
    case process
    case optics
    case glow
    case grain
    case damage
    case motion

    public var id: String { rawValue }

    public var isVideoOnly: Bool {
        self == .motion
    }
}

public enum FilmtoneAdvancedAdjustRecipeKind: Sendable {
    case none
    case stamp
}

public struct FilmtoneAdvancedAdjustControlSpec: Identifiable, Sendable {
    public let key: String
    public let range: ClosedRange<Double>
    public let digits: Int

    public init(
        key: String,
        range: ClosedRange<Double>,
        digits: Int = 2
    ) {
        self.key = key
        self.range = range
        self.digits = digits
    }

    public var id: String { key }
}

public struct FilmtoneAdvancedAdjustRecipeSpec: Identifiable, Sendable {
    public let id: String
    public let kind: FilmtoneAdvancedAdjustRecipeKind
    public let values: @Sendable (FilmtonePhase0Params) -> [String: Double]

    public init(
        id: String,
        kind: FilmtoneAdvancedAdjustRecipeKind,
        values: @escaping @Sendable (FilmtonePhase0Params) -> [String: Double]
    ) {
        self.id = id
        self.kind = kind
        self.values = values
    }
}

public struct FilmtoneAdvancedAdjustGroupSpec: Identifiable, Sendable {
    public let id: FilmtoneAdvancedAdjustGroupID
    public let controls: [FilmtoneAdvancedAdjustControlSpec]
    public let recipes: [FilmtoneAdvancedAdjustRecipeSpec]

    public init(
        id: FilmtoneAdvancedAdjustGroupID,
        controls: [FilmtoneAdvancedAdjustControlSpec],
        recipes: [FilmtoneAdvancedAdjustRecipeSpec]
    ) {
        self.id = id
        self.controls = controls
        self.recipes = recipes
    }

    public var rawID: String { id.rawValue }
    public var videoOnly: Bool { id.isVideoOnly }
    public var keys: [String] { controls.map(\.key) }
}

public enum FilmtoneAdvancedAdjustCatalog {
    public static let paramEqualityTolerance: Double = 0.0001

    public static let allGroups: [FilmtoneAdvancedAdjustGroupSpec] = [
        FilmtoneAdvancedAdjustGroupSpec(
            id: .basic,
            controls: [
                .init(key: "exposure", range: -2...2),
                .init(key: "contrast", range: 0...2),
                .init(key: "saturation", range: 0...2),
                .init(key: "temperature", range: -1...1),
                .init(key: "tint", range: -1...1),
                .init(key: "fade", range: 0...1),
                .init(key: "blackPoint", range: -1...1),
                .init(key: "toeContrast", range: 0...1),
            ],
            recipes: []
        ),
        FilmtoneAdvancedAdjustGroupSpec(
            id: .process,
            controls: [
                .init(key: "cyan", range: -1...1),
                .init(key: "magenta", range: -1...1),
                .init(key: "yellow", range: -1...1),
                .init(key: "printContrast", range: 0...1),
                .init(key: "compressionAmount", range: 0...1),
                .init(key: "compressionRange", range: 0...1),
            ],
            recipes: [
                .init(id: "standard", kind: .none) { _ in [:] },
                .init(id: "airy", kind: .stamp) { _ in
                    [
                        "cyan": 0.018,
                        "magenta": -0.025,
                        "yellow": -0.030,
                        "printContrast": 0.04,
                        "compressionAmount": 0.04,
                        "compressionRange": 0.54,
                    ]
                },
                .init(id: "sunset", kind: .stamp) { _ in
                    [
                        "cyan": -0.026,
                        "magenta": 0.028,
                        "yellow": 0.045,
                        "printContrast": 0.04,
                        "compressionAmount": 0.05,
                        "compressionRange": 0.56,
                    ]
                },
                .init(id: "depth", kind: .stamp) { _ in
                    [
                        "cyan": 0,
                        "magenta": 0,
                        "yellow": 0.010,
                        "printContrast": 0.09,
                        "compressionAmount": 0.08,
                        "compressionRange": 0.58,
                    ]
                },
            ]
        ),
        FilmtoneAdvancedAdjustGroupSpec(
            id: .optics,
            controls: [
                .init(key: "rgbShift", range: 0...FilmtonePhase0Generated.rgbShiftMax, digits: 3),
                .init(key: "lensSoftness", range: 0...1),
                .init(key: "detailSoftness", range: 0...1),
                .init(key: "vignette", range: 0...1),
            ],
            recipes: standardRecipes(
                defaultValues: { base in
                    [
                        "rgbShift": max(base.rgbShift, 0.0038),
                        "lensSoftness": max(base.lensSoftness, 0.30),
                        "vignette": max(base.vignette, 0.46),
                    ]
                },
                strongValues: { base in
                    [
                        "rgbShift": max(base.rgbShift, FilmtonePhase0Generated.rgbShiftMax),
                        "lensSoftness": max(base.lensSoftness, 0.44),
                        "vignette": max(base.vignette, 0.62),
                    ]
                }
            )
        ),
        FilmtoneAdvancedAdjustGroupSpec(
            id: .glow,
            controls: [
                .init(key: "bloomThreshold", range: 0...1),
                .init(key: "bloomStrength", range: 0...1),
                .init(key: "bloomRadius", range: 0...1),
                .init(key: "bloomSoftKnee", range: 0...1),
                .init(key: "halationIntensity", range: 0...1),
                .init(key: "halationSpread", range: 0...40, digits: 0),
                .init(key: "halationHue", range: 0...100, digits: 0),
                .init(key: "halationThreshold", range: 0...1),
                .init(key: "halationRadius", range: 0...1),
                .init(key: "halationSoftKnee", range: 0...1),
                .init(key: "diffusion", range: 0...1),
            ],
            recipes: standardRecipes(
                defaultValues: { base in
                    [
                        "bloomThreshold": min(base.bloomThreshold, 0.64),
                        "bloomStrength": max(base.bloomStrength, 0.24),
                        "bloomRadius": max(base.bloomRadius, 0.68),
                        "bloomSoftKnee": max(base.bloomSoftKnee, 0.76),
                        "halationIntensity": max(base.halationIntensity, 0.06),
                        "halationSpread": max(base.halationSpread, 34),
                        "halationHue": abs(base.halationHue) < paramEqualityTolerance ? 22 : base.halationHue,
                        "halationThreshold": min(base.halationThreshold, 0.56),
                        "halationRadius": max(base.halationRadius, 0.66),
                        "halationSoftKnee": max(base.halationSoftKnee, 0.58),
                        "diffusion": max(base.diffusion, 0.09),
                    ]
                },
                strongValues: { base in
                    [
                        "bloomThreshold": min(base.bloomThreshold, 0.58),
                        "bloomStrength": max(base.bloomStrength, 0.34),
                        "bloomRadius": max(base.bloomRadius, 0.78),
                        "bloomSoftKnee": max(base.bloomSoftKnee, 0.86),
                        "halationIntensity": max(base.halationIntensity, 0.10),
                        "halationSpread": max(base.halationSpread, 38),
                        "halationHue": abs(base.halationHue) < paramEqualityTolerance ? 22 : base.halationHue,
                        "halationThreshold": min(base.halationThreshold, 0.50),
                        "halationRadius": max(base.halationRadius, 0.80),
                        "halationSoftKnee": max(base.halationSoftKnee, 0.70),
                        "diffusion": max(base.diffusion, 0.14),
                    ]
                }
            )
        ),
        FilmtoneAdvancedAdjustGroupSpec(
            id: .grain,
            controls: [
                .init(key: "grainIntensity", range: 0...FilmtonePhase0Generated.grainIntensityMax, digits: 3),
                .init(key: "grainSize", range: 0...1),
                .init(key: "grainRadialMix", range: 0...1),
            ],
            recipes: [
                .init(id: "none", kind: .none) { _ in [:] },
                .init(id: "fine", kind: .stamp) { _ in
                    [
                        "grainIntensity": 0.017,
                        "grainSize": 0.10,
                        "grainRadialMix": 0.60,
                    ]
                },
                .init(id: "classic", kind: .stamp) { _ in
                    [
                        "grainIntensity": 0.034,
                        "grainSize": 0.30,
                        "grainRadialMix": 0.85,
                    ]
                },
                .init(id: "push", kind: .stamp) { _ in
                    [
                        "grainIntensity": 0.064,
                        "grainSize": 0.62,
                        "grainRadialMix": 0.95,
                    ]
                },
            ]
        ),
        FilmtoneAdvancedAdjustGroupSpec(
            id: .damage,
            controls: [
                .init(key: "dustAmount", range: 0...1),
                .init(key: "scratchAmount", range: 0...1),
            ],
            recipes: standardRecipes(
                defaultValues: { base in
                    [
                        "dustAmount": max(base.dustAmount, 0.20),
                        "scratchAmount": max(base.scratchAmount, 0.16),
                    ]
                },
                strongValues: { base in
                    [
                        "dustAmount": max(base.dustAmount, 0.52),
                        "scratchAmount": max(base.scratchAmount, 0.56),
                    ]
                }
            )
        ),
        FilmtoneAdvancedAdjustGroupSpec(
            id: .motion,
            controls: [
                .init(key: "shutterAngle", range: 0...720, digits: 0),
                .init(key: "trailIntensity", range: 0...0.95),
                .init(key: "filmBreathAmount", range: 0...1),
            ],
            recipes: standardRecipes(
                defaultValues: { _ in
                    [
                        "shutterAngle": 360,
                        "trailIntensity": 0,
                        "filmBreathAmount": 0,
                    ]
                },
                strongValues: { _ in
                    [
                        "shutterAngle": 720,
                        "trailIntensity": 0.35,
                        "filmBreathAmount": 0.28,
                    ]
                }
            )
        ),
    ]

    public static func groups(forVideo isVideo: Bool) -> [FilmtoneAdvancedAdjustGroupSpec] {
        allGroups.filter { !$0.videoOnly || isVideo }
    }

    public static func group(for id: FilmtoneAdvancedAdjustGroupID) -> FilmtoneAdvancedAdjustGroupSpec? {
        allGroups.first { $0.id == id }
    }

    private static func standardRecipes(
        defaultValues: @escaping @Sendable (FilmtonePhase0Params) -> [String: Double],
        strongValues: @escaping @Sendable (FilmtonePhase0Params) -> [String: Double]
    ) -> [FilmtoneAdvancedAdjustRecipeSpec] {
        [
            .init(id: "none", kind: .none) { _ in [:] },
            .init(id: "default", kind: .stamp, values: defaultValues),
            .init(id: "strong", kind: .stamp, values: strongValues),
        ]
    }
}
