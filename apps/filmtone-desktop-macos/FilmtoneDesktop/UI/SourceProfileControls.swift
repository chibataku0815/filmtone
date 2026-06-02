import SwiftUI

// M5-C.1: right-rail Source Profile Picker. Sits above the Look panel so the
// user picks the source-side normalization (Auto / Apple Log / Apple Log 2 /
// ARRI LogC3 / DJI D-Log / D-Log M / Canon C-Log / Canon Log 3 + Cinema
// Gamut / V-Log / S-Log3 / Rec.709) before the Look layer.
//
// Visual posture matches the right-rail controls (Pass 4 readability fix):
// white labels on dark-tinted .clear Liquid Glass, with `.colorScheme(.dark)` on the
// Picker so the AppKit-bridged NSPopUpButton renders with a white label.
//
// Auto resolution surfaces a small "Detected: <englishName>" caption
// underneath the Picker so the user can see which catalog entry the
// detection-hint matcher resolved to. When Auto sees a wide-gamut /
// HDR source with no matching detection hint, the source-cap gate notice
// replaces the caption.

struct SourceProfileControls: View {
    @Bindable var state: EditorState

    private static let optionLabel = "Auto"

    private struct PickerOption: Hashable {
        let label: String
        let selection: CameraProfileSelection
    }

    private static let options: [PickerOption] = {
        var rows: [PickerOption] = [
            PickerOption(label: "Auto", selection: .auto)
        ]
        for entry in FilmtoneSourceProfileCatalog.allProfiles {
            rows.append(PickerOption(
                label: entry.englishName,
                selection: .builtIn(catalogId: entry.id)
            ))
        }
        return rows
    }()

    private var selectionBinding: Binding<CameraProfileSelection> {
        Binding(
            get: { state.sourceProfileSelection },
            set: { state.sourceProfileSelection = $0 }
        )
    }

    private var resolvedAutoEntry: CameraProfileCatalogEntry? {
        guard case .auto = state.sourceProfileSelection else { return nil }
        return FilmtoneSourceProfileCatalog.entry(forColorClass: state.probedSourceColorClass)
    }

    private var sourceCapNotice: String? {
        FilmtoneSourceInputTransform.sourceCapReason(probedColorClass: state.probedSourceColorClass)
            .flatMap { reason in
                FilmtoneSourceInputTransform.sourceExceedsCapacity(
                    selection: state.sourceProfileSelection,
                    probedColorClass: state.probedSourceColorClass
                ) ? reason : nil
            }
    }

    private var selectedLabel: String {
        switch state.sourceProfileSelection {
        case .auto:
            if let resolvedAutoEntry {
                return FilmtoneSourceProfileCatalog.autoResolvedValueLabel(for: resolvedAutoEntry)
            }
            return Self.optionLabel
        case .builtIn(let catalogId):
            return FilmtoneSourceProfileCatalog.entry(forCatalogId: catalogId)?.englishName ?? catalogId
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Menu {
                Button {
                    selectionBinding.wrappedValue = .auto
                } label: {
                    menuRow("Auto", selected: state.sourceProfileSelection == .auto)
                }
                Section("Camera Profiles") {
                    ForEach(Self.options.dropFirst(), id: \.self) { option in
                        Button {
                            selectionBinding.wrappedValue = option.selection
                        } label: {
                            menuRow(option.label, selected: state.sourceProfileSelection == option.selection)
                        }
                    }
                }
            } label: {
                FilmtoneGlassMenuTrigger(
                    title: "Source",
                    value: selectedLabel,
                    systemImage: "camera.filters"
                )
            }
            .filmtoneGlassMenuChrome()

            if let notice = sourceCapNotice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 220, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let resolvedAutoEntry {
                Text(FilmtoneSourceProfileCatalog.autoDetectedCaption(
                    for: resolvedAutoEntry,
                    prefersJapanese: FilmtoneDesktopStrings.prefersJapanese()
                ))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 220, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func menuRow(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
