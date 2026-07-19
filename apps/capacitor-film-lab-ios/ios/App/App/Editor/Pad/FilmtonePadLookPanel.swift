import FilmLabSwiftCore
import SwiftUI

/// Inline Look panel for the iPad inspector rail.
///
/// Surfaces the saved-Look library (built-in + user) as a vertical grid so
/// the iPad user can apply / save / rename / favorite / delete without
/// entering a sheet.  Strength and creative-LUT intensity sliders mirror
/// the fullscreen-editor bottom dock so the same control surface is
/// reachable from the inspector while the preview stays on-canvas.
///
/// Modal text entry (saved-Look naming, LUT rename) still uses the
/// existing `FilmtoneSavedLookSheet` flow — only the picking / clearing
/// / strength / save-current loop is inline.  Built-in vs user entries
/// are differentiated by the chip styling already shared with
/// `FilmtoneSavedLooksStrip` (camera-aperture icon for entries, sparkles
/// reserved for bundled Looks).
struct FilmtonePadLookPanel: View {
    @ObservedObject var store: FilmtoneEditorStore
    @Binding var savedLookSheet: SavedLookSheetMode?
    @Binding var lookDeleteConfirmation: SavedLookEntry?
    let onSaveCurrentLook: () -> Void

    private static let columns: [GridItem] = [
        GridItem(.flexible(), spacing: FilmtonePadTouchMetrics.gridSpacing),
        GridItem(.flexible(), spacing: FilmtonePadTouchMetrics.gridSpacing),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FilmtonePadTouchMetrics.sectionSpacing) {
            activeLookSummary

            looksGrid

            importLookLutButton

            if store.appliedSavedLookId != nil || store.project.creativeLut != nil {
                clearLookButton
            }

            if store.project.creativeLut != nil {
                lookIntensitySlider
            }

            if store.project.presetName != FilmtonePhase0Generated.presetDefault {
                strengthSlider
            }

            Divider()
                .background(Color.white.opacity(0.06))

            saveCurrentLookButton
        }
    }

    private var activeLookSummary: some View {
        let label: String = {
            if let id = store.appliedSavedLookId,
               let entry = store.library.looks.first(where: { $0.id == id }) {
                return store.strings.displayName(for: entry)
            }
            if store.project.creativeLut != nil {
                return store.strings.usesJapaneseTypography ? "カスタム LUT" : "Custom LUT"
            }
            return store.strings.usesJapaneseTypography ? "Look 未適用" : "No Look applied"
        }()

        return Text(label)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.86))
            .lineLimit(1)
            .truncationMode(.middle)
            .accessibilityIdentifier("filmtone.pad.inspector.look.activeLabel")
    }

    private var looksGrid: some View {
        LazyVGrid(
            columns: Self.columns,
            alignment: .leading,
            spacing: FilmtonePadTouchMetrics.gridSpacing
        ) {
            ForEach(store.library.looks) { entry in
                lookChip(entry: entry)
            }
        }
        .accessibilityIdentifier("filmtone.pad.inspector.look.grid")
    }

    private func lookChip(entry: SavedLookEntry) -> some View {
        let isActive = store.appliedSavedLookId == entry.id

        return Button {
            Task { await store.applySavedLook(id: entry.id) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: entry.bundled ? "sparkles" : "camera.aperture")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isActive ? Color.black.opacity(0.86) : Color.filmtoneAmber.opacity(0.86))

                Text(store.strings.displayName(for: entry))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(isActive ? Color.black.opacity(0.92) : .white.opacity(0.92))

                if entry.favorite {
                    Spacer(minLength: 4)
                    Image(systemName: "star.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isActive ? Color.black.opacity(0.78) : Color.filmtoneAmber.opacity(0.78))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(
            FilmtonePadTouchButtonStyle(
                isActive: isActive,
                activeFill: Color.filmtoneAmber.opacity(0.92),
                inactiveFill: Color.white.opacity(0.06),
                inactiveStroke: Color.white.opacity(0.10),
                minHeight: FilmtonePadTouchMetrics.minimumControlHeight
            )
        )
        .contextMenu {
            // M7 (WP4): chip context menu iterates the canonical
            // `FilmtoneLookOperation.contextMenuOperations` set so the
            // per-row affordances are derived from the shared Core
            // vocabulary, not hand-listed on each platform. Desktop's
            // library-action row consumes the same enum via
            // `libraryActionRowOperations`. Adding a new context-menu
            // operation means appending to the FilmLabSwiftCore set
            // once and handling the new case on both platforms.
            ForEach(
                FilmtoneLookOperation.contextMenuOperations.filter { op in
                    op.isAvailable(
                        hasTargetEntry: true,
                        entryImmutable: entry.immutable
                    )
                }
            ) { op in
                lookOperationButton(op, for: entry)
            }
        }
        .accessibilityIdentifier("filmtone.pad.inspector.look.chip.\(entry.id.uuidString.lowercased())")
    }

    private var importLookLutButton: some View {
        let ja = store.strings.usesJapaneseTypography
        return Button {
            Task { await store.importCreativeLut() }
        } label: {
            Label(
                ja ? "ルックLUTを読み込む" : "Import Look LUT",
                systemImage: "square.and.arrow.down"
            )
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(FilmtonePadTouchButtonStyle())
        .accessibilityIdentifier("filmtone.pad.inspector.look.importLut")
    }

    /// Dispatches a `FilmtoneLookOperation` to the iPad-typed store
    /// methods. The Core enum drives ordering, availability, and
    /// accessibility identifiers; this function owns iPad-specific
    /// localization and the typed store calls.
    @ViewBuilder
    private func lookOperationButton(
        _ operation: FilmtoneLookOperation,
        for entry: SavedLookEntry
    ) -> some View {
        switch operation {
        case .apply:
            Button {
                Task { await store.applySavedLook(id: entry.id) }
            } label: {
                Label(store.strings.libraryApplyAction,
                      systemImage: operation.systemImage)
            }
            .accessibilityIdentifier(operation.accessibilityIdentifier)

        case .toggleFavorite:
            Button {
                Task { await store.toggleFavoriteSavedLook(id: entry.id) }
            } label: {
                Label(
                    entry.favorite
                        ? store.strings.libraryUnfavoriteAction
                        : store.strings.libraryFavoriteAction,
                    systemImage: entry.favorite ? "star.slash" : "star"
                )
            }
            .accessibilityIdentifier(operation.accessibilityIdentifier)

        case .rename:
            Button {
                savedLookSheet = .renameLook(entry)
            } label: {
                Label(store.strings.libraryRenameAction,
                      systemImage: operation.systemImage)
            }
            .accessibilityIdentifier(operation.accessibilityIdentifier)

        case .delete:
            Button(role: .destructive) {
                lookDeleteConfirmation = entry
            } label: {
                Label(store.strings.libraryDeleteAction,
                      systemImage: operation.systemImage)
            }
            .accessibilityIdentifier(operation.accessibilityIdentifier)

        case .clear, .saveCurrent:
            // Not part of `contextMenuOperations`; if a future
            // entry-context op is added that lacks a dispatch here,
            // SwiftUI will still compile via the catch-all
            // EmptyView — but the filter above already excludes these
            // two by their `isEntryContextOperation` flag, so this
            // branch is unreachable in current code paths.
            EmptyView()
        }
    }

    private var clearLookButton: some View {
        Button {
            store.clearCreativeLut()
        } label: {
            Label(
                store.strings.fullscreenNoLookLabel,
                systemImage: "circle.dashed"
            )
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(
            FilmtonePadTouchButtonStyle(
                inactiveFill: Color.white.opacity(0.05),
                inactiveForeground: Color.white.opacity(0.78)
            )
        )
        .accessibilityIdentifier("filmtone.pad.inspector.look.clear")
    }

    private var lookIntensitySlider: some View {
        let control = FilmtoneLookControlID.creativeLutIntensity
        let clamped = FilmtonePhase0Math.clampLutIntensity(store.project.creativeLut?.intensity ?? 1.0)

        return FilmtonePadSliderControl(
            title: store.strings.fullscreenLookIntensityLabel,
            valueText: Self.percentLabel(clamped),
            valueAccessibilityIdentifier: control.iPadValueAccessibilityIdentifier,
            sliderAccessibilityIdentifier: control.iPadSliderAccessibilityIdentifier,
            value: Binding(
                get: {
                    FilmtonePhase0Math.clampLutIntensity(store.project.creativeLut?.intensity ?? 1.0)
                },
                set: { store.setCreativeLutIntensity($0) }
            ),
            range: control.range,
            isActive: true
        )
    }

    private var strengthSlider: some View {
        let control = FilmtoneLookControlID.strength
        let clamped = FilmtonePhase0Math.clampStrength(store.project.strength)

        return FilmtonePadSliderControl(
            title: store.strings.fullscreenStrengthLabel,
            valueText: Self.percentLabel(clamped),
            valueAccessibilityIdentifier: control.iPadValueAccessibilityIdentifier,
            sliderAccessibilityIdentifier: control.iPadSliderAccessibilityIdentifier,
            value: Binding(
                get: { FilmtonePhase0Math.clampStrength(store.project.strength) },
                set: { store.setStrength($0) }
            ),
            range: control.range,
            isActive: true
        )
    }

    private var saveCurrentLookButton: some View {
        Button(action: onSaveCurrentLook) {
            Label("Save Current Look", systemImage: "bookmark")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(
            FilmtonePadTouchButtonStyle(
                inactiveFill: Color.filmtoneAmber.opacity(0.20),
                inactiveStroke: Color.filmtoneAmber.opacity(0.42),
                inactiveForeground: Color.filmtoneAmber,
                minHeight: FilmtonePadTouchMetrics.prominentControlHeight
            )
        )
        .accessibilityIdentifier("filmtone.pad.inspector.look.save")
    }

    private static func percentLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
