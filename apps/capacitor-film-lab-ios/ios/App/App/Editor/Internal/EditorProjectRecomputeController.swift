import FilmLabSwiftCore
import Foundation

/// Project recompute / probe-apply collaborator, extracted verbatim from
/// `FilmtoneEditorStore` (god-object regrowth pass).
///
/// Responsibilities:
/// - `recomputeProjectParams()`: the general slider/preset recompute path
///   (bumps `updatedAt`, persists, reschedules preview).
/// - `recomputeProjectParamsPreservingOpticsGlow()`: variant used by
///   `EditorProjectMutationCoordinator.applySavedLook` so a Look's optical
///   signature stays explicit in `paramOverrides` even when it matches the
///   resolved baseline.
/// - `refreshCreativePack01AdaptationIfApplicable()`: re-resolves a Pack 01
///   bundled Look's adaptation when source / Camera Profile context
///   changes.
/// - `applyProbe(source:probe:)`: the source-replacement pipeline (camera
///   profile retention rule, capture-relay linkage drop, preview/export
///   reset, Pack 01 re-adaptation, video-timing reset, mezzanine prewarm).
///
/// Holds `facade` directly (mirroring `EditorCaptureRelay` /
/// `EditorProjectMutationCoordinator`) and a `weak` back-reference to the
/// store. `applyCameraProfileSourceChangeRule(probe:)` and
/// `refreshSourceAudioDebugLabel(for:)` widened from `private` to internal
/// access on `FilmtoneEditorStore` so `applyProbe` here can call them —
/// same widening precedent already used for
/// `EditorProjectMutationCoordinator`'s helpers (see that file's doc
/// comment).
@MainActor
final class EditorProjectRecomputeController {
    private let facade: FilmtoneEditorFacade
    private weak var store: FilmtoneEditorStore?

    init(facade: FilmtoneEditorFacade) {
        self.facade = facade
    }

    func attach(_ store: FilmtoneEditorStore) {
        self.store = store
    }

    func recomputeProjectParams() {
        guard let store else { return }
        store.project.quickState = store.project.quickState.clamped()
        let resolved = FilmtonePhase0Math.resolveParams(
            presetName: store.project.presetName,
            strength: store.project.strength,
            quickState: store.project.quickState,
            paramOverrides: store.project.paramOverrides
        )
        store.project.paramOverrides = resolved.overrides
        store.project.params = resolved.effective
        store.project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        store.persist()
        store.schedulePreviewRender()
    }

    /// Variant of `recomputeProjectParams` that keeps optics + glow keys
    /// explicit in `paramOverrides` even if their value matches the resolved
    /// baseline. Used by `applySavedLook` so the Look's optical signature
    /// surfaces in Adjust-sheet UI signals — without it, a Look whose optics
    /// happen to align with the active preset's defaults would normalize away
    /// into an empty patch and the user would see "no adjustments" UI even
    /// though the kernel is rendering with the Look's chosen optics values.
    func recomputeProjectParamsPreservingOpticsGlow() {
        guard let store else { return }
        store.project.quickState = store.project.quickState.clamped()
        let base = FilmtonePhase0Math.deriveParams(
            presetName: store.project.presetName,
            strength: store.project.strength,
            quickState: store.project.quickState
        )
        store.project.paramOverrides = store.project.paramOverrides
            .normalizedPreservingOpticsGlow(over: base)
        store.project.params = base.applyingPatch(store.project.paramOverrides)
        store.project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        store.persist()
        store.schedulePreviewRender()
    }

    /// M1 Max Quality Look Director — re-resolve adaptation when source
    /// or Camera Profile changes so a previously-applied Creative Pack 01
    /// Look re-adapts to the new context instead of staying baked from
    /// apply-time. No-op when the current `creativeLut` is not a Pack 01
    /// bundled Look. Returns `true` when it mutated state and already
    /// persisted + scheduled a re-render via
    /// `recomputeProjectParamsPreservingOpticsGlow`.
    ///
    /// M1C: the merge now writes the FULL catalog baseline first (every
    /// Pack 01 key, not just the adaptation overlay subset), then layers
    /// the Look Director overlay on top. This is the migration mechanism
    /// for persisted projects from earlier builds: their stale
    /// `grainIntensity`, `lensSoftness`, `bloomRadius`, etc. get
    /// overwritten with the current M1C catalog values without needing a
    /// `Profile.version` bump. User-side tweaks on Pack 01 baseline keys
    /// are reset on every refresh by design — bundled Looks are owned by
    /// the catalog, custom variants belong in saved Looks.
    @discardableResult
    func refreshCreativePack01AdaptationIfApplicable() -> Bool {
        guard let store else { return false }
        guard
            let creativeLut = store.project.creativeLut,
            let slug = creativeLut.bundledSlug,
            let builtIn = FilmtoneBuiltInCatalog.look(matchingSlug: slug)
        else {
            return false
        }

        let sourceProfileId = FilmtoneLookDirector.sourceProfileId(
            for: store.project.cameraProfile
        )
        let sourceColorClassRaw = FilmtoneLookDirector.sourceColorClassRaw(
            probe: store.probe
        )
        let adaptation = FilmtoneCreativePack01Adaptation.resolve(
            slug: slug,
            descriptor: store.probe?.sourceToneDescriptor,
            sourceProfileId: sourceProfileId,
            sourceDetailBias: FilmtoneLookDirector.resolveSourceDetailBias(
                probe: store.probe,
                cameraProfile: store.project.cameraProfile
            ),
            sourceColorClassRaw: sourceColorClassRaw
        )
        let selectedBinding = FilmtoneBuiltInCatalog.creativeLutBinding(
            for: builtIn,
            sourceProfileId: sourceProfileId,
            sourceColorClassRaw: sourceColorClassRaw
        )
        let selectedCreativeLut = FilmtoneEditorStore.loadBundledCreativeLut(
            binding: selectedBinding,
            packId: builtIn.packId ?? FilmtoneBuiltInCatalog.creativePack01Id
        )

        guard let mergedValues = FilmtoneCreativePack01Patches.refreshedParamOverrides(
            existing: store.project.paramOverrides.values,
            slug: slug,
            adaptation: adaptation
        ) else {
            return false
        }

        var nextOverrides = store.project.paramOverrides
        nextOverrides.values = mergedValues

        let nextIntensity = adaptation?.intensity ?? 1.0
        let nextCreativeLut = selectedCreativeLut?.withIntensity(nextIntensity)
        let intensityChanged = abs(creativeLut.intensity - nextIntensity) > 1e-6
        let lutVariantChanged = nextCreativeLut.map {
            $0.title != creativeLut.title ||
            $0.size != creativeLut.size ||
            $0.data.count != creativeLut.data.count
        } ?? false
        let overridesChanged = nextOverrides.values != store.project.paramOverrides.values
        guard intensityChanged || overridesChanged || lutVariantChanged else {
            return false
        }

        store.project.paramOverrides = nextOverrides
        store.project.creativeLut = nextCreativeLut ?? creativeLut.withIntensity(nextIntensity)
        recomputeProjectParamsPreservingOpticsGlow()
        return true
    }

    func applyProbe(source: SourceInfoDTO, probe: SourceProbeDTO) {
        guard let store else { return }
        let isSourceReplacement = store.source?.uri != source.uri
        store.source = source
        store.probe = probe
        #if DEBUG
        store.refreshSourceAudioDebugLabel(for: source)
        #endif
        // Camera/input LUTs are source-specific. Carrying one across clips can
        // mis-normalize non-log footage when replacing a prior log source.
        if isSourceReplacement, store.project.inputLut != nil {
            store.project.inputLut = nil
            store.project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        }
        // v1.3 Camera Profiles Phase F (D-CP4) — apply the retention rule
        // for the selected Camera Profile against the new probe. Sticky
        // for manual profiles, reset for Apple Log mismatches.
        if isSourceReplacement {
            store.applyCameraProfileSourceChangeRule(probe: probe)
            #if os(iOS)
            store.captureRelay.dropLinkageIfNotProxy(of: source)
            #endif
        }
        store.previewOrchestrator.reset()
        store.exportCoordinator.resetForSourceChange()
        // M1 Max Quality Look Director — new probe means a new
        // `sourceToneDescriptor`. If a Pack 01 bundled Look is current,
        // re-resolve so the night / high-key / Log / digital signals from
        // the new clip drive intensity + overlay overrides. Caller's own
        // persist/reclaim path runs after this returns; the refresher's
        // recompute (if it mutated) also persists + schedules. Placing
        // this after the orchestrator reset so the scheduled render is
        // not immediately canceled.
        refreshCreativePack01AdaptationIfApplicable()
        if isSourceReplacement || !store.canUseSlow24VideoTiming {
            store.videoTimingMode = .normal
        }
        store.error = nil
        store.notice = nil
        store.sourceLoadState = nil
        store.highlightMarkers = nil
        facade.prewarmMezzanines(for: source)
    }
}
