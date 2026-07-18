import FilmLabSwiftCore
import Foundation

/// Apply-side helpers for the Max Quality Look Director. Lives in its own
/// file so the standalone resolver tests can compile
/// `FilmtoneLookDirector.swift` without `SourceProbeDTO` /
/// `CameraProfileSelection` (which pull in UIKit-tainted types through
/// `FilmtoneMediaTypes`).
extension FilmtoneLookDirector {

    /// Translate a `CameraProfileSelection` into the catalog id the
    /// Look Director and `FilmtoneSourceDetailCompensation` both
    /// understand. `.auto` and `.userImport` map to nil so the
    /// auto-detection path keeps owning the decision.
    static func sourceProfileId(
        for cameraProfile: CameraProfileSelection?
    ) -> String? {
        guard let cameraProfile else { return nil }
        switch cameraProfile {
        case .builtIn(let catalogId):
            return catalogId
        case .auto, .userImport:
            return nil
        }
    }

    static func sourceColorClassRaw(probe: SourceProbeDTO?) -> String? {
        probe?.sourceVideoMetadata?.colorClass.rawValue
    }

    /// Mirror of `GradeRenderPipeline.resolveSourceDetailBias` (moved there
    /// from `FilmtoneExportSession` in the R3 god-object regrowth pass) so
    /// the editor / capture relay can coordinate detail softness against
    /// the same compensation profile the export pipeline will pick.
    static func resolveSourceDetailBias(
        probe: SourceProbeDTO?,
        cameraProfile: CameraProfileSelection?
    ) -> Double {
        guard let probe else { return 0 }
        let video = probe.sourceVideoMetadata
        let logTransfer = video?.logTransferFunction ?? probe.logTransferFunction
        let transformStrategy = (video?.inputTransformPolicy ?? probe.inputTransformPolicy)?.strategy
        let codec = video?.codecFamily ?? probe.codecFamily
        let input = FilmtoneSourceDetailCompensationInput(
            cameraMake: probe.cameraOptics?.cameraMake,
            cameraModel: probe.cameraOptics?.cameraModel,
            logTransferFunction: logTransfer?.rawValue,
            inputTransformStrategy: transformStrategy?.rawValue,
            codecFamily: codec?.rawValue,
            colorClass: video?.colorClass.rawValue,
            sourceProfileId: sourceProfileId(for: cameraProfile)
        )
        return FilmtoneSourceDetailCompensation.resolve(input).recommendedBias
    }
}
