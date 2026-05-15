import FilmLabSwiftCore
import Foundation

/// Phase 3B collaborator that owns export + cache lifecycle state.
///
/// Responsibilities:
/// - Owns `@Published` storage for `exportProgress`, `exportResult`,
///   `exportLocalAvailability`, `saveToPhotosState`, `isSavingToPhotos`,
///   `cacheInventory`, `isReleasingCache` so the facade only forwards.
/// - Owns master/proxy resolution (`ResolvedExportSource`,
///   `ExportSourceDecision`) and the sidecar capture-provenance mapping.
/// - Runs `export()` / `exportAndSave()` / `saveToPhotos()` /
///   `shareOutput()` / `exportHighlightReel()` against
///   `FilmtoneEditorFacade`.
/// - Owns cache reclamation flows (`loadCacheInventory`, `releaseCache`,
///   `reclaimCacheForCurrentState`, `reclaimCacheForBackground`) and the
///   `protectedCacheURIs` projection that straddles source + export +
///   preview state.
/// - Provides `resetForSourceChange()` / `invalidateForProjectChange()` /
///   `applyFixture(...)` hooks used by the facade during source / project
///   mutation flows so the legacy invariants survive without exposing the
///   individual `@Published` setters across the boundary.
///
/// Combine `objectWillChange.sink` bridges into the facade's
/// `objectWillChange` (Phase 3A preview pattern) so SwiftUI redraws via
/// `@ObservedObject var store` continue working without view-side change.
@MainActor
final class EditorExportCoordinator: ObservableObject {
    @Published var exportProgress: Phase0ExportProgressDTO?
    @Published var exportResult: Phase0ExportResultDTO?
    @Published var exportLocalAvailability: FilmtoneExportLocalAvailability = .none
    @Published var saveToPhotosState: FilmtoneSaveToPhotosState = .notRun
    @Published var isSavingToPhotos = false
    @Published private(set) var cacheInventory: CacheInventoryDTO?
    @Published private(set) var isReleasingCache = false

    private let facade: FilmtoneEditorFacade
    private let projectController: EditorProjectController
    private let libraryController: EditorLibraryController
    private let strings: FilmtoneStrings
    private weak var store: FilmtoneEditorStore?

    init(
        facade: FilmtoneEditorFacade,
        projectController: EditorProjectController,
        libraryController: EditorLibraryController,
        strings: FilmtoneStrings
    ) {
        self.facade = facade
        self.projectController = projectController
        self.libraryController = libraryController
        self.strings = strings
    }

    func attach(_ store: FilmtoneEditorStore) {
        self.store = store
    }

    // MARK: - Capability projections

    var canUseLocalExport: Bool {
        exportResult != nil && exportLocalAvailability == .available
    }

    // MARK: - Master/proxy export source resolution (M14-A / M14-B)

    /// M14-A: which file the export pipeline ended up sourcing from.
    /// Used to drive the post-export toast wording so the owner can
    /// tell whether the artifact is the high-quality master path or
    /// the proxy fallback.
    enum ExportSourceDecision: Equatable {
        /// No capture package in play (Photos / Files edit). The
        /// existing `source` + `probe` are used unchanged. Toast keeps
        /// the legacy "Export complete" wording so non-capture flows
        /// do not pick up master / proxy language.
        case noCapturePackage
        /// Capture package master is reachable + probed cleanly. Export
        /// runs from the master. Toast: "Exported from master".
        case usingMaster
        /// Capture package master file is missing on disk. Falls back
        /// to proxy. Toast: "Exported from proxy — master not reachable".
        case usingProxyMasterMissing
        /// Capture package master file exists but cannot be probed
        /// (permission denied, malformed file, security-scoped resource
        /// access not held). Falls back to proxy.
        case usingProxyMasterUnreadable(reason: String)
    }

    /// M14-A resolution result. The export pipeline consumes
    /// `(source, probe)`; the `decision` drives toast wording.
    ///
    /// M14-B: also carries a `scopedURL` for the case where the
    /// resolver acquired security-scope on a SSD master file via the
    /// package's `masterBookmark`. The export call site MUST defer
    /// `release()` so scope is dropped on every exit path.
    struct ResolvedExportSource {
        let source: SourceInfoDTO?
        let probe: SourceProbeDTO?
        let decision: ExportSourceDecision
        /// URL we currently hold a security-scoped resource access on.
        /// `nil` for internal masters and proxy fallbacks.
        fileprivate let scopedURL: URL?

        /// Drop the held security scope. Idempotent — calling
        /// `release()` more than once or on a `.scopedURL == nil`
        /// instance is a no-op. Always paired with a `defer` at the
        /// call site so abnormal exits do not leak scope.
        func release() {
            scopedURL?.stopAccessingSecurityScopedResource()
        }
    }

    /// M14-A + M14-B: pick master vs proxy at export time. Photos /
    /// Files edits pass through unchanged via `.noCapturePackage`.
    /// Capture-package edits prefer the master when reachable.
    ///
    /// Resolution order:
    /// 1. **Bookmark resolution + scope acquire** (M14-B). If the
    ///    package carries a `masterBookmark`, resolve it and start
    ///    scoped access. On failure (stale bookmark, scope denied),
    ///    fall through with no scope held.
    /// 2. **fileExists** — catches deleted-internal and unmounted-SSD
    ///    cases.
    /// 3. **facade.probeSource(masterSource)** — catches
    ///    permission-denied (no scope held + iOS sandbox refusing
    ///    read), malformed-file, codec-not-supported.
    ///
    /// Every fallback branch drops the bookmark scope before returning
    /// (we only retain scope on `.usingMaster` because that's the only
    /// branch where the export pipeline will actually read the file).
    /// The `release()` defer at the call site handles the success
    /// branch.
    private func resolveExportSource() -> ResolvedExportSource {
        guard let store else {
            return ResolvedExportSource(
                source: nil,
                probe: nil,
                decision: .noCapturePackage,
                scopedURL: nil
            )
        }
        guard let package = store.lastCapturePackage, let proxyProbe = store.probe else {
            return ResolvedExportSource(
                source: store.source,
                probe: store.probe,
                decision: .noCapturePackage,
                scopedURL: nil
            )
        }

        // M14-B: if the package carries a bookmark, try to resolve +
        // acquire scope before any reachability check. This is what
        // unlocks SSD master export across capture-view dismissal and
        // app relaunch.
        var heldScopeURL: URL?
        if let bookmark = package.masterBookmark,
           let resolvedURL = FilmtoneSecurityScopedBookmark.resolve(bookmark) {
            if resolvedURL.startAccessingSecurityScopedResource() {
                heldScopeURL = resolvedURL
                NSLog(
                    "[M14-B] master bookmark resolved + scope acquired at %@",
                    resolvedURL.path
                )
            } else {
                NSLog(
                    "[M14-B] bookmark resolved at %@ but scope acquire denied — falling back",
                    resolvedURL.path
                )
            }
        }

        let masterURL = package.masterURL
        guard FileManager.default.fileExists(atPath: masterURL.path) else {
            heldScopeURL?.stopAccessingSecurityScopedResource()
            NSLog("[M14-A] master missing at %@ — falling back to proxy export", masterURL.path)
            return ResolvedExportSource(
                source: store.source,
                probe: proxyProbe,
                decision: .usingProxyMasterMissing,
                scopedURL: nil
            )
        }

        let masterSource = SourceInfoDTO(
            uri: masterURL.absoluteString,
            filename: masterURL.lastPathComponent,
            kind: .video,
            mimeType: "video/quicktime"
        )

        do {
            let masterProbe = try facade.probeSource(masterSource)
            NSLog("[M14-A] master reachable + probed at %@ — exporting from master", masterURL.path)
            return ResolvedExportSource(
                source: masterSource,
                probe: masterProbe,
                decision: .usingMaster,
                scopedURL: heldScopeURL
            )
        } catch {
            heldScopeURL?.stopAccessingSecurityScopedResource()
            let reason = (error as NSError).localizedDescription
            NSLog("[M14-A] master probe failed (%@) — falling back to proxy export", reason)
            return ResolvedExportSource(
                source: store.source,
                probe: proxyProbe,
                decision: .usingProxyMasterUnreadable(reason: reason),
                scopedURL: nil
            )
        }
    }

    /// M14-A: maps the export-source decision to the right localized
    /// success toast. Non-capture sources keep the legacy
    /// "Export complete" wording so the master / proxy language only
    /// appears where it is meaningful.
    private func toastForDecision(_ decision: ExportSourceDecision) -> String {
        switch decision {
        case .noCapturePackage:
            return strings.toastExportComplete
        case .usingMaster:
            return strings.toastExportUsedMaster
        case .usingProxyMasterMissing, .usingProxyMasterUnreadable:
            return strings.toastExportUsedProxyMasterUnavailable
        }
    }

    /// M14-C (2026-05-09): map the M14-A `ExportSourceDecision` into
    /// the sidecar's `SidecarCaptureProvenance` block. Returns nil
    /// when the export source is not a capture package (Photos /
    /// Files edits) — sidecar omits the block entirely in that case.
    ///
    /// The `lastCapturePackage` parameter is captured from the store's
    /// in-memory state at export-trigger time so we can record both
    /// the master URI (always, even on proxy fallback so DaVinci
    /// importers can see what was *intended*) and the proxy URI (only
    /// on fallback so consumers can identify the actual artifact).
    private func sidecarCaptureProvenance(
        from decision: ExportSourceDecision,
        package: FilmtoneCapturePackage?
    ) -> SidecarCaptureProvenance? {
        guard let package else {
            return nil
        }
        let masterURI = package.masterURL.absoluteString
        let proxyURI = package.proxyURL.absoluteString
        // S1 (2026-05-09): carry the requested + observed
        // stabilization truth into every capture-sourced sidecar so a
        // future audit can reconstruct what the owner asked for and
        // what AVFoundation actually delivered.  Pre-S1 packages
        // decoded from disk infer `.on` from the legacy
        // `parameters.stabilization` string and leave
        // `observedStabilization` nil; the encoder omits absent fields
        // (`encodeIfPresent`) so older sidecars stay byte-identical.
        let requested = package.parameters.requestedStabilization.rawValue
        let observed = package.observedStabilization
        let requestedRotation = package.requestedCaptureRotationDegrees
        let observedRotation = package.observedCaptureRotationDegrees
        let customLut = package.customLut
        func makeProvenance(
            mode: String,
            reason: String?,
            masterUriUsed: String?,
            proxyUriUsed: String?
        ) -> SidecarCaptureProvenance {
            SidecarCaptureProvenance(
                mode: mode,
                reason: reason,
                masterUriUsed: masterUriUsed,
                proxyUriUsed: proxyUriUsed,
                requestedStabilization: requested,
                observedStabilization: observed,
                requestedCaptureRotationDegrees: requestedRotation,
                observedCaptureRotationDegrees: observedRotation,
                customLutTitle: customLut?.title,
                customLutLibraryId: customLut?.libraryId?.uuidString,
                customLutSourceHash: customLut?.sourceHash,
                customLutSize: customLut?.size,
                customLutIntensity: customLut?.intensity,
                customLutConversionPolicy: customLut?.conversionPolicy,
                customLutTransformWarningAccepted: customLut?.transformWarningAccepted,
                customLutTransformWarningReason: customLut?.transformWarningReason,
                customLutTransformWarningKind: customLut?.transformWarningKind,
                customLutTransformWarningSignal: customLut?.transformWarningSignal
            )
        }
        switch decision {
        case .noCapturePackage:
            return nil
        case .usingMaster:
            return makeProvenance(
                mode: "master",
                reason: nil,
                masterUriUsed: masterURI,
                proxyUriUsed: nil
            )
        case .usingProxyMasterMissing:
            return makeProvenance(
                mode: "proxy",
                reason: "masterFileMissing",
                masterUriUsed: masterURI,
                proxyUriUsed: proxyURI
            )
        case .usingProxyMasterUnreadable(let reason):
            return makeProvenance(
                mode: "proxy",
                reason: "masterProbeFailed:\(reason)",
                masterUriUsed: masterURI,
                proxyUriUsed: proxyURI
            )
        }
    }

    // MARK: - Export

    func export() async {
        guard let store else { return }
        guard !store.isBusy && !isSavingToPhotos else {
            return
        }

        // M14-A / M14-B: pick master vs proxy at export time.
        // `resolveExportSource()` may have acquired security-scope on
        // an SSD master via the package's bookmark — `defer release()`
        // drops scope on every exit path (success, throw, early
        // return). Captured outside `do` so even a build-request throw
        // releases scope.
        let resolved = resolveExportSource()
        defer { resolved.release() }

        do {
            let request = try FilmtonePhase0Math.buildExportRequest(
                source: resolved.source,
                probe: resolved.probe,
                project: store.project,
                videoTimingMode: store.resolvedVideoTimingMode
            )

            // v1.3 Item 2 Phase E: resolve the active Saved Look (if any) so
            // the sidecar can record provenance. Built-in catalog entries
            // materialize from `FilmtoneBuiltInCatalog` without disk I/O;
            // user-saved entries are read from the in-memory actor state.
            // Resolution failures surface as "no provenance" — never block
            // the export — because the look might have been deleted between
            // apply and export, and a missing block is preferable to a hard
            // export failure (CLAUDE.md §11 `feedback_no_fallback_bug_hotbed`
            // permits this: provenance absence is explicit, not silent
            // success-with-degraded-output).
            let resolvedSavedLook = await resolveAppliedSavedLookForExport()
            // v1.3 Camera Profiles Phase E: thread the project's selected
            // Camera Profile through facade.runExport. Stored OFF the wire
            // DTO because it's iOS-side state, not bridge data.
            let cameraProfileSelection = store.project.cameraProfile

            store.isBusy = true
            store.error = nil
            store.notice = nil
            exportResult = nil
            exportProgress = nil
            exportLocalAvailability = .none
            saveToPhotosState = .notRun

            let cacheProtection = protectedCacheURIs
            // M14-C: emit the master/proxy decision into the sidecar
            // so DaVinci importers can distinguish a master-quality
            // artifact from a proxy fallback.
            let sidecarProvenance = sidecarCaptureProvenance(
                from: resolved.decision,
                package: store.lastCapturePackage
            )
            let result = try await facade.runExport(
                request: request,
                protectedCacheURIs: cacheProtection,
                appliedSavedLook: resolvedSavedLook,
                cameraProfile: cameraProfileSelection,
                highlightMarkers: store.exportHighlightMarkers,
                captureProvenance: sidecarProvenance
            ) { [weak self] progress in
                self?.exportProgress = progress
            }

            store.isBusy = false
            exportProgress = nil
            exportResult = result
            exportLocalAvailability = .available
            reclaimCacheForCurrentState()
            store.presentToast(toastForDecision(resolved.decision), kind: .success)
        } catch {
            store.isBusy = false
            exportProgress = nil
            isSavingToPhotos = false
            let message = strings.userMessage(for: error, context: .export)
            store.error = message
            store.presentToast(message, kind: .error)
        }
    }

    func exportAndSave() async {
        guard let store else { return }
        guard !store.isBusy && !isSavingToPhotos else {
            return
        }

        // M14-A / M14-B: see `export()` for the resolved + defer
        // rationale.
        let resolved = resolveExportSource()
        defer { resolved.release() }

        do {
            let request = try FilmtonePhase0Math.buildExportRequest(
                source: resolved.source,
                probe: resolved.probe,
                project: store.project,
                videoTimingMode: store.resolvedVideoTimingMode
            )

            // v1.3 Item 2 Phase E + Camera Profiles Phase E: see `export()`
            // above for the resolveAppliedSavedLook + cameraProfile rationale.
            let resolvedSavedLook = await resolveAppliedSavedLookForExport()
            let cameraProfileSelection = store.project.cameraProfile

            store.isBusy = true
            isSavingToPhotos = false
            store.error = nil
            store.notice = nil
            exportResult = nil
            exportProgress = nil
            exportLocalAvailability = .none
            saveToPhotosState = .notRun

            let cacheProtection = protectedCacheURIs
            // M14-C: same provenance as `export()` — see
            // sidecarCaptureProvenance(...) for the mapping rationale.
            let sidecarProvenance = sidecarCaptureProvenance(
                from: resolved.decision,
                package: store.lastCapturePackage
            )
            let result = try await facade.runExport(
                request: request,
                protectedCacheURIs: cacheProtection,
                appliedSavedLook: resolvedSavedLook,
                cameraProfile: cameraProfileSelection,
                highlightMarkers: store.exportHighlightMarkers,
                captureProvenance: sidecarProvenance
            ) { [weak self] progress in
                self?.exportProgress = progress
            }

            store.isBusy = false
            exportProgress = nil
            exportResult = result
            exportLocalAvailability = .available
            reclaimCacheForCurrentState()
            // Surface the master/proxy decision before saveToPhotos
            // runs its own toast, so the owner sees both signals.
            store.presentToast(toastForDecision(resolved.decision), kind: .success)
            await saveExportResultToPhotos(result)
        } catch {
            store.isBusy = false
            exportProgress = nil
            isSavingToPhotos = false
            store.error = strings.userMessage(for: error, context: .export)
        }
    }

    func saveToPhotos() async {
        guard let exportResult,
              canUseLocalExport,
              saveToPhotosState != .saved,
              !isSavingToPhotos else {
            return
        }

        await saveExportResultToPhotos(exportResult)
    }

    private func saveExportResultToPhotos(_ result: Phase0ExportResultDTO) async {
        guard let store else { return }
        guard !isSavingToPhotos else {
            return
        }

        isSavingToPhotos = true
        defer {
            isSavingToPhotos = false
        }

        do {
            try await facade.saveToPhotos(uri: result.outputUri)
            saveToPhotosState = .saved
            // Keep the local export package available after Photos save so the
            // same result can still be shared or inspected from the app cache.
            store.notice = strings.saveToPhotosDone
            store.error = nil
            store.presentToast(strings.toastSaveSuccess, kind: .success)
        } catch {
            saveToPhotosState = .failed
            let message = strings.userMessage(for: error, context: .saveToPhotos)
            store.error = message
            store.presentToast(message, kind: .error)
        }
    }

    func shareOutput() async {
        guard let store else { return }
        guard let exportResult, canUseLocalExport else {
            return
        }

        do {
            let completed = try await facade.shareOutput(
                mediaURI: exportResult.outputUri,
                sidecarURI: exportResult.sidecarUri,
                packageFileURIs: exportResult.packageFileUris
            )
            if completed {
                store.notice = nil
                store.error = nil
                store.presentToast(strings.toastShareSuccess, kind: .success)
            }
        } catch {
            store.error = strings.userMessage(for: error, context: .share)
            store.presentToast(strings.toastShareFailed, kind: .error)
        }
    }

    func exportHighlightReel() async {
        guard let store else { return }
        guard store.canCreateHighlightReel else {
            return
        }

        do {
            let request = try FilmtonePhase0Math.buildExportRequest(
                source: store.source,
                probe: store.probe,
                project: store.project
            )
            let resolvedSavedLook = await resolveAppliedSavedLookForExport()
            let cameraProfileSelection = store.project.cameraProfile

            store.isBusy = true
            store.error = nil
            store.notice = nil
            exportProgress = nil
            let cacheProtection = protectedCacheURIs
            let result = try await facade.runHighlightReel(
                request: request,
                protectedCacheURIs: cacheProtection,
                appliedSavedLook: resolvedSavedLook,
                cameraProfile: cameraProfileSelection,
                highlightMarkers: store.exportHighlightMarkers
            ) { [weak self] progress in
                self?.exportProgress = progress
            }

            store.isBusy = false
            exportProgress = nil
            _ = try await facade.shareOutput(mediaURI: result.outputUri)
        } catch {
            store.isBusy = false
            exportProgress = nil
            store.error = strings.userMessage(for: error, context: .export)
        }
    }

    // MARK: - Cache lifecycle

    func reclaimCacheForBackground() {
        guard let store else { return }
        guard !store.isBusy && !isSavingToPhotos else {
            return
        }
        reclaimCacheForCurrentState()
    }

    func loadCacheInventory() async {
        let snapshot = await facade.cacheInventory()
        cacheInventory = snapshot
    }

    func releaseCache() async {
        guard let store else { return }
        guard !isReleasingCache, !store.isBusy, !isSavingToPhotos else {
            return
        }
        isReleasingCache = true
        defer { isReleasingCache = false }

        let result = await facade.releaseCache(protecting: protectedCacheURIs)
        await loadCacheInventory()

        if let result, result.removedBytes > 0 {
            let formatted = ByteCountFormatter.string(
                fromByteCount: result.removedBytes,
                countStyle: .file
            )
            store.notice = String(
                format: strings.storageReleasedNotice,
                locale: Locale.current,
                formatted
            )
        }
    }

    var protectedCacheURIs: [String] {
        guard let store else { return [] }
        var uris: [String] = []
        if let source = store.source {
            uris.append(source.uri)
        }
        if canUseLocalExport, let exportResult {
            uris.append(contentsOf: localExportURIs(for: exportResult))
        }
        uris.append(contentsOf: store.previewOrchestrator.preview.cacheURIs)
        if let comparePreviewFrame = store.previewOrchestrator.comparePreviewFrame {
            uris.append(comparePreviewFrame.originalURI)
            uris.append(comparePreviewFrame.gradedURI)
        }
        return uniqueURIs(uris)
    }

    func reclaimCacheForCurrentState() {
        facade.reclaimCache(protecting: protectedCacheURIs)
    }

    /// v1.3 Item 2 Phase E: resolve `appliedSavedLookId` to a full
    /// `SavedLookEntry` for sidecar provenance. Returns nil when the project
    /// has been dirtied since `applySavedLook` (the apply path nils
    /// `appliedSavedLookId` on every mutation), when no Saved Look was
    /// applied, when the library actor is unavailable, or when the entry
    /// fails to load (e.g. user-saved entry deleted between apply and
    /// export). Built-in catalog entries materialize without disk I/O via
    /// `FilmtoneBuiltInCatalog`, so the read is cheap.
    private func resolveAppliedSavedLookForExport() async -> SavedLookEntry? {
        guard let store else { return nil }
        return await projectController.resolveAppliedSavedLook(
            id: store.appliedSavedLookId,
            via: libraryController
        )
    }

    private func localExportURIs(for result: Phase0ExportResultDTO) -> [String] {
        if let packageFileUris = result.packageFileUris, !packageFileUris.isEmpty {
            return uniqueURIs(packageFileUris)
        }
        return [
            result.outputUri,
            result.sidecarUri,
        ].compactMap { $0 }
    }

    private func uniqueURIs(_ uris: [String]) -> [String] {
        var seen: Set<String> = []
        var unique: [String] = []
        for uri in uris where !uri.isEmpty {
            guard !seen.contains(uri) else {
                continue
            }
            seen.insert(uri)
            unique.append(uri)
        }
        return unique
    }

    // MARK: - Facade-driven resets

    /// Called from `applyProbe` when a new source replaces the old one.
    /// Mirrors the legacy in-place writes in `FilmtoneEditorStore.applyProbe`.
    func resetForSourceChange() {
        saveToPhotosState = .notRun
        isSavingToPhotos = false
        exportResult = nil
        exportProgress = nil
        exportLocalAvailability = .none
    }

    /// Called from `invalidateRenderedOutputState` so any project-state
    /// mutation invalidates the current export artifact + save-state.
    func invalidateForProjectChange() {
        exportResult = nil
        exportProgress = nil
        exportLocalAvailability = .none
        saveToPhotosState = .notRun
    }

    /// Called from `invalidateExportPackageState` (highlight-marker add/remove)
    /// — same write set as `invalidateForProjectChange`, kept as a separate
    /// hook so future divergence is easy.
    func invalidateExportPackageState() {
        exportResult = nil
        exportProgress = nil
        exportLocalAvailability = .none
        saveToPhotosState = .notRun
    }

    /// Snapshot/UI-fixture hook used by `FilmtoneEditorStore.applySnapshotScene`.
    func applyFixture(
        exportResult: Phase0ExportResultDTO?,
        saveToPhotosState: FilmtoneSaveToPhotosState
    ) {
        exportProgress = nil
        self.exportResult = exportResult
        exportLocalAvailability = exportResult == nil ? .none : .available
        self.saveToPhotosState = saveToPhotosState
        isSavingToPhotos = false
    }
}
