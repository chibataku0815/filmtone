import FilmLabSwiftCore
import SwiftUI

/// Top toolbar for the iPad Workspace.
///
/// Mirrors the Desktop toolbar primary actions in Desktop visual order:
/// Source-replace, Compare, Export, Inspector visibility.  The folder
/// button is the Desktop-parity Open affordance — it presents the
/// system source picker dialog (Photo Library / Files) so the
/// user can replace the current media without entering the Source/Profile
/// sheet.  Source/Profile selection (camera profile, input LUT, intensity,
/// saved LUTs, storage) lives inline in the inspector Source panel.
///
/// Compare is context-aware:
/// - still source → toggles `isCompareHeld` (graded ↔ original)
/// - video source → calls `setVideoCompareMode(_:)` on the orchestrator so
///   the player visibly switches graded ↔ original instead of doing
///   nothing.  The button is disabled when no comparable frame exists.
struct FilmtonePadToolbar: View {
    @ObservedObject var store: FilmtoneEditorStore
    @Binding var compareEnabled: Bool
    @Binding var inspectorVisible: Bool
    let onClose: () -> Void
    let onReplaceSource: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            commandButton(
                .openSource,
                action: onReplaceSource
            )

            commandButton(
                .compare,
                isDisabled: !compareAvailable,
                isActive: isCompareActive,
                action: toggleCompare
            )

            commandButton(
                .export,
                isDisabled: store.source == nil,
                action: onExport
            )

            Spacer(minLength: 12)

            sourceLabel

            Spacer(minLength: 12)

            commandButton(.inspector) {
                inspectorVisible.toggle()
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close source")
            .accessibilityIdentifier("filmtone.pad.toolbar.close")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        )
    }

    private var compareAvailable: Bool {
        store.comparePreviewFrame != nil || store.videoPreviewState != nil
    }

    /// Reflects the active compare state so the toolbar capsule lights up.
    /// Video case mirrors the iPhone editor's `compareMode == .original`
    /// indicator. Still case is the iPad workspace's persistent split toggle.
    private var isCompareActive: Bool {
        if let video = store.videoPreviewState {
            return video.compareMode == .original
        }
        return compareEnabled
    }

    /// Routes the Compare tap to the right state writer based on whether
    /// the live preview is a still or a video.
    private func toggleCompare() {
        if let video = store.videoPreviewState {
            let next: FilmtoneVideoCompareMode =
                video.compareMode == .graded ? .original : .graded
            Task { await store.setVideoCompareMode(next) }
        } else {
            compareEnabled.toggle()
        }
    }

    @ViewBuilder
    private var sourceLabel: some View {
        if let source = store.source {
            Text(displayName(for: source.uri))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("filmtone.pad.toolbar.sourceLabel")
        }
    }

    private func displayName(for uri: String) -> String {
        guard let url = URL(string: uri) else { return "" }
        return url.lastPathComponent
    }

    @ViewBuilder
    private func commandButton(
        _ command: FilmtoneEditorToolbarCommand,
        isDisabled: Bool = false,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: command.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(command.label)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(foregroundStyle(isDisabled: isDisabled, isActive: isActive))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(
                .regular.tint(tintColor(isActive: isActive)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier(command.iPadAccessibilityIdentifier)
    }

    private func foregroundStyle(isDisabled: Bool, isActive: Bool) -> Color {
        if isDisabled { return Color.white.opacity(0.32) }
        if isActive { return Color.black }
        return .white
    }

    private func tintColor(isActive: Bool) -> Color {
        isActive ? Color.filmtoneAmber.opacity(0.86) : Color.black.opacity(0.22)
    }
}
