import SwiftUI


struct FilmtoneAdjustmentHelpTopic: Identifiable {
    let id: String
    let copy: FilmtoneAdjustmentHelpCopy
    let comparisonStyle: FilmtoneAdjustmentComparisonStyle
}

enum FilmtoneAdjustmentComparisonStyle: Equatable {
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

extension FilmtoneAdjustmentComparisonStyle {
    enum Family: String {
        case strength
        case exposure
        case contrast
        case saturation
        case tone
        case optics
        case glow
        case halation
        case grain
        case motion

        var beforeAssetName: String {
            switch self {
            case .strength, .optics, .glow, .halation:
                return "HelpCompareSceneGlow"
            case .exposure, .contrast, .saturation, .tone, .grain, .motion:
                return "HelpCompareSceneSkin"
            }
        }

        var afterAssetName: String {
            switch self {
            case .strength: return "HelpCompareStrengthAfter"
            case .exposure: return "HelpCompareExposureAfter"
            case .contrast: return "HelpCompareContrastAfter"
            case .saturation: return "HelpCompareSaturationAfter"
            case .tone: return "HelpCompareToneAfter"
            case .optics: return "HelpCompareOpticsAfter"
            case .glow: return "HelpCompareGlowAfter"
            case .halation: return "HelpCompareHalationAfter"
            case .grain: return "HelpCompareGrainAfter"
            case .motion: return "HelpCompareMotionAfter"
            }
        }
    }

    var family: Family {
        switch self {
        case .strength, .quick, .advanced:
            return .strength
        case .exposure:
            return .exposure
        case .contrast:
            return .contrast
        case .saturation, .colorBalance:
            return .saturation
        case .tone, .highlight:
            return .tone
        case .optics, .softness, .vignette, .colorFringe, .diffusion:
            return .optics
        case .glow, .bloom:
            return .glow
        case .halation:
            return .halation
        case .grain:
            return .grain
        case .motion:
            return .motion
        }
    }
}

struct FilmtoneAdjustmentHelpSheet: View {
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
        Image(isAfter ? style.family.afterAssetName : style.family.beforeAssetName)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}
