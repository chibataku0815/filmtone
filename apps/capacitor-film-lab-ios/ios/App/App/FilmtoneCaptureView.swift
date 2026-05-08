// Filmtone V2 native camera capture — SwiftUI surface (M10).
//
// Live preview, big record button, storage status pill, mode toggle
// (internal 10s vs external SSD), elapsed countdown, error banner.
// Mounted from `FilmtoneRootView` as a `fullScreenCover` triggered by
// the empty-view record CTA.  All UX surfaces are intentionally minimal
// — the lane scope is "make recording the entry surface", not polish.
//
// On `.completed(package)`, the view dismisses and hands the package
// up to the editor store via the supplied closure.  The store adopts
// the proxy as the active source while keeping the master URL on the
// capture package for downstream export / share.

import SwiftUI

#if os(iOS)

import AVFoundation
import UniformTypeIdentifiers

/// S8-D: snapshot of the editor's current Look state passed into the
/// capture surface so a small reference thumbnail can show the owner
/// the active color direction *before* recording.  The live preview
/// itself remains the raw `AVCaptureVideoPreviewLayer` — applying the
/// grade to the live frame would require `AVCaptureVideoDataOutput`,
/// which is incompatible with the ProRes 422 HQ + Apple Log 2 +
/// cinematicEE record pipeline (M2-A: iOS 26.4 does not deliver 10-bit
/// `x422`/`x420` from VDO under `.appleLog2`).  We deliberately stop
/// at the reference strip and label the live image ungraded.
struct FilmtoneCaptureLookReference: Equatable {
    /// `file://` URI of the editor's currently graded still poster, or
    /// nil when the editor has no source / the preview is mid-render
    /// / the source is a video without a baked graded poster.  Nil
    /// hides the reference panel.
    let displayURI: String?
    /// Owner-friendly Look name — `creativeLut.title` when a creative
    /// LUT is applied, otherwise `strings.lookFilmtone` (the default
    /// Filmtone label).  Also nilable so callers without a meaningful
    /// label can pass nil and the panel falls back to "Editor reference".
    let lookLabel: String?
}

/// M11 / S11-B: Look option exposed in the capture-time chip strip.
///
/// Three fixed chips: `filmtone` (default — `creativeLut == nil`,
/// Filmtone signature ungraded baseline), `stone`, and `urban`.  Stone
/// and Urban resolve their `canonicalUUID` from
/// `FilmtoneBuiltInCatalog.allLooks` by slug so the canonical bundled-Look
/// UUIDs stay single-sourced in the catalog file (no duplication of
/// hard-coded UUIDs here).  The default chip's UUID is `nil` because
/// "Filmtone (no creative LUT)" is not a saved-Look entry; the
/// `applySavedLook` route is never invoked for it.
struct FilmtoneCaptureLook: Identifiable, Equatable {
    let id: String
    let displayName: String
    /// `BuiltInLook.canonicalUUID` for Stone / Urban; `nil` for the
    /// Filmtone default chip (which represents "no Look applied").
    let canonicalUUID: UUID?
    /// `BuiltInLook.slug` for Stone / Urban; `nil` for the Filmtone
    /// default chip.  Recorded into `FilmtoneSelectedLookRecord.slug`
    /// so the persisted capture-package retains a bundled-only
    /// secondary identifier (S11-D).
    let slug: String?

    static let filmtone = FilmtoneCaptureLook(
        id: "filmtone",
        displayName: "Filmtone",
        canonicalUUID: nil,
        slug: nil
    )

    static let stone: FilmtoneCaptureLook = {
        let slug = "filmtone-creative-pack-01-stone"
        let entry = FilmtoneBuiltInCatalog.allLooks.first { $0.slug == slug }
        return FilmtoneCaptureLook(
            id: "stone",
            displayName: entry?.englishName ?? "Stone",
            canonicalUUID: entry?.canonicalUUID,
            slug: slug
        )
    }()

    static let urban: FilmtoneCaptureLook = {
        let slug = "filmtone-creative-pack-01-urban"
        let entry = FilmtoneBuiltInCatalog.allLooks.first { $0.slug == slug }
        return FilmtoneCaptureLook(
            id: "urban",
            displayName: entry?.englishName ?? "Urban",
            canonicalUUID: entry?.canonicalUUID,
            slug: slug
        )
    }()

    /// Fixed chip-strip order: default → Stone → Urban.  v1.4 only
    /// ships these two bundled Creative LUTs (M11 strategy doc §
    /// "M11 Out of scope" defers saved Looks to a later lane).
    static let allCases: [FilmtoneCaptureLook] = [.filmtone, .stone, .urban]

    /// Resolve a chip from a saved-Look canonical UUID (e.g. the editor's
    /// `appliedSavedLookId` at capture-present time).  Returns
    /// `.filmtone` when no UUID is set or the UUID does not belong to
    /// one of the M11 chips — saved Looks outside the chip strip
    /// fall back to default rather than being silently selected.
    static func resolve(from canonicalUUID: UUID?) -> FilmtoneCaptureLook {
        guard let uuid = canonicalUUID else { return .filmtone }
        return allCases.first { $0.canonicalUUID == uuid } ?? .filmtone
    }

    /// S11-D: project a chip onto the persisted capture-package shape.
    /// Filmtone default → `nil` (selectedLook absent → editor preserves
    /// pre-capture state on adoption per S11-A Design Locks).  Stone /
    /// Urban → record with stable identity so S11-E's adoptCaptureResult
    /// can call `applySavedLook(id: canonicalUUID)`.  M11 ships
    /// intensity = 1.0 (slider lane is out-of-scope).
    func toSelectedLookRecord() -> FilmtoneSelectedLookRecord? {
        guard let canonicalUUID else { return nil }
        return FilmtoneSelectedLookRecord(
            canonicalUUID: canonicalUUID,
            slug: slug,
            englishName: displayName,
            intensity: 1.0
        )
    }
}

struct FilmtoneCaptureView: View {

    let lookReference: FilmtoneCaptureLookReference?
    /// S8-F F3: editor's current grade chain captured at fullScreenCover
    /// present time (snapshot — not bound to publishers).  When non-nil,
    /// the live preview applies it on every VDO sample so the surface
    /// shows the editor's current Look + adjustments before recording.
    /// Nil falls back to F2 ungraded pass-through.
    let liveGradeProcessor: FilmtoneSharedGradeProcessor?
    /// S8-F F3-R: diagnostic snapshot captured at the same moment as
    /// `liveGradeProcessor`.  When non-nil, the capture surface
    /// renders a top-left overlay showing the editor inputs flowing
    /// into the grade chain so we can compare against the editor
    /// preview without rebuilding both pipelines blind.  Removed in
    /// F3-Fix once parity is verified.
    let liveDiagnostics: FilmtoneLivePreviewDiagnostics?
    /// M11 / S11-B: initial chip selection for the capture-time Look
    /// strip.  Caller resolves from the editor's `appliedSavedLookId`
    /// via `FilmtoneCaptureLook.resolve(from:)` so re-entering capture
    /// after applying Stone / Urban in the editor surfaces the same
    /// Look as the active chip.  Defaults to `.filmtone` (no Look) so
    /// callers without M11 wiring still compile; S11-C will couple
    /// chip changes to live preview rebuild.
    let initialCaptureLook: FilmtoneCaptureLook
    /// M11 / S11-C: closure handed in by `FilmtoneRootView` that calls
    /// `FilmtoneEditorStore.makeLivePreviewGradeProcessor(overridingBuiltInLook:)`
    /// for a given chip selection.  `.filmtone` maps to `nil` override
    /// (no rebuild against the editor's pre-capture state); Stone / Urban
    /// map to their `BuiltInLook` so the live preview reruns the 3-layer
    /// wiring (`appliedSavedLook` + camera profile) against the chip's
    /// catalog params.  Optional so test surfaces / preview targets that
    /// do not need rebuild can pass `nil`.
    let makeGradeProcessor: ((FilmtoneCaptureLook) -> FilmtoneLivePreviewBundle?)?
    let onCompleted: (FilmtoneCapturePackage) -> Void
    let onCancelled: () -> Void
    let onFailed: (FilmtoneCaptureFailure) -> Void

    init(
        lookReference: FilmtoneCaptureLookReference?,
        liveGradeProcessor: FilmtoneSharedGradeProcessor?,
        liveDiagnostics: FilmtoneLivePreviewDiagnostics?,
        initialCaptureLook: FilmtoneCaptureLook = .filmtone,
        makeGradeProcessor: ((FilmtoneCaptureLook) -> FilmtoneLivePreviewBundle?)? = nil,
        onCompleted: @escaping (FilmtoneCapturePackage) -> Void,
        onCancelled: @escaping () -> Void,
        onFailed: @escaping (FilmtoneCaptureFailure) -> Void
    ) {
        self.lookReference = lookReference
        self.liveGradeProcessor = liveGradeProcessor
        self.liveDiagnostics = liveDiagnostics
        self.initialCaptureLook = initialCaptureLook
        self.makeGradeProcessor = makeGradeProcessor
        self.onCompleted = onCompleted
        self.onCancelled = onCancelled
        self.onFailed = onFailed
        // `_captureLookSelection` initialized to the caller-resolved
        // initial Look so a cold open into capture surfaces the same
        // chip the editor has applied.  See `resolve(from:)` for the
        // fallback rule when an active saved Look is not in the chip
        // strip (saved Look outside Stone/Urban → `.filmtone`).
        self._captureLookSelection = State(initialValue: initialCaptureLook)
        // S11-C: seed the active grade chain from the props so the
        // first frame after present matches the editor's pre-capture
        // grade.  Chip taps then swap these via `makeGradeProcessor`.
        self._activeGradeProcessor = State(initialValue: liveGradeProcessor)
        self._activeLiveDiagnostics = State(initialValue: liveDiagnostics)
    }

    @StateObject private var session = FilmtoneCaptureSession()
    @State private var prepareError: FilmtoneCaptureFailure?
    @State private var showFolderImporter = false
    @State private var preflightWarnings: [String] = []
    @State private var preflightError: String?
    @State private var heldExternalFolderURL: URL?
    /// S8-B: rear lenses that satisfy the M10 capture contract,
    /// resolved once on `.task` from `FilmtoneCaptureLensCatalog`.
    @State private var lenses: [FilmtoneCaptureLens] = []
    /// S8-B: lens currently configured on the session.  Default = wide
    /// (`FilmtoneCaptureLensCatalog.defaultLens(in:)`).  Tapping a
    /// different pill triggers `selectLens(_:)` which tears down the
    /// session and re-prepares against the chosen lens.
    @State private var selectedLens: FilmtoneCaptureLens?
    /// Guards re-entrant `selectLens(_:)` taps while a teardown +
    /// re-prepare is in flight.
    @State private var lensSwitchInFlight: Bool = false
    /// S8-D: cached UIImage decoded from `lookReference.displayURI`.
    /// Loaded once on `.task(id:)` so SwiftUI recomputes during
    /// recording state ticks do not redecode the file every frame.
    @State private var lookReferenceImage: UIImage?
    /// M11 / S11-B: ephemeral capture-time Look chip selection.  Lives
    /// only inside the capture surface — `onCancelled` does NOT propagate
    /// it so cancelling preserves the editor's pre-capture Look state
    /// (M11 cancel-preservation invariant).  S11-C wires this to live
    /// preview rebuild via `makeGradeProcessor`; S11-D will persist it
    /// on `.completed(package)` via `selectedLook` on
    /// `FilmtoneCapturePackage`.  Initialized in `init(...)` from
    /// `initialCaptureLook` so a cold open into capture mirrors the
    /// editor's currently applied Look.
    @State private var captureLookSelection: FilmtoneCaptureLook
    /// M11 / S11-C: active grade processor driving the live preview.
    /// Seeded from `liveGradeProcessor` at init and swapped by the
    /// chip-tap rebuild closure.  Holding it as `@State` lets a chip
    /// change rebuild without going through the editor store, keeping
    /// the editor's persisted state untouched until the user records.
    @State private var activeGradeProcessor: FilmtoneSharedGradeProcessor?
    /// M11 / S11-C: diagnostic snapshot paired with `activeGradeProcessor`.
    /// Updated alongside it so the F3-R overlay stays consistent with
    /// the chain currently feeding the renderer.
    @State private var activeLiveDiagnostics: FilmtoneLivePreviewDiagnostics?
    /// M12 / S12-C: last view-local tap location for the focus / meter
    /// reticle.  Lives in the SwiftUI body's coordinate space (the
    /// `GeometryReader` wrapping the tap-interaction layer); paired
    /// with `reticleVisible` for the fade-out animation.
    @State private var reticleViewPoint: CGPoint?
    /// M12 / S12-C: visible state for the reticle.  Goes true on a tap
    /// (with a brief ease-in fade), then back to false 0.6 s later
    /// (with a longer ease-out fade).  Token-guarded so a second tap
    /// inside the fade window restarts the timer cleanly without
    /// blinking the previous reticle off and on.
    @State private var reticleVisible: Bool = false
    /// M12 / S12-C: monotonically-incrementing token used by the
    /// fade-out task to abandon itself when a newer tap supersedes it.
    /// Wraps via `&+`; the absolute value never matters, only equality.
    @State private var reticleFadeToken: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            previewLayer

            previewTapInteractionLayer

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()
                bottomDeck
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }

            if let prepareError {
                failureOverlay(prepareError)
            }

            if let activeLiveDiagnostics {
                diagnosticOverlay(activeLiveDiagnostics)
            }
        }
        .task {
            if let activeLiveDiagnostics {
                logLiveDiagnostics(activeLiveDiagnostics)
            } else {
                NSLog("[F3R] live preview diagnostics: nil (capture entered without source / build failed)")
            }
            // S11-D: seed the session's pending capture-Look record
            // from the initial chip selection so a record without a
            // chip change still persists `selectedLook` (or nil for
            // Filmtone).  Subsequent chip changes update via .onChange.
            session.setSelectedLook(captureLookSelection.toSelectedLookRecord())
            // Auto-restore previously picked SSD folder so the owner
            // does not have to re-pick on every capture-view present.
            // Runs before prepareSession so the storage pill shows the
            // right destination when the surface first paints.  Stale
            // bookmark / SSD disconnected → silent fallback to internal
            // mode (the helper clears the bookmark on its own).
            restorePersistedExternalFolderIfPossible()
            await prepareSession()
        }
        .task(id: lookReference?.displayURI) {
            // S8-D: decode the editor's graded poster once per URI so
            // SwiftUI body recomputes during recording (state ticks
            // every ~0.1s while .recording) do not redecode the file.
            // Decoding off the main thread keeps the capture session
            // setup unaffected.
            guard let uri = lookReference?.displayURI else {
                lookReferenceImage = nil
                return
            }
            let decoded = await Task.detached(priority: .utility) {
                Self.decodeReferenceImage(from: uri)
            }.value
            await MainActor.run {
                lookReferenceImage = decoded
            }
        }
        .onChange(of: captureLookSelection) { newLook in
            // S11-D: push the chip's selected-Look record into the
            // session so the package built at record-stop time carries
            // the right `selectedLook` (or nil for Filmtone).  Done
            // before the live-preview rebuild so a record that races
            // an in-flight chip change still observes the latest pick.
            session.setSelectedLook(newLook.toSelectedLookRecord())
            // S11-C: a chip tap rebuilds the live preview's grade chain
            // off the new Look without touching the editor store.  The
            // closure resolves Stone / Urban to a built-in catalog
            // entry and Filmtone to nil (no override) — see
            // FilmtoneEditorStore.makeLivePreviewGradeProcessor(overridingBuiltInLook:).
            // Disabled while recording (chip strip itself blocks the
            // tap), so the swap can never happen mid-write.
            guard let make = makeGradeProcessor else { return }
            let bundle = make(newLook)
            activeGradeProcessor = bundle?.processor
            activeLiveDiagnostics = bundle?.diagnostics
            if let bundle {
                logLiveDiagnostics(bundle.diagnostics)
            } else {
                NSLog("[F3R] live preview rebuild for chip=\(newLook.id) returned nil")
            }
        }
        .onChange(of: session.state) { newState in
            switch newState {
            case .completed(let pkg):
                Task {
                    await session.teardown()
                    await MainActor.run {
                        releaseExternalFolderScope()
                        onCompleted(pkg)
                    }
                }
            case .failed(let failure):
                Task {
                    await session.teardown()
                    await MainActor.run {
                        releaseExternalFolderScope()
                        onFailed(failure)
                    }
                }
            default:
                break
            }
        }
        .onDisappear {
            // Defensive teardown: covers paths where the view is dismissed
            // by gesture / system-driven dismissal without going through
            // dismissCapture() or the .completed / .failed branches.
            // FilmtoneCaptureSession.teardown() is idempotent.
            Task { [session] in
                await session.teardown()
            }
            releaseExternalFolderScope()
        }
        .fileImporter(
            isPresented: $showFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderPick(result: result)
        }
        .accessibilityIdentifier("filmtone.capture.surface")
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewLayer: some View {
        // S8-F F2: render the Metal-backed live preview when the
        // session attached a preview-only VDO.  When canAddOutput
        // rejected the VDO at prepare(lens:) time, fall back to the
        // raw `AVCaptureVideoPreviewLayer` so the surface still shows
        // a viewfinder — graceful degrade keeps the record path
        // available even on hardware where VDO + MovieFileOutput
        // coexistence is refused.
        if session.hasLivePreview {
            FilmtoneCaptureLivePreview(
                sink: session.previewFrameSink,
                gradeProcessor: activeGradeProcessor
            )
                .ignoresSafeArea()
                .accessibilityIdentifier("filmtone.capture.preview")
        } else if let layer = session.previewLayer {
            FilmtoneCapturePreview(previewLayer: layer)
                .ignoresSafeArea()
                .accessibilityIdentifier("filmtone.capture.preview")
        }
    }

    // MARK: - Top bar (close + storage pill)

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: dismissCapture) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.45), in: Circle())
            }
            .accessibilityIdentifier("filmtone.capture.close")
            .disabled(isRecordingOrStopping)

            Spacer(minLength: 8)

            // S8-D: stack the storage pill on top of the look-reference
            // panel along the right edge.  This anchors all "decisions
            // for this take" — destination, duration cap, color
            // direction — in a single glanceable column without
            // crowding the bottom controls deck.
            VStack(alignment: .trailing, spacing: 8) {
                storagePill
                lookReferencePanel
            }
        }
    }

    private var storagePill: some View {
        HStack(spacing: 8) {
            Image(systemName: storagePillIcon)
                .font(.system(size: 13, weight: .medium))
            Text(storagePillLabel)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.45), in: Capsule())
        .accessibilityIdentifier("filmtone.capture.storagePill")
    }

    private var storagePillIcon: String {
        switch session.storagePolicy {
        case .internalDocumentsCapped: return "internaldrive"
        case .externalSecurityScopedFolder: return "externaldrive.fill.badge.checkmark"
        }
    }

    private var storagePillLabel: String {
        let cap = Int(session.currentDurationLimit())
        switch session.storagePolicy {
        case .internalDocumentsCapped:
            return "Internal master · \(cap)s cap"
        case .externalSecurityScopedFolder(let url):
            return "External master · \(url.lastPathComponent) · \(cap)s cap"
        }
    }

    // MARK: - Look reference panel (S8-D)

    /// Compact reference strip showing the editor's currently graded
    /// poster, the active Look name, and an explicit "Live ungraded"
    /// disclaimer.  Goal: let the owner judge color direction *before*
    /// pressing record without misleading them into thinking the live
    /// preview is graded.  Hidden when the editor has no source / the
    /// graded poster is mid-render / the source is a video without a
    /// baked still poster.
    @ViewBuilder
    private var lookReferencePanel: some View {
        if let image = lookReferenceImage {
            VStack(alignment: .leading, spacing: 6) {
                Text("LOOK REFERENCE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.55))
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityIdentifier("filmtone.capture.lookReference.image")
                Text(resolvedLookLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 120, alignment: .leading)
                // S8-F F3: when the live preview is being graded by the
                // editor's chain, the disclaimer is misleading — drop
                // it so the panel reads as a comparison thumbnail
                // (still poster vs. live framing) instead of a "look
                // not yet applied" warning.  When the grade chain
                // could not be built (no source loaded etc.) we keep
                // the disclaimer so the owner isn't tricked into
                // thinking the unlooked feed already reflects color.
                if activeGradeProcessor == nil {
                    Text("Live ungraded")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Color.black.opacity(0.45),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .accessibilityIdentifier("filmtone.capture.lookReference")
        }
    }

    /// Falls back to "Editor reference" when the caller passed nil or
    /// an empty Look label.  `nilIfEmpty` lives on `FilmtoneEditorStore`
    /// as `fileprivate`, so we inline the trim-and-empty check here
    /// rather than widen the access level just for this one read.
    private var resolvedLookLabel: String {
        let trimmed = (lookReference?.lookLabel ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Editor reference" : trimmed
    }

    /// `nonisolated` so the off-main `Task.detached` in `.task(id:)`
    /// can call it without an actor hop.  Pure file IO + `UIImage`
    /// init — no UI side effects — and `UIImage` carries cleanly
    /// across actors.
    nonisolated private static func decodeReferenceImage(
        from uri: String
    ) -> UIImage? {
        guard let url = URL(string: uri), url.isFileURL else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - Bottom deck (status, ssd picker, record button)

    private var bottomDeck: some View {
        VStack(spacing: 16) {
            if let preflightError {
                Text(preflightError)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color(red: 0.96, green: 0.32, blue: 0.32))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            if !preflightWarnings.isEmpty {
                ForEach(preflightWarnings, id: \.self) { line in
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }

            if lenses.count > 1 {
                lensSelector
            }

            // M11 / S11-B: capture-time Look chip strip.  Visually
            // identical pill row to `lensSelector` so the two
            // capture-time selectors read as siblings.  Disabled while
            // recording / stopping — owner cannot change Look mid-take
            // (live preview rebuild would visibly tear, and the
            // selectedLook-on-completion semantic only commits on the
            // first record success).
            captureLookStrip

            if showsEVSlider {
                evSliderRow
            }

            contractBanner

            statusLine

            HStack(spacing: 12) {
                pickFolderButton
                Spacer(minLength: 4)
                recordButton
                Spacer(minLength: 4)
                modeToggle
            }
        }
    }

    // MARK: - Lens selector (S8-B)

    /// Horizontal pill row of qualifying rear lenses.  Hidden when only
    /// one (or zero) lens passes the M10 contract — the spec line
    /// already names the active lens, so the selector only adds value
    /// when there is something to switch between.  Disabled while
    /// recording/stopping or while a teardown + re-prepare is in flight.
    private var lensSelector: some View {
        HStack(spacing: 8) {
            ForEach(lenses) { lens in
                Button {
                    selectLens(lens)
                } label: {
                    VStack(spacing: 1) {
                        Text(lens.magnificationLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        if !lens.canonicalSubtext.isEmpty {
                            Text(lens.canonicalSubtext)
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        lens == selectedLens
                            ? Color.white.opacity(0.28)
                            : Color.black.opacity(0.42),
                        in: Capsule()
                    )
                }
                .accessibilityLabel(
                    Text("\(lens.magnificationLabel) \(lens.canonicalSubtext)")
                )
                .accessibilityIdentifier("filmtone.capture.lens.\(lens.deviceTypeRaw)")
                .accessibilityAddTraits(lens == selectedLens ? .isSelected : [])
                .disabled(
                    isRecordingOrStopping
                        || lensSwitchInFlight
                        || lens == selectedLens
                )
            }
        }
        .accessibilityIdentifier("filmtone.capture.lensSelector")
    }

    // MARK: - Capture-time Look chip strip (M11 / S11-B)

    /// Horizontal pill row of three Look chips: Filmtone (default —
    /// no creative LUT) / Stone / Urban.  Mirrors `lensSelector` so the
    /// capture-time selectors read as siblings.  S11-B keeps the tap
    /// handler local-state-only (updates `captureLookSelection` and
    /// nothing else) — S11-C wires the live preview rebuild and S11-D
    /// commits the selection into the capture package on
    /// `.completed`.  Disabled while recording / stopping so the
    /// rebuild path cannot tear the active VDO chain mid-write.
    private var captureLookStrip: some View {
        HStack(spacing: 8) {
            ForEach(FilmtoneCaptureLook.allCases) { look in
                Button {
                    captureLookSelection = look
                } label: {
                    Text(look.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            look == captureLookSelection
                                ? Color.white.opacity(0.28)
                                : Color.black.opacity(0.42),
                            in: Capsule()
                        )
                }
                .accessibilityIdentifier("filmtone.capture.look.\(look.id)")
                .accessibilityAddTraits(
                    look == captureLookSelection ? .isSelected : []
                )
                .disabled(
                    isRecordingOrStopping
                        || look == captureLookSelection
                )
            }
        }
        .accessibilityIdentifier("filmtone.capture.lookStrip")
    }

    /// S8-C: display-only readout of the locked M10 capture contract.
    /// Surfaces the five fixed contract items the owner must see at
    /// record time — 4K24 / ProRes 422 HQ / Apple Log 2 / cinematic
    /// stabilization (EE) / proxy → editor handoff — using the
    /// `FilmtoneCaptureParameters.baseline` strings as source of
    /// truth.  M10 does not expose camera knobs; this banner keeps
    /// the owner honest about what is being recorded without
    /// inviting a settings page that would dilute the lane.
    ///
    /// Duration cap is owned by the storage pill (top-right) since
    /// the cap is mode-dependent (internal 10s vs SSD 60s).  The
    /// lens prefix appears here only when the lens selector pill row
    /// is hidden — i.e. when there is at most one qualifying rear
    /// lens — so the active lens name does not duplicate the pill
    /// row above.  The view leaves the area between this banner and
    /// the controls cluster open so S8-D's look-applied preview can
    /// expand into a thumbnail strip without restructuring the deck.
    private var contractBanner: some View {
        let p = FilmtoneCaptureParameters.baseline
        // Nearest-K rounding so 3840 reads as the conventional "4K"
        // (UHD), not the integer-truncated "3K".
        let kRounded = (p.widthPx + 500) / 1000
        let resolution = "\(kRounded)K\(Int(p.frameRate))"
        // "Cinematic EE" is the compact owner label for
        // `cinematicExtendedEnhanced`; the parameter string remains
        // verbatim in capture-package.json for downstream audit.
        let segments: [String] = [
            resolution,
            p.codec,
            p.colorSpace,
            "Cinematic EE",
            "Proxy → Editor",
        ]
        let shouldShowLensPrefix = lenses.count <= 1
        let lensPrefix = shouldShowLensPrefix
            ? (selectedLens.map { "\($0.magnificationLabel) · " } ?? "")
            : ""
        return Text(lensPrefix + segments.joined(separator: " · "))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.78))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityIdentifier("filmtone.capture.contractBanner")
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            if isRecordingOrStopping {
                Circle()
                    .fill(Color(red: 0.96, green: 0.32, blue: 0.32))
                    .frame(width: 9, height: 9)
            }
            Text(statusText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .accessibilityIdentifier("filmtone.capture.status")
        }
    }

    private var statusText: String {
        switch session.state {
        case .idle, .configuring, .ready:
            return "Ready · \(Int(session.currentDurationLimit())) s max"
        case .recording:
            let remaining = max(0, session.currentDurationLimit() - session.elapsedSeconds)
            return String(format: "Recording · %.1f s left", remaining)
        case .stopping:
            return "Stopping…"
        case .completed:
            return "Completed"
        case .failed(let failure):
            return failure.displayMessage
        }
    }

    private var pickFolderButton: some View {
        Button(action: { showFolderImporter = true }) {
            VStack(spacing: 4) {
                Image(systemName: pickFolderIcon)
                    .font(.system(size: 22, weight: .medium))
                Text(pickFolderLabel)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(width: 64, height: 56)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(isRecordingOrStopping)
        .accessibilityIdentifier("filmtone.capture.pickFolder")
    }

    private var pickFolderIcon: String {
        if case .externalSecurityScopedFolder = session.storagePolicy {
            return "externaldrive.fill"
        }
        return "externaldrive.badge.plus"
    }

    private var pickFolderLabel: String {
        if case .externalSecurityScopedFolder = session.storagePolicy {
            return "Change"
        }
        return "SSD"
    }

    private var recordButton: some View {
        Button(action: toggleRecord) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.85), lineWidth: 4)
                    .frame(width: 84, height: 84)
                if isRecordingOrStopping {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.96, green: 0.32, blue: 0.32))
                        .frame(width: 36, height: 36)
                } else {
                    Circle()
                        .fill(Color(red: 0.96, green: 0.32, blue: 0.32))
                        .frame(width: 68, height: 68)
                }
            }
        }
        .disabled(!canToggleRecord)
        .accessibilityIdentifier("filmtone.capture.record")
        .accessibilityLabel(isRecordingOrStopping ? "Stop recording" : "Start recording")
    }

    private var modeToggle: some View {
        VStack(spacing: 4) {
            if case .externalSecurityScopedFolder = session.storagePolicy {
                Button(action: clearExternalFolder) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .medium))
                        Text("Clear")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 56)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityIdentifier("filmtone.capture.clearFolder")
                .disabled(isRecordingOrStopping)
            } else {
                Color.clear
                    .frame(width: 64, height: 56)
            }
        }
    }

    // MARK: - Tap-to-focus interaction layer (M12 / S12-C)

    /// Transparent overlay that catches taps in the dead area between
    /// the top bar and the bottom deck and routes them to the session
    /// as tap-to-focus + tap-to-meter.  The reticle floats inside the
    /// same `GeometryReader` so its position uses the gesture's local
    /// coordinate space directly — no second conversion.
    ///
    /// Hit-testing is disabled while recording / stopping so the owner
    /// cannot drag the focus / metering POI mid-take (S12-A's
    /// "通常状態を複雑にしない" / "もしものため" framing — keep the
    /// active record path on whatever was set at start).  The tap
    /// layer is always frontmost relative to `previewLayer` so taps on
    /// blank areas do not pass through to the raw
    /// `AVCaptureVideoPreviewLayer`; controls in the `topBar` /
    /// `bottomDeck` `VStack` render above this layer (ZStack child
    /// order) so button hits still win.
    @ViewBuilder
    private var previewTapInteractionLayer: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                handlePreviewTap(at: value.location, in: geo.size)
                            }
                    )
                    .allowsHitTesting(canAcceptPreviewTap)

                if let pos = reticleViewPoint {
                    focusReticle
                        .position(pos)
                        .opacity(reticleVisible ? 1.0 : 0.0)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("filmtone.capture.focusReticle")
                }
            }
        }
        .ignoresSafeArea()
    }

    /// 64 pt yellow viewfinder reticle.  Single SF Symbol so the visual
    /// matches Apple Camera's reticle without bringing in custom assets;
    /// `.position()` aligns it to the tap location.  `weight: .light`
    /// keeps the stroke thin so the reticle does not bury the subject.
    private var focusReticle: some View {
        Image(systemName: "viewfinder")
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(.yellow)
            .frame(width: 64, height: 64)
            .shadow(color: .black.opacity(0.45), radius: 1, x: 0, y: 1)
    }

    private var canAcceptPreviewTap: Bool {
        if isRecordingOrStopping { return false }
        switch session.state {
        case .ready: return true
        default: return false
        }
    }

    private func handlePreviewTap(at location: CGPoint, in viewSize: CGSize) {
        guard canAcceptPreviewTap else { return }
        guard let layer = session.previewLayer else { return }
        // The Metal preview path renders the frames; the
        // AVCaptureVideoPreviewLayer is created and configured during
        // `prepare(lens:)` but is only attached to the view hierarchy
        // when `hasLivePreview == false`.  `captureDevicePointConverted
        // (fromLayerPoint:)` does the conversion math from `bounds` +
        // `videoGravity` + connection rotation, so synthesizing the
        // bounds inline (matching the visible view's size) gives a
        // valid POI even when the layer is not on screen.
        layer.bounds = CGRect(origin: .zero, size: viewSize)
        let devicePoint = layer.captureDevicePointConverted(fromLayerPoint: location)
        session.applyTapToFocusAndMeter(devicePoint: devicePoint)

        reticleViewPoint = location
        let token = reticleFadeToken &+ 1
        reticleFadeToken = token
        withAnimation(.easeIn(duration: 0.08)) {
            reticleVisible = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            // A newer tap (or a state transition that hid the reticle)
            // bumped the token — abandon this fade so the reticle does
            // not blink off in the middle of the new one.
            guard reticleFadeToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                reticleVisible = false
            }
        }
    }

    // MARK: - EV slider (M12 / S12-C)

    /// Horizontal EV bias slider.  Conservative range — `[-2, +2]` ∩
    /// device range (most iPhone wide / tele expose ±8 EV at the
    /// device level, but a slider that wide invites accidental
    /// blow-out drags; "もしものため" keeps the cap tight).  Sun icon
    /// is purely visual; tapping the EV value resets to 0 (S12-A's
    /// tap-and-hold-to-reset adapted to a discoverable tap target on
    /// the horizontal layout).  Disabled while recording / stopping
    /// so the active record cannot be re-exposed mid-take.
    private var evSliderRow: some View {
        let range = session.exposureBiasRange
        return HStack(spacing: 10) {
            Image(systemName: "sun.max")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Slider(
                value: Binding(
                    get: { Double(session.exposureBiasEV) },
                    set: { session.setExposureBias(Float($0)) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound)
            )
            .tint(session.exposureBiasEV == 0 ? .white : .yellow)
            .frame(maxWidth: 220)
            .accessibilityIdentifier("filmtone.capture.evSlider.control")
            Button(action: { session.resetExposureBias() }) {
                Text(evDisplayLabel)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(
                        session.exposureBiasEV == 0
                            ? .white.opacity(0.7)
                            : .yellow
                    )
                    .frame(width: 56, alignment: .trailing)
            }
            .accessibilityIdentifier("filmtone.capture.evSlider.reset")
            .accessibilityLabel(Text("Reset exposure"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.45), in: Capsule())
        .accessibilityIdentifier("filmtone.capture.evSlider")
        .disabled(isRecordingOrStopping)
        .opacity(isRecordingOrStopping ? 0.5 : 1.0)
    }

    private var showsEVSlider: Bool {
        let range = session.exposureBiasRange
        // SwiftUI `Slider(value:in:)` requires a non-empty range; a
        // device that exposes no bias range (e.g. a future lens that
        // reports `min == max`) would produce a degenerate slider that
        // emits NaN on drag.  Guard here rather than in the body so
        // the EV row simply hides on such hardware.
        guard range.upperBound > range.lowerBound else { return false }
        switch session.state {
        case .ready, .recording, .stopping: return true
        default: return false
        }
    }

    /// Compact "+0.7 EV" / "0.0 EV" string for the reset button label.
    /// Magnitude clamp on the rounding boundary so a value of -0.04
    /// reads as "0.0 EV" rather than "-0.0 EV" (the unary minus in
    /// `%+.1f` would otherwise leak through).
    private var evDisplayLabel: String {
        let v = session.exposureBiasEV
        if abs(v) < 0.05 {
            return "0.0 EV"
        }
        return String(format: "%+.1f EV", v)
    }

    // MARK: - Failure overlay

    private func failureOverlay(_ failure: FilmtoneCaptureFailure) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Color(red: 0.96, green: 0.32, blue: 0.32))
            Text(failure.displayMessage)
                .font(.callout)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button(action: dismissCapture) {
                Text("Close")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18), in: Capsule())
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("filmtone.capture.failure.close")
        }
        .padding(28)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 28)
    }

    // MARK: - F3-R diagnostic overlay

    /// Top-left diagnostic chip showing the editor inputs flowing into
    /// the live grade chain.  Removed in F3-Fix once parity gaps are
    /// closed.  Anchored to `.topLeading` and pushed past the close X
    /// button so it doesn't overlap the controls.  `allowsHitTesting`
    /// is off so the chip never intercepts a tap on the close button
    /// even if its frame grows.
    private func diagnosticOverlay(
        _ diag: FilmtoneLivePreviewDiagnostics
    ) -> some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("F3-R DIAG")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow)
                    Text("Look: \(diag.lookLabel)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                    Text("Profile: \(diag.cameraProfileLabel)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                    if let intensity = diag.creativeLutIntensity, diag.creativeLutPresent {
                        Text("LUT: ON x \(String(format: "%.2f", intensity))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    } else {
                        Text("LUT: OFF")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    Text("InputLUT: \(diag.inputLutWillApply ? "WILL APPLY (\(diag.detectedInputTransform ?? "auto"))" : "off")")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(diag.inputLutWillApply ? .red : .white)
                    // F3-Fix #1 post-fix interpretation:
                    //   camProf:N is now a genuine wiring regression
                    //     (post-fix `project.cameraProfile` is always at
                    //     least `.auto`) → red `[!]` alarm.
                    //   savedLook:N is informational — most edits don't
                    //     have a Saved Look applied → neutral white text.
                    Group {
                        if !diag.cameraProfilePassedToProcessor {
                            Text("[!] wiring camProf:N savedLook:\(diag.savedLookPassedToProcessor ? "Y" : "N")")
                                .foregroundStyle(.red)
                        } else {
                            Text("wiring camProf:Y savedLook:\(diag.savedLookPassedToProcessor ? "Y" : "N")")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    Text(String(
                        format: "E:%+.2f C:%.2f S:%.2f T:%+.2f",
                        diag.exposure, diag.contrast, diag.saturation, diag.temperature
                    ))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Color.black.opacity(0.65),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .accessibilityIdentifier("filmtone.capture.f3rDiag")
                Spacer()
            }
            .padding(.leading, 60)
            .padding(.top, 8)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func logLiveDiagnostics(_ diag: FilmtoneLivePreviewDiagnostics) {
        NSLog(
            "[F3R] live preview diagnostics: look=%@ profile=%@ camProfPassed=%@ savedLookPassed=%@ savedLookId=%@ creativeLut=%@ size=%@ intensity=%@ slug=%@ inputLutWillApply=%@ detectedTransform=%@ presetVersion=%@ E=%+.3f C=%.3f S=%.3f T=%+.3f",
            diag.lookLabel,
            diag.cameraProfileLabel,
            diag.cameraProfilePassedToProcessor ? "Y" : "N",
            diag.savedLookPassedToProcessor ? "Y" : "N",
            diag.savedLookId ?? "nil",
            diag.creativeLutPresent ? "ON" : "OFF",
            diag.creativeLutSize.map(String.init) ?? "nil",
            diag.creativeLutIntensity.map { String(format: "%.3f", $0) } ?? "nil",
            diag.creativeLutBundledSlug ?? "nil",
            diag.inputLutWillApply ? "Y" : "N",
            diag.detectedInputTransform ?? "nil",
            diag.presetVersion,
            diag.exposure,
            diag.contrast,
            diag.saturation,
            diag.temperature
        )
    }

    // MARK: - Behaviors

    private var isRecordingOrStopping: Bool {
        switch session.state {
        case .recording, .stopping: return true
        default: return false
        }
    }

    private var canToggleRecord: Bool {
        switch session.state {
        case .ready, .recording: return true
        default: return false
        }
    }

    private func prepareSession() async {
        // S8-B: enumerate rear lenses on first call; on subsequent
        // calls (after a lens swap) reuse the existing list.  The
        // catalog is cheap (it walks AVCaptureDevice.DiscoverySession),
        // but rerunning it would re-resolve `device` references and
        // invalidate `selectedLens` Equatable comparisons.
        if lenses.isEmpty {
            let discovered = FilmtoneCaptureLensCatalog.availableRearLenses()
            lenses = discovered
            selectedLens = FilmtoneCaptureLensCatalog.defaultLens(in: discovered)
        }
        guard let lens = selectedLens else {
            // No rear lens passed the M10 contract.  Surface as the
            // existing `.noWideCamera` failure (semantically: "no
            // qualifying rear camera"), which the failure overlay
            // already routes correctly.
            prepareError = .noWideCamera
            return
        }
        do {
            try await session.prepare(lens: lens)
        } catch let failure as FilmtoneCaptureFailure {
            prepareError = failure
        } catch {
            prepareError = .unexpected(reason: error.localizedDescription)
        }
    }

    /// S8-B: switch the active rear lens.  Tears down the current
    /// session graph and re-prepares against the chosen lens.  The
    /// `lensSwitchInFlight` guard prevents re-entrant taps from
    /// interleaving teardown + prepare on a half-configured session.
    private func selectLens(_ lens: FilmtoneCaptureLens) {
        guard lens != selectedLens, !lensSwitchInFlight else { return }
        lensSwitchInFlight = true
        let previous = selectedLens
        selectedLens = lens
        prepareError = nil
        Task {
            await session.teardown()
            do {
                try await session.prepare(lens: lens)
            } catch let failure as FilmtoneCaptureFailure {
                // Roll back the selection so the spec line / pill row
                // do not lie about which lens is active when prepare()
                // failed.  The failure overlay surfaces the reason.
                selectedLens = previous
                prepareError = failure
            } catch {
                selectedLens = previous
                prepareError = .unexpected(reason: error.localizedDescription)
            }
            lensSwitchInFlight = false
        }
    }

    private func toggleRecord() {
        switch session.state {
        case .ready:
            Task { await session.start() }
        case .recording:
            session.stop()
        default:
            return
        }
    }

    private func dismissCapture() {
        Task {
            await session.teardown()
            await MainActor.run {
                releaseExternalFolderScope()
                onCancelled()
            }
        }
    }

    // MARK: - Folder picker

    private func handleFolderPick(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            preflightError = "Folder picker failed: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            applyPickedFolder(url: url)
        }
    }

    private func applyPickedFolder(url: URL) {
        releaseExternalFolderScope()
        guard url.startAccessingSecurityScopedResource() else {
            preflightError = "Could not acquire security-scoped access on the selected folder."
            preflightWarnings = []
            return
        }
        let outcome = FilmtoneCapturePreflight.preflight(folderURL: url)
        if !outcome.passed {
            url.stopAccessingSecurityScopedResource()
            preflightError = outcome.notes.joined(separator: "; ")
            preflightWarnings = outcome.warnings
            return
        }
        heldExternalFolderURL = url
        preflightError = nil
        preflightWarnings = outcome.warnings
        session.useExternalFolder(url)
        // Persist so the next capture-view present auto-resolves the
        // same SSD folder without forcing the owner through the Files
        // importer again.  Stored only after preflight passes so we
        // never bookmark an internal / no-capacity path.
        FilmtoneExternalFolderBookmark.save(url: url)
    }

    /// Auto-restore on `.task`: pull the saved bookmark, run the same
    /// preflight + security-scope acquire path as `applyPickedFolder`,
    /// and only commit when both gates pass.  Anything failing
    /// silently clears the bookmark and leaves the surface in internal
    /// mode — the SSD button is still available so the owner can
    /// re-pick if they reconnected the drive after launch.
    private func restorePersistedExternalFolderIfPossible() {
        guard let url = FilmtoneExternalFolderBookmark.loadAndResolve() else {
            return
        }
        guard url.startAccessingSecurityScopedResource() else {
            FilmtoneExternalFolderBookmark.clear()
            return
        }
        let outcome = FilmtoneCapturePreflight.preflight(folderURL: url)
        if !outcome.passed {
            url.stopAccessingSecurityScopedResource()
            FilmtoneExternalFolderBookmark.clear()
            return
        }
        heldExternalFolderURL = url
        preflightError = nil
        preflightWarnings = outcome.warnings
        session.useExternalFolder(url)
    }

    private func clearExternalFolder() {
        releaseExternalFolderScope()
        preflightWarnings = []
        preflightError = nil
        session.useExternalFolder(nil)
        // Clear the saved bookmark so the next capture-view present
        // does not re-attach the same SSD the owner just dismissed.
        FilmtoneExternalFolderBookmark.clear()
    }

    private func releaseExternalFolderScope() {
        if let url = heldExternalFolderURL {
            url.stopAccessingSecurityScopedResource()
        }
        heldExternalFolderURL = nil
    }
}

// MARK: - Preview layer wrapper

private struct FilmtoneCapturePreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewContainer {
        let v = PreviewContainer()
        v.attach(layer: previewLayer)
        return v
    }

    func updateUIView(_ uiView: PreviewContainer, context: Context) {
        uiView.attach(layer: previewLayer)
    }

    final class PreviewContainer: UIView {
        private var attachedLayer: AVCaptureVideoPreviewLayer?

        override class var layerClass: AnyClass { CALayer.self }

        func attach(layer: AVCaptureVideoPreviewLayer) {
            if attachedLayer === layer { return }
            attachedLayer?.removeFromSuperlayer()
            self.attachedLayer = layer
            layer.frame = bounds
            self.layer.addSublayer(layer)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            attachedLayer?.frame = bounds
        }
    }
}

#endif
