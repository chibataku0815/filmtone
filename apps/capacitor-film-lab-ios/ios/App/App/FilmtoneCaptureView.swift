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

struct FilmtoneCaptureView: View {

    let onCompleted: (FilmtoneCapturePackage) -> Void
    let onCancelled: () -> Void
    let onFailed: (FilmtoneCaptureFailure) -> Void

    @StateObject private var session = FilmtoneCaptureSession()
    @State private var prepareError: FilmtoneCaptureFailure?
    @State private var showFolderImporter = false
    @State private var preflightWarnings: [String] = []
    @State private var preflightError: String?
    @State private var heldExternalFolderURL: URL?

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
        HStack(spacing: 12) {
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

            storagePill
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
        switch session.storagePolicy {
        case .internalDocumentsCapped:
            return "Internal · 10s"
        case .externalSecurityScopedFolder(let url):
            return "SSD: \(url.lastPathComponent)"
        }
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

            specLine

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

    /// Display-only readout of the capture parameters pinned to the
    /// `FilmtoneCaptureParameters.baseline` quality contract.  M10 does
    /// not expose camera knobs (resolution / fps / codec / colorspace /
    /// stabilization) — the product directive is "make recording the
    /// entry surface", not "expose every knob".  This label keeps the
    /// owner honest about what is being recorded without inviting a
    /// settings page that would dilute the lane.
    private var specLine: some View {
        let p = FilmtoneCaptureParameters.baseline
        // Nearest-K rounding so 3840 reads as the conventional "4K"
        // (UHD), not the integer-truncated "3K".  The product baseline
        // is 3840×2160 24fps (cinematic 24p); the readout is
        // owner-visible truth.
        let kRounded = (p.widthPx + 500) / 1000
        let resolution = "\(kRounded)K\(Int(p.frameRate))"
        let durationCap = Int(session.currentDurationLimit())
        return Text(
            "\(resolution) · \(p.codec) · \(p.colorSpace) · \(p.stabilization) · \(durationCap)s cap"
        )
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.55))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .accessibilityIdentifier("filmtone.capture.specLine")
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
        do {
            try await session.prepare()
        } catch let failure as FilmtoneCaptureFailure {
            prepareError = failure
        } catch {
            prepareError = .unexpected(reason: error.localizedDescription)
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
