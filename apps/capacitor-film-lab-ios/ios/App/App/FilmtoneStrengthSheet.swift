import Foundation
import SwiftUI
import UIKit

struct FilmtoneStrengthSheet: View {
    @ObservedObject var store: FilmtoneEditorStore
    let onClose: () -> Void

    @State private var adjustmentsExpanded = false
    @State private var advancedParamsExpanded = false
    @State private var expandedAdvancedGroupIds: Set<String> = []
    @State private var activeHelpTopic: FilmtoneAdjustmentHelpTopic?

    var body: some View {
        VStack(spacing: 0) {
            handle

            header
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    strengthSection
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
        .sheet(item: $activeHelpTopic) { topic in
            FilmtoneAdjustmentHelpSheet(
                topic: topic,
                beforeLabel: store.strings.adjustmentHelpBeforeLabel,
                afterLabel: store.strings.adjustmentHelpAfterLabel,
                effectLabel: store.strings.adjustmentHelpEffectLabel,
                guidanceLabel: store.strings.adjustmentHelpGuidanceLabel,
                dismissLabel: store.strings.helpDismiss
            ) {
                activeHelpTopic = nil
            }
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
                Text(store.activePresetLabel)
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
                activeHelpTopic = makeHelpTopic(
                    id: "strength",
                    copy: store.strings.strengthHelpCopy(),
                    comparisonStyle: .strength
                )
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
                        value: store.project.quickState.dynamics,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) },
                        helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.quickFilmCharacter),
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.filmCharacter"
                    ) { value in
                        store.setQuickValue(value, for: \.dynamics)
                    } helpAction: {
                        activeHelpTopic = makeHelpTopic(
                            id: "quick.filmCharacter",
                            copy: store.strings.quickFilmCharacterHelpCopy(),
                            comparisonStyle: .exposure
                        )
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickEra,
                        value: -store.project.quickState.era,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) },
                        helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.quickEra),
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.era"
                    ) { value in
                        store.setQuickValue(-value, for: \.era)
                    } helpAction: {
                        activeHelpTopic = makeHelpTopic(
                            id: "quick.era",
                            copy: store.strings.quickEraHelpCopy(),
                            comparisonStyle: .contrast
                        )
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickDynamics,
                        value: store.project.quickState.filmCharacter,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) },
                        helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.quickDynamics),
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.dynamics"
                    ) { value in
                        store.setQuickValue(value, for: \.filmCharacter)
                    } helpAction: {
                        activeHelpTopic = makeHelpTopic(
                            id: "quick.dynamics",
                            copy: store.strings.quickDynamicsHelpCopy(),
                            comparisonStyle: .saturation
                        )
                    }
            }
        } helpAction: {
            activeHelpTopic = makeHelpTopic(
                id: "section.adjustments",
                copy: store.strings.quickAdjustmentSectionHelpCopy(),
                comparisonStyle: .quick
            )
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
            activeHelpTopic = makeHelpTopic(
                id: "section.advanced",
                copy: store.strings.advancedParamsSectionHelpCopy(),
                comparisonStyle: .advanced
            )
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
                activeHelpTopic = makeHelpTopic(
                    id: "group.\(group.id)",
                    copy: store.strings.advancedGroupHelpCopy(for: group.id, title: group.title),
                    comparisonStyle: comparisonStyleForGroup(group.id)
                )
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
                        activeHelpTopic = makeHelpTopic(
                            id: "param.\(control.key)",
                            copy: store.strings.paramHelpCopy(for: control.key, label: control.label),
                            comparisonStyle: comparisonStyleForParam(control.key)
                        )
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
