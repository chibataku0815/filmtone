import FilmLabSwiftCore
import Foundation
import SwiftUI
import UIKit

struct FilmtoneStrengthSheet: View {
    @ObservedObject var store: FilmtoneEditorStore
    @Binding var activeHelpTopic: FilmtoneAdjustmentHelpTopic?
    let onClose: () -> Void

    @State private var adjustmentsExpanded = false
    @State private var advancedParamsExpanded = false
    @State private var expandedAdvancedGroupIds: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            handle

            header
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    strengthSection
                    backlightVeilSection
                    adjustmentsSection
                    advancedParamsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            if !adjustmentsExpanded {
                adjustmentsExpanded = store.hasQuickAdjustments
            }
            if !advancedParamsExpanded {
                advancedParamsExpanded = store.hasAdvancedAdjustments
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func openHelp(_ topic: FilmtoneAdjustmentHelpTopic) {
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            activeHelpTopic = topic
        }
    }

    private var handle: some View {
        Rectangle()
            .fill(Color.white.opacity(0.22))
            .frame(width: 44, height: 3)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 16)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.lookProfileLabel)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("filmtone.sheet.strength")

                if store.hasAnyAdjustments {
                    Text(store.adjustmentSummaryText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            HStack(spacing: 8) {
                Button(store.strings.presetDefaultLabel) {
                    store.restoreActivePresetDefaults()
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
                .lineLimit(1)
                .disabled(!store.hasPresetCustomValues)
                .opacity(store.hasPresetCustomValues ? 1 : 0.42)
                .accessibilityIdentifier("filmtone.sheet.default")

                Button(store.strings.doneLabel) {
                    onClose()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
                .lineLimit(1)
            }
            .fixedSize()
        }
    }

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FilmtoneSliderRow(
                label: store.strings.strengthLabel,
                value: store.project.strength,
                range: 0...1,
                format: { Self.percentLabel($0) },
                helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.strengthLabel),
                accessibilityIdentifier: "filmtone.sheet.slider.strength"
            ) { value in
                store.setStrength(value)
            } helpAction: {
                openHelp(makeHelpTopic(
                    id: "strength",
                    copy: store.strings.strengthHelpCopy(),
                    comparisonStyle: .strength
                ))
            }

            if let creativeLut = store.project.creativeLut {
                lookLutAmountControl(creativeLut.intensity)
            }
        }
        .sectionDivider()
    }

    private func lookLutAmountControl(_ value: Double) -> some View {
        let clampedValue = FilmtonePhase0Math.clampLutIntensity(value)
        let percentLabel = Self.percentLabel(clampedValue)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(store.strings.lookLutAmountLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.filmtoneAmber.opacity(0.92))

                Spacer()

                Text(percentLabel)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(Color.filmtoneAmber.opacity(0.82))
                    .accessibilityIdentifier("filmtone.sheet.slider.creativeLutIntensity.value")
            }

            Slider(
                value: Binding(
                    get: { clampedValue },
                    set: { store.setCreativeLutIntensity($0) }
                ),
                in: 0...1
            )
            .tint(Color.filmtoneAmber)
            .accessibilityIdentifier("filmtone.sheet.slider.creativeLutIntensity")
            .accessibilityLabel(store.strings.lookLutAmountLabel)
            .accessibilityValue(percentLabel)
        }
    }

    /// Backlight Veil Phase 1c — segmented Picker for the optical filter
    /// family. OFF / 1/8 / 1/4 / 1/2 (Desktop canonical curve, no
    /// interpolation). Mutates `FilmtoneEditorStore.selectedOpticalFilterId`,
    /// which mirrors to `FilmtoneOpticalFilterSelectionStore.shared` so the
    /// composite kernel picks up the new branch on the next preview frame.
    private var backlightVeilSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Backlight Veil")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text(backlightVeilDensityLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.64))
                    .accessibilityIdentifier("filmtone.sheet.backlightVeil.value")
            }

            Picker(
                "Backlight Veil",
                selection: Binding(
                    get: { store.selectedOpticalFilterId ?? "off" },
                    set: { newValue in
                        store.setOpticalFilterId(newValue == "off" ? nil : newValue)
                    }
                )
            ) {
                Text("Off").tag("off")
                Text("1/8").tag("backlightVeil-1-8")
                Text("1/4").tag("backlightVeil-1-4")
                Text("1/2").tag("backlightVeil-1-2")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("filmtone.sheet.backlightVeil.picker")
        }
        .sectionDivider()
    }

    private var backlightVeilDensityLabel: String {
        switch store.selectedOpticalFilterId {
        case "backlightVeil-1-8": return "Subtle"
        case "backlightVeil-1-4": return "Mid"
        case "backlightVeil-1-2": return "Max"
        default: return "Off"
        }
    }

    private var adjustmentsSection: some View {
        FilmtoneDisclosureSection(
            title: store.strings.adjustLabel,
            summary: quickSummaryText,
            accessibilityIdentifier: "filmtone.sheet.adjustments",
            isExpanded: $adjustmentsExpanded,
            helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.adjustLabel)
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if store.hasQuickAdjustments {
                    Text(store.quickSummaryText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.56))
                }

                    FilmtoneSliderRow(
                        label: store.strings.quickFilmCharacter,
                        value: max(-1, min(1, store.effectiveParamValue(for: "exposure"))),
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) },
                        isActive: store.isParamOverridden("exposure"),
                        helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.quickFilmCharacter),
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.exposure"
                    ) { value in
                        store.setParamOverride(value, for: "exposure")
                    } helpAction: {
                        openHelp(makeHelpTopic(
                            id: "quick.exposure",
                            copy: store.strings.quickFilmCharacterHelpCopy(),
                            comparisonStyle: .exposure
                        ))
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickEra,
                        value: max(-1, min(1, store.effectiveParamValue(for: "contrast") - 1.0)),
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) },
                        isActive: store.isParamOverridden("contrast"),
                        helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.quickEra),
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.contrast"
                    ) { value in
                        store.setParamOverride(1.0 + value, for: "contrast")
                    } helpAction: {
                        openHelp(makeHelpTopic(
                            id: "quick.contrast",
                            copy: store.strings.quickEraHelpCopy(),
                            comparisonStyle: .contrast
                        ))
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickDynamics,
                        value: max(-1, min(1, store.effectiveParamValue(for: "saturation") - 1.0)),
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) },
                        isActive: store.isParamOverridden("saturation"),
                        helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.quickDynamics),
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.saturation"
                    ) { value in
                        store.setParamOverride(1.0 + value, for: "saturation")
                    } helpAction: {
                        openHelp(makeHelpTopic(
                            id: "quick.saturation",
                            copy: store.strings.quickDynamicsHelpCopy(),
                            comparisonStyle: .saturation
                        ))
                    }
            }
        } helpAction: {
            openHelp(makeHelpTopic(
                id: "section.adjustments",
                copy: store.strings.quickAdjustmentSectionHelpCopy(),
                comparisonStyle: .quick
            ))
        }
    }

    private var advancedParamsSection: some View {
        FilmtoneDisclosureSection(
            title: store.strings.advancedParamsLabel,
            summary: store.strings.advancedParamsHint,
            accessibilityIdentifier: "filmtone.sheet.advanced",
            isExpanded: $advancedParamsExpanded,
            contentSpacing: 20,
            helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.advancedParamsLabel)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(advancedParamGroups) { group in
                    advancedGroupSection(group)
                }
            }
        } helpAction: {
            openHelp(makeHelpTopic(
                id: "section.advanced",
                copy: store.strings.advancedParamsSectionHelpCopy(),
                comparisonStyle: .advanced
            ))
        }
    }

    private func advancedGroupSection(_ group: FilmtoneAdvancedParamGroup) -> some View {
        let base = store.baseParamsForCurrentAdjustments()
        let selection = recipeSelection(for: group, base: base)

        return FilmtoneAdvancedParamGroupSection(
            id: group.id,
            title: group.title,
            selection: selection,
            recipes: group.recipes,
            customLabel: store.strings.advancedPresetCustomLabel,
            helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: group.title),
            isExpanded: Binding(
                get: { expandedAdvancedGroupIds.contains(group.id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedAdvancedGroupIds.insert(group.id)
                    } else {
                        expandedAdvancedGroupIds.remove(group.id)
                    }
                }
            ),
            onSelectRecipe: { recipe in
                store.applyParamPreset(values: recipe.values(base), for: group.keys)
            },
            onHelp: {
                openHelp(makeHelpTopic(
                    id: "group.\(group.id)",
                    copy: store.strings.advancedGroupHelpCopy(for: group.id, title: group.title),
                    comparisonStyle: comparisonStyleForGroup(group.id)
                ))
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(group.controls) { control in
                    FilmtoneSliderRow(
                        label: control.label,
                        value: store.effectiveParamValue(for: control.key),
                        range: control.range,
                        format: control.format,
                        isActive: store.isParamOverridden(control.key),
                        helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: control.label),
                        accessibilityIdentifier: "filmtone.sheet.slider.param.\(control.key)"
                    ) { value in
                        store.setParamOverride(value, for: control.key)
                    } helpAction: {
                        openHelp(makeHelpTopic(
                            id: "param.\(control.key)",
                            copy: store.strings.paramHelpCopy(for: control.key, label: control.label),
                            comparisonStyle: comparisonStyleForParam(control.key)
                        ))
                    }
                }
            }
        }
    }

    private func recipeSelection(
        for group: FilmtoneAdvancedParamGroup,
        base: FilmtonePhase0Params
    ) -> FilmtoneAdvancedRecipeSelection {
        let activeCount = group.keys.filter { store.project.paramOverrides.values[$0] != nil }.count
        if activeCount == 0, let standardRecipe = group.recipes.first(where: { $0.values(base).isEmpty }) {
            return .recipe(standardRecipe.id)
        }

        for recipe in group.recipes {
            let values = recipe.values(base)
            guard !values.isEmpty else {
                continue
            }

            let matchesRecipe = group.keys.allSatisfy { key in
                let expected = values[key] ?? base.value(for: key)
                let clampedExpected = FilmtonePhase0Math.clampParam(key, expected)
                return abs(store.project.params.value(for: key) - clampedExpected) < FilmtonePhase0Math.paramEqualityTolerance
            }
            if matchesRecipe {
                return .recipe(recipe.id)
            }
        }

        return .custom(activeCount: activeCount)
    }

    private var quickSummaryText: String {
        store.hasQuickAdjustments ? store.quickSummaryText : ""
    }

}
