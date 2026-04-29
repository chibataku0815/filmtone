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
                                title: entry.name,
                                systemImage: "camera.aperture",
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

/// Compact pill used for both Recent LUT and Saved Look entries. Favorite
/// items get a subtle amber star to match the existing `Color.filmtoneAmber`
/// accent system — no new colors introduced.
struct FilmtoneLibraryChip: View {
    let title: String
    let systemImage: String
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.filmtoneAmber.opacity(0.86))
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
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
        .background(
            RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(isFavorite ? "\(title), favorite" : title))
    }
}
