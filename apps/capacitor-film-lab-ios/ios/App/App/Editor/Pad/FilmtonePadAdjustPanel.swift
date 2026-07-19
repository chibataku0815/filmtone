import FilmLabSwiftCore
import SwiftUI

/// Inline Adjust panel for the iPad inspector rail.
///
/// Mirrors the iPhone strength-sheet control surface so adjust
/// work happens inside the inspector instead of behind a modal. Strength,
/// Advanced Adjust groups, Film Damage, and Deep Glow all live inline.
///
/// Help icons stay in the iPhone sheet for now, but the iPad rail no
/// longer uses the iPhone quick-only subset as its normal Adjust body.
struct FilmtonePadAdjustPanel: View {
    @ObservedObject var store: FilmtoneEditorStore

    @State private var advancedExpandedGroupIds: Set<FilmtoneAdvancedAdjustGroupID> = [.basic]

    private static let deepGlowColumns: [GridItem] = [
        GridItem(.flexible(), spacing: FilmtonePadTouchMetrics.gridSpacing),
        GridItem(.flexible(), spacing: FilmtonePadTouchMetrics.gridSpacing),
        GridItem(.flexible(), spacing: FilmtonePadTouchMetrics.gridSpacing),
        GridItem(.flexible(), spacing: FilmtonePadTouchMetrics.gridSpacing),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FilmtonePadTouchMetrics.sectionSpacing) {
            strengthRow

            advancedAdjustRows

            deepGlowRow
        }
    }

    // MARK: Strength

    private var strengthRow: some View {
        let clamped = FilmtonePhase0Math.clampStrength(store.project.strength)

        return FilmtonePadSliderControl(
            title: store.strings.strengthLabel,
            valueText: Self.percentLabel(clamped),
            valueAccessibilityIdentifier: "filmtone.pad.inspector.adjust.strength.value",
            sliderAccessibilityIdentifier: "filmtone.pad.inspector.adjust.strength.slider",
            value: Binding(
                get: { FilmtonePhase0Math.clampStrength(store.project.strength) },
                set: { store.setStrength($0) }
            ),
            range: 0...1,
            isActive: clamped < 0.995
        )
    }

    // MARK: Deep Glow

    private var deepGlowRow: some View {
        VStack(alignment: .leading, spacing: FilmtonePadTouchMetrics.rowSpacing) {
            HStack {
                Text(FilmtoneOpticalFilterEditorCatalog.featureName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text(deepGlowStrengthLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.62))
                    .accessibilityIdentifier("filmtone.pad.inspector.adjust.backlightVeil.value")
            }

            LazyVGrid(
                columns: Self.deepGlowColumns,
                alignment: .leading,
                spacing: FilmtonePadTouchMetrics.gridSpacing
            ) {
                ForEach(deepGlowOptions) { option in
                    deepGlowChip(option)
                }
            }
            .accessibilityIdentifier("filmtone.pad.inspector.adjust.backlightVeil.picker")
        }
    }

    private var deepGlowStrengthLabel: String {
        FilmtoneOpticalFilterEditorCatalog.localizedShortLabel(
            for: store.selectedOpticalFilterId,
            prefersJapanese: store.strings.usesJapaneseTypography
        )
    }

    private var selectedDeepGlowId: String {
        store.selectedOpticalFilterId ?? FilmtoneOpticalFilterEditorCatalog.noneIdentifier
    }

    private var deepGlowOptions: [DeepGlowOption] {
        [
            DeepGlowOption(
                id: FilmtoneOpticalFilterEditorCatalog.noneIdentifier,
                label: FilmtoneOpticalFilterEditorCatalog.localizedShortLabel(
                    for: nil,
                    prefersJapanese: store.strings.usesJapaneseTypography
                )
            ),
        ]
        + FilmtoneOpticalFilterEditorCatalog.entries.map {
            DeepGlowOption(
                id: $0.id,
                label: FilmtoneOpticalFilterEditorCatalog.localizedShortLabel(
                    for: $0.id,
                    prefersJapanese: store.strings.usesJapaneseTypography
                )
            )
        }
    }

    private func deepGlowChip(_ option: DeepGlowOption) -> some View {
        let isActive = option.id == selectedDeepGlowId

        return Button {
            store.setOpticalFilterId(
                option.id == FilmtoneOpticalFilterEditorCatalog.noneIdentifier
                    ? nil
                    : option.id
            )
        } label: {
            Text(option.label)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(
            FilmtonePadTouchButtonStyle(
                isActive: isActive,
                activeFill: Color.filmtoneAmber.opacity(0.86),
                inactiveFill: Color.white.opacity(0.06),
                inactiveStroke: Color.white.opacity(0.12)
            )
        )
        .accessibilityIdentifier(
            "filmtone.pad.inspector.adjust.backlightVeil.option.\(option.id)"
        )
    }

    // MARK: Advanced Adjust

    private var advancedAdjustRows: some View {
        VStack(alignment: .leading, spacing: FilmtonePadTouchMetrics.rowSpacing) {
            HStack {
                Text(store.strings.advancedParamsLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text(advancedActiveBadge)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.62))
            }

            ForEach(advancedGroups) { group in
                advancedGroupSection(group)
            }
        }
        .accessibilityIdentifier("filmtone.pad.inspector.adjust.advanced")
    }

    private var advancedGroups: [FilmtoneAdvancedAdjustGroupSpec] {
        FilmtoneAdvancedAdjustCatalog.groups(forVideo: store.source?.kind == .video)
    }

    private var advancedActiveBadge: String {
        let active = store.project.paramOverrides.values.count
        let total = advancedGroups.reduce(0) { $0 + $1.controls.count }
        return "\(active)/\(total)"
    }

    private func advancedGroupSection(_ group: FilmtoneAdvancedAdjustGroupSpec) -> some View {
        let isExpanded = Binding(
            get: { advancedExpandedGroupIds.contains(group.id) },
            set: { expanded in
                if expanded {
                    advancedExpandedGroupIds.insert(group.id)
                } else {
                    advancedExpandedGroupIds.remove(group.id)
                }
            }
        )
        let activeCount = group.keys.filter { store.isParamOverridden($0) }.count

        return DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                if !group.recipes.isEmpty {
                    advancedRecipeGrid(for: group)
                }
                ForEach(group.controls) { control in
                    advancedParamSlider(control)
                }
            }
            .padding(.top, FilmtonePadTouchMetrics.rowSpacing)
        } label: {
            HStack(spacing: 8) {
                Text(advancedGroupTitle(for: group.id))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                Text("(\(group.controls.count))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.46))
                if activeCount > 0 {
                    Text("\(activeCount) on")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.filmtoneAmber.opacity(0.86), in: Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(
                maxWidth: .infinity,
                minHeight: FilmtonePadTouchMetrics.minimumControlHeight,
                alignment: .leading
            )
            .background(
                RoundedRectangle(
                    cornerRadius: FilmtonePadTouchMetrics.controlCornerRadius,
                    style: .continuous
                )
                .fill(Color.white.opacity(activeCount > 0 ? 0.06 : 0.035))
            )
            .contentShape(Rectangle())
        }
        .tint(.white.opacity(0.86))
        .accessibilityIdentifier("filmtone.pad.inspector.adjust.advanced.\(group.rawID)")
    }

    private func advancedRecipeGrid(for group: FilmtoneAdvancedAdjustGroupSpec) -> some View {
        let base = store.baseParamsForCurrentAdjustments()
        let activeRecipeID = activeRecipeID(for: group, base: base)

        return LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: 86),
                    spacing: FilmtonePadTouchMetrics.gridSpacing
                ),
            ],
            alignment: .leading,
            spacing: FilmtonePadTouchMetrics.gridSpacing
        ) {
            ForEach(group.recipes) { recipe in
                let isActive = recipe.id == activeRecipeID
                Button {
                    store.applyParamPreset(values: recipe.values(base), for: group.keys)
                } label: {
                    Text(advancedRecipeLabel(for: recipe, groupID: group.id))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    FilmtonePadTouchButtonStyle(
                        isActive: isActive,
                        activeFill: Color.filmtoneAmber.opacity(0.86),
                        inactiveFill: Color.white.opacity(0.08),
                        inactiveStroke: Color.white.opacity(0.16),
                        minHeight: FilmtonePadTouchMetrics.minimumControlHeight
                    )
                )
                .accessibilityIdentifier(
                    "filmtone.pad.inspector.adjust.advanced.\(group.rawID).recipe.\(recipe.id)"
                )
            }
        }
    }

    private func advancedParamSlider(_ control: FilmtoneAdvancedAdjustControlSpec) -> some View {
        let value = store.effectiveParamValue(for: control.key)
        let isOverridden = store.isParamOverridden(control.key)

        return FilmtonePadSliderControl(
            title: store.strings.paramLabel(for: control.key),
            valueText: Self.decimalLabel(value, digits: control.digits),
            valueAccessibilityIdentifier: "filmtone.pad.inspector.adjust.advanced.\(control.key).value",
            sliderAccessibilityIdentifier: "filmtone.pad.inspector.adjust.advanced.\(control.key).slider",
            value: Binding(
                get: { store.effectiveParamValue(for: control.key) },
                set: { value in
                    store.setParamOverride(value, for: control.key)
                }
            ),
            range: control.range,
            isActive: isOverridden,
            leadingIndicatorColor: isOverridden
                ? Color.filmtoneAmber.opacity(0.92)
                : Color.white.opacity(0.18),
            resetAccessibilityIdentifier: "filmtone.pad.inspector.adjust.advanced.\(control.key).reset",
            resetEnabled: isOverridden,
            resetAction: {
                store.clearParamOverrides(for: [control.key])
            }
        )
    }

    private func activeRecipeID(
        for group: FilmtoneAdvancedAdjustGroupSpec,
        base: FilmtonePhase0Params
    ) -> String? {
        let activeCount = group.keys.filter { store.project.paramOverrides.values[$0] != nil }.count
        if activeCount == 0,
           let clearRecipe = group.recipes.first(where: { $0.values(base).isEmpty }) {
            return clearRecipe.id
        }

        for recipe in group.recipes {
            let values = recipe.values(base)
            guard !values.isEmpty else { continue }
            let matches = group.keys.allSatisfy { key in
                let expected = values[key] ?? base.value(for: key)
                let clampedExpected = FilmtonePhase0Math.clampParam(key, expected)
                return abs(store.project.params.value(for: key) - clampedExpected)
                    < FilmtonePhase0Math.paramEqualityTolerance
            }
            if matches { return recipe.id }
        }

        return nil
    }

    private func advancedGroupTitle(for groupID: FilmtoneAdvancedAdjustGroupID) -> String {
        switch groupID {
        case .basic:   return store.strings.advancedBasicLabel
        case .process: return store.strings.advancedProcessLabel
        case .optics:  return store.strings.advancedOpticsLabel
        case .glow:    return store.strings.advancedGlowLabel
        case .grain:   return store.strings.advancedGrainLabel
        case .damage:  return store.strings.advancedDamageLabel
        case .motion:  return store.strings.advancedMotionLabel
        }
    }

    private func advancedRecipeLabel(
        for recipe: FilmtoneAdvancedAdjustRecipeSpec,
        groupID: FilmtoneAdvancedAdjustGroupID
    ) -> String {
        switch (groupID, recipe.id) {
        case (.process, "standard"): return store.strings.advancedToneStandardLabel
        case (.process, "airy"):     return store.strings.advancedToneAiryLabel
        case (.process, "sunset"):   return store.strings.advancedToneSunsetLabel
        case (.process, "depth"):    return store.strings.advancedToneDepthLabel
        case (.grain, "fine"):       return store.strings.advancedGrainFineLabel
        case (.grain, "classic"):    return store.strings.advancedGrainClassicLabel
        case (.grain, "push"):       return store.strings.advancedGrainPushLabel
        case (_, "none"):            return store.strings.advancedPresetNoneLabel
        case (_, "default"):         return store.strings.advancedPresetDefaultLabel
        case (_, "strong"):          return store.strings.advancedPresetStrongLabel
        default:                     return recipe.id
        }
    }

    private static func percentLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func decimalLabel(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }
}

private struct DeepGlowOption: Identifiable {
    let id: String
    let label: String
}
