import SwiftUI

/// Source / Camera profile sheet — picks the input source profile (Apple Log
/// / S-Log3 / V-Log etc.), imports a custom input LUT, and surfaces the
/// saved-LUT strip. Creative-LUT (look) selection lives in the Look carousel
/// in fullscreen + the Library sheet (B6).
///
/// Migrated from `FilmtoneCameraProfileCard.swift` as part of the IA pivot.
/// Identifiers (`filmtone.lut.input.menu`, `filmtone.lut.input.intensity.*`)
/// are preserved verbatim so XCUITest snapshot suite keeps working.
struct FilmtoneSourceProfileSheet: View {
    @ObservedObject var store: FilmtoneEditorStore
    @Binding var savedLookSheet: SavedLookSheetMode?
    @Binding var lutDeleteConfirmation: LutLibraryEntry?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    cameraProfileSection
                    creativeLutImportSection
                    inputIntensitySection
                    savedLutsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("filmtone.sheet.source")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(store.strings.cameraLabel)
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("filmtone.section.source")

            Spacer(minLength: 12)

            Button(action: onDismiss) {
                Text(store.strings.savedLookSheetCancel)
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.glass)
            .controlSize(.regular)
            .accessibilityIdentifier("filmtone.sheet.source.dismiss")
        }
    }

    private var cameraProfileSection: some View {
        FilmtoneLutControls.profileRow(
            title: store.strings.cameraLabel,
            value: store.cameraProfileLabel,
            menuTitle: store.strings.cameraImport,
            systemImage: "camera.filters",
            menuIdentifier: "filmtone.lut.input.menu"
        ) {
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
    }

    private var creativeLutImportSection: some View {
        let ja = store.strings.usesJapaneseTypography
        return Button {
            Task { await store.importCreativeLut() }
        } label: {
            Label(
                ja ? "ルックLUTを読み込む" : "Import Look LUT",
                systemImage: "square.and.arrow.down"
            )
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .accessibilityIdentifier("filmtone.lut.creative.import")
    }

    @ViewBuilder
    private var inputIntensitySection: some View {
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
    }

    private var savedLutsSection: some View {
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
    }
}
