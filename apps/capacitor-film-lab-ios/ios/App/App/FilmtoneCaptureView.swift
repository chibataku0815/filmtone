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
import UIKit
import UniformTypeIdentifiers

struct FilmtoneCaptureView: View {

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
        liveGradeProcessor: FilmtoneSharedGradeProcessor?,
        liveDiagnostics: FilmtoneLivePreviewDiagnostics?,
        initialCaptureLook: FilmtoneCaptureLook = .filmtone,
        makeGradeProcessor: ((FilmtoneCaptureLook) -> FilmtoneLivePreviewBundle?)? = nil,
        onCompleted: @escaping (FilmtoneCapturePackage) -> Void,
        onCancelled: @escaping () -> Void,
        onFailed: @escaping (FilmtoneCaptureFailure) -> Void
    ) {
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
    /// M13-M-2: which parameter chip in the top row is currently
    /// active. Owned by this orchestrator; passed down to
    /// `FilmtoneCaptureCockpitTopBar` as a `Binding`. `.iso` / `.shutter`
    /// / `.ev` open a ruler region beneath the chip row (stub today,
    /// real ruler in M13-M-3). `.wb` toggles auto/locked directly.
    /// LOOK lives in the bottom-right capture control so the top row
    /// stays at five chips on hardware. `nil` = no scrubber row.
    @State private var activeParameterChip: CaptureParameterChip?
    /// M13-M-2: presentation flag for the Look picker sheet, bound to
    /// `.sheet(isPresented:)`.
    @State private var showLookPicker: Bool = false
    /// M13-M-3: tracks whether the active manual exposure was entered
    /// via a parameter chip tap. When true, tapping the same chip
    /// again exits manual back to auto. False if the manual mode was
    /// entered through some other path (none today; M13-M-4 simplifies
    /// when the dormant drawer code is deleted).
    @State private var manualEntryViaChipTap: Bool = false
    /// S3 (2026-05-09): completed packages accumulated within the
    /// current capture session.  After every successful `.completed`
    /// the session auto-rearms (see `.onChange(of: session.state)`),
    /// the latest package is appended here, and the cockpit's commit
    /// pill becomes tappable.  Tapping it adopts a chosen take into
    /// the editor via `onCompleted(_:)` and dismisses the surface.
    /// Earlier takes are not lost — each has its own
    /// `capture-package.json` on disk; the relaunch reconnect path
    /// can find them.  When multiple takes exist, a chooser avoids
    /// silently treating the latest take as the only keeper.
    @State private var capturedPackages: [FilmtoneCapturePackage] = []
    /// S3: guards re-entrant taps on the commit pill while the
    /// teardown + adopt path is in flight.  The pill is also disabled
    /// during recording so a stop-into-commit double-tap cannot
    /// race the proxy export's `.completed` transition.
    @State private var commitInFlight: Bool = false
    /// S3 owner-smoke revision: multiple takes require an explicit
    /// owner choice because the editor is a single-source surface.
    @State private var showTakePicker: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            previewLayer

            FilmtoneCaptureInteractionOverlay(
                canAcceptTap: canAcceptPreviewTap,
                reticlePoint: reticleViewPoint,
                reticleVisible: reticleVisible,
                onTap: handlePreviewTap
            )

            // M13-M-2: cockpit composition. Top zone holds HUD bar +
            // parameter chip row + ruler region (component-owned); bottom
            // zone holds lens chip row + compact shutter cluster. The
            // single GlassEffectContainer lets adjacent Liquid Glass
            // shapes merge as one material instead of stacking
            // translucencies. Each control owns its own glass primitive
            // — there is no longer a single shelf slab.
            GlassEffectContainer(spacing: 8) {
                VStack(spacing: 0) {
                    cockpitTopBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    if isUngradedPreviewFallback {
                        HStack {
                            ungradedPreviewBadge
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    Spacer()
                    bottomZone
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                }
            }

            if let prepareError {
                failureOverlay(prepareError)
            }

            if showTakePicker {
                FilmtoneCaptureTakePickerOverlay(
                    packages: capturedPackages,
                    onPick: commitTake,
                    onCancel: {
                        FilmtoneCaptureHaptics.selection()
                        showTakePicker = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: showTakePicker)
        .onAppear {
            // Capture connections are intentionally portrait-pinned
            // (`videoRotationAngle = 90`) to preserve the existing
            // master / proxy / motion contract. Keep the full-screen
            // capture surface portrait too; otherwise rotating the
            // iPhone lets SwiftUI relayout in landscape while the
            // camera pipeline remains portrait, making the preview's
            // up/down direction appear wrong.
            FilmtoneInterfaceOrientationLock.lockToPortrait()
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
                // S3 (2026-05-09): no longer auto-routes to the
                // editor.  Accumulate the package, immediately
                // re-arm the live AVCaptureSession for the next
                // take, and let the cockpit's commit pill carry
                // the explicit "open editor" affordance.  The
                // session state ticks `.completed` → `.ready` in
                // one main-actor hop so the cockpit never paints
                // a frozen post-record screen.
                capturedPackages.append(pkg)
                session.rearm()
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
            FilmtoneInterfaceOrientationLock.restoreDefault()
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
        .sheet(isPresented: $showLookPicker) {
            FilmtoneCaptureLookSheet(
                selection: $captureLookSelection,
                onDismiss: { showLookPicker = false }
            )
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
        //
        // S5 (2026-05-09): the fallback path now drives an explicit
        // "Ungraded" badge in the cockpit overlay so the owner does
        // not mistake the raw preview for a graded preview.  The Look
        // chip and the master record path still apply the chosen Look
        // at record time — only the live preview cannot show it on
        // this hardware.
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

    private var isUngradedPreviewFallback: Bool {
        !session.hasLivePreview && session.previewLayer != nil
    }

    /// S5 (2026-05-09): explicit "Ungraded" badge for the fallback
    /// preview path.  It lives in the cockpit overlay flow, directly
    /// below the top controls, so S3's take-commit pill and the
    /// quality-contract HUD cannot visually collide with it.
    /// `allowsHitTesting(false)` prevents the badge from intercepting
    /// taps that should reach the preview's tap-to-focus /
    /// tap-to-meter surface.
    private var ungradedPreviewBadge: some View {
        Text("Ungraded preview")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .captureGlassHUD(in: FilmtoneCaptureChrome.hudShape())
            .allowsHitTesting(false)
            .accessibilityIdentifier("filmtone.capture.ungradedPreviewBadge")
            .accessibilityLabel(Text("Ungraded preview"))
    }

    // MARK: - HUD readout sources

    private var storagePillIcon: String {
        switch session.storagePolicy {
        case .internalDocumentsCapped: return "internaldrive"
        case .externalSecurityScopedFolder: return "externaldrive.fill.badge.checkmark"
        }
    }

    private var storagePillLabel: String {
        let cap = Int(session.currentDurationLimit())
        let formatted = formatDurationCap(cap)
        switch session.storagePolicy {
        case .internalDocumentsCapped:
            return "Internal \(formatted)"
        case .externalSecurityScopedFolder:
            // S4 (2026-05-09): the external pill now carries the
            // resolved cap rather than a static "External master"
            // string so the owner sees the same readout shape on both
            // storage policies and can verify the 5 min ceiling at a
            // glance.
            return "External \(formatted)"
        }
    }

    /// S4 (2026-05-09): owner-visible duration-cap formatter.  Caps
    /// under 60 s render as `"10s"`; ≥ 60 s collapses to minutes
    /// (`"5m"`) and adds a residual seconds token only when the cap
    /// is not a whole minute (`"1m30s"`).  Keeps the storage pill
    /// readable across the existing `Internal 10s` / `External 5m`
    /// product-policy spread and any future intermediate ceilings.
    private func formatDurationCap(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let residual = seconds % 60
        if residual == 0 { return "\(minutes)m" }
        return "\(minutes)m\(residual)s"
    }

    // MARK: - Quality contract / manual summary chips (S13-C)

    private var qualityContractText: String {
        let p = FilmtoneCaptureParameters.baseline
        let kRounded = (p.widthPx + 500) / 1000
        let resolution = "\(kRounded)K\(Int(p.frameRate))"
        let segments: [String] = [
            resolution,
            "Log2",
            "ProRes",
        ]
        // S2 (2026-05-09): the active lens magnification belongs on the
        // canonical contract line for every topology — single-lens
        // devices have no chip row at all, and multi-lens devices need
        // a text readout that does not rely on the chip row's
        // selected-state styling alone.  The chip row's tint + rim +
        // bold-weight selection signal remains the control affordance;
        // this string is its readable companion.
        let lensPrefix = selectedLens.map { "\($0.magnificationLabel) · " } ?? ""
        return lensPrefix + segments.joined(separator: " · ")
    }

    // MARK: - Bottom deck (status, ssd picker, record button)

    private var bottomDeck: some View {
        FilmtoneCaptureBottomDeck(
            preflightError: preflightError,
            preflightWarnings: preflightWarnings,
            storagePressure: session.storagePressure,
            statusText: statusText,
            isRecordingOrStopping: isRecordingOrStopping,
            canToggleRecord: canToggleRecord,
            pickFolderIcon: pickFolderIcon,
            pickFolderLabel: pickFolderLabel,
            lookLabel: captureLookSelection.displayName,
            showsExternalClear: isExternalFolderSelected,
            onPickFolder: { showFolderImporter = true },
            onToggleRecord: toggleRecord,
            onClearFolder: clearExternalFolder,
            onPickLook: { showLookPicker = true }
        )
    }

    // MARK: - M13-M-2 cockpit zones (composition-only — chip / ruler /
    //         lens-row / look-sheet rendering live in their own files)

    /// Top zone: HUD bar + parameter chip row + ruler region. All
    /// internals live in `FilmtoneCaptureCockpitTopBar`; the orchestrator
    /// only forwards session state, ranges, and chip-tap / scrub
    /// callbacks. Auto↔manual mode entry on chip tap is owned here so
    /// the cockpit layer stays UI-only.
    private var cockpitTopBar: some View {
        FilmtoneCaptureCockpitTopBar(
            isCloseDisabled: isRecordingOrStopping,
            storageIcon: storagePillIcon,
            storageLabel: storagePillLabel,
            qualityContractText: qualityContractText,
            onClose: dismissCapture,
            takeCount: capturedPackages.count,
            isCommitDisabled: isRecordingOrStopping || commitInFlight,
            onCommitTakes: commitTakes,
            exposureMode: session.exposureMode,
            manualISO: session.manualISO,
            manualShutterSeconds: session.manualShutterSeconds,
            exposureBiasEV: session.exposureBiasEV,
            whiteBalanceMode: session.whiteBalanceMode,
            requestedStabilization: session.requestedStabilization,
            isRecordingOrStopping: isRecordingOrStopping,
            isoRange: session.isoRange,
            shutterDurationRange: session.shutterDurationRange,
            exposureBiasRange: session.exposureBiasRange,
            activeChip: $activeParameterChip,
            onChipTap: handleParameterChipTap,
            onScrubISO: { session.setManualISO($0) },
            onScrubShutter: { session.setManualShutter($0) },
            onScrubEV: { session.setExposureBias($0) }
        )
    }

    /// Bottom zone: lens chip horizontal row above the compact shutter
    /// cluster. Lens row hides itself when only one lens qualifies.
    private var bottomZone: some View {
        VStack(spacing: 10) {
            if lenses.count > 1 {
                FilmtoneCaptureLensChipRow(
                    lenses: lenses,
                    selectedLens: selectedLens,
                    isRecordingOrStopping: isRecordingOrStopping,
                    lensSwitchInFlight: lensSwitchInFlight,
                    onSelect: selectLens
                )
            }
            bottomDeck
        }
    }

    /// Routes a parameter chip tap. Handles the auto↔manual exposure
    /// mode entry pattern (Blackmagic-style one-tap mode entry):
    ///
    /// - `.iso` / `.shutter`:
    ///     - Tap when active → exit scrubber. If we entered manual via
    ///       this chip, also exit manual back to auto.
    ///     - Tap when inactive in auto → enter manual + open scrubber.
    ///     - Tap when inactive in manual → just switch the active
    ///       scrubber to this chip; stay in manual.
    /// - `.ev`: open / close scrubber. Auto-only chip; never appears
    ///   in manual (cockpit filters it out).
    /// - `.wb`: toggle auto / locked.
    /// LOOK is handled by the bottom-right capture control.
    private func handleParameterChipTap(_ chip: CaptureParameterChip) {
        switch chip {
        case .iso, .shutter:
            handleManualModeChipTap(chip)
        case .ev:
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                activeParameterChip = (activeParameterChip == chip) ? nil : chip
            }
        case .wb:
            let next: FilmtoneCaptureSession.WhiteBalanceMode =
                session.whiteBalanceMode == .locked ? .auto : .locked
            applyWhiteBalanceMode(next)
        case .stab:
            // S1 (2026-05-09): owner toggles stabilization between
            // On (cinematicExtendedEnhanced) and Off (.off).  The
            // chip itself is disabled while recording (cockpit
            // applies `.disabled(isRecordingOrStopping)`); the
            // session also gates `setRequestedStabilization` on
            // `state == .ready` for defensive callers.
            let next: FilmtoneRequestedStabilization =
                session.requestedStabilization == .on ? .off : .on
            session.setRequestedStabilization(next)
        }
    }

    private func handleManualModeChipTap(_ chip: CaptureParameterChip) {
        guard !isRecordingOrStopping else { return }
        if activeParameterChip == chip {
            // Tap the active chip → close scrubber, and if we entered
            // manual via the chip, exit back to auto.
            if manualEntryViaChipTap {
                session.exitManualExposure()
                manualEntryViaChipTap = false
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                activeParameterChip = nil
            }
        } else {
            // Tap a non-active scrubber chip. Auto → manual entry,
            // inheriting the auto reading. Manual → stay; just swap
            // active scrubber.
            if session.exposureMode == .auto {
                session.enterManualExposure()
                manualEntryViaChipTap = true
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                activeParameterChip = chip
            }
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

    private var isExternalFolderSelected: Bool {
        if case .externalSecurityScopedFolder = session.storagePolicy {
            return true
        }
        return false
    }

    // MARK: - Tap-to-focus interaction layer (M12 / S12-C)

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

    private func applyWhiteBalanceMode(
        _ mode: FilmtoneCaptureSession.WhiteBalanceMode
    ) {
        guard !isRecordingOrStopping else { return }
        guard session.whiteBalanceMode != mode else { return }
        switch mode {
        case .auto:
            session.unlockWhiteBalance()
        case .locked:
            // The `canLockWhiteBalance` gate is also enforced inside
            // the session, but checking here lets the UI short-circuit
            // before the seg button visually flashes a press.
            guard session.canLockWhiteBalance else { return }
            session.lockWhiteBalance()
        }
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

    /// S3 owner-smoke revision: one take opens directly; multiple
    /// takes require an explicit pick so the second take can be the
    /// keeper even if the owner recorded a third one afterwards.  All
    /// packages stay on disk regardless; the editor itself remains
    /// single-source, so "all takes" is a persistence guarantee here,
    /// not a batch-import action.
    private func commitTakes() {
        guard !commitInFlight else { return }
        switch capturedPackages.count {
        case 0:
            return
        case 1:
            commitTake(at: 0)
        default:
            showTakePicker = true
        }
    }

    private func commitTake(at index: Int) {
        guard capturedPackages.indices.contains(index) else { return }
        guard !commitInFlight else { return }
        let package = capturedPackages[index]
        commitInFlight = true
        showTakePicker = false
        Task {
            await session.teardown()
            await MainActor.run {
                releaseExternalFolderScope()
                onCompleted(package)
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

// MARK: - Take picker

private struct FilmtoneCaptureTakePickerOverlay: View {
    let packages: [FilmtoneCapturePackage]
    let onPick: (Int) -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.20)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onCancel)

                panel
                    .frame(maxHeight: min(proxy.size.height * 0.74, 660))
                    .padding(.horizontal, 14)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 12, 18))
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .accessibilityIdentifier("filmtone.capture.takePicker")
    }

    private var panel: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let ordered = Array(packages.indices.reversed())

        return GlassEffectContainer(spacing: 8) {
            VStack(spacing: 0) {
                Capsule()
                    .fill(.white.opacity(0.28))
                    .frame(width: 54, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                    .accessibilityHidden(true)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose take")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.96))
                        Text("\(packages.count) takes")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Spacer(minLength: 0)

                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glass)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Cancel")
                    .accessibilityIdentifier("filmtone.capture.takePicker.cancel")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(ordered, id: \.self) { index in
                            Button {
                                FilmtoneCaptureHaptics.selection()
                                onPick(index)
                            } label: {
                                FilmtoneCaptureTakePickerRow(
                                    package: packages[index],
                                    takeNumber: index + 1,
                                    isLatest: index == packages.indices.last
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("filmtone.capture.takePicker.take\(index + 1)")

                            if index != ordered.last {
                                Rectangle()
                                    .fill(.white.opacity(0.12))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, 2)
            .glassEffect(.clear.tint(.white.opacity(0.055)), in: shape)
            .overlay(
                shape.strokeBorder(.white.opacity(0.20), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(0.34), radius: 32, x: 0, y: 18)
        }
    }
}

private struct FilmtoneCaptureTakePickerRow: View {
    let package: FilmtoneCapturePackage
    let takeNumber: Int
    let isLatest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("Take \(takeNumber)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))

                if isLatest {
                    Text("Latest")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .glassEffect(.clear.tint(.white.opacity(0.07)), in: Capsule())
                }

                Spacer(minLength: 0)

                Text(formatRecordedDuration(package.recordedDurationSeconds))
                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.64))
            }

            FilmtoneCaptureTakeContactStrip(package: package)

            HStack(spacing: 8) {
                Text(detailLine)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var detailLine: String {
        var parts: [String] = []
        if let lens = package.lens?.magnificationLabel {
            parts.append(lens)
        }
        if let look = package.selectedLook?.englishName {
            parts.append(look)
        } else {
            parts.append("Filmtone")
        }
        return parts.joined(separator: " · ")
    }

    private var accessibilityLabel: String {
        let latest = isLatest ? ", latest" : ""
        return "Take \(takeNumber)\(latest), \(formatRecordedDuration(package.recordedDurationSeconds)), \(detailLine)"
    }

    private func formatRecordedDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0.0s" }
        if seconds < 10 {
            return String(format: "%.1fs", seconds)
        }
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct FilmtoneCaptureTakeContactStrip: View {
    let package: FilmtoneCapturePackage

    private static let sampleFractions: [Double] = [0.12, 0.38, 0.62, 0.88]

    @State private var images: [UIImage?] = Array(
        repeating: nil,
        count: FilmtoneCaptureTakeContactStrip.sampleFractions.count
    )

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.sampleFractions.indices, id: \.self) { index in
                frameSlot(image: images[index])
            }
        }
        .frame(height: 112)
        .task(id: package.captureId) {
            images = await Self.frames(for: package.proxyURL)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func frameSlot(image: UIImage?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        ZStack {
            shape.fill(.black.opacity(0.18))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "video")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.44))
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
    }

    private static func frames(for url: URL) async -> [UIImage?] {
        await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 240)

            let durationTime = try? await asset.load(.duration)
            let duration = durationTime.map(CMTimeGetSeconds) ?? 0

            var results: [UIImage?] = []
            for fraction in sampleFractions {
                let seconds: Double
                if duration.isFinite, duration > 0.4 {
                    seconds = min(duration * fraction, duration - 0.12)
                } else {
                    seconds = 0
                }

                let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
                guard let frame = try? await generator.image(at: time) else {
                    results.append(nil)
                    continue
                }
                results.append(UIImage(cgImage: frame.image))
            }

            return results
        }.value
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
