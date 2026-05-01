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
                .buttonStyle(FilmtoneSheetPrimaryActionStyle())
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
        }
        .sectionDivider()
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
                        value: store.project.quickState.filmCharacter,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) },
                        helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.quickFilmCharacter),
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.filmCharacter"
                    ) { value in
                        store.setQuickValue(value, for: \.filmCharacter)
                    } helpAction: {
                        activeHelpTopic = makeHelpTopic(
                            id: "quick.filmCharacter",
                            copy: store.strings.quickFilmCharacterHelpCopy(),
                            comparisonStyle: .exposure
                        )
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickEra,
                        value: store.project.quickState.era,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) },
                        helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.quickEra),
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.era"
                    ) { value in
                        store.setQuickValue(value, for: \.era)
                    } helpAction: {
                        activeHelpTopic = makeHelpTopic(
                            id: "quick.era",
                            copy: store.strings.quickEraHelpCopy(),
                            comparisonStyle: .contrast
                        )
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickDynamics,
                        value: store.project.quickState.dynamics,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) },
                        helpAccessibilityLabel: store.strings.adjustmentHelpAccessibilityLabel(for: store.strings.quickDynamics),
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.dynamics"
                    ) { value in
                        store.setQuickValue(value, for: \.dynamics)
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

private struct FilmtoneSheetPreview: View {
    let displayURI: String?
    let compareFrame: FilmtoneComparePreviewFrame?
    let videoPreview: FilmtoneVideoPreviewState?
    let emptyMessage: String
    let loadingMessage: String
    let originalLabel: String
    let gradedLabel: String
    let metaLabel: String?
    let isRendering: Bool

    var body: some View {
        let stillImage = displayURI.flatMap(previewImage(from:))
        let hasVisiblePreview = compareFrame != nil || videoPreview != nil || stillImage != nil

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.black)

            if let compareFrame {
                FilmtoneCompareRevealPreview(
                    frame: compareFrame,
                    originalLabel: originalLabel,
                    gradedLabel: gradedLabel
                )
            } else if let videoPreview {
                FilmtonePreviewPlayerView(player: videoPreview.player)
                    .accessibilityIdentifier("filmtone.sheet.preview.video")
            } else if let image = stillImage {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(Rectangle())
                }
            } else {
                Text(emptyMessage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineSpacing(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(16)
            }

            if let metaLabel {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(metaLabel)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.white.opacity(0.68))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.black.opacity(0.5))
                            )
                            .padding(12)
                    }
                }
            }

            if isRendering {
                if hasVisiblePreview {
                    refreshIndicator
                } else {
                    loadingPanel
                }
            }
        }
        .frame(height: 210)
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipped()
    }

    private func previewImage(from uri: String) -> UIImage? {
        guard let url = URL(string: uri), url.isFileURL else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private var refreshIndicator: some View {
        VStack {
            HStack {
                Spacer()

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.filmtoneAmber)
                    .scaleEffect(0.72)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.46))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(12)
            }

            Spacer()
        }
        .accessibilityIdentifier("filmtone.sheet.preview.refreshing")
        .accessibilityLabel(loadingMessage)
    }

    private var loadingPanel: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.filmtoneAmber)

                Text(loadingMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.6))
            )
        }
        .padding(12)
        .accessibilityIdentifier("filmtone.sheet.preview.loading")
    }
}

private struct FilmtoneCompareRevealPreview: View {
    let frame: FilmtoneComparePreviewFrame
    let originalLabel: String
    let gradedLabel: String

    @State private var revealAmount = 0.58

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let dividerX = min(max(width * revealAmount, 18), width - 18)

            ZStack {
                if let originalImage = previewImage(from: frame.originalURI),
                   let gradedImage = previewImage(from: frame.gradedURI) {
                    Image(uiImage: originalImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: height)

                    Image(uiImage: gradedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: height)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: dividerX, height: height)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                    labelPills
                        .padding(12)

                    Rectangle()
                        .fill(Color.white.opacity(0.84))
                        .frame(width: 2, height: height)
                        .position(x: dividerX, y: height / 2)

                    Image(systemName: "arrow.left.and.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black.opacity(0.82))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(Color.filmtoneAmber)
                        )
                        .shadow(color: Color.black.opacity(0.34), radius: 12, x: 0, y: 4)
                        .position(x: dividerX, y: height / 2)
                } else {
                    Color.black
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        revealAmount = min(max(value.location.x / width, 0), 1)
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("filmtone.sheet.preview.compare.slider")
            .accessibilityLabel("\(gradedLabel) / \(originalLabel)")
            .accessibilityValue("\(Int((revealAmount * 100).rounded()))%")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    revealAmount = min(revealAmount + 0.05, 1)
                case .decrement:
                    revealAmount = max(revealAmount - 0.05, 0)
                @unknown default:
                    break
                }
            }
        }
    }

    private var labelPills: some View {
        VStack {
            HStack {
                Text(gradedLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.filmtoneAmber)
                    )

                Spacer()

                Text(originalLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.56))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }

            Spacer()
        }
    }

    private func previewImage(from uri: String) -> UIImage? {
        guard let url = URL(string: uri), url.isFileURL else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}

private struct FilmtoneAdjustmentHelpTopic: Identifiable {
    let id: String
    let copy: FilmtoneAdjustmentHelpCopy
    let comparisonStyle: FilmtoneAdjustmentComparisonStyle
}

private enum FilmtoneAdjustmentComparisonStyle: Equatable {
    case strength
    case quick
    case exposure
    case contrast
    case saturation
    case advanced
    case tone
    case colorBalance
    case highlight
    case optics
    case colorFringe
    case softness
    case vignette
    case glow
    case bloom
    case halation
    case diffusion
    case grain
    case motion
}

private struct FilmtoneAdjustmentHelpSheet: View {
    let topic: FilmtoneAdjustmentHelpTopic
    let beforeLabel: String
    let afterLabel: String
    let effectLabel: String
    let guidanceLabel: String
    let dismissLabel: String
    let onDismiss: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                FilmtoneHelpComparisonImage(
                    style: topic.comparisonStyle,
                    beforeLabel: beforeLabel,
                    afterLabel: afterLabel
                )
                .accessibilityIdentifier("filmtone.help.adjustment.compare")

                Text(topic.copy.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier("filmtone.help.adjustment.body")

                VStack(alignment: .leading, spacing: 12) {
                    helpBlock(title: effectLabel, text: topic.copy.effect)
                    if let guidance = topic.copy.guidance {
                        helpBlock(title: guidanceLabel, text: guidance)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(Color.filmtoneBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(topic.copy.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.filmtoneAmber)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("filmtone.help.adjustment.title")

            Spacer(minLength: 12)

            Button(action: onDismiss) {
                Text(dismissLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.78))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("filmtone.help.adjustment.dismiss")
        }
    }

    private func helpBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.54))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct FilmtoneHelpComparisonImage: View {
    let style: FilmtoneAdjustmentComparisonStyle
    let beforeLabel: String
    let afterLabel: String

    var body: some View {
        HStack(spacing: 0) {
            sample(isAfter: false)
                .overlay(alignment: .topLeading) {
                    comparisonLabel(beforeLabel, isPrimary: false)
                        .padding(10)
                }

            sample(isAfter: true)
                .overlay(alignment: .topLeading) {
                    comparisonLabel(afterLabel, isPrimary: true)
                        .padding(10)
                }
        }
        .frame(height: 184)
        .clipShape(RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .overlay(alignment: .center) {
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 1)
        }
    }

    private func sample(isAfter: Bool) -> some View {
        FilmtoneHelpSampleFrame(style: style, isAfter: isAfter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    private func comparisonLabel(_ label: String, isPrimary: Bool) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isPrimary ? .black.opacity(0.88) : .white.opacity(0.82))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isPrimary ? Color.filmtoneAmber : Color.black.opacity(0.52))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isPrimary ? Color.clear : Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

private struct FilmtoneHelpSampleFrame: View {
    let style: FilmtoneAdjustmentComparisonStyle
    let isAfter: Bool

    var body: some View {
        ZStack {
            baseScene

            if isAfter {
                effectOverlay
            }

            if isAfter && (style == .grain) {
                grainOverlay
            }

            if isAfter && (style == .motion) {
                motionOverlay
            }
        }
        .brightness(isAfter ? brightnessDelta : 0)
        .contrast(isAfter ? contrastValue : 1)
        .saturation(isAfter ? saturationValue : 1)
        .blur(radius: isAfter ? blurRadius : 0)
        .overlay {
            if isAfter && (style == .vignette || style == .optics) {
                vignetteOverlay
            }
        }
    }

    private var baseScene: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.20, blue: 0.24),
                    Color(red: 0.31, green: 0.35, blue: 0.34),
                    Color(red: 0.12, green: 0.12, blue: 0.11),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Color.clear
                Rectangle()
                    .fill(Color.black.opacity(0.22))
                    .frame(height: 48)
            }

            Circle()
                .fill(Color.white.opacity(0.88))
                .frame(width: 26, height: 26)
                .offset(x: 40, y: -44)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.66, green: 0.57, blue: 0.47),
                            Color(red: 0.31, green: 0.27, blue: 0.24),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 78)
                .offset(x: -26, y: 24)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.black.opacity(0.42))
                .frame(width: 74, height: 10)
                .offset(x: -20, y: 70)
        }
    }

    @ViewBuilder
    private var effectOverlay: some View {
        switch style {
        case .strength, .quick, .advanced:
            Color.filmtoneAmber.opacity(0.13)
        case .exposure:
            Color.white.opacity(0.13)
        case .contrast:
            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.clear, Color.white.opacity(0.10)],
                startPoint: .bottom,
                endPoint: .top
            )
        case .saturation:
            LinearGradient(
                colors: [Color.orange.opacity(0.18), Color.filmtoneSky.opacity(0.14)],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        case .tone:
            LinearGradient(
                colors: [Color.filmtoneAmber.opacity(0.16), Color.blue.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .colorBalance:
            LinearGradient(
                colors: [
                    Color(red: 0.30, green: 0.86, blue: 0.92).opacity(0.18),
                    Color(red: 0.92, green: 0.30, blue: 0.78).opacity(0.12),
                    Color.yellow.opacity(0.14),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .highlight:
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.filmtoneAmber.opacity(0.10), Color.black.opacity(0.04)],
                startPoint: .topTrailing,
                endPoint: .bottom
            )
        case .optics, .softness, .diffusion:
            Color.white.opacity(0.08)
        case .colorFringe:
            colorFringeOverlay
        case .vignette:
            Color.clear
        case .glow, .bloom:
            glowOverlay(tint: Color.filmtoneAmber.opacity(0.44))
        case .halation:
            glowOverlay(tint: Color.red.opacity(0.34))
        case .grain:
            Color.black.opacity(0.02)
        case .motion:
            Color.filmtoneSky.opacity(0.08)
        }
    }

    private var brightnessDelta: Double {
        switch style {
        case .exposure:
            return 0.10
        case .highlight:
            return 0.04
        default:
            return 0
        }
    }

    private var contrastValue: Double {
        switch style {
        case .contrast, .tone:
            return 1.22
        case .highlight:
            return 0.92
        default:
            return 1
        }
    }

    private var saturationValue: Double {
        switch style {
        case .saturation:
            return 1.36
        case .tone, .colorBalance:
            return 1.12
        case .highlight, .softness, .diffusion:
            return 0.92
        default:
            return 1
        }
    }

    private var blurRadius: CGFloat {
        switch style {
        case .softness, .diffusion:
            return 0.85
        default:
            return 0
        }
    }

    private func glowOverlay(tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint)
                .frame(width: 78, height: 78)
                .blur(radius: 18)
                .offset(x: 40, y: -44)

            Circle()
                .stroke(tint.opacity(0.9), lineWidth: 7)
                .frame(width: 34, height: 34)
                .blur(radius: 4)
                .offset(x: 40, y: -44)
        }
    }

    private var colorFringeOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.red.opacity(0.48), lineWidth: 2)
                .frame(width: 50, height: 80)
                .offset(x: -30, y: 24)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.cyan.opacity(0.48), lineWidth: 2)
                .frame(width: 50, height: 80)
                .offset(x: -22, y: 24)
        }
    }

    private var vignetteOverlay: some View {
        RadialGradient(
            colors: [
                Color.clear,
                Color.clear,
                Color.black.opacity(0.46),
            ],
            center: .center,
            startRadius: 34,
            endRadius: 132
        )
    }

    private var grainOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<34, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 3) ? Color.white.opacity(0.18) : Color.black.opacity(0.22))
                        .frame(width: index.isMultiple(of: 4) ? 2.5 : 1.4, height: index.isMultiple(of: 4) ? 2.5 : 1.4)
                        .position(
                            x: geometry.size.width * CGFloat((index * 37) % 97) / 97,
                            y: geometry.size.height * CGFloat((index * 53) % 89) / 89
                        )
                }
            }
        }
    }

    private var motionOverlay: some View {
        ZStack {
            ForEach(1..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.filmtoneSky.opacity(0.10 / Double(index)))
                    .frame(width: 48, height: 78)
                    .offset(x: -26 - CGFloat(index * 12), y: 24)
            }

            LinearGradient(
                colors: [Color.clear, Color.filmtoneSky.opacity(0.18), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 34)
            .offset(y: 28)
        }
    }
}

private struct FilmtoneAdvancedParamGroup: Identifiable {
    let id: String
    let title: String
    let recipes: [FilmtoneAdvancedParamRecipe]
    let controls: [FilmtoneAdvancedParamControl]

    var keys: [String] {
        controls.map(\.key)
    }
}

private struct FilmtoneAdvancedParamRecipe: Identifiable {
    let id: String
    let label: String
    let values: (FilmtonePhase0Params) -> [String: Double]
}

private enum FilmtoneAdvancedRecipeSelection: Equatable {
    case recipe(String)
    case custom(activeCount: Int)
}

private struct FilmtoneAdvancedParamControl: Identifiable {
    let key: String
    let label: String
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var id: String { key }
}

private struct FilmtoneAdvancedParamGroupSection<Content: View>: View {
    let id: String
    let title: String
    let selection: FilmtoneAdvancedRecipeSelection
    let recipes: [FilmtoneAdvancedParamRecipe]
    let customLabel: String
    let helpAccessibilityLabel: String
    @Binding var isExpanded: Bool
    let onSelectRecipe: (FilmtoneAdvancedParamRecipe) -> Void
    let onHelp: () -> Void
    let content: Content

    private var disclosureAnimation: Animation {
        .smooth(duration: 0.22, extraBounce: 0)
    }

    init(
        id: String,
        title: String,
        selection: FilmtoneAdvancedRecipeSelection,
        recipes: [FilmtoneAdvancedParamRecipe],
        customLabel: String,
        helpAccessibilityLabel: String,
        isExpanded: Binding<Bool>,
        onSelectRecipe: @escaping (FilmtoneAdvancedParamRecipe) -> Void,
        onHelp: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.title = title
        self.selection = selection
        self.recipes = recipes
        self.customLabel = customLabel
        self.helpAccessibilityLabel = helpAccessibilityLabel
        self._isExpanded = isExpanded
        self.onSelectRecipe = onSelectRecipe
        self.onHelp = onHelp
        self.content = content()
    }

    var body: some View {
        let groupShape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Button {
                        withAnimation(disclosureAnimation) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.58))

                                Text(statusText)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(statusColor)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 12)

                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(isExpanded ? 0.88 : 0.62))
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color.white.opacity(isExpanded ? 0.08 : 0.035))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(Color.white.opacity(isExpanded ? 0.10 : 0.06), lineWidth: 1)
                                )
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("filmtone.sheet.advanced.group.\(id)")

                    FilmtoneHelpIconButton(
                        accessibilityLabel: helpAccessibilityLabel,
                        accessibilityIdentifier: "filmtone.help.advanced.group.\(id)",
                        action: onHelp
                    )
                    }

                HStack(spacing: 8) {
                    ForEach(recipes) { recipe in
                        FilmtoneParamPresetChip(
                            label: recipe.label,
                            isSelected: selection == .recipe(recipe.id),
                            accessibilityIdentifier: "filmtone.sheet.advanced.group.\(id).\(recipe.id)",
                            action: {
                                onSelectRecipe(recipe)
                            }
                        )
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            if isExpanded {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 14)

                content
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
        .background(
            groupShape
                .fill(Color.white.opacity(isExpanded ? 0.045 : 0.028))
        )
        .overlay(
            groupShape
                .stroke(Color.white.opacity(isExpanded ? 0.10 : 0.06), lineWidth: 1)
        )
        .clipShape(groupShape)
        .animation(disclosureAnimation, value: isExpanded)
        .animation(disclosureAnimation, value: selection)
    }

    private var statusText: String {
        switch selection {
        case .recipe(let id):
            return recipes.first(where: { $0.id == id })?.label ?? customLabel
        case .custom:
            return customLabel
        }
    }

    private var statusColor: Color {
        switch selection {
        case .recipe(let id) where recipes.first?.id == id:
            return .white.opacity(0.74)
        case .recipe, .custom(_):
            return Color.filmtoneAmber.opacity(0.88)
        }
    }
}

private struct FilmtoneParamPresetChip: View {
    let label: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .black.opacity(0.88) : .white.opacity(0.78))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.filmtoneAmber : Color.white.opacity(0.045))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct FilmtoneHelpIconButton: View {
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.filmtoneAmber.opacity(0.84))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct FilmtoneDisclosureSection<Content: View>: View {
    let title: String
    let summary: String
    let accessibilityIdentifier: String
    let contentSpacing: CGFloat
    let helpAccessibilityLabel: String?
    @Binding var isExpanded: Bool
    let helpAction: (() -> Void)?
    let content: Content

    private var disclosureAnimation: Animation {
        .smooth(duration: 0.24, extraBounce: 0)
    }

    init(
        title: String,
        summary: String,
        accessibilityIdentifier: String,
        isExpanded: Binding<Bool>,
        contentSpacing: CGFloat = 16,
        helpAccessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            summary: summary,
            accessibilityIdentifier: accessibilityIdentifier,
            isExpanded: isExpanded,
            contentSpacing: contentSpacing,
            helpAccessibilityLabel: helpAccessibilityLabel,
            helpAction: nil,
            content: content
        )
    }

    init(
        title: String,
        summary: String,
        accessibilityIdentifier: String,
        isExpanded: Binding<Bool>,
        contentSpacing: CGFloat = 16,
        helpAccessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content,
        helpAction: @escaping () -> Void
    ) {
        self.title = title
        self.summary = summary
        self.accessibilityIdentifier = accessibilityIdentifier
        self._isExpanded = isExpanded
        self.contentSpacing = contentSpacing
        self.helpAccessibilityLabel = helpAccessibilityLabel
        self.helpAction = helpAction
        self.content = content()
    }

    private init(
        title: String,
        summary: String,
        accessibilityIdentifier: String,
        isExpanded: Binding<Bool>,
        contentSpacing: CGFloat,
        helpAccessibilityLabel: String?,
        helpAction: (() -> Void)?,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.summary = summary
        self.accessibilityIdentifier = accessibilityIdentifier
        self._isExpanded = isExpanded
        self.contentSpacing = contentSpacing
        self.helpAccessibilityLabel = helpAccessibilityLabel
        self.helpAction = helpAction
        self.content = content()
    }

    var body: some View {
        let sectionShape = RoundedRectangle(
            cornerRadius: filmtoneSurfaceCornerRadius,
            style: .continuous
        )

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Button {
                    withAnimation(disclosureAnimation) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(isExpanded ? 0.64 : 0.52))

                            if !summary.isEmpty {
                                Text(summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(isExpanded ? 0.84 : 0.76))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                        }

                        Spacer(minLength: 12)

                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(isExpanded ? 0.88 : 0.62))
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(isExpanded ? 0.08 : 0.035))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(isExpanded ? 0.10 : 0.06), lineWidth: 1)
                            )
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(accessibilityIdentifier)

                if let helpAction, let helpAccessibilityLabel {
                    FilmtoneHelpIconButton(
                        accessibilityLabel: helpAccessibilityLabel,
                        accessibilityIdentifier: "\(accessibilityIdentifier).help",
                        action: helpAction
                    )
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .opacity(isExpanded ? 1 : 0)

            if isExpanded {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
        .background(
            sectionShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isExpanded ? 0.06 : 0.045),
                            Color.white.opacity(isExpanded ? 0.028 : 0.02),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            sectionShape
                .stroke(
                    Color.white.opacity(isExpanded ? 0.10 : 0.07),
                    lineWidth: 1
                )
        )
        .clipShape(sectionShape)
        .animation(disclosureAnimation, value: isExpanded)
    }
}

private struct FilmtoneSliderRow: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String
    var isActive = false
    let helpAccessibilityLabel: String
    let accessibilityIdentifier: String
    let onChange: (Double) -> Void
    let helpAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isActive ? Color.filmtoneAmber.opacity(0.92) : .white.opacity(0.92))

                FilmtoneHelpIconButton(
                    accessibilityLabel: helpAccessibilityLabel,
                    accessibilityIdentifier: "\(accessibilityIdentifier).help",
                    action: helpAction
                )

                Spacer()

                Text(format(value))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(isActive ? Color.filmtoneAmber.opacity(0.82) : .white.opacity(0.66))
            }

            Slider(value: Binding(get: { value }, set: onChange), in: range)
                .tint(Color.filmtoneAmber)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}

struct FilmtoneSheetPrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .fill(Color.filmtoneAmber.opacity(configuration.isPressed ? 0.84 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct FilmtoneSheetSecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private extension View {
    func sectionDivider() -> some View {
        overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
        .padding(.top, 8)
    }
}
