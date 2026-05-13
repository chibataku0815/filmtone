import FilmLabSwiftCore
import Foundation

/// Phase 3B collaborator that owns project-state mutation orchestration.
///
/// Responsibilities:
/// - Picker-driven LUT import (input / creative / capture user-LUT).
/// - Library-driven LUT apply (`applyLibraryLut`, `applyCaptureCustomLut`).
/// - Saved Look save + apply (`saveCurrentLook`, `applySavedLook`).
/// - The shared `applyLutMutation` pipeline (mutate project → bump updatedAt
///   → invalidate render output → persist → reschedule preview).
/// - Per-slot LUT clear + intensity setters (`clearInputLut`, etc.).
///
/// View-facing facade keeps the same `FilmtoneEditorStore` method names; each
/// call is a 1-line forward into this collaborator. The coordinator holds a
/// `weak` back-reference to the store and re-enters through internal helpers
/// (`invalidateRenderedOutputState`, `persist`, `refreshLibrarySnapshot`,
/// `recomputeProjectParamsPreservingOpticsGlow`) for shared mutation
/// post-processing. Those helpers widened from `private` to internal access
/// for this Phase 3B bundle.
@MainActor
final class EditorProjectMutationCoordinator {
    private let facade: FilmtoneEditorFacade
    private let libraryController: EditorLibraryController
    private let projectController: EditorProjectController
    private let strings: FilmtoneStrings
    private weak var store: FilmtoneEditorStore?

    init(
        facade: FilmtoneEditorFacade,
        libraryController: EditorLibraryController,
        projectController: EditorProjectController,
        strings: FilmtoneStrings
    ) {
        self.facade = facade
        self.libraryController = libraryController
        self.projectController = projectController
        self.strings = strings
    }

    func attach(_ store: FilmtoneEditorStore) {
        self.store = store
    }

    // MARK: - LUT Import

    func importInputLut() async {
        guard let store else { return }
        do {
            guard let lut = try await facade.pickCubeLut() else {
                return
            }
            await persistImportedLutToLibrary(lut, slot: .input)
            store.appliedSavedLookId = nil
            applyLutMutation {
                $0.inputLut = lut
            }
        } catch {
            if let mediaError = error as? FilmtoneMediaError,
               mediaError.code == "UNSUPPORTED_SOURCE" {
                store.error = strings.lutParseError
            } else {
                store.error = strings.userMessage(for: error, context: .importLut)
            }
        }
    }

    func importCreativeLut() async {
        guard let store else { return }
        do {
            guard let lut = try await facade.pickCubeLut() else {
                return
            }
            await persistImportedLutToLibrary(lut, slot: .creative)
            store.appliedSavedLookId = nil
            applyLutMutation {
                $0.creativeLut = lut
            }
        } catch {
            if let mediaError = error as? FilmtoneMediaError,
               mediaError.code == "UNSUPPORTED_SOURCE" {
                store.error = strings.lookLutParseError
            } else {
                store.error = strings.userMessage(for: error, context: .importCreativeLut)
            }
        }
    }

    /// S7: capture-surface import path. Unlike `importCreativeLut()`,
    /// this does not mutate the editor project immediately. It persists
    /// the cube into the LUT library and returns a capture Look record
    /// the capture surface can preview and stamp into the package.
    func importCaptureUserLut() async -> FilmtoneCaptureLook? {
        guard let store else { return nil }
        do {
            guard let picked = try await facade.pickCubeLutFile() else {
                return nil
            }
            guard let result = try await libraryController.importLut(
                parsedLut: picked.lut,
                originalFilename: picked.originalFilename,
                preferredSlot: .creative
            ) else {
                store.error = strings.userMessage(
                    for: FilmtoneMediaError.bridgeUnavailable,
                    context: .importCreativeLut
                )
                return nil
            }
            guard let parsed = try await libraryController.loadLut(id: result.entry.id) else {
                return nil
            }
            await store.refreshLibrarySnapshot()
            return FilmtoneCaptureLook.userLut(
                entry: result.entry,
                parsedLut: parsed
            )
        } catch {
            if let mediaError = error as? FilmtoneMediaError,
               mediaError.code == "UNSUPPORTED_SOURCE" {
                store.error = strings.lookLutParseError
            } else if let storeError = error as? LibraryStoreActor.StoreError,
                      case .quotaExceeded = storeError {
                store.error = strings.libraryQuotaExceeded
            } else {
                store.error = strings.userMessage(for: error, context: .importCreativeLut)
            }
            return nil
        }
    }

    func loadCaptureUserLut(entry: LutLibraryEntry) async -> FilmtoneCaptureLook? {
        guard let store else { return nil }
        guard libraryController.isAvailable else {
            return nil
        }
        do {
            guard let parsed = try await libraryController.loadLut(id: entry.id) else {
                return nil
            }
            await libraryController.touchLutLastUsed(id: entry.id)
            await store.refreshLibrarySnapshot()
            return FilmtoneCaptureLook.userLut(entry: entry, parsedLut: parsed)
        } catch {
            store.error = strings.libraryLutMissingOnApply
            return nil
        }
    }

    /// Persist a freshly-picked LUT into the library so it shows up in
    /// Recent. Quota / dedup logic lives in the actor; if persistence fails
    /// we still apply the LUT to the project — library-disabled mode is a
    /// degraded but acceptable state, never a hard editor failure.
    private func persistImportedLutToLibrary(
        _ lut: ParsedCubeLutDTO,
        slot: SlotHint
    ) async {
        guard let store else { return }
        guard libraryController.isAvailable else {
            return
        }
        do {
            _ = try await libraryController.importLut(
                parsedLut: lut,
                originalFilename: nil,
                preferredSlot: slot
            )
            await store.refreshLibrarySnapshot()
        } catch let storeError as LibraryStoreActor.StoreError {
            // Surface quota errors but never block the in-memory LUT apply —
            // the user can keep working, they just won't see the entry in
            // Recent until they free up space and re-import.
            if case .quotaExceeded = storeError {
                store.error = strings.libraryQuotaExceeded
            }
        } catch {
            // Swallow other library errors (disk write failure etc.); they
            // are non-load-bearing for the in-memory editor.
        }
    }

    // MARK: - LUT Apply

    /// Apply a LUT from the library to the named slot. Tap-to-apply path on
    /// the Recent strip routes through here so we (a) reuse the existing
    /// `applyLutMutation` invalidate/persist path, (b) bump the entry's
    /// `lastUsedAt`, and (c) touch the slot's intensity according to the
    /// entry's `defaultIntensity`.
    func applyLibraryLut(libraryId: UUID, slot: SlotHint) async {
        guard let store else { return }
        guard libraryController.isAvailable else {
            return
        }
        do {
            guard let parsed = try await libraryController.loadLut(id: libraryId) else {
                return
            }
            await libraryController.touchLutLastUsed(id: libraryId)
            await store.refreshLibrarySnapshot()
            store.appliedSavedLookId = nil
            applyLutMutation { state in
                switch slot {
                case .input:
                    state.inputLut = parsed
                case .creative, .any:
                    state.creativeLut = parsed
                }
            }
        } catch {
            store.error = strings.libraryLutMissingOnApply
        }
    }

    func applyCaptureCustomLut(_ record: FilmtoneCaptureCustomLutRecord) async {
        guard let store else { return }
        guard libraryController.isAvailable, let libraryId = record.libraryId else {
            store.error = strings.libraryLutMissingOnApply
            return
        }
        do {
            guard let parsed = try await libraryController.loadLut(
                id: libraryId,
                intensity: record.intensity
            ) else {
                store.error = strings.libraryLutMissingOnApply
                return
            }
            await libraryController.touchLutLastUsed(id: libraryId)
            await store.refreshLibrarySnapshot()
            store.appliedSavedLookId = nil
            applyLutMutation { state in
                state.creativeLut = parsed
            }
        } catch {
            store.error = strings.libraryLutMissingOnApply
        }
    }

    // MARK: - Saved Look

    /// Snapshot the current creative state into a Saved Look. Source-side
    /// (input LUT / source URI / source probe) is intentionally **not**
    /// captured — those are source-locally re-derived per `applyProbe`.
    @discardableResult
    func saveCurrentLook(name: String) async -> SavedLookEntry? {
        guard let store else { return nil }
        guard libraryController.isAvailable else {
            return nil
        }
        let creativeBinding = await currentCreativeLutBinding()
        // Stamp optics + glow into the Look's identity. Built-in Looks
        // (Stone / Urban) hardcode these; user-saved Looks would otherwise
        // omit any key the user did not personally tune, leaving the Look's
        // optical signature dependent on whichever preset baseline applies it.
        let densifiedOverrides = store.project.paramOverrides
            .densifyingOpticsGlow(from: store.project.params)
        do {
            guard let entry = try await libraryController.saveLook(
                name: name,
                presetName: store.project.presetName,
                presetVersion: FilmtonePhase0Math.presetVersion,
                strength: store.project.strength,
                quickState: store.project.quickState,
                paramOverrides: densifiedOverrides,
                creativeLut: creativeBinding
            ) else {
                return nil
            }
            await store.refreshLibrarySnapshot()
            store.appliedSavedLookId = entry.id
            projectController.setAppliedSavedLookEntry(entry)
            store.presentToast(
                String(format: strings.lookSavedToastFormat, entry.name),
                kind: .success
            )
            return entry
        } catch {
            store.error = strings.userMessage(for: error, context: .importLut)
            return nil
        }
    }

    /// Find or create the `CreativeLutBinding` that represents the current
    /// `project.creativeLut`. We prefer a `libraryRef` when the LUT's content
    /// hash matches an existing library entry; otherwise we register the LUT
    /// as a new library entry so the look survives delete-from-library.
    private func currentCreativeLutBinding() async -> CreativeLutBinding? {
        guard let store else { return nil }
        guard let creativeLut = store.project.creativeLut else {
            return nil
        }
        guard libraryController.isAvailable else {
            return nil
        }
        do {
            guard let result = try await libraryController.importLut(
                parsedLut: creativeLut,
                originalFilename: nil,
                preferredSlot: .creative
            ) else {
                return nil
            }
            // result.entry.id always represents the canonical library entry
            // for this hash — dedup hit reuses the existing one, miss creates.
            if !result.deduped {
                await store.refreshLibrarySnapshot()
            }
            return .libraryRef(id: result.entry.id, intensity: creativeLut.intensity)
        } catch {
            // If the import itself failed (quota etc.), embed the data
            // inline so the look still saves and stays applicable.
            let hash = (try? FilmtoneLutBlobCodec.sourceHash(
                data: creativeLut.data,
                size: creativeLut.size
            )) ?? ""
            let embedded = SavedLookEmbeddedLut(
                title: creativeLut.title,
                size: creativeLut.size,
                data: creativeLut.data,
                sourceHash: hash
            )
            return .embedded(lut: embedded, intensity: creativeLut.intensity)
        }
    }

    /// Apply a saved Look's creative state to the project.
    ///
    /// Per the Item 3 plan §"Apply-Saved-Look Semantics":
    /// - Overwrites: `presetName`, `strength`, `quickState`, `paramOverrides`
    ///   (and the resolved `params` derived from them), `creativeLut`,
    ///   creative-LUT intensity.
    /// - Does NOT touch: `project.inputLut`, source URI, source probe.
    ///   The source-side normalization is deliberately source-local — the
    ///   look survives source swaps, the camera profile does not.
    func applySavedLook(id: UUID) async {
        guard let store else { return }
        guard libraryController.isAvailable else {
            return
        }
        do {
            guard let entry = try await libraryController.loadLook(id: id) else {
                return
            }
            var resolvedCreativeLut: ParsedCubeLutDTO?
            var creativePack01Adaptation: FilmtoneCreativePack01Adaptation.Resolved?
            var lutMissingForApply = false

            switch entry.creativeLut {
            case .libraryRef(let lutId, let intensity):
                if let _ = store.library.lutEntry(id: lutId) {
                    do {
                        resolvedCreativeLut = try await libraryController.loadLut(
                            id: lutId,
                            intensity: intensity
                        )
                        if resolvedCreativeLut == nil {
                            lutMissingForApply = true
                        } else {
                            await libraryController.touchLutLastUsed(id: lutId)
                        }
                    } catch {
                        lutMissingForApply = true
                    }
                } else {
                    lutMissingForApply = true
                }
            case .embedded(let lut, let intensity):
                resolvedCreativeLut = ParsedCubeLutDTO(
                    title: lut.title,
                    size: lut.size,
                    data: lut.data,
                    intensity: FilmtonePhase0Math.clampLutIntensity(intensity)
                )
            case .bundled(let slug, let filename, let pinnedSha256, let intensity):
                // v1.4 Creative LUT Pack 01: resolve from Bundle.main under
                // `Resources/CreativeLuts/`. fail-closed — if the resource is
                // missing or its SHA-256 does not match the pinned value, we
                // surface the same `lutMissingForApply` toast as for a deleted
                // library entry rather than silently degrading
                // (`feedback_no_fallback_bug_hotbed`).
                if let resolved = FilmtoneEditorStore.loadBundledCreativeLut(
                    slug: slug,
                    filename: filename,
                    pinnedSha256: pinnedSha256,
                    intensity: intensity,
                    packId: FilmtoneBuiltInCatalog.creativePack01Id
                ) {
                    resolvedCreativeLut = resolved
                    creativePack01Adaptation = FilmtoneCreativePack01Adaptation.resolve(
                        slug: slug,
                        descriptor: store.probe?.sourceToneDescriptor,
                        sourceProfileId: FilmtoneLookDirector.sourceProfileId(
                            for: store.project.cameraProfile
                        ),
                        sourceDetailBias: FilmtoneLookDirector.resolveSourceDetailBias(
                            probe: store.probe,
                            cameraProfile: store.project.cameraProfile
                        )
                    )
                } else {
                    lutMissingForApply = true
                }
            case .none:
                resolvedCreativeLut = nil
            }

            applyLutMutation { state in
                state.presetName = FilmtonePhase0Math.safePresetName(entry.presetName)
                // v1.4 backward compat — stamp the saved Look's preset version
                // onto the project so the export pipeline dispatches v1 kernel
                // for v1 saves and v2 kernel for v2 saves. handoff §10 guard.
                state.presetVersion = entry.presetVersion
                state.strength = FilmtonePhase0Math.clampStrength(entry.strength)
                state.quickState = entry.quickState.clamped()
                var paramOverrides = entry.paramOverrides
                if let creativePack01Adaptation {
                    for (key, value) in creativePack01Adaptation.paramOverrides.values {
                        paramOverrides.values[key] = value
                    }
                }
                state.paramOverrides = paramOverrides
                if let creativePack01Adaptation, let resolvedCreativeLut {
                    state.creativeLut = resolvedCreativeLut.withIntensity(creativePack01Adaptation.intensity)
                } else {
                    state.creativeLut = resolvedCreativeLut
                }
                // Note: state.inputLut is intentionally untouched — the look
                // is source-independent. See applySavedLook docs above.
            }
            store.recomputeProjectParamsPreservingOpticsGlow()
            store.appliedSavedLookId = entry.id
            projectController.setAppliedSavedLookEntry(entry)
            await store.refreshLibrarySnapshot()

            if lutMissingForApply {
                store.error = strings.libraryLutMissingOnApply
            } else {
                store.presentToast(
                    String(format: strings.lookAppliedToastFormat, entry.name),
                    kind: .info
                )
            }
        } catch {
            store.error = strings.userMessage(for: error, context: .importCreativeLut)
        }
    }

    // MARK: - LUT clear / intensity

    func clearInputLut() {
        guard let store else { return }
        store.appliedSavedLookId = nil
        applyLutMutation {
            $0.inputLut = nil
        }
    }

    func clearCreativeLut() {
        guard let store else { return }
        store.appliedSavedLookId = nil
        applyLutMutation {
            let presetName = FilmtonePhase0Generated.presetDefault
            $0.creativeLut = nil
            $0.presetName = presetName
            $0.presetVersion = FilmtonePhase0Math.presetVersion
            $0.strength = FilmtonePhase0Math.presetStrengthDefault
            $0.quickState = .zero
            $0.paramOverrides = .empty
            $0.params = FilmtonePhase0Math.deriveParams(
                presetName: presetName,
                strength: FilmtonePhase0Math.presetStrengthDefault,
                quickState: .zero
            )
        }
    }

    func setInputLutIntensity(_ intensity: Double) {
        guard let store else { return }
        let clampedIntensity = FilmtonePhase0Math.clampLutIntensity(intensity)
        guard let currentLut = store.project.inputLut, currentLut.intensity != clampedIntensity else {
            return
        }
        store.appliedSavedLookId = nil
        applyLutMutation {
            guard let lut = $0.inputLut else {
                return
            }
            $0.inputLut = lut.withIntensity(clampedIntensity)
        }
    }

    func setCreativeLutIntensity(_ intensity: Double) {
        guard let store else { return }
        let clampedIntensity = FilmtonePhase0Math.clampLutIntensity(intensity)
        guard let currentLut = store.project.creativeLut, currentLut.intensity != clampedIntensity else {
            return
        }
        store.appliedSavedLookId = nil
        applyLutMutation {
            guard let lut = $0.creativeLut else {
                return
            }
            $0.creativeLut = lut.withIntensity(clampedIntensity)
        }
    }

    // MARK: - Shared mutation pipeline

    /// Mutate-then-finalize the project state: bump `updatedAt`, invalidate
    /// any rendered output, persist to disk, and reschedule a preview. All
    /// LUT slot mutations route through here so the post-mutation pipeline
    /// stays in a single place.
    private func applyLutMutation(_ mutate: (inout FilmtoneProjectState) -> Void) {
        guard let store else { return }
        mutate(&store.project)
        store.project.updatedAt = FilmtonePhase0Math.isoTimestamp()
        store.invalidateRenderedOutputState()
        store.persist()
        store.previewOrchestrator.schedule()
    }
}
