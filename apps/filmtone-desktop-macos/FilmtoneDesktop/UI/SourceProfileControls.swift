import SwiftUI

// M5-C.1: right-rail Source Profile Picker. Sits above GradeControls so the
// user picks the source-side normalization (Auto / Apple Log / Apple Log 2 /
// DJI D-Log / D-Log M / Canon C-Log / Canon Log 3 + Cinema Gamut / V-Log /
// S-Log3 / Rec.709) before the Look layer.
//
// Visual posture matches GradeControls (Pass 4 readability fix): white labels
// on dark-tinted .clear Liquid Glass, with `.colorScheme(.dark)` on the
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Source", selection: selectionBinding) {
                ForEach(Self.options, id: \.self) { option in
                    Text(option.label).tag(option.selection)
                }
            }
            .pickerStyle(.menu)
            .colorScheme(.dark)
            .frame(width: 220)

            if let notice = sourceCapNotice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 220, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let resolvedAutoEntry {
                Text("Detected: \(resolvedAutoEntry.englishName)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 220, alignment: .leading)
            }
        }
    }
}
