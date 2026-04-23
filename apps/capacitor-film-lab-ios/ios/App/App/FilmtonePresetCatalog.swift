import Foundation

enum FilmtonePresetCategory: String, Codable {
    case filmStock
    case look
    case utility
}

struct FilmtonePresetDescriptor: Identifiable, Hashable {
    let name: String
    let label: String
    let subtitleKey: String
    let subtitleDefaultValue: String
    let category: FilmtonePresetCategory

    var id: String { name }

    var subtitle: String {
        filmtoneLocalized(
            subtitleKey,
            defaultValue: subtitleDefaultValue,
            comment: "Subtitle shown on a film preset card."
        )
    }
}

enum FilmtonePresetCatalog {
    static let all: [FilmtonePresetDescriptor] = [
        .init(name: "reset", label: "Neutral", subtitleKey: "filmtone.preset.reset.subtitle", subtitleDefaultValue: "Clean Base", category: .utility),
        .init(name: "portra", label: "Portra 400", subtitleKey: "filmtone.preset.portra.subtitle", subtitleDefaultValue: "Warm Pastel", category: .filmStock),
        .init(name: "gold200", label: "Gold 200", subtitleKey: "filmtone.preset.gold200.subtitle", subtitleDefaultValue: "Saturated Warm", category: .filmStock),
        .init(name: "pro400h", label: "Pro 400H", subtitleKey: "filmtone.preset.pro400h.subtitle", subtitleDefaultValue: "Cool Soft", category: .filmStock),
        .init(name: "ektar100", label: "Ektar 100", subtitleKey: "filmtone.preset.ektar100.subtitle", subtitleDefaultValue: "Vivid Sharp", category: .filmStock),
        .init(name: "superia400", label: "Superia 400", subtitleKey: "filmtone.preset.superia400.subtitle", subtitleDefaultValue: "Cool Green", category: .filmStock),
        .init(name: "cinestill800t", label: "CineStill 800T", subtitleKey: "filmtone.preset.cinestill800t.subtitle", subtitleDefaultValue: "Tungsten Glow", category: .filmStock),
        .init(name: "bw", label: "B&W", subtitleKey: "filmtone.preset.bw.subtitle", subtitleDefaultValue: "Classic Mono", category: .filmStock),
        .init(name: "velvia50", label: "Velvia 50", subtitleKey: "filmtone.preset.velvia50.subtitle", subtitleDefaultValue: "Vivid Slide", category: .filmStock),
        .init(name: "cinematic", label: "Cinematic", subtitleKey: "filmtone.preset.cinematic.subtitle", subtitleDefaultValue: "Teal & Orange", category: .look),
    ]

    static func descriptor(named name: String) -> FilmtonePresetDescriptor? {
        all.first { $0.name == name }
    }
}
