// Filmtone V2 native camera capture — Look selection models.

import Foundation

#if os(iOS)

/// M11 / S11-B: Look option exposed in the capture-time chip strip.
struct FilmtoneCaptureLook: Identifiable, Equatable {
    let id: String
    let displayName: String
    let canonicalUUID: UUID?
    let slug: String?

    static let filmtone = FilmtoneCaptureLook(
        id: "filmtone",
        displayName: "Filmtone",
        canonicalUUID: nil,
        slug: nil
    )

    static let stone: FilmtoneCaptureLook = {
        let slug = "filmtone-creative-pack-01-stone"
        let entry = FilmtoneBuiltInCatalog.allLooks.first { $0.slug == slug }
        return FilmtoneCaptureLook(
            id: "stone",
            displayName: entry?.englishName ?? "Stone",
            canonicalUUID: entry?.canonicalUUID,
            slug: slug
        )
    }()

    static let urban: FilmtoneCaptureLook = {
        let slug = "filmtone-creative-pack-01-urban"
        let entry = FilmtoneBuiltInCatalog.allLooks.first { $0.slug == slug }
        return FilmtoneCaptureLook(
            id: "urban",
            displayName: entry?.englishName ?? "Urban",
            canonicalUUID: entry?.canonicalUUID,
            slug: slug
        )
    }()

    static let allCases: [FilmtoneCaptureLook] = [.filmtone, .stone, .urban]

    static func resolve(from canonicalUUID: UUID?) -> FilmtoneCaptureLook {
        guard let uuid = canonicalUUID else { return .filmtone }
        return allCases.first { $0.canonicalUUID == uuid } ?? .filmtone
    }

    func toSelectedLookRecord() -> FilmtoneSelectedLookRecord? {
        guard let canonicalUUID else { return nil }
        return FilmtoneSelectedLookRecord(
            canonicalUUID: canonicalUUID,
            slug: slug,
            englishName: displayName,
            intensity: 1.0
        )
    }
}

#endif
