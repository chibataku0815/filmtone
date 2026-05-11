import Foundation

enum FilmtonePresetCategory: String, Codable {
    case base
    case camera
    case look
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
        .init(name: "reset", label: "Natural", subtitleKey: "filmtone.preset.reset.subtitle", subtitleDefaultValue: "Gentle Base", category: .base),
        .init(name: "iphone", label: "iPhone", subtitleKey: "filmtone.preset.iphone.subtitle", subtitleDefaultValue: "Camera Finish", category: .camera),
        .init(name: "softBlue", label: "Soft Blue", subtitleKey: "filmtone.preset.soft_blue.subtitle", subtitleDefaultValue: "Airy Glow", category: .look),
        .init(name: "amberGlow", label: "Amber Glow", subtitleKey: "filmtone.preset.amber_glow.subtitle", subtitleDefaultValue: "Warm Flare", category: .look),
    ]

    static func descriptor(named name: String) -> FilmtonePresetDescriptor? {
        all.first { $0.name == name }
    }
}
