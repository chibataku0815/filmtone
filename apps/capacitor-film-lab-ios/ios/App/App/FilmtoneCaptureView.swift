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

struct FilmtoneCaptureView: View {

    let lookReference: FilmtoneCaptureLookReference?
    let onCompleted: (FilmtoneCapturePackage) -> Void
    let onCancelled: () -> Void
    let onFailed: (FilmtoneCaptureFailure) -> Void

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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            previewLayer

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
        }
        .task {
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
        if let layer = session.previewLayer {
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
                Text("Live ungraded")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
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
                    Text(lens.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            lens == selectedLens
                                ? Color.white.opacity(0.28)
                                : Color.black.opacity(0.42),
                            in: Capsule()
                        )
                }
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
            ? (selectedLens.map { "\($0.displayName) · " } ?? "")
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
    }

    private func clearExternalFolder() {
        releaseExternalFolderScope()
        preflightWarnings = []
        preflightError = nil
        session.useExternalFolder(nil)
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
