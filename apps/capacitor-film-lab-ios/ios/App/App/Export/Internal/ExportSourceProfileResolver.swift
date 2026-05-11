import Foundation

/// Builds the camera-profile provenance block written into the export
/// sidecar. Moved out of `FilmtoneExportSession` during the v1.x
/// feature-architecture refactor (Phase 2B-2). The returned
/// `SidecarCameraProfile` field order and selection-kind strings are
/// byte-identical to the pre-refactor implementation so the V1 sidecar
/// schema stays canonical.
enum ExportSourceProfileResolver {

    /// v1.3 Camera Profiles Phase G: build the sidecar provenance block
    /// for the active selection. Returns nil when the selection is `.auto`
    /// AND the probe doesn't resolve to any catalog entry — the legacy
    /// "auto, no source profile" case stays byte-identical to v1.2.
    static func makeCameraProfileSidecar(
        for selection: CameraProfileSelection?,
        probeColorClass: SourceColorClassDTO?
    ) -> SidecarCameraProfile? {
        switch selection ?? .auto {
        case .auto:
            // Auto with a probe that maps to a catalog entry — record the
            // resolution. Auto without a match returns nil so the v1.2
            // "no profile applied" path keeps producing an empty
            // cameraProfile block.
            guard let entry = FilmtoneSourceProfileCatalog.entry(forColorClass: probeColorClass) else {
                return SidecarCameraProfile(
                    selectionKind: "auto",
                    catalogId: nil,
                    curve: nil,
                    impl: nil,
                    resolvedFromAutoVia: probeColorClass?.rawValue
                )
            }
            return SidecarCameraProfile(
                selectionKind: "auto",
                catalogId: entry.id,
                curve: entry.curve?.rawValue,
                impl: implTag(entry.impl),
                resolvedFromAutoVia: probeColorClass?.rawValue
            )
        case .builtIn(let catalogId):
            guard let entry = FilmtoneSourceProfileCatalog.entry(forCatalogId: catalogId) else {
                return SidecarCameraProfile(
                    selectionKind: "built-in",
                    catalogId: catalogId,
                    curve: nil,
                    impl: nil,
                    resolvedFromAutoVia: nil
                )
            }
            return SidecarCameraProfile(
                selectionKind: "built-in",
                catalogId: entry.id,
                curve: entry.curve?.rawValue,
                impl: implTag(entry.impl),
                resolvedFromAutoVia: nil
            )
        case .userImport:
            return SidecarCameraProfile(
                selectionKind: "user-import",
                catalogId: nil,
                curve: nil,
                impl: nil,
                resolvedFromAutoVia: nil
            )
        }
    }

    private static func implTag(_ impl: SourceProfileImpl) -> String {
        switch impl {
        case .nilProfile:    return "nil-profile"
        case .nativePolicy:  return "native-policy"
        case .synthesized:   return "synthesized"
        case .bundledCube:   return "bundled-cube"
        }
    }
}
