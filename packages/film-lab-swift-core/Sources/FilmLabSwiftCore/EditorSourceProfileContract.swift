//
//  EditorSourceProfileContract.swift
//  FilmLabSwiftCore
//
//  Shared Source Profile catalog identity for native Desktop and iPad.
//

import Foundation

/// Shared curve identity for built-in Source Profiles.
///
/// Platform apps keep their local implementation types for now because iOS
/// still has native-policy / synthesized / user-import export plumbing while
/// Desktop uses a curve-driven resolver. This enum owns the product-facing
/// identity both sides must agree on.
public enum FilmtoneSourceProfileCurveID: String, Codable, CaseIterable, Sendable {
    case appleLog              = "apple-log"
    case appleLog2             = "apple-log-2"
    case djiDLog               = "dji-dlog"
    case djiDLogM              = "dji-dlog-m"
    case canonCLog             = "canon-clog"
    case canonLog3CinemaGamut  = "canon-log3-cinema-gamut"
    case panasonicVLog         = "panasonic-vlog"
    case sonySLog3             = "sony-slog3"
}

/// Product-facing Source Profile catalog row shared by Desktop and iPad.
///
/// `detectionHintRawValue` intentionally stores the source color-class raw
/// value instead of importing either app's local `SourceColorClassDTO`.
/// Each app materializes the hint into its local DTO until that DTO graph is
/// promoted to FilmLabSwiftCore.
public struct FilmtoneSourceProfileCatalogRow: Equatable, Sendable, Identifiable {
    public let id: String
    public let englishName: String
    public let curve: FilmtoneSourceProfileCurveID?
    public let detectionHintRawValue: String?
    public let bundled: Bool
    public let immutable: Bool

    public init(
        id: String,
        englishName: String,
        curve: FilmtoneSourceProfileCurveID?,
        detectionHintRawValue: String?,
        bundled: Bool = true,
        immutable: Bool = true
    ) {
        self.id = id
        self.englishName = englishName
        self.curve = curve
        self.detectionHintRawValue = detectionHintRawValue
        self.bundled = bundled
        self.immutable = immutable
    }
}

public enum FilmtoneSourceProfileCoreCatalog {
    /// Built-in entries in the canonical product order. Auto is intentionally
    /// not a row; it is a UI / project-state sentinel on each platform.
    public static let allProfiles: [FilmtoneSourceProfileCatalogRow] = [
        FilmtoneSourceProfileCatalogRow(
            id: "built-in:source-profile.apple-log",
            englishName: "Apple Log",
            curve: .appleLog,
            detectionHintRawValue: "apple-log"
        ),
        FilmtoneSourceProfileCatalogRow(
            id: "built-in:source-profile.apple-log-2",
            englishName: "Apple Log 2",
            curve: .appleLog2,
            detectionHintRawValue: "apple-log2"
        ),
        FilmtoneSourceProfileCatalogRow(
            id: "built-in:source-profile.dji-dlog",
            englishName: "DJI D-Log",
            curve: .djiDLog,
            detectionHintRawValue: nil
        ),
        FilmtoneSourceProfileCatalogRow(
            id: "built-in:source-profile.dji-dlog-m",
            englishName: "DJI D-Log M",
            curve: .djiDLogM,
            detectionHintRawValue: nil
        ),
        FilmtoneSourceProfileCatalogRow(
            id: "built-in:source-profile.canon-clog",
            englishName: "Canon C-Log",
            curve: .canonCLog,
            detectionHintRawValue: nil
        ),
        FilmtoneSourceProfileCatalogRow(
            id: "built-in:source-profile.canon-log3-cinema-gamut",
            englishName: "Canon Log 3 / Cinema Gamut",
            curve: .canonLog3CinemaGamut,
            detectionHintRawValue: nil
        ),
        FilmtoneSourceProfileCatalogRow(
            id: "built-in:source-profile.panasonic-vlog",
            englishName: "V-Log",
            curve: .panasonicVLog,
            detectionHintRawValue: nil
        ),
        FilmtoneSourceProfileCatalogRow(
            id: "built-in:source-profile.sony-slog3",
            englishName: "S-Log3",
            curve: .sonySLog3,
            detectionHintRawValue: nil
        ),
        FilmtoneSourceProfileCatalogRow(
            id: "built-in:source-profile.rec709",
            englishName: "Rec.709",
            curve: nil,
            detectionHintRawValue: "sdr-bt709"
        ),
    ]

    public static func row(forCatalogId id: String) -> FilmtoneSourceProfileCatalogRow? {
        allProfiles.first(where: { $0.id == id })
    }
}

public enum FilmtoneSourcePanelSectionID: String, CaseIterable, Hashable, Sendable, Identifiable {
    case sourceProfile

    public var id: String { rawValue }

    public var debugTitle: String {
        switch self {
        case .sourceProfile:
            return "Source Profile"
        }
    }
}

public enum FilmtoneSourcePanelContract {
    /// Canonical Desktop Source panel structure. iPad may append explicitly
    /// platform-local adjuncts, but the profile picker itself must consume
    /// this shared section ID.
    public static let canonicalOrder: [FilmtoneSourcePanelSectionID] = [
        .sourceProfile,
    ]
}
