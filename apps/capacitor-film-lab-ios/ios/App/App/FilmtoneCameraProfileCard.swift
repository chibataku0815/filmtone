import SwiftUI

struct FilmtoneCameraProfileCard: View {
    @ObservedObject var store: FilmtoneEditorStore
    @Binding var savedLookSheet: SavedLookSheetMode?
    @Binding var lutTermHelpPresented: Bool
    @Binding var lutDeleteConfirmation: LutLibraryEntry?
    @Binding var lookDeleteConfirmation: SavedLookEntry?

    var body: some View {
        VStack(spacing: 14) {
            FilmtoneLutControls.profileRow(
                title: store.strings.cameraLabel,
                value: store.cameraProfileLabel,
                menuTitle: store.strings.cameraImport,
                systemImage: "camera.filters",
                menuIdentifier: "filmtone.lut.input.menu",
                helpAction: { lutTermHelpPresented = true },
                helpAccessibilityLabel: store.strings.helpLutAccessibilityLabel,
                helpButtonIdentifier: "filmtone.help.lut.button"
            ) {
                // v1.3 Camera Profiles Phase F — built-in source profile
                // catalog rendered ahead of Auto / Import so users see the
                // primary explicit choices first. Order mirrors
                // FilmtoneSourceProfileCatalog.allProfiles. Auto stays as
                // a separate top-level item so it reads as "let Filmtone
                // decide" rather than "another preset".
                Button(store.strings.cameraAuto) {
                    store.applyCameraProfile(.auto)
                }
                ForEach(FilmtoneSourceProfileCatalog.allProfiles, id: \.id) { entry in
                    Button(store.strings.builtInSourceProfileName(for: entry.id) ?? entry.englishName) {
                        store.applyCameraProfile(.builtIn(catalogId: entry.id))
                    }
                }
                Divider()
                Button(store.strings.cameraImport) {
                    Task { await store.importInputLut() }
                }
                if store.project.inputLut != nil {
                    Button(store.strings.clearLut, role: .destructive) {
                        store.clearInputLut()
                    }
                }
            }

            if let inputLut = store.project.inputLut {
                FilmtoneLutControls.intensityControl(
                    title: store.strings.inputLutAmountLabel,
                    value: inputLut.intensity,
                    valueIdentifier: "filmtone.lut.input.intensity.value",
                    sliderIdentifier: "filmtone.lut.input.intensity.slider"
                ) { nextValue in
                    store.setInputLutIntensity(nextValue)
                }
            }

            // Saved LUTs strip — only renders when there is at least one
            // entry, so the LUT card stays the same height as v1.2 for users
            // who have never imported a LUT. Bound to `library.luts` (the
            // full list, lastUsedAt-desc sorted by the actor) rather than
            // the 6-cap `recentLuts` projection so the "保存したLUT" header
            // stays honest — every imported LUT is reachable via horizontal
            // scroll. v1.4 may reintroduce a Recent / All split when the
            // dedicated management screen ships.
            FilmtoneSavedLutsStrip(
                entries: store.library.luts,
                strings: store.strings,
                onApply: { entry in
                    Task { await store.applyLibraryLut(libraryId: entry.id, slot: .input) }
                },
                onRename: { entry in
                    savedLookSheet = .renameLut(entry)
                },
                onDelete: { entry in
                    lutDeleteConfirmation = entry
                },
                onToggleFavorite: { entry in
                    Task { await store.toggleFavoriteLibraryLut(id: entry.id) }
                }
            )

            Divider()
                .overlay(Color.white.opacity(0.08))

            FilmtoneLutControls.profileRow(
                title: store.strings.lookLabel,
                value: store.lookProfileLabel,
                menuTitle: store.strings.lookImport,
                systemImage: "camera.aperture",
                menuIdentifier: "filmtone.lut.creative.menu"
            ) {
                Button(store.strings.lookFilmtone) {
                    store.clearCreativeLut()
                }
                Button(store.strings.lookImport) {
                    Task { await store.importCreativeLut() }
                }
                Button(store.strings.lookSaveCurrentMenu) {
                    savedLookSheet = .createCurrentLook
                }
                .disabled(!canSaveCurrentLook)
                if store.project.creativeLut != nil {
                    Button(store.strings.clearLut, role: .destructive) {
                        store.clearCreativeLut()
                    }
                }
            }

            if let creativeLut = store.project.creativeLut {
                FilmtoneLutControls.intensityControl(
                    title: store.strings.lookLutAmountLabel,
                    value: creativeLut.intensity,
                    valueIdentifier: "filmtone.lut.creative.intensity.value",
                    sliderIdentifier: "filmtone.lut.creative.intensity.slider"
                ) { nextValue in
                    store.setCreativeLutIntensity(nextValue)
                }
            }

            // Saved Looks strip — always visible (with empty-state copy when
            // no looks exist) so first-time users see the pitch for the
            // reuse loop without needing to scroll or hunt through menus.
            FilmtoneSavedLooksStrip(
                entries: store.library.looks,
                strings: store.strings,
                onApply: { entry in
                    Task { await store.applySavedLook(id: entry.id) }
                },
                onRename: { entry in
                    savedLookSheet = .renameLook(entry)
                },
                onDelete: { entry in
                    lookDeleteConfirmation = entry
                },
                onToggleFavorite: { entry in
                    Task { await store.toggleFavoriteSavedLook(id: entry.id) }
                }
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    /// "Save current Look…" is gated to states where there is something
    /// meaningful to save: any preset different from `reset` defaults, OR
    /// any quick / advanced adjustment, OR a creative LUT applied.
    private var canSaveCurrentLook: Bool {
        if store.project.creativeLut != nil {
            return true
        }
        if store.hasAnyAdjustments {
            return true
        }
        if abs(store.project.strength - FilmtonePhase0Math.presetStrengthDefault) > 0.01 {
            return true
        }
        return false
    }
}
