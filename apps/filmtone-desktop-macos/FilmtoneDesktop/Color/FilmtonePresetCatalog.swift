import Foundation

// Wraps the 4 built-in presets emitted by `bun run generate:swift` into
// FilmtonePhase0Generated.paramsByName. Stable ordering ("reset" first,
// then alphabetical) so the SwiftUI Picker shows a deterministic list.

enum FilmtonePresetCatalog {
    static let presetVersion = FilmtonePhase0Generated.presetVersion
    static let defaultName = FilmtonePhase0Generated.presetDefault

    static let orderedNames: [String] = {
        let all = FilmtonePhase0Generated.paramsByName.keys
        let sorted = all.sorted()
        if let resetIndex = sorted.firstIndex(of: defaultName), resetIndex != 0 {
            var reordered = sorted
            reordered.remove(at: resetIndex)
            reordered.insert(defaultName, at: 0)
            return reordered
        }
        return sorted
    }()

    static func params(for name: String) -> FilmtonePhase0Params {
        FilmtonePhase0Generated.paramsByName[name]
            ?? FilmtonePhase0Generated.paramsByName[defaultName]
            ?? FilmtonePhase0Generated.resetParams
    }

    static func displayName(for name: String) -> String {
        switch name {
        case "reset": return "Reset"
        case "iphone": return "iPhone"
        case "softBlue": return "Soft Blue"
        case "amberGlow": return "Amber Glow"
        default: return name
        }
    }

    static func lookId(for name: String) -> String {
        // Look canonical id format mirrors film-lab-core `lookIdForBaseLook` —
        // `filmtone:base:<presetName>:<presetVersion>`. Matches Case B sidecar
        // contract in master handoff §10.
        "filmtone:base:\(name):\(presetVersion)"
    }
}
