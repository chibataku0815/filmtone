import FilmLabSwiftCore
import Foundation

/// Source-aware adaptation for Creative Pack 01 built-in Looks. The
/// resolver itself lives in `FilmtoneLookDirector`; this enum is the
/// public entry point so editor / saved-look apply / capture relay paths
/// can call the same surface and so the legacy two-arg form keeps
/// compiling.
enum FilmtoneCreativePack01Adaptation {
    struct Resolved {
        let intensity: Double
        let paramOverrides: FilmtonePhase0ParamsPatch
    }

    /// Legacy two-arg form retained for callers that do not yet have
    /// `cameraProfile` / `sourceDetailBias` in scope. Forwards to the
    /// extended form with both signals absent.
    static func resolve(
        slug: String,
        descriptor: FilmtoneSourceToneDescriptor?
    ) -> Resolved? {
        return resolve(
            slug: slug,
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: nil,
            sourceColorClassRaw: nil
        )
    }

    /// M1 Max Quality Look Director — full resolver. Source Profile id
    /// (`built-in:source-profile.*`) and the resolved `sourceDetailBias`
    /// promote confidence so Log/profile material gets stronger LUT
    /// intensity and detail bias coordination.
    static func resolve(
        slug: String,
        descriptor: FilmtoneSourceToneDescriptor?,
        sourceProfileId: String?,
        sourceDetailBias: Double?,
        sourceColorClassRaw: String? = nil
    ) -> Resolved? {
        return FilmtoneLookDirector.resolveCreativePack01(
            slug: slug,
            descriptor: descriptor,
            sourceProfileId: sourceProfileId,
            sourceDetailBias: sourceDetailBias,
            sourceColorClassRaw: sourceColorClassRaw
        )
    }
}
