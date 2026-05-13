import AVFoundation
import Combine
import FilmLabSwiftCore
import Foundation
import SwiftUI

/// Phase 3C collaborator that owns iOS capture-surface relay state and
/// package adoption flow.
///
/// Responsibilities:
/// - Owns `@Published` storage for `recordingState`, `recordingError`,
///   `lastCapturePackage` (iOS), `currentCapturePackageRef` (iOS).
/// - Implements `recordProductClip(durationSeconds:)`,
///   `adoptCaptureResult(_:)`, and
///   `makeCapturePackagePreviewGradeProcessor(_:)`.
/// - Persistence rehydration (`rehydrate(currentCapturePackageRef:)`) and
///   source-change linkage clearing (`dropLinkageIfNotProxy`, `clearLinkage`)
///   so the facade's `init`/`applyProbe` keep the same invariants without
///   owning the M10 package state directly.
///
/// Re-enters the facade through internal helpers (`applyProbe`, `persist`,
/// `schedulePreviewRender`, `reclaimCacheForCurrentState`, `applySavedLook`,
/// `applyCaptureCustomLut`). Combine `objectWillChange.sink` bridges into
/// the facade's `objectWillChange` (Phase 3A/3B pattern) so SwiftUI view
/// code (`store.recordingError`, `store.recordingState`,
/// `store.lastCapturePackage`) keeps redrawing through
/// `@ObservedObject var store: FilmtoneEditorStore`.
///
/// `desktopHandoffPromptPresented` intentionally stays on the facade — it
/// is the only capture-flow surface with a real projected binding
/// (`$store.desktopHandoffPromptPresented` on a `.sheet`), and its single
/// write site lives in `pickSource` (which is not part of this phase's
/// move). Routing it through a relay-side `@Published` mirror would either
/// force a SwiftUI view edit or introduce a pass-through bridge.
@MainActor
final class EditorCaptureRelay: ObservableObject {
    @Published var recordingState: FilmtoneRecordingUIState?
    @Published var recordingError: String?
    #if os(iOS)
    @Published var lastCapturePackage: FilmtoneCapturePackage?
    @Published var currentCapturePackageRef: String?
    #endif

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

    // MARK: - Persistence rehydration / linkage management

    #if os(iOS)
    /// Re-hydrate the M10 capture-package linkage from a persisted JSON
    /// path. Missing JSON (cache eviction, user wiped storage) is benign —
    /// `currentCapturePackageRef` is cleared and the proxy source stays
    /// as a normal video; the master simply isn't reachable until the
    /// user re-records.
    func rehydrate(currentCapturePackageRef ref: String?) {
        currentCapturePackageRef = ref
        guard let ref else { return }
        if let pkg = FilmtoneCapturePackagePersistence.read(localPackageJSONPath: ref) {
            lastCapturePackage = pkg
        } else {
            currentCapturePackageRef = nil
        }
    }

    /// Source replacement breaks the capture-package linkage when the new
    /// source URI does not match the package proxy. `adoptCaptureResult`
    /// re-establishes the linkage immediately after the underlying
    /// `applyProbe`; `pickSource` and other replacement entry points
    /// legitimately drop the M10 master/proxy linkage.
    func dropLinkageIfNotProxy(of source: SourceInfoDTO) {
        if lastCapturePackage?.proxyURL.absoluteString != source.uri {
            lastCapturePackage = nil
            currentCapturePackageRef = nil
        }
    }

    /// Hard clear (used when the persisted source no longer exists on disk).
    func clearLinkage() {
        lastCapturePackage = nil
        currentCapturePackageRef = nil
    }
    #endif

    // MARK: - Product clip recording

    /// Records one fixed-duration ProRes 422 HQ Apple Log 2 clip with
    /// AVFoundation `cinematicExtendedEnhanced` stabilization, then adopts
    /// the resulting `clip.mov` as the active source — same downstream
    /// pipeline as `pickSource` (probe → applyProbe → persist → reclaim →
    /// schedulePreviewRender).
    func recordProductClip(durationSeconds: Double = 5.0) async {
        guard let store else { return }
        store.isBusy = true
        store.notice = strings.recordProductClipRunning
        store.error = nil
        recordingError = nil
        store.sourceLoadState = nil
        recordingState = FilmtoneRecordingUIState(
            startedAt: Date(),
            durationSeconds: durationSeconds
        )

        let capture = FilmtoneProductCapture()
        do {
            let result: FilmtoneProductCapture.RecordClipResult = try await withCheckedThrowingContinuation { continuation in
                capture.recordClip(durationSeconds: durationSeconds) { result in
                    continuation.resume(with: result)
                }
            }

            recordingState = nil

            let recordedSource = SourceInfoDTO(
                uri: result.movURL.absoluteString,
                filename: result.movURL.lastPathComponent,
                kind: .video,
                mimeType: "video/quicktime"
            )

            store.sourceLoadState = .init(
                stage: .probing,
                route: .photoLibrary,
                message: strings.probePending,
                progress: nil,
                isDeterminate: false
            )
            let probe = try facade.probeSource(recordedSource)
            store.applyProbe(source: recordedSource, probe: probe)
            store.isBusy = false
            store.sourceLoadState = nil
            store.notice = nil
            store.persist()
            store.reclaimCacheForCurrentState()
            store.schedulePreviewRender()
        } catch {
            recordingState = nil
            store.isBusy = false
            store.sourceLoadState = nil
            store.notice = nil
            let detail: String
            if let recordError = error as? FilmtoneProductCapture.RecordClipError {
                detail = recordError.errorDescription ?? String(describing: recordError)
            } else {
                detail = (error as NSError).localizedDescription
            }
            recordingError = detail
        }
    }

    // MARK: - Capture package adoption (M10)

    #if os(iOS)
    /// Adopts a `FilmtoneCapturePackage` produced by the M10 native capture
    /// surface. Probes the **proxy** (not the master) and applies the
    /// resulting probe through the same downstream pipeline as `pickSource`
    /// / `recordProductClip`. The capture package itself is retained on
    /// `lastCapturePackage` so downstream operations (export-from-master /
    /// share-master) can resolve the security-scoped external folder URL
    /// when needed. The capture-time Look chip is re-applied against the
    /// proxy so the editor opens in the same chain the live preview
    /// rendered during capture.
    func adoptCaptureResult(_ package: FilmtoneCapturePackage) async {
        guard let store else { return }
        store.isBusy = true
        store.notice = nil
        store.error = nil
        recordingError = nil
        recordingState = nil
        store.sourceLoadState = .init(
            stage: .probing,
            route: .photoLibrary,
            message: strings.probePending,
            progress: nil,
            isDeterminate: false
        )

        let proxySource = SourceInfoDTO(
            uri: package.proxyURL.absoluteString,
            filename: package.proxyURL.lastPathComponent,
            kind: .video,
            mimeType: "video/quicktime"
        )

        do {
            let probe = try facade.probeSource(proxySource)
            store.applyProbe(source: proxySource, probe: probe)
            lastCapturePackage = package
            // Capture session itself writes `capture-package.json` on
            // .completed transition (and hard-fails the run if that write
            // fails). Defense in depth: re-write if missing, and only set
            // the ref when the file is provably on disk so a relaunch can
            // read it.
            let localJSONURL = package.packageDirURL.appendingPathComponent(
                FilmtoneCapturePackagePersistence.snapshotFilename,
                isDirectory: false
            )
            if !FileManager.default.fileExists(atPath: localJSONURL.path) {
                _ = FilmtoneCapturePackagePersistence.write(package: package)
            }
            if FileManager.default.fileExists(atPath: localJSONURL.path) {
                currentCapturePackageRef = localJSONURL.path
            } else {
                currentCapturePackageRef = nil
            }
            // S11-E: re-apply the capture-time Look chip against the proxy
            // so the editor opens in the same chain the live preview
            // rendered during capture. Stone / Urban `canonicalUUID`s
            // resolve through `libraryController.loadLook(id:)` →
            // `FilmtoneBuiltInCatalog.materializeAsSavedLookEntry`, routing
            // through the same `.bundled` cube + Adaptation wiring as the
            // chip strip and the editor's library sheet. Cancel never
            // reaches this branch — `adoptCaptureResult` is only entered on
            // `.completed(package)`. `applySavedLook` surfaces its own
            // `error` / `presentToast` on bundled-cube SHA-256 mismatch or
            // missing resource; the `await` blocks adoption until the apply
            // settles so the trailing `schedulePreviewRender()` reflects
            // the Look state rather than the pre-Look state.
            if let canonicalUUID = package.selectedLook?.canonicalUUID {
                await store.applySavedLook(id: canonicalUUID)
            } else if let customLut = package.customLut {
                await store.applyCaptureCustomLut(customLut)
            }
            store.isBusy = false
            store.sourceLoadState = nil
            store.persist()
            store.reclaimCacheForCurrentState()
            store.schedulePreviewRender()
        } catch {
            store.isBusy = false
            store.sourceLoadState = nil
            let detail = (error as NSError).localizedDescription
            recordingError = detail
        }
    }
    #endif

    // MARK: - Capture package preview processor (S3 take-picker)

    #if os(iOS)
    /// S3 take-picker preview: build a lightweight processor against the
    /// recorded proxy itself, then apply the capture-time Look metadata to
    /// thumbnail samples. Keeps the chooser visually aligned with the
    /// editor adoption path without putting AVPlayers in every take row.
    func makeCapturePackagePreviewGradeProcessor(
        _ package: FilmtoneCapturePackage
    ) async -> FilmtoneSharedGradeProcessor? {
        guard let store else { return nil }
        guard package.selectedLook != nil || package.customLut != nil else {
            return nil
        }

        let proxySource = SourceInfoDTO(
            uri: package.proxyURL.absoluteString,
            filename: package.proxyURL.lastPathComponent,
            kind: .video,
            mimeType: "video/quicktime"
        )

        do {
            let probe = try facade.probeSource(proxySource)
            var transient = store.project
            var savedLookEntry: SavedLookEntry?

            if let canonicalUUID = package.selectedLook?.canonicalUUID,
               let builtIn = FilmtoneBuiltInCatalog.look(matching: canonicalUUID) {
                transient.presetName = FilmtonePhase0Math.safePresetName(builtIn.presetName)
                transient.presetVersion = FilmtonePhase0Math.presetVersion
                transient.strength = FilmtonePhase0Math.clampStrength(builtIn.strength)
                transient.quickState = builtIn.quickState.clamped()

                var paramOverrides = builtIn.paramOverrides
                var resolvedCreativeLut: ParsedCubeLutDTO?
                if case let .bundled(slug, filename, pinnedSha256, intensity) = builtIn.creativeLut {
                    resolvedCreativeLut = FilmtoneEditorStore.loadBundledCreativeLut(
                        slug: slug,
                        filename: filename,
                        pinnedSha256: pinnedSha256,
                        intensity: intensity,
                        packId: builtIn.packId ?? FilmtoneBuiltInCatalog.creativePack01Id
                    )
                }
                if let adaptation = FilmtoneCreativePack01Adaptation.resolve(
                    slug: builtIn.slug,
                    descriptor: probe.sourceToneDescriptor,
                    sourceProfileId: FilmtoneLookDirector.sourceProfileId(
                        for: store.project.cameraProfile
                    ),
                    sourceDetailBias: FilmtoneLookDirector.resolveSourceDetailBias(
                        probe: probe,
                        cameraProfile: store.project.cameraProfile
                    )
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

                if let loaded = try? await libraryController.loadLook(id: canonicalUUID) {
                    savedLookEntry = loaded
                } else {
                    savedLookEntry = FilmtoneBuiltInCatalog.materializeAsSavedLookEntry(
                        builtIn,
                        favoriteOverride: false,
                        asOf: Date()
                    )
                }
            } else if let customLut = package.customLut,
                      let libraryId = customLut.libraryId,
                      let parsed = try await libraryController.loadLut(id: libraryId) {
                transient.creativeLut = parsed.withIntensity(customLut.intensity)
            } else {
                return nil
            }

            let request = try FilmtonePhase0Math.buildExportRequest(
                source: proxySource,
                probe: probe,
                project: transient
            )
            return try facade.makeLivePreviewGradeProcessor(
                request: request,
                appliedSavedLook: savedLookEntry,
                cameraProfile: store.project.cameraProfile
            )
        } catch {
            return nil
        }
    }
    #endif
}
