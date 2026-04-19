import Foundation

enum FilmtonePresetCategory: String, Codable {
    case filmStock
    case look
    case utility
}

struct FilmtonePresetDescriptor: Identifiable, Hashable {
    let name: String
    let label: String
    let subtitle: String
    let category: FilmtonePresetCategory

    var id: String { name }
}

enum FilmtonePresetCatalog {
    static let all: [FilmtonePresetDescriptor] = [
        .init(name: "portra", label: "Portra 400", subtitle: "Warm Pastel", category: .filmStock),
        .init(name: "gold200", label: "Gold 200", subtitle: "Saturated Warm", category: .filmStock),
        .init(name: "pro400h", label: "Pro 400H", subtitle: "Cool Soft", category: .filmStock),
        .init(name: "ektar100", label: "Ektar 100", subtitle: "Vivid Sharp", category: .filmStock),
        .init(name: "superia400", label: "Superia 400", subtitle: "Cool Green", category: .filmStock),
        .init(name: "cinestill800t", label: "CineStill 800T", subtitle: "Tungsten Glow", category: .filmStock),
        .init(name: "bw", label: "B&W", subtitle: "Classic Mono", category: .filmStock),
        .init(name: "velvia50", label: "Velvia 50", subtitle: "Vivid Slide", category: .filmStock),
        .init(name: "cinematic", label: "Cinematic", subtitle: "Teal & Orange", category: .look),
        .init(name: "reset", label: "Reset", subtitle: "No Grade", category: .utility),
    ]

    static let paramsByName: [String: FilmtonePhase0Params] = [
        "portra": .init(
            exposure: 0.2,
            contrast: 1.1,
            saturation: 0.9,
            temperature: 0.1,
            tint: 0,
            fade: 0.05,
            vignette: 0.2,
            grainIntensity: 0.14
        ),
        "gold200": .init(
            exposure: 0.15,
            contrast: 1.2,
            saturation: 1.15,
            temperature: 0.18,
            tint: 0,
            fade: 0.03,
            vignette: 0.25,
            grainIntensity: 0.12
        ),
        "pro400h": .init(
            exposure: 0.25,
            contrast: 1.05,
            saturation: 0.85,
            temperature: -0.1,
            tint: 0,
            fade: 0.08,
            vignette: 0.15,
            grainIntensity: 0.075
        ),
        "ektar100": .init(
            exposure: 0.05,
            contrast: 1.25,
            saturation: 1.3,
            temperature: 0.02,
            tint: 0,
            fade: 0,
            vignette: 0.15,
            grainIntensity: 0.05
        ),
        "superia400": .init(
            exposure: 0.1,
            contrast: 1.18,
            saturation: 1.08,
            temperature: -0.08,
            tint: 0,
            fade: 0.04,
            vignette: 0.2,
            grainIntensity: 0.115
        ),
        "cinestill800t": .init(
            exposure: 0.15,
            contrast: 1.15,
            saturation: 0.95,
            temperature: -0.3,
            tint: 0,
            fade: 0.03,
            vignette: 0.3,
            grainIntensity: 0.14
        ),
        "bw": .init(
            exposure: 0.1,
            contrast: 1.4,
            saturation: 0,
            temperature: 0,
            tint: 0,
            fade: 0.02,
            vignette: 0.5,
            grainIntensity: 0.18
        ),
        "velvia50": .init(
            exposure: 0,
            contrast: 1.35,
            saturation: 1.45,
            temperature: 0.04,
            tint: 0,
            fade: 0,
            vignette: 0.1,
            grainIntensity: 0.02
        ),
        "cinematic": .init(
            exposure: 0.09,
            contrast: 1.24,
            saturation: 0.87,
            temperature: -0.11,
            tint: 0,
            fade: 0.025,
            vignette: 0.32,
            grainIntensity: 0.09
        ),
        "reset": .reset,
    ]

    static func descriptor(named name: String) -> FilmtonePresetDescriptor? {
        all.first { $0.name == name }
    }
}
