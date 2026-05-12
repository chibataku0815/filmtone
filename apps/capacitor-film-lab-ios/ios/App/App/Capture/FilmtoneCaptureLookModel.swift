// Filmtone V2 native camera capture — Look selection models.

import Foundation

#if os(iOS)

/// M11 / S11-B: Look option exposed in the capture-time chip strip.
struct FilmtoneCaptureLook: Identifiable, Equatable {
    let id: String
    let displayName: String
    let canonicalUUID: UUID?
    let slug: String?
    let libraryLutId: UUID?
    let parsedCreativeLut: ParsedCubeLutDTO?
    let customLutRecord: FilmtoneCaptureCustomLutRecord?

    static let filmtone = FilmtoneCaptureLook(
        id: "filmtone",
        displayName: "Filmtone",
        canonicalUUID: nil,
        slug: nil,
        libraryLutId: nil,
        parsedCreativeLut: nil,
        customLutRecord: nil
    )

    static let stone: FilmtoneCaptureLook = {
        let slug = "filmtone-creative-pack-01-stone"
        let entry = FilmtoneBuiltInCatalog.allLooks.first { $0.slug == slug }
        return FilmtoneCaptureLook(
            id: "stone",
            displayName: entry?.englishName ?? "Stone",
            canonicalUUID: entry?.canonicalUUID,
            slug: slug,
            libraryLutId: nil,
            parsedCreativeLut: nil,
            customLutRecord: nil
        )
    }()

    static let urban: FilmtoneCaptureLook = {
        let slug = "filmtone-creative-pack-01-urban"
        let entry = FilmtoneBuiltInCatalog.allLooks.first { $0.slug == slug }
        return FilmtoneCaptureLook(
            id: "urban",
            displayName: entry?.englishName ?? "Urban",
            canonicalUUID: entry?.canonicalUUID,
            slug: slug,
            libraryLutId: nil,
            parsedCreativeLut: nil,
            customLutRecord: nil
        )
    }()

    static let noir: FilmtoneCaptureLook = {
        let slug = "filmtone-creative-pack-01-noir"
        let entry = FilmtoneBuiltInCatalog.allLooks.first { $0.slug == slug }
        return FilmtoneCaptureLook(
            id: "noir",
            displayName: entry?.englishName ?? "Noir",
            canonicalUUID: entry?.canonicalUUID,
            slug: slug,
            libraryLutId: nil,
            parsedCreativeLut: nil,
            customLutRecord: nil
        )
    }()

    static let allCases: [FilmtoneCaptureLook] = [.filmtone, .stone, .urban, .noir]

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

    func toCustomLutRecord() -> FilmtoneCaptureCustomLutRecord? {
        customLutRecord
    }

    func toCustomLutPayload() -> FilmtoneCaptureCustomLutPayload? {
        guard customLutRecord != nil,
              let parsedCreativeLut,
              let blob = try? FilmtoneLutBlobCodec.encode(
                data: parsedCreativeLut.data,
                size: parsedCreativeLut.size
              ) else {
            return nil
        }
        return FilmtoneCaptureCustomLutPayload(
            dataRef: FilmtoneCaptureCustomLutPayload.defaultDataRef,
            dataFormat: FilmtoneCaptureCustomLutPayload.dataFormat,
            blob: blob
        )
    }

    var needsTransformWarningAcceptance: Bool {
        customLutRecord?.transformWarningReason != nil
            && customLutRecord?.transformWarningAccepted == false
    }

    func acceptingTransformWarning() -> FilmtoneCaptureLook {
        guard let record = customLutRecord else { return self }
        let accepted = FilmtoneCaptureCustomLutRecord(
            libraryId: record.libraryId,
            title: record.title,
            size: record.size,
            sourceHash: record.sourceHash,
            intensity: record.intensity,
            conversionPolicy: record.conversionPolicy,
            transformWarningReason: record.transformWarningReason,
            transformWarningKind: record.transformWarningKind,
            transformWarningSignal: record.transformWarningSignal,
            transformWarningAccepted: true
        )
        return FilmtoneCaptureLook(
            id: id,
            displayName: displayName,
            canonicalUUID: canonicalUUID,
            slug: slug,
            libraryLutId: libraryLutId,
            parsedCreativeLut: parsedCreativeLut,
            customLutRecord: accepted
        )
    }

    static func userLut(
        entry: LutLibraryEntry,
        parsedLut: ParsedCubeLutDTO
    ) -> FilmtoneCaptureLook {
        let warning = FilmtoneCaptureTransformLutClassifier.warning(
            title: entry.title,
            originalFilename: entry.originalFilename,
            size: parsedLut.size,
            data: parsedLut.data
        )
        let record = FilmtoneCaptureCustomLutRecord(
            libraryId: entry.id,
            title: entry.title,
            size: entry.size,
            sourceHash: entry.sourceHash,
            intensity: parsedLut.intensity,
            conversionPolicy: FilmtoneCaptureCustomLutRecord.captureConversionPolicy,
            transformWarningReason: warning?.message,
            transformWarningKind: warning?.kind.rawValue,
            transformWarningSignal: warning?.matchedSignal,
            transformWarningAccepted: false
        )
        return FilmtoneCaptureLook(
            id: "user-lut-\(entry.id.uuidString.lowercased())",
            displayName: entry.title,
            canonicalUUID: nil,
            slug: nil,
            libraryLutId: entry.id,
            parsedCreativeLut: parsedLut,
            customLutRecord: record
        )
    }

    static func == (lhs: FilmtoneCaptureLook, rhs: FilmtoneCaptureLook) -> Bool {
        lhs.id == rhs.id
    }
}

#endif
