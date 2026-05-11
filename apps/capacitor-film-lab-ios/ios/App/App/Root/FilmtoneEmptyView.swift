import SwiftUI

/// Pre-load entry surface (`store.source == nil`).
///
/// **M15-final v3 (2026-05-09)**: drops the sphere mask entirely
/// after owner clarified 「mask 自体が必要ない / 球体は求めていない /
/// 複数 blob が混ざり合うアニメーション」. The shader now renders
/// 5 pastel blobs drifting across the full screen as the empty-view
/// backdrop; Liquid Glass UI (saved-Looks chips + action capsule
/// stack) sits on top and refracts the fluid color underneath.
///
/// Filmtone editor effects integrated in the backdrop:
/// chromatic aberration, film grain, glow halation. The empty view
/// is the product previewing what Filmtone does to user clips.
struct FilmtoneEmptyView: View {
    @ObservedObject var store: FilmtoneEditorStore
    let onPickPhotoLibrary: () -> Void
    let onPickFiles: () -> Void
    let onRecordProductClip: () -> Void
    var isRecordProductClipSupported: Bool = true
    var recordProductClipUnsupportedMessage: String? = nil
    var onPickWithLook: (SavedLookEntry) -> Void = { _ in }

    var body: some View {
        ZStack {
            substrate
                .ignoresSafeArea()

            FilmtoneFluidBlobBackdrop()
                .ignoresSafeArea()
                .accessibilityIdentifier("filmtone.empty.fluidBackdrop")

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                if !store.library.looks.isEmpty {
                    savedLooksTeaser
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                actionStack
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // v6: empty view is the only light-themed surface in an
        // otherwise dark editor app — flip the local color scheme
        // so `.primary` foreground colors and the system status bar
        // adapt to the cream substrate without breaking the rest of
        // the app's dark theme. `.preferredColorScheme` only affects
        // the receiver subtree.
        .preferredColorScheme(.light)
        .accessibilityIdentifier("filmtone.empty")
    }

    // MARK: Substrate

    /// Cream warm-pastel substrate (matches shader BASE_COLOR). v6
    /// commits to a genuinely light bg matching reference images
    /// #7 / #8 instead of the previous near-black "warm bias" cuts
    /// that read as black to the eye.
    private var substrate: some View {
        Color(red: 0.86, green: 0.82, blue: 0.78)
    }

    // MARK: Saved Looks teaser

    /// Existing `FilmtoneSavedLooksStrip` (post-M15-bis chip re-tune
    /// — neutral Liquid Glass, amber survives only on the camera-
    /// aperture icon and the favorite star). Rendered only when the
    /// owner has at least one saved Look.
    private var savedLooksTeaser: some View {
        GlassEffectContainer(spacing: 10) {
            FilmtoneSavedLooksStrip(
                entries: store.library.looks,
                strings: store.strings,
                onApply: { entry in
                    onPickWithLook(entry)
                },
                onRename: { _ in },
                onDelete: { _ in },
                onToggleFavorite: { _ in }
            )
            .padding(.horizontal, 8)
        }
        .accessibilityIdentifier("filmtone.empty.savedLooks")
    }

    // MARK: Action stack — Apple Liquid Glass capsule buttons

    /// Three glass capsule buttons inside a single
    /// `GlassEffectContainer` so adjacent capsules merge as one
    /// material instead of stacking translucencies. The fluid sphere
    /// drifting / breathing above gives the capsules an actual
    /// pastel atmosphere to refract — that is the Liquid Glass
    /// signature the surface had been missing through M15-ter.
    ///
    /// Layout: 2-up Photo Library / Files (compact) above a
    /// full-width Record (wide). Wide row lightly emphasizes the
    /// Filmtone-authored capture path; equal material grammar binds
    /// the three actions into one CTA stack.
    private var actionStack: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    glassCTA(
                        title: store.strings.pickFromPhotoLibrary,
                        systemImage: "photo.on.rectangle.angled",
                        identifier: "filmtone.empty.photoLibrary",
                        action: onPickPhotoLibrary
                    )
                    glassCTA(
                        title: store.strings.pickFromFiles,
                        systemImage: "folder",
                        identifier: "filmtone.empty.files",
                        action: onPickFiles
                    )
                }
                glassCTA(
                    title: store.strings.recordProductClip,
                    systemImage: "video.fill",
                    identifier: "filmtone.empty.recordProductClip",
                    isDisabled: store.isBusy || !isRecordProductClipSupported,
                    action: onRecordProductClip
                )
                if !isRecordProductClipSupported,
                   let recordProductClipUnsupportedMessage {
                    Text(recordProductClipUnsupportedMessage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 14)
                        .accessibilityIdentifier("filmtone.empty.recordProductClip.unsupported")
                }
            }
        }
    }

    @ViewBuilder
    private func glassCTA(
        title: String,
        systemImage: String,
        identifier: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        // v6: text/icon use `.primary` and rim uses `Color.primary`
        // so this capsule adapts to the surrounding color scheme.
        // On the empty view (`.preferredColorScheme(.light)`) → black
        // text on cream-glass. On any other surface (dark scheme) →
        // white text. No hard-coded white that would disappear on
        // the new cream substrate.
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.86))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: Capsule())
            .overlay(
                Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .opacity(isDisabled ? 0.45 : 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier(identifier)
    }
}
