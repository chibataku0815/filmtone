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
        ZStack {
            Color.filmtoneBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                handle

                VStack(alignment: .leading, spacing: 14) {
                    header
                    sheetPreview
                }
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
        }
        .onAppear {
            if !adjustmentsExpanded {
                adjustmentsExpanded = store.hasQuickAdjustments
            }
            if !advancedParamsExpanded {
                advancedParamsExpanded = store.hasAdvancedAdjustments
            }
        }
        .presentationDetents([.medium, .large])
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
        HStack(alignment: .top, spacing: 14) {
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

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button(store.strings.presetDefaultLabel) {
                    store.restoreActivePresetDefaults()
                }
                .buttonStyle(FilmtoneSheetSecondaryActionStyle())
                .disabled(!store.hasPresetCustomValues)
                .opacity(store.hasPresetCustomValues ? 1 : 0.42)
                .accessibilityIdentifier("filmtone.sheet.default")

                Button(store.strings.doneLabel) {
                    onClose()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
            }
        }
    }

    private var sheetPreview: some View {
        FilmtoneSheetPreview(
            displayURI: store.selectedPreviewURI,
            compareFrame: store.comparePreviewFrame,
            videoPreview: store.videoPreviewState,
            emptyMessage: previewEmptyMessage,
            loadingMessage: store.strings.previewRendering,
            originalLabel: store.strings.compareLabel,
            gradedLabel: store.strings.previewGradedLabel,
            metaLabel: store.previewMetaLabel,
            isRendering: store.preview.isRendering
        )
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
            summary: store.advancedSummaryText,
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

    private func makeHelpTopic(
        id: String,
        copy: FilmtoneAdjustmentHelpCopy,
        comparisonStyle: FilmtoneAdjustmentComparisonStyle
    ) -> FilmtoneAdjustmentHelpTopic {
        FilmtoneAdjustmentHelpTopic(id: id, copy: copy, comparisonStyle: comparisonStyle)
    }

    private func comparisonStyleForGroup(_ id: String) -> FilmtoneAdjustmentComparisonStyle {
        switch id {
        case "basic":
            return .exposure
        case "process":
            return .tone
        case "optics":
            return .optics
        case "glow":
            return .glow
        case "grain":
            return .grain
        case "motion":
            return .motion
        default:
            return .advanced
        }
    }

    private func comparisonStyleForParam(_ key: String) -> FilmtoneAdjustmentComparisonStyle {
        switch key {
        case "exposure":
            return .exposure
        case "contrast":
            return .contrast
        case "saturation":
            return .saturation
        case "temperature", "tint", "fade":
            return .tone
        case "cyan", "magenta", "yellow":
            return .colorBalance
        case "printContrast":
            return .contrast
        case "compressionAmount", "compressionRange":
            return .highlight
        case "rgbShift":
            return .colorFringe
        case "lensSoftness":
            return .softness
        case "vignette":
            return .vignette
        case "bloomThreshold", "bloomStrength", "bloomRadius", "bloomSoftKnee":
            return .bloom
        case "halationIntensity", "halationSpread", "halationHue", "halationThreshold", "halationRadius", "halationSoftKnee":
            return .halation
        case "diffusion":
            return .diffusion
        case "grainIntensity", "grainSize", "grainRadialMix":
            return .grain
        case "shutterAngle", "trailIntensity":
            return .motion
        default:
            return .advanced
        }
    }

    private var quickSummaryText: String {
        store.hasQuickAdjustments ? store.quickSummaryText : ""
    }

    private var previewEmptyMessage: String {
        if let error = store.previewError {
            return error
        }
        if store.source == nil {
            return store.strings.sourceEmpty
        }
        return store.strings.previewRendering
    }

    private var advancedParamGroups: [FilmtoneAdvancedParamGroup] {
        var groups: [FilmtoneAdvancedParamGroup] = [
            .init(
                id: "basic",
                title: store.strings.advancedBasicLabel,
                recipes: [],
                controls: [
                    control("exposure", range: -2...2),
                    control("contrast", range: 0...2),
                    control("saturation", range: 0...2),
                    control("temperature", range: -1...1),
                    control("tint", range: -1...1),
                    control("fade", range: 0...1),
                ]
            ),
            .init(
                id: "process",
                title: store.strings.advancedProcessLabel,
                recipes: toneAdvancedRecipes,
                controls: [
                    control("cyan", range: -1...1),
                    control("magenta", range: -1...1),
                    control("yellow", range: -1...1),
                    control("printContrast", range: 0...1),
                    control("compressionAmount", range: 0...1),
                    control("compressionRange", range: 0...1),
                ]
            ),
            .init(
                id: "optics",
                title: store.strings.advancedOpticsLabel,
                recipes: standardAdvancedRecipes(
                    defaultValues: { base in
                        [
                            "rgbShift": max(base.rgbShift, 0.0038),
                            "lensSoftness": max(base.lensSoftness, 0.30),
                            "vignette": max(base.vignette, 0.46),
                        ]
                    },
                    strongValues: { base in
                        [
                            "rgbShift": max(base.rgbShift, FilmtonePhase0Math.rgbShiftMax),
                            "lensSoftness": max(base.lensSoftness, 0.44),
                            "vignette": max(base.vignette, 0.62),
                        ]
                    }
                ),
                controls: [
                    control("rgbShift", range: 0...FilmtonePhase0Math.rgbShiftMax, digits: 3),
                    control("lensSoftness", range: 0...1),
                    control("vignette", range: 0...1),
                ]
            ),
            .init(
                id: "glow",
                title: store.strings.advancedGlowLabel,
                recipes: standardAdvancedRecipes(
                    defaultValues: { base in
                        [
                            "bloomThreshold": min(base.bloomThreshold, 0.64),
                            "bloomStrength": max(base.bloomStrength, 0.24),
                            "bloomRadius": max(base.bloomRadius, 0.68),
                            "bloomSoftKnee": max(base.bloomSoftKnee, 0.76),
                            "halationIntensity": max(base.halationIntensity, 0.06),
                            "halationSpread": max(base.halationSpread, 34),
                            "halationHue": abs(base.halationHue) < FilmtonePhase0Math.paramEqualityTolerance ? 22 : base.halationHue,
                            "halationThreshold": min(base.halationThreshold, 0.56),
                            "halationRadius": max(base.halationRadius, 0.66),
                            "halationSoftKnee": max(base.halationSoftKnee, 0.58),
                            "diffusion": max(base.diffusion, 0.09),
                        ]
                    },
                    strongValues: { base in
                        [
                            "bloomThreshold": min(base.bloomThreshold, 0.58),
                            "bloomStrength": max(base.bloomStrength, 0.34),
                            "bloomRadius": max(base.bloomRadius, 0.78),
                            "bloomSoftKnee": max(base.bloomSoftKnee, 0.86),
                            "halationIntensity": max(base.halationIntensity, 0.10),
                            "halationSpread": max(base.halationSpread, 38),
                            "halationHue": abs(base.halationHue) < FilmtonePhase0Math.paramEqualityTolerance ? 22 : base.halationHue,
                            "halationThreshold": min(base.halationThreshold, 0.50),
                            "halationRadius": max(base.halationRadius, 0.80),
                            "halationSoftKnee": max(base.halationSoftKnee, 0.70),
                            "diffusion": max(base.diffusion, 0.14),
                        ]
                    }
                ),
                controls: [
                    control("bloomThreshold", range: 0...1),
                    control("bloomStrength", range: 0...1),
                    control("bloomRadius", range: 0...1),
                    control("bloomSoftKnee", range: 0...1),
                    control("halationIntensity", range: 0...1),
                    control("halationSpread", range: 0...40, digits: 0),
                    control("halationHue", range: 0...100, digits: 0),
                    control("halationThreshold", range: 0...1),
                    control("halationRadius", range: 0...1),
                    control("halationSoftKnee", range: 0...1),
                    control("diffusion", range: 0...1),
                ]
            ),
            .init(
                id: "grain",
                title: store.strings.advancedGrainLabel,
                recipes: standardAdvancedRecipes(
                    defaultValues: { base in
                        [
                            "grainIntensity": max(base.grainIntensity, 0.025),
                            "grainSize": max(base.grainSize, 0.30),
                            "grainRadialMix": 1.0,
                        ]
                    },
                    strongValues: { base in
                        [
                            "grainIntensity": max(base.grainIntensity, 0.045),
                            "grainSize": max(base.grainSize, 0.38),
                            "grainRadialMix": 1.0,
                        ]
                    }
                ),
                controls: [
                    control("grainIntensity", range: 0...FilmtonePhase0Generated.grainIntensityMax),
                    control("grainSize", range: 0...1),
                    control("grainRadialMix", range: 0...1),
                ]
            ),
        ]

        if store.source?.kind == .video {
            groups.append(
                .init(
                    id: "motion",
                    title: store.strings.advancedMotionLabel,
                    recipes: standardAdvancedRecipes(
                        defaultValues: { _ in
                            [
                                "shutterAngle": 360,
                                "trailIntensity": 0,
                            ]
                        },
                        strongValues: { _ in
                            [
                                "shutterAngle": 720,
                                "trailIntensity": 0.35,
                            ]
                        }
                    ),
                    controls: [
                        control("shutterAngle", range: 0...720, digits: 0),
                        control("trailIntensity", range: 0...0.95),
                    ]
                )
            )
        }

        return groups
    }

    private var toneAdvancedRecipes: [FilmtoneAdvancedParamRecipe] {
        [
            recipe("standard", store.strings.advancedToneStandardLabel) { _ in
                [:]
            },
            recipe("airy", store.strings.advancedToneAiryLabel) { _ in
                [
                    "cyan": 0.018,
                    "magenta": -0.025,
                    "yellow": -0.030,
                    "printContrast": 0.04,
                    "compressionAmount": 0.04,
                    "compressionRange": 0.54,
                ]
            },
            recipe("sunset", store.strings.advancedToneSunsetLabel) { _ in
                [
                    "cyan": -0.026,
                    "magenta": 0.028,
                    "yellow": 0.045,
                    "printContrast": 0.04,
                    "compressionAmount": 0.05,
                    "compressionRange": 0.56,
                ]
            },
            recipe("depth", store.strings.advancedToneDepthLabel) { _ in
                [
                    "cyan": 0,
                    "magenta": 0,
                    "yellow": 0.010,
                    "printContrast": 0.09,
                    "compressionAmount": 0.08,
                    "compressionRange": 0.58,
                ]
            },
        ]
    }

    private func standardAdvancedRecipes(
        defaultValues: @escaping (FilmtonePhase0Params) -> [String: Double],
        strongValues: @escaping (FilmtonePhase0Params) -> [String: Double]
    ) -> [FilmtoneAdvancedParamRecipe] {
        [
            recipe("none", store.strings.advancedPresetNoneLabel) { _ in
                [:]
            },
            recipe("default", store.strings.advancedPresetDefaultLabel, values: defaultValues),
            recipe("strong", store.strings.advancedPresetStrongLabel, values: strongValues),
        ]
    }

    private func recipe(
        _ id: String,
        _ label: String,
        values: @escaping (FilmtonePhase0Params) -> [String: Double]
    ) -> FilmtoneAdvancedParamRecipe {
        .init(id: id, label: label, values: values)
    }

    private func control(
        _ key: String,
        range: ClosedRange<Double>,
        digits: Int = 2
    ) -> FilmtoneAdvancedParamControl {
        .init(
            key: key,
            label: store.strings.paramLabel(for: key),
            range: range,
            format: { value in
                Self.decimalLabel(value, digits: digits)
            }
        )
    }

    private static func percentLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func signedPercentLabel(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(Int((value * 100).rounded()))%"
    }

    private static func decimalLabel(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }
}

