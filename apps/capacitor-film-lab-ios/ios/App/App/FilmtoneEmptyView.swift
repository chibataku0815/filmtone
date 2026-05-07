import SwiftUI

/// Pre-load entry surface (`store.source == nil`). The wordmark + tagline
/// hero was rejected by CD as cheap brand surface; tagline was deleted at
/// the source-of-truth level. The current land hosts a CD-supplied symbol
/// image (`FilmtoneSymbol01`) as the sole hero, over a quiet near-black
/// substrate. Saved Looks teaser + photo / files CTAs preserve prior wiring.
struct FilmtoneEmptyView: View {
    @ObservedObject var store: FilmtoneEditorStore
    let onPickPhotoLibrary: () -> Void
    let onPickFiles: () -> Void
    let onRecordProductClip: () -> Void
    var onPickWithLook: (SavedLookEntry) -> Void = { _ in }

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                symbolHero

                Spacer(minLength: 24)

                if !store.library.looks.isEmpty {
                    savedLooksTeaser
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                Spacer(minLength: 0)

                ctaBlock
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("filmtone.empty")
    }

    // MARK: Background

    /// Quiet near-black substrate. A faint center-warm radial gives Liquid
    /// Glass a minimal substrate variation to refract without competing with
    /// the symbol hero. The amber/teal hero gradients of the rejected design
    /// are intentionally absent.
    private var backgroundLayer: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.45),
                ],
                center: .center,
                startRadius: 80,
                endRadius: 620
            )
        }
    }

    // MARK: Symbol hero

    private var symbolHero: some View {
        Image("FilmtoneSymbol01")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 140, maxHeight: 140)
            .accessibilityIdentifier("filmtone.empty.symbol")
            .accessibilityLabel(store.strings.appName)
    }

    // MARK: Saved Looks teaser (≥1 件)

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

    // MARK: CTA pickers

    private var ctaBlock: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                Button(action: onPickPhotoLibrary) {
                    Label(
                        store.strings.pickFromPhotoLibrary,
                        systemImage: "photo.on.rectangle.angled"
                    )
                    .font(.footnote.weight(.medium))
                }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("filmtone.empty.photoLibrary")

                Button(action: onPickFiles) {
                    Label(store.strings.pickFromFiles, systemImage: "folder")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("filmtone.empty.files")

                Button(action: onRecordProductClip) {
                    Label(store.strings.recordProductClip, systemImage: "video.fill")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.glass)
                .disabled(store.isBusy)
                .accessibilityIdentifier("filmtone.empty.recordProductClip")
            }
        }
    }
}
