import Foundation
import SwiftUI
import UIKit

struct FilmtoneStrengthSheet: View {
    @ObservedObject var store: FilmtoneEditorStore
    let onClose: () -> Void

    @State private var adjustmentsExpanded = false
    @State private var advancedParamsExpanded = false

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

                Text(store.adjustmentSummaryText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(2)
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
        VStack(alignment: .leading, spacing: 8) {
            FilmtoneSheetPreview(
                source: store.source,
                displayURI: store.selectedPreviewURI,
                emptyMessage: previewEmptyMessage,
                hintMessage: store.strings.previewSheetHint,
                compareLabel: store.strings.compareLabel,
                metaLabel: store.previewMetaLabel,
                isRendering: store.preview.isRendering,
                isComparing: store.isCompareHeld,
                onCompareHeld: store.setCompareHeld
            )

            Text(store.strings.compareHint)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.56))
        }
    }

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.strings.strengthLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.52))
                        .textCase(.uppercase)

                    Text(Self.percentLabel(store.project.strength))
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()
            }

            FilmtoneSliderRow(
                label: store.strings.strengthLabel,
                value: store.project.strength,
                range: 0...1,
                format: { Self.percentLabel($0) }
            ) { value in
                store.setStrength(value)
            }
        }
        .sectionDivider()
    }

    private var adjustmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    adjustmentsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.strings.adjustLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                            .textCase(.uppercase)

                        Text(quickSummaryText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.leading)
                            .lineLimit(adjustmentsExpanded ? nil : 2)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .rotationEffect(.degrees(adjustmentsExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if adjustmentsExpanded {
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
                        format: { Self.signedPercentLabel($0) }
                    ) { value in
                        store.setQuickValue(value, for: \.filmCharacter)
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickEra,
                        value: store.project.quickState.era,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) }
                    ) { value in
                        store.setQuickValue(value, for: \.era)
                    }

                    FilmtoneSliderRow(
                        label: store.strings.quickDynamics,
                        value: store.project.quickState.dynamics,
                        range: -1...1,
                        format: { Self.signedPercentLabel($0) }
                    ) { value in
                        store.setQuickValue(value, for: \.dynamics)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sectionDivider()
    }

    private var advancedParamsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    advancedParamsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.strings.advancedParamsLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                            .textCase(.uppercase)

                        Text(store.advancedSummaryText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.leading)
                            .lineLimit(advancedParamsExpanded ? nil : 2)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .rotationEffect(.degrees(advancedParamsExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if advancedParamsExpanded {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(advancedParamGroups) { group in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(group.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.52))
                                .textCase(.uppercase)

                            ForEach(group.controls) { control in
                                FilmtoneSliderRow(
                                    label: control.label,
                                    value: store.effectiveParamValue(for: control.key),
                                    range: control.range,
                                    format: control.format,
                                    isActive: store.isParamOverridden(control.key)
                                ) { value in
                                    store.setParamOverride(value, for: control.key)
                                }
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sectionDivider()
    }

    private var quickSummaryText: String {
        store.hasQuickAdjustments ? store.quickSummaryText : store.strings.quickHint
    }

    private var previewEmptyMessage: String {
        if let error = store.preview.error {
            return error
        }
        if store.source == nil {
            return store.strings.sourceEmpty
        }
        return store.strings.previewRendering
    }

    private var advancedParamGroups: [FilmtoneAdvancedParamGroup] {
        [
            .init(
                id: "basic",
                title: store.strings.advancedBasicLabel,
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
                id: "optics",
                title: store.strings.advancedOpticsLabel,
                controls: [
                    control("rgbShift", range: 0...FilmtonePhase0Math.rgbShiftMax, digits: 3),
                    control("lensSoftness", range: 0...1),
                    control("vignette", range: 0...1),
                ]
            ),
            .init(
                id: "glow",
                title: store.strings.advancedGlowLabel,
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
                controls: [
                    control("grainIntensity", range: 0...1),
                    control("grainSize", range: 0...1),
                    control("grainRadialMix", range: 0...1),
                ]
            ),
            .init(
                id: "tone",
                title: store.strings.advancedToneLabel,
                controls: [
                    control("compressionAmount", range: 0...1),
                    control("compressionRange", range: 0...1),
                ]
            ),
        ]
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
    let source: SourceInfoDTO?
    let displayURI: String?
    let emptyMessage: String
    let hintMessage: String
    let compareLabel: String
    let metaLabel: String?
    let isRendering: Bool
    let isComparing: Bool
    let onCompareHeld: (Bool) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.black)

            if let source, let displayURI, let image = previewImage(from: displayURI) {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(Rectangle())
                        .onLongPressGesture(
                            minimumDuration: 0.18,
                            maximumDistance: 24,
                            pressing: { isPressing in
                                if source.filename.isEmpty {
                                    return
                                }
                                onCompareHeld(isPressing)
                            },
                            perform: {}
                        )
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(emptyMessage)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineSpacing(2)

                    Text(hintMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.52))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(16)
            }

            if isComparing {
                Text(compareLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.filmtoneAmber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.65))
                    .padding(12)
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
                            .background(Color.black.opacity(0.5))
                            .padding(12)
                    }
                }
            }

            if isRendering {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.filmtoneAmber)

                        Text(emptyMessage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.82))

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.6))
                }
                .padding(12)
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
}

private struct FilmtoneAdvancedParamGroup: Identifiable {
    let id: String
    let title: String
    let controls: [FilmtoneAdvancedParamControl]
}

private struct FilmtoneAdvancedParamControl: Identifiable {
    let key: String
    let label: String
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var id: String { key }
}

private struct FilmtoneSliderRow: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String
    var isActive = false
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
                Rectangle()
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
                Rectangle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.04))
            )
            .overlay(
                Rectangle()
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
