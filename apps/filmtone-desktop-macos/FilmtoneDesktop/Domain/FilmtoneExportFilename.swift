import Foundation

enum FilmtoneExportFilename {
    static func defaultFilename(
        sourceURL: URL,
        presetName: String,
        lookSlug: String?,
        fileExtension: String
    ) -> String {
        let stem = sourceURL.deletingPathExtension().lastPathComponent
        let suffix = identitySuffix(presetName: presetName, lookSlug: lookSlug)
        let normalizedExtension = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if normalizedExtension.isEmpty {
            return "\(stem)-\(suffix)"
        }
        return "\(stem)-\(suffix).\(normalizedExtension)"
    }

    static func identitySuffix(presetName: String, lookSlug: String?) -> String {
        if let lookSlug,
           let look = FilmtoneCreativePackCatalog.find(slug: lookSlug) {
            return slugify(look.englishName)
        }

        if let lookSlug,
           !lookSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return slugify(shortLookSlug(lookSlug))
        }

        let presetSuffix = slugify(presetName)
        return presetSuffix.isEmpty ? "filmtone" : presetSuffix
    }

    private static func shortLookSlug(_ lookSlug: String) -> String {
        let prefix = "filmtone-creative-pack-01-"
        if lookSlug.hasPrefix(prefix) {
            return String(lookSlug.dropFirst(prefix.count))
        }
        return lookSlug
    }

    private static func slugify(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        var result = ""
        var previousWasSeparator = false

        for scalar in value.lowercased().unicodeScalars {
            if allowed.contains(scalar) {
                result.append(String(scalar))
                previousWasSeparator = false
            } else if !previousWasSeparator {
                result.append("-")
                previousWasSeparator = true
            }
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "filmtone" : trimmed
    }
}
