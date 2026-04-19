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

    static func descriptor(named name: String) -> FilmtonePresetDescriptor? {
        all.first { $0.name == name }
    }
}
