import SwiftUI

/// Horizontal-scroll strip that surfaces every imported library LUT under
/// the Camera (input-LUT) row, sorted lastUsedAt-desc so the entries the
/// user touches most often stay nearest. Tap-to-apply uses the entry's
/// `defaultIntensity`. Long-press surfaces a context menu so users can
/// rename, delete, or favorite without leaving the main editor.
///
/// Named `Saved LUTs` (not `Recent LUTs`) because the v1.3 MVP has no
/// `Manage all…` sibling to contrast a temporal subset against — the strip
/// is the user's entire LUT library. v1.4 may reintroduce the
/// `Recent / All` split when the full management screen ships.
struct FilmtoneSavedLutsStrip: View {
    let entries: [LutLibraryEntry]
    let strings: FilmtoneStrings
    let onApply: (LutLibraryEntry) -> Void
    let onRename: (LutLibraryEntry) -> Void
    let onDelete: (LutLibraryEntry) -> Void
    let onToggleFavorite: (LutLibraryEntry) -> Void

    var body: some View {
        if entries.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(strings.librarySavedLutsTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .accessibilityIdentifier("filmtone.library.recentLuts.title")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(entries.prefix(FilmtoneLibraryConstants.recentLutDisplayCap)) { entry in
                            FilmtoneLibraryChip(
                                title: entry.title,
                                systemImage: "camera.filters",
                                isFavorite: entry.favorite
                            )
                            .onTapGesture { onApply(entry) }
                            .contextMenu {
                                Button {
                                    onApply(entry)
                                } label: {
                                    Label(strings.libraryApplyAction, systemImage: "checkmark.circle")
                                }
                                Button {
                                    onRename(entry)
                                } label: {
                                    Label(strings.libraryRenameAction, systemImage: "pencil")
                                }
                                Button {
                                    onToggleFavorite(entry)
                                } label: {
                                    Label(
                                        entry.favorite
                                            ? strings.libraryUnfavoriteAction
                                            : strings.libraryFavoriteAction,
                                        systemImage: entry.favorite ? "star.slash" : "star"
                                    )
                                }
                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Label(strings.libraryDeleteAction, systemImage: "trash")
                                }
                            }
                            .accessibilityIdentifier("filmtone.library.recentLuts.chip.\(entry.id.uuidString.lowercased())")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .accessibilityIdentifier("filmtone.library.recentLuts")
        }
    }
}

extension LutLibraryEntry: Identifiable {}

/// Horizontal-scroll strip surfacing every saved Look. Empty state is a
/// short hint inviting the user to save their first Look — the row is the
/// primary advertisement for the reuse loop.
struct FilmtoneSavedLooksStrip: View {
    let entries: [SavedLookEntry]
    let strings: FilmtoneStrings
    let onApply: (SavedLookEntry) -> Void
    let onRename: (SavedLookEntry) -> Void
    let onDelete: (SavedLookEntry) -> Void
    let onToggleFavorite: (SavedLookEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(strings.librarySavedLooksTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.52))
                Spacer()
            }

            if entries.isEmpty {
                Text(strings.librarySavedLooksEmpty)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("filmtone.library.savedLooks.empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(entries) { entry in
                            FilmtoneLibraryChip(
                                title: strings.displayName(for: entry),
                                systemImage: "camera.aperture",
                                isFavorite: entry.favorite,
                                isBundled: entry.bundled
                            )
                            .onTapGesture { onApply(entry) }
                            .contextMenu {
                                Button {
                                    onApply(entry)
                                } label: {
                                    Label(strings.libraryApplyAction, systemImage: "checkmark.circle")
                                }
                                if !entry.immutable {
                                    Button {
                                        onRename(entry)
                                    } label: {
                                        Label(strings.libraryRenameAction, systemImage: "pencil")
                                    }
                                }
                                Button {
                                    onToggleFavorite(entry)
                                } label: {
                                    Label(
                                        entry.favorite
                                            ? strings.libraryUnfavoriteAction
                                            : strings.libraryFavoriteAction,
                                        systemImage: entry.favorite ? "star.slash" : "star"
                                    )
                                }
                                if !entry.immutable {
                                    Button(role: .destructive) {
                                        onDelete(entry)
                                    } label: {
                                        Label(strings.libraryDeleteAction, systemImage: "trash")
                                    }
                                }
                            }
                            .accessibilityIdentifier("filmtone.library.savedLooks.chip.\(entry.id.uuidString.lowercased())")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .accessibilityIdentifier("filmtone.library.savedLooks")
    }
}

extension SavedLookEntry: Identifiable {}

/// Compact pill used for both Recent LUT and Saved Look entries.
/// Favorite items get a subtle amber star to match the existing
/// `Color.filmtoneAmber` accent system — no new colors introduced.
///
/// **M15-bis (2026-05-09)**: redesign after M15 was rejected at 20点.
/// Dropped the amber background tint (the M15 0.10 alpha still washed
/// the chip into opaque brown on the dark substrate). `isBundled`
/// status is now communicated through the **icon color** (amber
/// camera-aperture symbol) and the favorite star — the chip-shape
/// material itself is always plain `.regular.interactive()`. The
/// hairline rim is white-only so refraction at the rim reads as
/// silvery-clear glass, not tinted leather. Glass is applied
/// directly on the padded HStack — no `Color.clear.glassEffect`
/// background trick (which diffused labels in the rejected M15
/// implementation).
struct FilmtoneLibraryChip: View {
    let title: String
    let systemImage: String
    let isFavorite: Bool
    var isBundled: Bool = false

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: filmtoneControlCornerRadius,
            style: .continuous
        )
        return HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.filmtoneAmber.opacity(0.86))
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.tail)

            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.filmtoneAmber.opacity(0.78))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .glassEffect(.regular.interactive(), in: shape)
        .overlay(
            // v6: was `Color.white.opacity(0.10)` (invisible on cream).
            // `.primary` adapts to the surrounding color scheme so the
            // rim is white-on-dark in library section, dark-on-cream
            // in the empty view.
            shape.strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if isBundled {
            parts.append("Filmtone")
        }
        parts.append(title)
        if isFavorite {
            parts.append("favorite")
        }
        return parts.joined(separator: ", ")
    }
}
