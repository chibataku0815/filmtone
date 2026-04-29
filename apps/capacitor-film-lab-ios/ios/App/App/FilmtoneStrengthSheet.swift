import Foundation
import SwiftUI
import UIKit

struct FilmtoneStrengthSheet: View {
    @ObservedObject var store: FilmtoneEditorStore
    let onClose: () -> Void

    @State private var adjustmentsExpanded = false
    @State private var advancedParamsExpanded = false
    @State private var expandedAdvancedGroupIds: Set<String> = []

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
                Button(store.strings.resetLabel) {
                    store.resetAdjustments()
                }
                .buttonStyle(FilmtoneSheetSecondaryActionStyle())

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
                accessibilityIdentifier: "filmtone.sheet.slider.strength"
            ) { value in
                store.setStrength(value)
            }
        }
        .sectionDivider()
    }

    private var adjustmentsSection: some View {
        FilmtoneDisclosureSection(
            title: store.strings.adjustLabel,
            summary: quickSummaryText,
            accessibilityIdentifier: "filmtone.sheet.adjustments",
            isExpanded: $adjustmentsExpanded
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
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.filmCharacter"
                    ) { value in
                        store.setQuickValue(value, for: \.filmCharacter)
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickEra,
                        value: store.project.quickState.era,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) },
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.era"
                    ) { value in
                        store.setQuickValue(value, for: \.era)
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickDynamics,
                        value: store.project.quickState.dynamics,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) },
                        accessibilityIdentifier: "filmtone.sheet.slider.quick.dynamics"
                    ) { value in
                        store.setQuickValue(value, for: \.dynamics)
                    }
            }
        }
    }

    private var advancedParamsSection: some View {
        FilmtoneDisclosureSection(
            title: store.strings.advancedParamsLabel,
            summary: store.advancedSummaryText,
            accessibilityIdentifier: "filmtone.sheet.advanced",
            isExpanded: $advancedParamsExpanded,
            contentSpacing: 20
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(advancedParamGroups) { group in
                    advancedGroupSection(group)
                }
            }
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
                        accessibilityIdentifier: "filmtone.sheet.slider.param.\(control.key)"
                    ) { value in
                        store.setParamOverride(value, for: control.key)
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
    @Binding var isExpanded: Bool
    let onSelectRecipe: (FilmtoneAdvancedParamRecipe) -> Void
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
        isExpanded: Binding<Bool>,
        onSelectRecipe: @escaping (FilmtoneAdvancedParamRecipe) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.title = title
        self.selection = selection
        self.recipes = recipes
        self.customLabel = customLabel
        self._isExpanded = isExpanded
        self.onSelectRecipe = onSelectRecipe
        self.content = content()
    }

    var body: some View {
        let groupShape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
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

private struct FilmtoneDisclosureSection<Content: View>: View {
    let title: String
    let summary: String
    let accessibilityIdentifier: String
    let contentSpacing: CGFloat
    @Binding var isExpanded: Bool
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
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.summary = summary
        self.accessibilityIdentifier = accessibilityIdentifier
        self._isExpanded = isExpanded
        self.contentSpacing = contentSpacing
        self.content = content()
    }

    var body: some View {
        let sectionShape = RoundedRectangle(
            cornerRadius: filmtoneSurfaceCornerRadius,
            style: .continuous
        )

        VStack(alignment: .leading, spacing: 0) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityIdentifier)

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
    let accessibilityIdentifier: String
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isActive ? Color.filmtoneAmber.opacity(0.92) : .white.opacity(0.92))

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
