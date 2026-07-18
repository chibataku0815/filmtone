import FilmLabSwiftCore
import Foundation

/// Live-preview grade-processor factory, extracted verbatim from
/// `FilmtoneEditorStore` (god-object regrowth pass). Previously mis-parked
/// under the `v1.3 Camera Profiles Phase F` MARK even though it is a
/// distinct concern from that Camera Profile retention-rule code.
///
/// Responsibilities:
/// - `makeLivePreviewGradeProcessor()` (M10 / S8-F F3): builds a
///   `FilmtoneSharedGradeProcessor` pinned to the editor's current
///   request + source URL so the capture surface can apply byte-parity
///   grading to live VDO frames.
/// - `makeLivePreviewGradeProcessor(overridingBuiltInLook:)` (M11 / S11-C):
///   the chip-strip override variant, including the cold-start synthetic
///   source/probe fixture path.
/// - `makeLivePreviewGradeProcessor(captureCreativeLut:)` (S7): the
///   owner-imported creative LUT variant.
/// - `makeCapturePackagePreviewGradeProcessor(_:)` (S3 take-picker): thin
///   forward into `EditorCaptureRelay`, moved here to stay grouped with
///   its factory siblings.
/// - `liveCaptureSyntheticSource()`: static fixture builder for the
///   cold-start (no editor source loaded) capture preview path.
/// - `makeLivePreviewDiagnostics(...)`: chip diagnostics snapshot.
///
/// Holds `facade` / `projectController` directly (mirroring
/// `EditorCaptureRelay` / `EditorProjectMutationCoordinator`) and a `weak`
/// back-reference to the store for `source` / `probe` / `project` /
/// `appliedSavedLookId` / `lookProfileLabel` / `cameraProfileLabel` /
/// `captureRelay`. `makeLivePreviewDiagnostics` takes those store-derived
/// values as parameters instead of reading `store` directly, since its
/// return type is non-optional and all three callers already have `store`
/// unwrapped at the call site.
@MainActor
final class EditorPreviewGradeFactory {
    private let facade: FilmtoneEditorFacade
    private let projectController: EditorProjectController
    private weak var store: FilmtoneEditorStore?

    init(
        facade: FilmtoneEditorFacade,
        projectController: EditorProjectController
    ) {
        self.facade = facade
        self.projectController = projectController
    }

    func attach(_ store: FilmtoneEditorStore) {
        self.store = store
    }

    /// Live capture preview grade applier (M10 / S8-F F3).
    ///
    /// Build a `FilmtoneSharedGradeProcessor` pinned to the editor's
    /// current request + source URL so the capture surface can apply
    /// byte-parity grading to live VDO frames.  Returns `nil` when:
    ///
    /// - no source is loaded (entering capture from empty state — there
    ///   is nothing for the grade chain to anchor its stable seed
    ///   against, and the look-reference panel will already be hidden
    ///   for the same reason in S8-D),
    /// - the request DTO can't be built (probe / project state in an
    ///   intermediate edit), or
    /// - the runtime can't open the source URL (deleted / unreachable).
    ///
    /// Failure is silent — the live preview falls back to ungraded
    /// pass-through, which matches the F2 behavior the user already
    /// validated.  This is `feedback_no_fallback_bug_hotbed`-compatible
    /// because the absence of grading on the live preview is never
    /// confused with a successful grade: the surface displays without
    /// the user thinking "the export will look like this," because
    /// captured masters still go through the editor on adopt and the
    /// editor reapplies the canonical grade for export.
    func makeLivePreviewGradeProcessor() -> FilmtoneLivePreviewBundle? {
        guard let store, store.source != nil else { return nil }
        do {
            let request = try FilmtonePhase0Math.buildExportRequest(
                source: store.source,
                probe: store.probe,
                project: store.project
            )
            // F3-Fix #1: forward Saved Look entry + camera profile so the
            // live preview's `FilmtoneExportSession` matches the export
            // path's input-LUT auto-injection and Saved Look provenance.
            // Saved Look entry is read sync from `projectController.appliedSavedLookEntryCache`,
            // populated at the two apply paths (`saveLookFromCurrentState` /
            // `applySavedLook`); the export path uses the async resolver,
            // but live preview cannot await without restructuring the
            // fullScreenCover capture path.
            let savedLookEntry = projectController.appliedSavedLookEntryCache
            let cameraProfile = store.project.cameraProfile
            let processor = try facade.makeLivePreviewGradeProcessor(
                request: request,
                appliedSavedLook: savedLookEntry,
                cameraProfile: cameraProfile
            )
            let diagnostics = makeLivePreviewDiagnostics(
                request: request,
                forwardedSavedLook: savedLookEntry,
                forwardedCameraProfile: cameraProfile,
                probe: store.probe,
                appliedSavedLookId: store.appliedSavedLookId,
                lookProfileLabel: store.lookProfileLabel,
                cameraProfileLabel: store.cameraProfileLabel
            )
            return FilmtoneLivePreviewBundle(
                processor: processor,
                diagnostics: diagnostics
            )
        } catch {
            return nil
        }
    }

    /// M11 / S11-C: live capture preview with a chip-strip override.
    ///
    /// `nil` defers to the argument-less variant — the chip-strip's
    /// "Filmtone" entry maps to nil so tapping it shows the editor's
    /// current pre-capture grade (custom adjustments, applied saved
    /// Look, etc.) without forcing a reset to a clean baseline.
    ///
    /// A non-nil built-in (Stone / Urban) builds a transient
    /// `FilmtoneProjectState` carrying the catalog entry's
    /// `presetName` / `strength` / `quickState` / `paramOverrides` /
    /// `creativeLut` and forwards the materialized `SavedLookEntry` so
    /// `FilmtoneSharedGradeProcessor` runs the same 3-layer wiring
    /// (`appliedSavedLook` + camera profile) the export path uses.
    ///
    /// The store's persisted state is intentionally untouched —
    /// capture-time chip changes only mutate the editor on
    /// `adoptCaptureResult` (S11-E).  Cancelling capture leaves the
    /// editor's pre-capture Look intact (M11 cancel-preservation).
    func makeLivePreviewGradeProcessor(
        overridingBuiltInLook builtIn: FilmtoneBuiltInCatalog.BuiltInLook?
    ) -> FilmtoneLivePreviewBundle? {
        guard let builtIn else {
            return makeLivePreviewGradeProcessor()
        }
        guard let store else { return nil }
        // Cold-start capture surface: the editor has no loaded source
        // yet (owner walked into capture before picking / recording),
        // but the live VDO frames are well-known by the M10 contract
        // — 4K24 ProRes 422 HQ Apple Log 2.  Synthesize a source +
        // probe describing exactly that stream so the chip-strip's
        // Stone / Urban grade chain can still be built and applied to
        // the live preview without forcing a record-first round trip.
        // The Filmtone default chip path (`builtIn == nil` above)
        // intentionally keeps the original nil-return because that
        // chip means "no Look applied" — falling back to raw camera
        // is the correct semantic there.
        let effectiveSource: SourceInfoDTO
        let effectiveProbe: SourceProbeDTO?
        if let source = store.source {
            effectiveSource = source
            effectiveProbe = store.probe
        } else {
            let synthetic = Self.liveCaptureSyntheticSource()
            effectiveSource = synthetic.source
            effectiveProbe = synthetic.probe
        }
        do {
            var transient = store.project
            transient.presetName = FilmtonePhase0Math.safePresetName(builtIn.presetName)
            transient.presetVersion = FilmtonePhase0Math.presetVersion
            transient.strength = FilmtonePhase0Math.clampStrength(builtIn.strength)
            transient.quickState = builtIn.quickState.clamped()

            var paramOverrides = builtIn.paramOverrides
            var resolvedCreativeLut: ParsedCubeLutDTO?
            let sourceProfileId = FilmtoneLookDirector.sourceProfileId(
                for: store.project.cameraProfile
            )
            let sourceColorClassRaw = FilmtoneLookDirector.sourceColorClassRaw(
                probe: effectiveProbe
            )
            resolvedCreativeLut = FilmtoneEditorStore.loadBundledCreativeLut(
                binding: FilmtoneBuiltInCatalog.creativeLutBinding(
                    for: builtIn,
                    sourceProfileId: sourceProfileId,
                    sourceColorClassRaw: sourceColorClassRaw
                ),
                packId: builtIn.packId ?? FilmtoneBuiltInCatalog.creativePack01Id
            )
            if let adaptation = FilmtoneCreativePack01Adaptation.resolve(
                slug: builtIn.slug,
                descriptor: effectiveProbe?.sourceToneDescriptor,
                sourceProfileId: sourceProfileId,
                sourceDetailBias: FilmtoneLookDirector.resolveSourceDetailBias(
                    probe: effectiveProbe,
                    cameraProfile: store.project.cameraProfile
                ),
                sourceColorClassRaw: sourceColorClassRaw
            ) {
                for (key, value) in adaptation.paramOverrides.values {
                    paramOverrides.values[key] = value
                }
                if let cube = resolvedCreativeLut {
                    resolvedCreativeLut = cube.withIntensity(adaptation.intensity)
                }
            }
            transient.paramOverrides = paramOverrides
            let base = FilmtonePhase0Math.deriveParams(
                presetName: transient.presetName,
                strength: transient.strength,
                quickState: transient.quickState
            )
            transient.params = base.applyingPatch(paramOverrides)
            transient.creativeLut = resolvedCreativeLut

            let request = try FilmtonePhase0Math.buildExportRequest(
                source: effectiveSource,
                probe: effectiveProbe,
                project: transient
            )
            let savedLookEntry = FilmtoneBuiltInCatalog.materializeAsSavedLookEntry(
                builtIn,
                favoriteOverride: false,
                asOf: Date()
            )
            let cameraProfile = store.project.cameraProfile
            let processor = try facade.makeLivePreviewGradeProcessor(
                request: request,
                appliedSavedLook: savedLookEntry,
                cameraProfile: cameraProfile
            )
            let diagnostics = makeLivePreviewDiagnostics(
                request: request,
                forwardedSavedLook: savedLookEntry,
                forwardedCameraProfile: cameraProfile,
                probe: store.probe,
                appliedSavedLookId: store.appliedSavedLookId,
                lookProfileLabel: store.lookProfileLabel,
                cameraProfileLabel: store.cameraProfileLabel
            )
            return FilmtoneLivePreviewBundle(
                processor: processor,
                diagnostics: diagnostics
            )
        } catch {
            return nil
        }
    }

    /// S7: live capture preview for an owner-imported creative LUT.
    /// The LUT is treated as a creative Look LUT; source conversion
    /// remains app-owned through the synthetic Apple Log 2 capture
    /// source / probe when capture starts without an editor source.
    func makeLivePreviewGradeProcessor(
        captureCreativeLut lut: ParsedCubeLutDTO
    ) -> FilmtoneLivePreviewBundle? {
        guard let store else { return nil }
        let effectiveSource: SourceInfoDTO
        let effectiveProbe: SourceProbeDTO?
        if let source = store.source {
            effectiveSource = source
            effectiveProbe = store.probe
        } else {
            let synthetic = Self.liveCaptureSyntheticSource()
            effectiveSource = synthetic.source
            effectiveProbe = synthetic.probe
        }
        do {
            var transient = store.project
            transient.creativeLut = lut
            let request = try FilmtonePhase0Math.buildExportRequest(
                source: effectiveSource,
                probe: effectiveProbe,
                project: transient
            )
            let cameraProfile = store.project.cameraProfile
            let processor = try facade.makeLivePreviewGradeProcessor(
                request: request,
                appliedSavedLook: nil,
                cameraProfile: cameraProfile
            )
            let diagnostics = makeLivePreviewDiagnostics(
                request: request,
                forwardedSavedLook: nil,
                forwardedCameraProfile: cameraProfile,
                probe: store.probe,
                appliedSavedLookId: store.appliedSavedLookId,
                lookProfileLabel: store.lookProfileLabel,
                cameraProfileLabel: store.cameraProfileLabel
            )
            return FilmtoneLivePreviewBundle(
                processor: processor,
                diagnostics: diagnostics
            )
        } catch {
            return nil
        }
    }

    /// S3 take-picker preview: build a lightweight processor against the
    /// recorded proxy itself, then apply the capture-time Look metadata to
    /// thumbnail samples. This keeps the chooser visually aligned with the
    /// editor adoption path without putting AVPlayers in every take row.
    #if os(iOS)
    func makeCapturePackagePreviewGradeProcessor(
        _ package: FilmtoneCapturePackage
    ) async -> FilmtoneSharedGradeProcessor? {
        guard let store else { return nil }
        return await store.captureRelay.makeCapturePackagePreviewGradeProcessor(package)
    }
    #endif

    /// Source / probe descriptor for the live capture VDO stream when
    /// the editor has no loaded source (cold-start chip preview).
    ///
    /// Hard-coded against the M10 capture contract — the live VDO
    /// frames are guaranteed to be 4K24 ProRes 422 HQ Apple Log 2 by
    /// `FilmtoneCaptureSession.prepare(lens:)` (locked codec + Apple
    /// Log 2 colorSpace + 24fps device format), so the descriptor can
    /// be a static fixture instead of probing at runtime.  The grade
    /// chain only needs `inputTransformPolicy.strategy =
    /// .appleLog2ToRec709` to wire the correct input LUT — every
    /// other field is filled in to a defensible default so
    /// `Phase0ExportRequestDTO` and downstream sidecar/diagnostic
    /// readers don't trip on nil branches that never fire for real
    /// editor sources.  The placeholder uri uses a `file://` scheme
    /// (not a custom `filmtone://`) because `FilmtoneMediaRuntime.
    /// resolveFileURL` returns any URL whose `isFileURL == true`
    /// directly without an existence check — and the
    /// `FilmtoneSharedGradeProcessor.applyForLivePreview` path never
    /// reads from disk (frames come from the live VDO sink), so the
    /// path itself is irrelevant.  A custom scheme would throw inside
    /// `resolveFileURL` and silently nil out the chip preview.
    private static func liveCaptureSyntheticSource() -> (
        source: SourceInfoDTO,
        probe: SourceProbeDTO
    ) {
        let inputPolicy = SourceInputTransformPolicyDTO(
            strategy: .appleLog2ToRec709,
            reason: "source-is-apple-log2",
            requiresFixtureValidation: false,
            warning: nil
        )
        let display = SourceDisplayGeometryDTO(
            rawWidth: 3840,
            rawHeight: 2160,
            displayWidth: 3840,
            displayHeight: 2160,
            rotationDeg: 0,
            source: "raw"
        )
        let color = SourceColorMetadataDTO(
            colorRange: "tv",
            colorSpace: "bt2020nc",
            colorTransfer: "smpte2084",
            colorPrimaries: "bt2020",
            logTransferFunction: .appleLog2,
            hasMasteringDisplayMetadata: false,
            hasContentLightMetadata: false
        )
        let videoMetadata = SourceVideoMetadataDTO(
            display: display,
            color: color,
            colorClass: .appleLog2,
            hdrPreparationPolicy: nil,
            timing: SourceVideoTimingMetadataDTO(
                nominalFrameRate: 24.0,
                estimatedFrameRate: nil,
                sourceFrameRateTrusted: true,
                trustReason: "nominal-only"
            ),
            codecFamily: .prores422,
            logTransferFunction: .appleLog2,
            inputTransformPolicy: inputPolicy
        )
        let probe = SourceProbeDTO(
            uri: "file:///filmtone-capture-live-preview.mov",
            filename: "capture-live-preview.mov",
            kind: .video,
            mimeType: "video/quicktime",
            width: 3840,
            height: 2160,
            durationSec: 0,
            fileSizeBytes: 0,
            codec: "apch",
            codecFamily: .prores422,
            frameRate: 24.0,
            logTransferFunction: .appleLog2,
            inputTransformPolicy: inputPolicy,
            cameraOptics: nil,
            sourceVideoMetadata: videoMetadata,
            sourceToneDescriptor: nil
        )
        let source = SourceInfoDTO(
            uri: "file:///filmtone-capture-live-preview.mov",
            filename: "capture-live-preview.mov",
            kind: .video,
            mimeType: "video/quicktime",
            mezzanineStatus: nil,
            hasDepth: false
        )
        return (source, probe)
    }

    /// S8-F F3-R / F3-Fix #1: snapshot the editor's grade chain inputs
    /// at the moment the capture surface presents.
    ///
    /// `forwardedSavedLook` / `forwardedCameraProfile` are the values
    /// actually handed to `facade.makeLivePreviewGradeProcessor` —
    /// reflecting whether the wiring carried them through (post-fix:
    /// always `true` for camera profile; `true` for Saved Look iff one
    /// is currently applied and its entry resolved into the cache).
    /// Pre-fix these were hard-coded `false`; the chip's red `[!]
    /// camProf:N savedLook:N` warning was the F3-R wiring-gap signal.
    ///
    /// `probe` / `appliedSavedLookId` / `lookProfileLabel` /
    /// `cameraProfileLabel` are threaded in as parameters (rather than
    /// read from `store` here) because all three callers already have
    /// `store` unwrapped, and this method's return type is non-optional.
    private func makeLivePreviewDiagnostics(
        request: Phase0ExportRequestDTO,
        forwardedSavedLook: SavedLookEntry?,
        forwardedCameraProfile: CameraProfileSelection?,
        probe: SourceProbeDTO?,
        appliedSavedLookId: UUID?,
        lookProfileLabel: String,
        cameraProfileLabel: String
    ) -> FilmtoneLivePreviewDiagnostics {
        let creative = request.creativeLut
        // Mirrors the input-LUT selection inside
        // `ExportInputLutBuilder.makeActiveInputLut(for:probe:)`: explicit
        // built-in Camera Profiles use the catalog, while Auto falls back
        // to the probe's native inputTransformPolicy.
        let detectedTransform =
            probe?.inputTransformPolicy?.strategy.rawValue
            ?? probe?.sourceVideoMetadata?.inputTransformPolicy?.strategy.rawValue

        let inputLutWillApply: Bool = {
            if request.inputLut != nil { return true }
            if case .builtIn(let catalogId) = forwardedCameraProfile,
               let entry = FilmtoneSourceProfileCatalog.entry(forCatalogId: catalogId) {
                switch entry.impl {
                case .nilProfile:
                    return false
                case .nativePolicy, .synthesized, .bundledCube:
                    return true
                }
            }
            switch detectedTransform {
            case "appleLogToRec709", "appleLog2ToRec709":
                return true
            default:
                return false
            }
        }()

        let savedLookIdShort: String? = appliedSavedLookId.map {
            String($0.uuidString.prefix(8).lowercased())
        }

        return FilmtoneLivePreviewDiagnostics(
            lookLabel: lookProfileLabel,
            creativeLutPresent: creative != nil,
            creativeLutSize: creative?.size,
            creativeLutIntensity: creative?.intensity,
            creativeLutBundledSlug: creative?.bundledSlug,
            cameraProfileLabel: cameraProfileLabel,
            cameraProfilePassedToProcessor: forwardedCameraProfile != nil,
            savedLookId: savedLookIdShort,
            savedLookPassedToProcessor: forwardedSavedLook != nil,
            detectedInputTransform: detectedTransform,
            inputLutWillApply: inputLutWillApply,
            presetVersion: request.grade.presetVersion,
            exposure: request.grade.params.exposure,
            contrast: request.grade.params.contrast,
            saturation: request.grade.params.saturation,
            temperature: request.grade.params.temperature
        )
    }
}
