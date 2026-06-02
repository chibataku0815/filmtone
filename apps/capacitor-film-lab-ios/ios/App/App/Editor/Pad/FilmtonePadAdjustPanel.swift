import FilmLabSwiftCore
import SwiftUI

/// Inline Adjust panel for the iPad inspector rail.
///
/// Mirrors the iPhone strength-sheet control surface so adjust
/// work happens inside the inspector instead of behind a modal. Strength,
/// Advanced Adjust groups, Film Damage, and Backlight Veil all live inline.
///
/// Help icons stay in the iPhone sheet for now, but the iPad rail no
/// longer uses the iPhone quick-only subset as its normal Adjust body.
struct FilmtonePadAdjustPanel: View {
    @ObservedObject var store: FilmtoneEditorStore

    @State private var advancedExpandedGroupIds: Set<FilmtoneAdvancedAdjustGroupID> = [.basic]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            strengthRow

            advancedAdjustRows

            backlightVeilRow
        }
    }

    // MARK: Strength

    private var strengthRow: some View {
        let clamped = FilmtonePhase0Math.clampStrength(store.project.strength)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(store.strings.strengthLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text(Self.percentLabel(clamped))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .accessibilityIdentifier("filmtone.pad.inspector.adjust.strength.value")
            }
            Slider(
                value: Binding(get: { clamped }, set: { store.setStrength($0) }),
                in: 0...1
            )
            .tint(Color.filmtoneAmber)
            .accessibilityIdentifier("filmtone.pad.inspector.adjust.strength.slider")
        }
    }

    // MARK: Backlight Veil

    private var backlightVeilRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Backlight Veil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text(backlightVeilDensityLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.62))
                    .accessibilityIdentifier("filmtone.pad.inspector.adjust.backlightVeil.value")
            }

            Picker(
                "Backlight Veil",
                selection: Binding(
                    get: {
                        store.selectedOpticalFilterId
                            ?? FilmtoneOpticalFilterEditorCatalog.noneIdentifier
                    },
                    set: { newValue in
                        store.setOpticalFilterId(
                            newValue == FilmtoneOpticalFilterEditorCatalog.noneIdentifier
                                ? nil
                                : newValue
                        )
                    }
                )
            ) {
                Text("Off").tag(FilmtoneOpticalFilterEditorCatalog.noneIdentifier)
                ForEach(FilmtoneOpticalFilterEditorCatalog.entries) { entry in
                    Text(entry.shortLabel).tag(entry.id)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("filmtone.pad.inspector.adjust.backlightVeil.picker")
        }
    }

    private var backlightVeilDensityLabel: String {
        FilmtoneOpticalFilterEditorCatalog
            .entry(for: store.selectedOpticalFilterId)?.shortLabel ?? "Off"
    }

    // MARK: Advanced Adjust

    private var advancedAdjustRows: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            .padding(.top, 8)
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
        }
        .tint(.white.opacity(0.86))
        .accessibilityIdentifier("filmtone.pad.inspector.adjust.advanced.\(group.rawID)")
    }

    private func advancedRecipeGrid(for group: FilmtoneAdvancedAdjustGroupSpec) -> some View {
        let base = store.baseParamsForCurrentAdjustments()
        let activeRecipeID = activeRecipeID(for: group, base: base)

        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 68), spacing: 6)],
            alignment: .leading,
            spacing: 6
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
                        .padding(.vertical, 6)
                        .foregroundStyle(isActive ? Color.black : Color.white.opacity(0.84))
                        .background(
                            isActive ? Color.filmtoneAmber.opacity(0.86) : Color.white.opacity(0.08),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.white.opacity(isActive ? 0 : 0.16), lineWidth: 0.75)
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    "filmtone.pad.inspector.adjust.advanced.\(group.rawID).recipe.\(recipe.id)"
                )
            }
        }
    }

    private func advancedParamSlider(_ control: FilmtoneAdvancedAdjustControlSpec) -> some View {
        let value = store.effectiveParamValue(for: control.key)
        let isOverridden = store.isParamOverridden(control.key)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(isOverridden ? Color.filmtoneAmber.opacity(0.92) : Color.white.opacity(0.18))
                    .frame(width: 6, height: 6)
                Text(store.strings.paramLabel(for: control.key))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOverridden ? Color.filmtoneAmber.opacity(0.92) : .white.opacity(0.86))
                Spacer()
                Text(Self.decimalLabel(value, digits: control.digits))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(isOverridden ? Color.filmtoneAmber.opacity(0.82) : .white.opacity(0.62))
                    .accessibilityIdentifier(
                        "filmtone.pad.inspector.adjust.advanced.\(control.key).value"
                    )
                Button {
                    store.clearParamOverrides(for: [control.key])
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isOverridden ? .white.opacity(0.76) : .white.opacity(0.24))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(!isOverridden)
                .accessibilityIdentifier(
                    "filmtone.pad.inspector.adjust.advanced.\(control.key).reset"
                )
            }
            Slider(
                value: Binding(
                    get: { store.effectiveParamValue(for: control.key) },
                    set: { value in
                        store.setParamOverride(value, for: control.key)
                    }
                ),
                in: control.range
            )
            .tint(Color.filmtoneAmber)
            .accessibilityIdentifier(
                "filmtone.pad.inspector.adjust.advanced.\(control.key).slider"
            )
        }
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
